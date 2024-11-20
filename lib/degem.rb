# frozen_string_literal: true

require_relative "degem/version"

module Degem
  class ParseGems
    def call(gemfile_path)
      Bundler::Dsl
        .evaluate(gemfile_path, nil, {})
        .dependencies
    end
  end
end
