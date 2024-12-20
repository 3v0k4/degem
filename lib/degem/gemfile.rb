# frozen_string_literal: true

module Degem
  class Gemfile
    def initialize(dsl:, gem_specification:)
      @dsl = dsl
      @gem_specification = gem_specification
    end

    def rubygems
      @rubygems ||=
        (gemfile_dependencies + gemspec_dependencies)
        .map { Rubygem.new(rubygem: _1, gem_specification: @gem_specification) }
        .uniq
    end

    def rails?
      !!rubygems.find(&:rails?)
    end

    private

    def gemfile_dependencies
      @dsl.dependencies.select(&:should_include?).reject do |dependency|
        @dsl.gemspecs.flat_map(&:name).include?(dependency.name)
      end
    end

    def gemspec_dependencies
      @dsl.gemspecs.flat_map(&:dependencies)
    end
  end
end
