require "test_helper"

class TestParseGemfile < Minitest::Test
  def test_it_returns_the_parsed_gemfile
    with_gemfile do |path|
      bundle_install(["foo"]) do
        actual = Degem::ParseGemfile.new.call(path)
        assert_equal ["foo"], actual.rubygems.map(&:name)
      end
    end
  end

  def test_it_returns_the_parsed_gemfile_for_the_current_platform
    with_gemfile do |path|
      bundle_install(["foo"]) do
        File.write(File.join(TEST_DIR, "app", "Gemfile"), "\ngem 'bar', platforms: [:jruby]", mode: "a")
        actual = Degem::ParseGemfile.new.call(path)
        assert_equal ["foo"], actual.rubygems.map(&:name)
      end
    end
  end

  def test_it_returns_the_parsed_gemfile_excluding_the_gem_itself
    gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name    = "bar"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
        spec.add_dependency "baz", "~> 1.0"
        spec.add_development_dependency "foobar", "~> 1.0"
      end
    CONTENT

    with_gemfile do |gemfile_path|
      bundle_install(["foo"]) do
        File.write(gemfile_path, "\ngemspec", mode: "a")
        with_file(path: File.join("app", "bar.gemspec"), content: gemspec) do
          actual = Degem::ParseGemfile.new.call(gemfile_path)
          assert_array %w[foo baz foobar], actual.rubygems.map(&:name)
        end
      end
    end
  end

  def test_it_detects_rails
    with_gemfile do |path|
      bundle_install(["foo"]) do
        actual = Degem::ParseGemfile.new.call(path)
        refute_predicate actual, :rails?
      end
    end

    with_gemfile do |path|
      bundle_install(["rails"]) do
        actual = Degem::ParseGemfile.new.call(path)
        assert_predicate actual, :rails?
      end
    end
  end
end
