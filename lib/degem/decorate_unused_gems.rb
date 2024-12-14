# frozen_string_literal: true

module Degem
  class DecorateUnusedGems
    def initialize(gem_specification:, git_adapter:)
      @gem_specification = gem_specification
      @git_adapter = git_adapter
    end

    def call(rubygems)
      rubygems.map do |rubygem|
        gemspec = @gem_specification.find_by_name(rubygem.name)
        git = @git_adapter.call(rubygem.name)
        UnusedGem.new(rubygem, gemspec, git)
      end
    end
  end
end
