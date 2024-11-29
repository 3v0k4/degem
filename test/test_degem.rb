require "test_helper"

class TestDegem < Minitest::Test
  TEST_DIR = File.join(Dir.pwd, "tmp", "test")

  def setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(TEST_DIR)
  end

  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end

  def with_file(path:, content:, &block)
    path = File.join(TEST_DIR, path)
    dir = File.dirname(path)
    FileUtils.mkdir_p(dir)
    file = File.new(path, "w")
    file.write(content)
    file.rewind
    block.call(file.path)
  ensure
    file.close
    FileUtils.rm_rf(dir)
  end

  def with_gemfile(&block)
    content = <<~CONTENT
      # frozen_string_literal: true
      source "https://rubygems.org"
    CONTENT

    with_file(path: File.join("app", "Gemfile"), content: content) do |path|
      block.call(path)
    end
  end

  def bundle_install(rubygems, gemspec_paths = [], &block)
    return block.call(gemspec_paths) if rubygems == []

    gem_name, source_code =
      if rubygems[0].instance_of?(Hash)
        rubygems[0].to_a.first
      else
        [rubygems[0], ""]
      end

    with_gem(name: gem_name, source_code: source_code) do |_gem_path, gemspec_path|
      File.write(File.join(TEST_DIR, "app", "Gemfile"), "\ngem '#{gem_name}'", mode: "a")
      bundle_install(rubygems[1..], gemspec_paths + [gemspec_path], &block)
    end
  end

  def with_gem(name:, source_code: "", &block)
    gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name    = "#{name}"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
      end
    CONTENT

    with_gemspec(gem_name: name, content: gemspec) do |gemspec_path|
      with_file(path: File.join("gems", "#{name}-1.0.0", "lib", "#{name}.rb"), content: source_code) do |gem_path|
        *parts, _lib, _rb = gem_path.split(File::SEPARATOR)
        block.call(parts.join(File::SEPARATOR), gemspec_path)
      end
    end
  end

  def with_gemspec(gem_name:, content:, &block)
    with_file(path: File.join("specifications", "#{gem_name}-1.0.0.gemspec"), content: content) do |path|
      block.call(path)
    end
  end

  class GitTestAdapter < Degem::GitAdapter
    require "ostruct"

    attr_reader :origin_url

    def initialize(origin_url = nil)
      @origin_url = origin_url
      @map = {}
    end

    def add_commit(gem_name, commit)
      @map[gem_name] ||= []
      attributes = commit.merge(url: to_commit_url(origin_url, commit.fetch(:hash)))
      @map[gem_name] += [OpenStruct.new(attributes)]
    end

    def call(gem_name)
      @map.fetch(gem_name, [])
    end
  end

  class TestableGemSpecification
    def initialize(gemspec_path)
      @gemspec_by_gem_name =
        Array(gemspec_path).each_with_object({}) do |path, hash|
          Gem::Specification.instance_variable_set(:@load_cache, {})
          gemspec = Gem::Specification.load(path)
          hash[gemspec.name] = gemspec
        end
    end

    def find_by_name(gem_name)
      @gemspec_by_gem_name.fetch(gem_name)
    end
  end

  def padding
    ["", " "].sample
  end

  def test_it_returns_the_parsed_gemfile
    with_gemfile do |path|
      bundle_install(["foo"]) do
        actual = Degem::ParseGemfile.new.call(path)
        assert_equal ["foo"], actual.rubygems.map(&:name)
      end
    end
  end

  def test_it_detects_rails
    with_gemfile do |path|
      bundle_install(["foo"]) do
        actual = Degem::ParseGemfile.new.call(path)
        refute actual.rails?
      end
    end

    with_gemfile do |path|
      bundle_install(["rails"]) do
        actual = Degem::ParseGemfile.new.call(path)
        assert actual.rails?
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_1
    content = "class Base < Baz::Foo::Bar".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_2
    content = "Foobar::Baz".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[foo foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_3
    content = "XFoobar::Baz".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_4
    content = "Baz::Foo::Bar".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_5
    content = "class Base < Foo::Bar".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_6
    content = "class Base < XFoo::Bar".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
        assert_equal %w[foo foo-bar bar], actual.map(&:name)
      end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_1
    content = "Foobar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[foo foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_2
    content = "XFooBar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_3
    content = "Baz::FooBar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_4
    content = "Foo::Bar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal ["bar"], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_5
    content = "XFoo::Bar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[foo foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_require
    content = "require 'foo-bar'".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[foo foobar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_required_path
    content = "require 'foo/bar'".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_required_prefix_path
    content = "require 'foo/bar'".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_equal %w[bar], actual.map(&:name)
        end
      end
    end
  end

  def test_with_a_rails_bundle_it_excludes_rails
    with_gemfile do |gemfile_path|
      bundle_install(%w[rails]) do |gemspec_paths|
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
        assert_empty actual.map(&:name)
      end
    end
  end

  def test_with_a_rails_bundle_it_excludes_gem_with_railtie
    %w[::Rails::Railtie Rails::Railtie ::Rails::Engine Rails::Engine].each do |klass|
      railtie = <<~CONTENT
        module Foo
          class Railtie < #{klass}
          end
        end
      CONTENT
        .prepend(padding).concat(padding)

      with_gemfile do |gemfile_path|
        bundle_install(["rails", { "foo" => railtie }]) do |gemspec_paths|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:).call
          assert_empty actual.map(&:name)
        end
      end
    end
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

      git_adapter = GitTestAdapter.new("git@github.com:3v0k4/foo.git")
      git_adapter.add_commit("foo", {
        hash: "afb779653f324eb1c6b486c871402a504a8fda42",
        date: "2020-01-12",
        message: "initial commit"
      })

      gem_specification = TestableGemSpecification.new(foo_gemspec_path)

      decorateds = Degem::Decorate.new(gem_specification:).call(rubygems:, git_adapter:)

      assert_equal ["foo"], decorateds.map(&:name)
      assert_equal [[true]], decorateds.map(&:autorequire)
      assert_equal ["http://example.com/homepage"], decorateds.map(&:homepage)
      assert_equal ["http://example.com/source"], decorateds.map(&:source_code_uri)

      decorateds.each do |decorated|
        assert_equal ["afb779653f324eb1c6b486c871402a504a8fda42"], decorated.commits.map(&:hash)
        assert_equal ["2020-01-12"], decorated.commits.map(&:date)
        assert_equal ["initial commit"], decorated.commits.map(&:message)
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
      git_adapter = GitTestAdapter.new
      gem_specification = TestableGemSpecification.new(foo_gemspec_path)

      actual = Degem::Decorate.new(gem_specification:).call(rubygems:, git_adapter:)

      assert_equal ["foo"], actual.map(&:name)
      assert_equal [nil], actual.map(&:autorequire)
      assert_equal [nil], actual.map(&:homepage)
      assert_equal [nil], actual.map(&:source_code_uri)
    end
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

        git_adapter = GitTestAdapter.new("git@github.com:3v0k4/foo.git")
        git_adapter.add_commit("foo", {
          hash: "afb779653f324eb1c6b486c871402a504a8fda42",
          date: "2020-01-12",
          message: "initial commit"
        })
        git_adapter.add_commit("foo", {
          hash: "f30156dd455d1f3f0b2b3e13de77ba5255096d61",
          date: "2020-01-14",
          message: "second commit"
        })

        gem_specification = TestableGemSpecification.new([foo_gemspec_path, bar_gemspec_path])

        decorated = Degem::Decorate.new(gem_specification:).call(rubygems:, git_adapter:)

        stderr = StringIO.new
        Degem::Report.new(stderr).call(decorated)

        assert_includes stderr.string, "foo: https://github.com/3v0k4/foo\n"
        assert_includes stderr.string, "=================================\n\n"

        assert_includes stderr.string, "afb7796 (2020-01-12) initial commit\n"
        assert_includes stderr.string, "https://github.com/3v0k4/foo/commit/afb779653f324eb1c6b486c871402a504a8fda42\n"
        assert_includes stderr.string, "f30156d (2020-01-14) second commit\n"
        assert_includes stderr.string, "https://github.com/3v0k4/foo/commit/f30156dd455d1f3f0b2b3e13de77ba5255096d61\n\n"

        assert_includes stderr.string, "bar\n"
        assert_includes stderr.string, "===\n\n\n"
      end
    end
  end
end
