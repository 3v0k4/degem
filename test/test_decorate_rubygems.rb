require "test_helper"

class TestDecorateRubygems < Minitest::Test
  def setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(TEST_DIR)
  end

  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end

  def test_it_decorates_the_result_with_git_information
    gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name    = "foo"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
        spec.homepage = "http://example.com/homepage"
        spec.metadata["source_code_uri"] = "http://example.com/source"
      end
    CONTENT

    with_gemspec(gem_name: "foo", content: gemspec) do |foo_gemspec_path|
      rubygems = [Bundler::Dependency.new("foo", nil, "require" => true)]

      git_adapter = TestableGitAdapter.new("git@github.com:3v0k4/foo.git")
      git_adapter.add_commit("foo", {
        hash: "afb779653f324eb1c6b486c871402a504a8fda42",
        date: "2020-01-12",
        title: "initial commit"
      })

      gem_specification = TestableGemSpecification.new(foo_gemspec_path)

      decorateds = Degem::DecorateRubygems.new(gem_specification:, git_adapter:).call(rubygems)

      assert_equal ["foo"], decorateds.map(&:name)
      assert_equal [[true]], decorateds.map(&:autorequire)
      assert_equal ["http://example.com/homepage"], decorateds.map(&:homepage)
      assert_equal ["http://example.com/source"], decorateds.map(&:source_code_uri)

      decorateds.each do |decorated|
        assert_equal ["afb779653f324eb1c6b486c871402a504a8fda42"], decorated.commits.map(&:hash)
        assert_equal ["2020-01-12"], decorated.commits.map(&:date)
        assert_equal ["initial commit"], decorated.commits.map(&:title)
        assert_equal(
          ["https://github.com/3v0k4/foo/commit/afb779653f324eb1c6b486c871402a504a8fda42"],
          decorated.commits.map(&:url)
        )
      end
    end
  end

  def test_with_minimal_gemspec_it_decorates_the_result_with_git_information
    gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name = "foo"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
      end
    CONTENT

    with_gemspec(gem_name: "foo", content: gemspec) do |foo_gemspec_path|
      rubygems = [Bundler::Dependency.new("foo", nil)]
      git_adapter = TestableGitAdapter.new
      gem_specification = TestableGemSpecification.new(foo_gemspec_path)

      actual = Degem::DecorateRubygems.new(gem_specification:, git_adapter:).call(rubygems)

      assert_equal ["foo"], actual.map(&:name)
      assert_equal [nil], actual.map(&:autorequire)
      assert_equal [nil], actual.map(&:homepage)
      assert_equal [nil], actual.map(&:source_code_uri)
    end
  end
end
