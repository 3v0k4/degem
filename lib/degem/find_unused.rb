# frozen_string_literal: true

module Degem
  class FindUnused
    def initialize(gemfile_path:, gem_specification: Gem::Specification, bundle_paths: GitLsFiles.new)
      @gemfile_path = gemfile_path
      @gem_specification = gem_specification
      fallback = Dir.glob(File.join(File.dirname(gemfile_path), "**/*.rb"))
      @bundle_paths = bundle_paths.call(fallback)
    end

    def call
      rubygems = gemfile.rubygems.reject { _1.name == "degem" }
      rubygems = reject_railties(rubygems) if gemfile.rails?
      reject_used(rubygems)
    end

    private

    attr_reader :gemfile_path

    def reject_railties(rubygems)
      rubygems.reject(&:rails?).reject(&:railtie?)
    end

    def reject_used(rubygems)
      bundle = ParseRuby.new.call(@bundle_paths)
      rubygems = reject_required(rubygems, bundle.requires)
      reject_consts(rubygems, bundle.consts)
    end

    def reject_consts(rubygems, bundle_consts)
      rubygems.reject do |rubygem|
        rubygem.own_consts.any? do |own_const|
          bundle_consts.include?(own_const)
        end
      end
    end

    def reject_required(rubygems, bundle_requires)
      rubygems.reject do |rubygem|
        bundle_requires.any? do |bundle_require|
          next true if bundle_require == rubygem.name
          next true if bundle_require == rubygem.name.tr("-", "/")

          bundle_require.start_with?("#{rubygem.name}/")
        end
      end
    end

    def gemfile
      @gemfile ||= ParseGemfile.new(@gem_specification).call(gemfile_path)
    end
  end
end
