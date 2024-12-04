# frozen_string_literal: true

require "open3"

module Degem
  class GitLsFiles
    def call(fallback)
      out, _err, status = git_ls
      return fallback unless status.zero?

      out.split("\x0").select { _1.end_with?(".rb") }.map { File.expand_path(_1) }
    end

    private

    def git_ls
      out, err, status = Open3.capture3("git ls-files -z")
      [out, err, status.exitstatus]
    end
  end
end
