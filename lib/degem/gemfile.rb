# frozen_string_literal: true

module Degem
  class Gemfile
    def initialize(dsl)
      @dsl = dsl
    end

    def rubygems
      @rubygems ||= (gemfile_dependencies + gemspec_dependencies).uniq
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
end
