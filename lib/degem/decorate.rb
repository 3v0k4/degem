module Degem
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
end
