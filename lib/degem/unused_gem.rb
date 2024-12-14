# frozen_string_literal: true

module Degem
  class UnusedGem < MultiDelegator
    attr_reader :commits

    def initialize(_, _, commits)
      super
      @commits = commits
    end

    def source_code_uri
      metadata["source_code_uri"] || homepage
    end
  end
end
