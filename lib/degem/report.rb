# frozen_string_literal: true

module Degem
  class Report
    def initialize(stderr)
      @stderr = stderr
    end

    def call(rubygems)
      @stderr.puts
      @stderr.puts
      @stderr.puts "The following gems may be unused (#{rubygems.size}):"
      @stderr.puts

      rubygems.each do |rubygem|
        gem_name(rubygem)
        @stderr.puts
        commits(rubygem)
        @stderr.puts
      end
    end

    private

    def gem_name(rubygem)
      heading =
        if rubygem.source_code_uri.nil?
          rubygem.name
        else
          "#{rubygem.name}: #{rubygem.source_code_uri}"
        end

      @stderr.puts(heading)
      @stderr.puts("=" * heading.size)
    end

    def commits(rubygem)
      rubygem.commits.each.with_index do |commit, i|
        @stderr.puts("#{commit.hash[0..6]} (#{commit.date}) #{commit.title}")
        @stderr.puts(commit.url)
        @stderr.puts if i + 1 == rubygem.commits.size
      end
    end
  end
end
