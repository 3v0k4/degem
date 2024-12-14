require "test_helper"

class TestReport < Minitest::Test
  def setup
    @original_stderr = Degem.stderr
    Degem.stderr = StringIO.new
  end

  def teardown
    Degem.stderr = @original_stderr
  end

  def test_it_reports_with_git_information
    foo_gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name = "foo"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
        spec.homepage = "http://example.com/homepage"
        spec.metadata["source_code_uri"] = "https://github.com/3v0k4/foo"
      end
    CONTENT

    bar_gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name = "bar"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
      end
    CONTENT

    with_gemspec(gem_name: "foo", content: foo_gemspec) do |foo_gemspec_path|
      with_gemspec(gem_name: "bar", content: bar_gemspec) do |bar_gemspec_path|
        rubygems = [
          Bundler::Dependency.new("foo", nil, "require" => true),
          Bundler::Dependency.new("bar", nil, "require" => true)
        ]

        git_adapter = TestableGitAdapter.new("git@github.com:3v0k4/foo.git")
        git_adapter.add_commit("foo", {
          hash: "afb779653f324eb1c6b486c871402a504a8fda42",
          date: "2020-01-12",
          title: "initial commit"
        })
        git_adapter.add_commit("foo", {
          hash: "f30156dd455d1f3f0b2b3e13de77ba5255096d61",
          date: "2020-01-14",
          title: "second commit"
        })

        gem_specification = TestableGemSpecification.new([foo_gemspec_path, bar_gemspec_path])

        decorated = Degem::DecorateUnusedGems.new(gem_specification:, git_adapter:).call(rubygems)

        Degem::Report.new.call(decorated)

        assert_includes Degem.stderr.string, "The following gems may be unused (2):\n\n"

        assert_includes Degem.stderr.string, "foo: https://github.com/3v0k4/foo\n"
        assert_includes Degem.stderr.string, "=================================\n\n"

        assert_includes Degem.stderr.string, "afb7796 (2020-01-12) initial commit\n"
        assert_includes Degem.stderr.string, "https://github.com/3v0k4/foo/commit/afb779653f324eb1c6b486c871402a504a8fda42\n"
        assert_includes Degem.stderr.string, "f30156d (2020-01-14) second commit\n"
        assert_includes Degem.stderr.string, "https://github.com/3v0k4/foo/commit/f30156dd455d1f3f0b2b3e13de77ba5255096d61\n\n"

        assert_includes Degem.stderr.string, "bar\n"
        assert_includes Degem.stderr.string, "===\n\n\n"
      end
    end
  end
end
