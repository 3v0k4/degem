# frozen_string_literal: true

require_relative "degem/version"
require_relative "degem/gemfile"
require_relative "degem/parse_gemfile"
require_relative "degem/grep"
require_relative "degem/git_ls_files"
require_relative "degem/matcher"
require_relative "degem/find_unused"
require_relative "degem/multi_delegator"
require_relative "degem/rubygem"
require_relative "degem/decorate_rubygems"
require_relative "degem/commit"
require_relative "degem/git_adapter"
require_relative "degem/report"
require_relative "degem/cli"

module Degem
end
