# frozen_string_literal: true

module Degem
  class ParseGemfile
    def initialize(gem_specification = Gem::Specification)
      @gem_specification = gem_specification
    end

    def call(gemfile_path)
      dsl = Bundler::Dsl.new
      dsl.eval_gemfile(gemfile_path)
      Gemfile.new(dsl: dsl, gem_specification: @gem_specification)
    end

    private

    def definition(gemfile_path)
      Bundler::Dsl.evaluate(gemfile_path, nil, {})
    end
  end
end
