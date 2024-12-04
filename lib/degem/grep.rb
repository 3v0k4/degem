module Degem
  class Grep
    require "find"

    def initialize(stderr = StringIO.new)
      @stderr = stderr
    end

    def inverse?(matcher, dir)
      Find.find(File.expand_path(dir)) do |path|
        next unless File.file?(path)
        next if File.extname(path) != ".rb"

        @stderr.putc "."
        File.foreach(path) do |line|
          next unless matcher.match?(line)

          return true
        end
      end

      false
    end

    def inverse_many(matchers, paths)
      Find.find(*paths) do |path|
        next unless File.file?(path)

        @stderr.putc "."
        File.foreach(path) do |line|
          matchers = matchers.reject do |matcher|
            matcher.match?(line)
          end
        end
      end

      matchers
    end
  end
end
