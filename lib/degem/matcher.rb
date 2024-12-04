# frozen_string_literal: true

module Degem
  class Matcher
    attr_reader :rubygem

    def initialize(rubygem:, matchers:)
      @rubygem = rubygem
      @matchers = matchers
    end

    def match?(string)
      @matchers.any? { _1.call(@rubygem, string) }
    end
  end
end
