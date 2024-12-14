# frozen_string_literal: true

module Degem
  class Cli
    GEMFILE = "Gemfile"

    def self.call
      exit new($stderr).call
    end

    def initialize(stderr)
      Degem.stderr = stderr
    end

    def call
      unless gemfile_exists?
        Degem.stderr.puts "Gemfile not found in the current directory"
        return 1
      end

      unused = find_unused.call
      decorated = decorate_rubygems.call(unused)
      Report.new.call(decorated)
      0
    end

    private

    def find_unused
      FindUnused.new(gemfile_path: GEMFILE)
    end

    def decorate_rubygems
      DecorateUnusedGems.new(
        gem_specification: Gem::Specification,
        git_adapter: GitAdapter.new
      )
    end

    def gemfile_exists?
      File.file?(GEMFILE)
    end
  end
end
