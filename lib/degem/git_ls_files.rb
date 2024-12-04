module Degem
  class GitLsFiles
    require "open3"

    def call(fallback)
      out, _err, status = git_ls
      return fallback unless status.zero?

      out.split("\x0").select { _1.end_with?(".rb") }.map { File.expand_path(_1).to_s }
    end

    private

    def git_ls
      out, err, status = Open3.capture3("git ls-files -z")
      [out, err, status.exitstatus]
    end
  end
end
