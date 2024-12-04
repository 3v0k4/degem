module Degem
  class Cli
    GEMFILE = "Gemfile"

    def self.call
      exit new($stderr).call
    end

    def initialize(stderr)
      @stderr = stderr
    end

    def call
      unless gemfile_exists?
        @stderr.puts "Gemfile not found in the current directory"
        return 1
      end

      rubygems = FindUnused
        .new(gemfile_path: GEMFILE, gem_specification: Gem::Specification, grep: Grep.new(@stderr))
        .call
      decorated = Decorate
        .new(gem_specification: Gem::Specification)
        .call(rubygems:, git_adapter: GitAdapter.new)
      Report.new(@stderr).call(decorated)
      0
    end

    private

    def gemfile_exists?
      File.file?(GEMFILE)
    end
  end
end
