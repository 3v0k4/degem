# frozen_string_literal: true

require_relative "degem/version"

module Degem
  class Gemfile
    def initialize(dsl)
      @dsl = dsl
    end

    def rubygems
      @rubygems ||= gemfile_dependencies + gemspec_dependencies
    end

    def rails?
      @rails ||= rubygems.map(&:name).include?("rails")
    end

    private

    def gemfile_dependencies
      @dsl.dependencies.select(&:should_include?)
    end

    def gemspec_dependencies
      @dsl.gemspecs.flat_map(&:dependencies)
    end
  end

  class ParseGemfile
    def call(gemfile_path)
      dsl = Bundler::Dsl.new
      dsl.eval_gemfile(gemfile_path)
      Gemfile.new(dsl)
    end

    private

    def definition(gemfile_path)
      Bundler::Dsl.evaluate(gemfile_path, nil, {})
    end
  end

  class Grep
    require "find"

    def initialize(stderr = StringIO.new)
      @stderr = stderr
    end

    def inverse?(matcher, dir)
      Find.find(File.expand_path(dir)) do |path|
        next unless File.file?(path)
        next if File.extname(path) != ".rb"

        @stderr.putc "."
        File.foreach(path) do |line|
          next unless matcher.match?(line)

          return true
        end
      end

      false
    end

    def inverse_many(matchers, paths)
      Find.find(*paths) do |path|
        next unless File.file?(path)

        @stderr.putc "."
        File.foreach(path) do |line|
          matchers = matchers.reject do |matcher|
            matcher.match?(line)
          end
        end
      end

      matchers
    end
  end

  class GitLsFiles
    require "open3"

    def call(fallback)
      out, _err, status = git_ls
      return fallback unless status.zero?

      out.split("\x0").select { _1.end_with?(".rb") }.map { File.expand_path(_1).to_s }
    end

    private

    def git_ls
      out, err, status = Open3.capture3("git ls-files -z")
      [out, err, status.exitstatus]
    end
  end

  class Matcher
    attr_reader :rubygem

    def initialize(rubygem:, matchers:)
      @rubygem = rubygem
      @matchers = matchers
    end

    def match?(string)
      @matchers.any? { _1.call(@rubygem, string) }
    end
  end

  class FindUnused
    def initialize(gemfile_path:, gem_specification:, grep: Grep.new, bundle_paths: GitLsFiles.new)
      @gemfile_path = gemfile_path
      @gem_specification = gem_specification
      @grep = grep
      @bundle_paths = bundle_paths.call(File.dirname(gemfile_path))
    end

    def call
      rubygems = gemfile.rubygems.reject { _1.name == "degem" }
      rubygems = reject_railties(rubygems) if rails?
      reject_used(rubygems)
    end

    private

    attr_reader :gemfile_path

    def reject_railties(rubygems)
      rubygems
        .reject { _1.name == "rails" }
        .reject do |rubygem|
          gem_path = @gem_specification.find_by_name(rubygem.name).full_gem_path
          @grep.inverse?(/(Rails::Railtie|Rails::Engine)/, gem_path)
        end
    end

    def reject_used(rubygems)
      candidates = rubygems.map { Matcher.new(rubygem: _1, matchers: matchers) }
      @grep.inverse_many(candidates, @bundle_paths).map(&:rubygem)
    end

    def matchers
      [
        method(:based_on_top_module),
        method(:based_on_top_composite_module),
        method(:based_on_top_call),
        method(:based_on_top_composite_call),
        method(:based_on_require),
        method(:based_on_require_prefix_path),
        method(:based_on_require_path)
      ].compact
    end

    def gemfile
      @gemfile = ParseGemfile.new.call(gemfile_path)
    end

    def rails?
      @rails ||= gemfile.rails?
    end

    # gem foo -> Foo:: (but not XFoo:: or X::Foo)
    def based_on_top_module(rubygem, line)
      return false if rubygem.name.include?("-")

      regex = %r{
        (?<!\w::) # Do not match if :: before
        (?<!\w) # Do not match if \w before
        #{rubygem.name.capitalize}
        ::
      }x
      regex.match?(line)
    end

    # gem foo-bar -> Foo::Bar (but not XFoo::Bar or X::Foo::Bar)
    def based_on_top_composite_module(rubygem, line)
      return false unless rubygem.name.include?("-")

      regex = %r{
        (?<!\w::) # Do not match if :: before
        (?<!\w) # Do not match if \w before
        #{rubygem.name.split("-").map(&:capitalize).join("::")}
      }x
      regex.match?(line)
    end

    # gem foo -> Foo. (but not X::Foo. or XBar.)
    def based_on_top_call(rubygem, line)
      return false if rubygem.name.include?("-")

      regex = %r{
        (?<!\w::) # Do not match if :: before
        (?<!\w) # Do not match if \w before
        #{rubygem.name.capitalize}
        \.
      }x
      regex.match?(line)
    end

    # gem foo-bar -> FooBar. (but not X::FooBar. or XFooBar.)
    def based_on_top_composite_call(rubygem, line)
      return false unless rubygem.name.include?("-")

      regex = %r{
        (?<!\w::) # Do not match if :: before
        (?<!\w) # Do not match if \w before
        #{rubygem.name.split("-").map(&:capitalize).join("")}
        \.
      }x
      regex.match?(line)
    end

    # gem foo-bar -> require 'foo-bar'
    def based_on_require(rubygem, line)
      regex = %r{
        ^
        \s*
        require
        \s+
        ['"]
        #{rubygem.name}
        ['"]
      }x
      regex.match?(line)
    end

    # gem foo-bar -> require 'foo/bar'
    def based_on_require_path(rubygem, line)
      return false unless rubygem.name.include?("-")

      regex = %r{
        ^
        \s*
        require
        \s+
        ['"]
        #{rubygem.name.gsub("-", "\/")} # match foo/bar when rubygem is foo-bar
        ['"]
      }x
      regex.match?(line)
    end

    # gem foo -> require 'foo/'
    def based_on_require_prefix_path(rubygem, line)
      return false if rubygem.name.include?("-")

      regex = %r{
        ^
        \s*
        require
        \s+
        ['"]
        #{rubygem.name}
        /
      }x
      regex.match?(line)
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
    attr_reader :commits

    def initialize(_, _, commits)
      super
      @commits = commits
    end

    def source_code_uri
      metadata["source_code_uri"] || homepage
    end
  end

  class Decorate
    def initialize(gem_specification:)
      @gem_specification = gem_specification
    end

    def call(rubygems:, git_adapter:)
      rubygems.map do |rubygem|
        gemspec = @gem_specification.find_by_name(rubygem.name)
        git = git_adapter.call(rubygem.name)
        Decorated.new(rubygem, gemspec, git)
      end
    end
  end

  class GitAdapter
    require "ostruct"
    require "open3"

    def call(gem_name)
      out, _err, status = git_log(gem_name)
      return [] unless status.zero?

      out.split("\n").map do |raw_commit|
        hash, date, title = raw_commit.split("\t")
        OpenStruct.new(hash:, date:, title:, url: to_commit_url(hash))
      end
    end

    private

    def git_remote_origin_url
      out, err, status = Open3.capture3("git remote get-url origin")
      [out, err, status.exitstatus]
    end

    def git_log(gem_name)
      out, err, status = Open3.capture3("git log --pretty=format:'%H%x09%cs%x09%s' --pickaxe-regex -S '#{gem_name}' -- Gemfile | cat")
      [out, err, status.exitstatus]
    end

    def to_commit_url(commit_hash)
      remote, _, status = git_remote_origin_url
      return "" unless status.zero?

      repository = (remote.match(%r{github\.com[:/](.+?)(\.git)}) || [])[1]
      return "" if repository.nil?

      "https://github.com/#{repository}/commit/#{commit_hash}"
    end
  end

  class Report
    def initialize(stderr)
      @stderr = stderr
    end

    def call(decorateds)
      decorateds.each do |decorated|
        heading =
          if decorated.source_code_uri.nil?
            decorated.name
          else
            "#{decorated.name}: #{decorated.source_code_uri}"
          end
        @stderr.puts(heading)
        @stderr.puts("=" * heading.size)
        @stderr.puts

        decorated.commits.each.with_index do |commit, i|
          @stderr.puts("#{commit.hash[0..6]} (#{commit.date}) #{commit.title}")
          @stderr.puts(commit.url)
          @stderr.puts if i+1 == decorated.commits.size
        end

        @stderr.puts
      end
    end
  end

  class Cli
    GEMFILE = "Gemfile"

    def self.call
      exit new($stderr).call
    end

    def initialize(stderr)
      @stderr = stderr
    end

    def call
      unless gemfile_exists?
        @stderr.puts "Gemfile not found in the current directory"
        return 1
      end

      rubygems = FindUnused
        .new(gemfile_path: GEMFILE, gem_specification: Gem::Specification, grep: Grep.new(@stderr))
        .call
      decorated = Decorate
        .new(gem_specification: Gem::Specification)
        .call(rubygems:, git_adapter: GitAdapter.new)
      Report.new(@stderr).call(decorated)
      0
    end

    private

    def gemfile_exists?
      File.file?(GEMFILE)
    end
  end
end
