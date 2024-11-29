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

    ZERO = {
      commit_hashes: [],
      committer_dates: [],
      commit_messages: [],
      commit_uris: [],
      origin_url: nil
    }.freeze

    def initialize(attributes_by_gem_name = {})
      @attributes_by_gem_name = attributes_by_gem_name
    end

    def call(gem_name)
      gem_attributes = @attributes_by_gem_name.fetch(gem_name.to_sym, ZERO)

      OpenStruct.new(gem_attributes).tap do |attributes|
        attributes.commit_uris =
          commit_uris(attributes.origin_url, attributes.commit_hashes)
      end
    end
  end

  class GithubTestAdapter < Degem::GithubAdapter
    require "ostruct"

    ZERO = {
      pr_numbers: [],
      pr_titles: [],
      pr_urls: []
    }.freeze

    def initialize(attributes_by_gem_name = {})
      @attributes_by_gem_name = attributes_by_gem_name
    end

    def call(gem_name)
      gem_attributes = @attributes_by_gem_name.fetch(gem_name.to_sym, ZERO)

      OpenStruct.new(gem_attributes)
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

  def test_it_decorates_the_gem
    gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name = "foo"
        spec.homepage = "http://example.com/homepage"
        spec.metadata["source_code_uri"] = "http://example.com/source"
      end
    CONTENT

    with_gemspec(gem_name: "foo", content: gemspec) do |foo_gemspec_path|
      rubygems = [Bundler::Dependency.new("foo", nil, "require" => true)]

      git_hash = {
        foo: {
          commit_hashes: ["afb779653f324eb1c6b486c871402a504a8fda42"],
          committer_dates: ["2020-01-12"],
          commit_messages: ["initial commit"],
          origin_url: "git@github.com:3v0k4/foo.git"
        }
      }
      git_adapter = GitTestAdapter.new(git_hash)

      github_hash = {
        foo: {
          pr_numbers: [1],
          pr_titles: ["first pr"],
          pr_urls: ["https://github.com/3v0k4/foo/pull/1"]
        }
      }
      host_adapter = GithubTestAdapter.new(github_hash)

      gem_specification = TestableGemSpecification.new(foo_gemspec_path)

      actual = Degem::Decorate.new(gem_specification:).call(rubygems:, git_adapter:, host_adapter:)

      assert_equal ["foo"], actual.map(&:name)
      assert_equal [[true]], actual.map(&:autorequire)
      assert_equal ["http://example.com/homepage"], actual.map(&:homepage)
      assert_equal ["http://example.com/source"], actual.map(&:source_code_uri)

      commit_hashes = git_hash.dig(:foo, :commit_hashes)
      assert_equal [commit_hashes], actual.map(&:commit_hashes)
      assert_equal [git_hash.dig(:foo, :committer_dates)], actual.map(&:committer_dates)
      assert_equal [git_hash.dig(:foo, :commit_messages)], actual.map(&:commit_messages)
      assert_equal(
        [["https://github.com/3v0k4/foo/commit/#{commit_hashes.first}"]],
        actual.map(&:commit_uris)
      )

      assert_equal [github_hash.dig(:foo, :pr_numbers)], actual.map(&:pr_numbers)
      assert_equal [github_hash.dig(:foo, :pr_titles)], actual.map(&:pr_titles)
      assert_equal [github_hash.dig(:foo, :pr_urls)], actual.map(&:pr_urls)
    end
  end

  def test_with_minimal_gemspec_it_decorates_the_gem
    gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name = "foo"
      end
    CONTENT

    with_gemspec(gem_name: "foo", content: gemspec) do |foo_gemspec_path|
      rubygems = [Bundler::Dependency.new("foo", nil)]
      git_adapter = GitTestAdapter.new
      host_adapter = GithubTestAdapter.new

      gem_specification = TestableGemSpecification.new(foo_gemspec_path)

      actual = Degem::Decorate.new(gem_specification:).call(rubygems:, git_adapter:, host_adapter:)

      assert_equal ["foo"], actual.map(&:name)
      assert_equal [nil], actual.map(&:autorequire)
      assert_equal [nil], actual.map(&:homepage)
      assert_equal [nil], actual.map(&:source_code_uri)
    end
  end
end
