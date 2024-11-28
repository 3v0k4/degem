# frozen_string_literal: true

require_relative "degem/version"

module Degem
  class Gemfile
    def initialize(definition)
      @definition = definition
    end

    def rubygems
      @rubygems ||= @definition.dependencies
    end

    def rails?
      rubygems.map(&:name).include?("rails")
    end
  end

  class ParseGemfile
    def call(gemfile_path)
      Gemfile.new(definition(gemfile_path))
    end

    private

    def definition(gemfile_path)
      Bundler::Dsl.evaluate(gemfile_path, nil, {})
    end
  end

  class FindUnused
    require "open3"

    def initialize(gemfile_path)
      @gemfile_path = gemfile_path
    end

    def call
      rubygems.filter_map do |rubygem|
        rubygem unless finders.any? { _1.call(rubygem) }
      end
    end

    private

    attr_reader :gemfile_path

    def finders
      [
        method(:based_on_top_module),
        method(:based_on_top_const),
        method(:based_on_require),
        method(:based_on_required_path),
        (method(:based_on_railtie) if rails?),
        (method(:based_on_rails) if rails?)
      ].compact
    end

    def gemfile
      @gemfile = ParseGemfile.new.call(gemfile_path)
    end

    def rails?
      @rails ||= gemfile.rails?
    end

    def rubygems
      @rubygems ||= gemfile.rubygems
    end

    def found?(pattern, dir)
      Open3
        .capture3("rg -g '*.rb' -g -l \"#{pattern}\" #{dir}")
        .last
        .exitstatus
        .zero?
    end

    def based_on_top_module(rubygem)
      return false unless rubygem.name.include?("-")

      pattern = "^\\b#{rubygem.name.split("-").map(&:capitalize).join("::")}\\b"
      found?(pattern, File.dirname(gemfile_path))
    end

    def based_on_top_const(rubygem)
      return false unless rubygem.name.include?("-")

      pattern = "^\\b#{rubygem.name.split("-").map(&:capitalize).join("")}\\b"
      found?(pattern, File.dirname(gemfile_path))
    end

    def based_on_require(rubygem)
      pattern = "^\\s*require\\s+['\\\"]#{rubygem.name}['\\\"]"
      found?(pattern, File.dirname(gemfile_path))
    end

    def based_on_required_path(rubygem)
      return false unless rubygem.name.include?("-")

      pattern = "^\\s*require\\s+['\\\"]#{rubygem.name.gsub("-", "\/")}['\\\"]"
      found?(pattern, File.dirname(gemfile_path))
    end

    def based_on_railtie(rubygem)
      gem_path = Gem::Specification.find_by_name(rubygem.name).full_gem_path

      [
        found?("Rails::Railtie", gem_path),
        found?("Rails::Engine", gem_path)
      ].any?
    end

    def based_on_rails(rubygem)
      ["rails"].include?(rubygem.name)
    end
  end

  class MultiDelegator
    def initialize(*delegates)
      @delegates = delegates
    end

    def method_missing(method, *args, &block)
      delegate = @delegates.find { _1.respond_to?(method) }
      return delegate.public_send(method, *args, &block) if delegate

      super
    end

    def respond_to_missing?(method, include_private = false)
      @delegates.any? { _1.respond_to?(method, include_private) } || super
    end
  end

  class Decorated < MultiDelegator
    def source_code_uri
      metadata["source_code_uri"] || homepage
    end
  end

  class Decorate
    def call(rubygems:, git_adapter:, host_adapter:)
      rubygems.map do |rubygem|
        gemspec = Gem::Specification.find_by_name(rubygem.name)
        git = git_adapter.call(rubygem.name)
        host = host_adapter.call(rubygem.name)
        Decorated.new(rubygem, gemspec, git, host)
      end
    end
  end

  class GitAdapter
    private

    def commit_uris(origin_url, commit_hashes)
      commit_hashes.map do |commit_hash|
        to_commit_url(origin_url, commit_hash)
      end
    end

    def parse(origin_url)
      origin_url.match(%r{github\.com[:/](.+?)(\.git)?$})[1]
    end

    def to_commit_url(origin_url, commit_hash)
      repository = parse(origin_url)
      "https://github.com/#{repository}/commit/#{commit_hash}"
    end
  end

  class GithubAdapter
  end
end
