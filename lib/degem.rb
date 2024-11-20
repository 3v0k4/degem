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
      gems(gemfile_path).filter_map do |gem_|
        next gem_ unless gem_.name.include?("-")

        top_level = gem_.name.split("-").map(&:capitalize).join("::")
        gem_ unless found?(top_level, File.dirname(gemfile_path))
      end
    end

    private

    def gems(gemfile_path)
      ParseGemfile.new.call(gemfile_path).gems
    end

    def found?(string, dir)
      Open3
        .capture3("rg -g '*.rb' -g -l '\\b#{string}\\b' #{dir}")
        .last
        .exitstatus
        .zero?
    end
  end
end
