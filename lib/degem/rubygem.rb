# frozen_string_literal: true

require "delegate"

module Degem
  class Rubygem < SimpleDelegator
    def initialize(rubygem:, gem_specification:)
      @gem_specification = gem_specification
      super(rubygem)
    end

    def consts
      parsed.consts
    end

    def own_consts
      variations = [
        name,
        name.delete("_-"),
        name.gsub("_", "::"),
        name.gsub("-", "::"),
        *name.split("_").each_cons(2).to_a.map { _1.join("::") },
        *name.split("_").each_cons(2).to_a.map(&:join),
        *name.split("-").each_cons(2).to_a.map { _1.join("::") },
        *name.split("-").each_cons(2).to_a.map(&:join)
      ]

      consts.filter { |const| variations.any? { |variation| const.downcase == variation.downcase } }
    end

    private

    def parsed
      @parsed ||=
        begin
          gem_path = @gem_specification.find_by_name(name).full_gem_path
          paths = Dir.glob(File.join(gem_path, "**/*.rb"))
          ParseRuby.new.call(paths)
        end
    end
  end
end
