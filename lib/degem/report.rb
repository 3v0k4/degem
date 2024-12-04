module Degem
  class Report
    def initialize(stderr)
      @stderr = stderr
    end

    def call(decorateds)
      @stderr.puts
      @stderr.puts
      @stderr.puts "The following gems may be unused:"
      @stderr.puts

      decorateds.each do |decorated|
        heading =
          if decorated.source_code_uri.nil?
            decorated.name
          else
            "#{decorated.name}: #{decorated.source_code_uri}"
          end
        @stderr.puts(heading)
        @stderr.puts("=" * heading.size)
        @stderr.puts

        decorated.commits.each.with_index do |commit, i|
          @stderr.puts("#{commit.hash[0..6]} (#{commit.date}) #{commit.title}")
          @stderr.puts(commit.url)
          @stderr.puts if i+1 == decorated.commits.size
        end

        @stderr.puts
      end
    end
  end
end
