require "test_helper"

class TestGitAdapter < Minitest::Test
  def setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(TEST_DIR)
  end

  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end

  def test_it_returns_parsed_commits
    testable_git_adapter = Class.new(Degem::GitAdapter) do
      def git_remote_origin_url
        out = " git@github.com:3v0k4/foo.git    "
        [out, nil, 0]
      end

      def git_log(_)
        out = [
          "afb779653f324eb1c6b486c871402a504a8fda42",
          "2020-01-12",
          "initial commit"
        ].join("\t")

        [out, nil, 0]
      end
    end

    actual = testable_git_adapter.new.call("foo")

    assert_equal ["afb779653f324eb1c6b486c871402a504a8fda42"], actual.map(&:hash)
    assert_equal ["2020-01-12"], actual.map(&:date)
    assert_equal ["initial commit"], actual.map(&:title)
    assert_equal ["https://github.com/3v0k4/foo/commit/afb779653f324eb1c6b486c871402a504a8fda42"], actual.map(&:url)
  end

  def test_within_repository_without_origin_it_returns_parsed_commits
    testable_git_adapter = Class.new(Degem::GitAdapter) do
      def git_remote_origin_url
        [nil, "error: No such remote 'origin'", 1]
      end

      def git_log(_)
        out = [
          "afb779653f324eb1c6b486c871402a504a8fda42",
          "2020-01-12",
          "initial commit"
        ].join("\t")

        [out, nil, 0]
      end
    end

    actual = testable_git_adapter.new.call("foo")

    assert_equal ["afb779653f324eb1c6b486c871402a504a8fda42"], actual.map(&:hash)
    assert_equal ["2020-01-12"], actual.map(&:date)
    assert_equal ["initial commit"], actual.map(&:title)
    assert_equal [""], actual.map(&:url)
  end

  def test_within_repository_with_unsupported_host_it_returns_parsed_commits
    testable_git_adapter = Class.new(Degem::GitAdapter) do
      def git_remote_origin_url
        out = "unsupported"
        [out, nil, 0]
      end

      def git_log(_)
        out = [
          "afb779653f324eb1c6b486c871402a504a8fda42",
          "2020-01-12",
          "initial commit"
        ].join("\t")

        [out, nil, 0]
      end
    end

    actual = testable_git_adapter.new.call("foo")

    assert_equal ["afb779653f324eb1c6b486c871402a504a8fda42"], actual.map(&:hash)
    assert_equal ["2020-01-12"], actual.map(&:date)
    assert_equal ["initial commit"], actual.map(&:title)
    assert_equal [""], actual.map(&:url)
  end

  def test_within_repository_without_commits_it_returns_parsed_commits
    testable_git_adapter = Class.new(Degem::GitAdapter) do
      def git_remote_origin_url
        out = " git@github.com:3v0k4/foo.git    "
        [out, nil, 0]
      end

      def git_log(_)
        [nil, "fatal: your current branch 'main' does not have any commits yet", 1]
      end
    end

    actual = testable_git_adapter.new.call("foo")

    assert_empty actual
  end
end
