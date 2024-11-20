# frozen_string_literal: true

require_relative "degem/version"

module Degem
  class Gemfile
    def initialize(definition)
      @definition = definition
    end

    def gems
      @gems ||= @definition.dependencies
    end

    def rails?
      gems.map(&:name).include?("rails")
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

    def call(gemfile_path)
      finders = [
        method(:based_on_top_module),
        method(:based_on_top_const),
        method(:based_on_require),
        method(:based_on_required_path)
      ]
      based_on(finders, gemfile_path)
    end

    private

    def gems(gemfile_path)
      ParseGemfile.new.call(gemfile_path).gems
    end

    def found?(pattern, dir)
      Open3
        .capture3("rg -g '*.rb' -g -l \"#{pattern}\" #{dir}")
        .last
        .exitstatus
        .zero?
    end

    def based_on(finders, gemfile_path)
      gems(gemfile_path).filter_map do |gem_|
        gem_ unless finders.any? { _1.call(gemfile_path, gem_) }
      end
    end

    def based_on_top_module(gemfile_path, gem_)
      return false unless gem_.name.include?("-")

      pattern = "^\\b#{gem_.name.split("-").map(&:capitalize).join("::")}\\b"
      found?(pattern, File.dirname(gemfile_path))
    end

    def based_on_top_const(gemfile_path, gem_)
      return false unless gem_.name.include?("-")

      pattern = "^\\b#{gem_.name.split("-").map(&:capitalize).join("")}\\b"
      found?(pattern, File.dirname(gemfile_path))
    end

    def based_on_require(gemfile_path, gem_)
      pattern = "^\\s*require\\s+['\\\"]#{gem_.name}['\\\"]"
      found?(pattern, File.dirname(gemfile_path))
    end

    def based_on_required_path(gemfile_path, gem_)
      return false unless gem_.name.include?("-")

      pattern = "^\\s*require\\s+['\\\"]foo/bar['\\\"]"
      found?(pattern, File.dirname(gemfile_path))
    end
  end
end
