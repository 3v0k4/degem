# frozen_string_literal: true

module Degem
  class Report
    def call(rubygems)
      Degem.stderr.puts
      Degem.stderr.puts
      Degem.stderr.puts "The following gems may be unused (#{rubygems.size}):"
      Degem.stderr.puts

      rubygems.each do |rubygem|
        gem_name(rubygem)
        Degem.stderr.puts
        commits(rubygem)
        Degem.stderr.puts
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

      Degem.stderr.puts(heading)
      Degem.stderr.puts("=" * heading.size)
    end

    def commits(rubygem)
      rubygem.commits.each.with_index do |commit, i|
        Degem.stderr.puts("#{commit.hash[0..6]} (#{commit.date}) #{commit.title}")
        Degem.stderr.puts(commit.url)
        Degem.stderr.puts if i + 1 == rubygem.commits.size
      end
    end
  end
end
