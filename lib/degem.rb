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
end
