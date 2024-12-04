# frozen_string_literal: true

require "ostruct"
require "open3"

module Degem
  class GitAdapter
    def call(gem_name)
      out, _err, status = git_log(gem_name)
      return [] unless status.zero?

      out.split("\n").map do |commit|
        hash, date, title = commit.split("\t")
        Commit.new(hash:, date:, title:, url: to_commit_url(hash))
      end
    end

    private

    def git_remote_origin_url
      out, err, status = Open3.capture3("git remote get-url origin")
      [out, err, status.exitstatus]
    end

    def git_log(gem_name)
      out, err, status = Open3.capture3([
        "git log",
        "--pretty=format:'%H%x09%cs%x09%s'",
        "--pickaxe-regex",
        "-S '#{gem_name}'",
        "--",
        "Gemfile",
        "|",
        "cat"
      ].join(" "))

      [out, err, status.exitstatus]
    end

    def to_commit_url(commit_hash)
      remote, _, status = git_remote_origin_url
      return "" unless status.zero?

      repository = (remote.match(%r{github\.com[:/](.+?)(\.git)}) || [])[1]
      return "" if repository.nil?

      "https://github.com/#{repository}/commit/#{commit_hash}"
    end
  end
end