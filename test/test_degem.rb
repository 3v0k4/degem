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

  def with_gemfile(gem_names:, &block)
    content = <<~CONTENT
      # frozen_string_literal: true
      source "https://rubygems.org"
      #{gem_names.map { "gem '#{_1}'" }.join("\n")}
    CONTENT

    with_file(path: "Gemfile", content: content) do |path|
      block.call(path)
    end
  end

  def with_gemspec(gem_name:, content:, &block)
    @map ||= {}

    with_file(path: "specifications/#{gem_name}-1.0.0.gemspec", content: content) do |path|
      Gem::Specification.instance_variable_set(:@load_cache, {})
      @map[gem_name] = Gem::Specification.load(path)

      find_by_name = Gem::Specification.method(:find_by_name)
      map = @map; Gem::Specification.singleton_class.class_eval do
        remove_method(:find_by_name)
        define_method(:find_by_name) do |name|
          raise "[Test] Forgot to stub #{name}?" unless map.key?(name)

          map[name]
        end
      end

      block.call(path)
    ensure
      @map = {}

      Gem::Specification.singleton_class.class_eval do
        if method_defined?(:find_by_name)
          remove_method(:find_by_name)
          define_method(:find_by_name, find_by_name)
        end
      end
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

    with_gemspec(gem_name: name, content: gemspec) do
      with_file(path: "gems/#{name}-1.0.0/lib/#{name}.rb", content: source_code) do |path|
        *parts, _lib, _rb = path.split(File::SEPARATOR)
        block.call(parts.join(File::SEPARATOR))
      end
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

  def padding
    ["", " "].sample
  end

  def test_it_returns_the_parsed_gemfile
    with_gemfile(gem_names: ["foo"]) do |path|
      actual = Degem::ParseGemfile.new.call(path)
      assert_equal ["foo"], actual.rubygems.map(&:name)
    end
  end

  def test_it_detects_rails
    with_gemfile(gem_names: ["foo"]) do |path|
      actual = Degem::ParseGemfile.new.call(path)
      refute actual.rails?
    end

    with_gemfile(gem_names: ["rails"]) do |path|
      actual = Degem::ParseGemfile.new.call(path)
      assert actual.rails?
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_level_module_call
    content = "Foo::Bar.new.call"

    with_gemfile(gem_names: %w[foo-bar bar]) do |gemfile_path|
      with_file(path: "app/services/baz.rb", content: content) do
        actual = Degem::FindUnused.new(gemfile_path).call
        assert_equal ["bar"], actual.map(&:name)
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_level_const
    content = <<~CONTENT
      FooBar.new.call
    CONTENT

    with_gemfile(gem_names: %w[foo foo-bar bar]) do |path|
      with_file(path: "app/services/baz.rb", content: content) do
        actual = Degem::FindUnused.new(path).call
        assert_equal %w[foo bar], actual.map(&:name)
      end
    end
  end

  def test_it_detects_unused_gems_based_on_require
    content = <<~CONTENT
      require 'foo-bar'
    CONTENT

    with_gemfile(gem_names: %w[foo foo-bar bar]) do |path|
      with_file(path: "app/services/baz.rb", content: content) do
        actual = Degem::FindUnused.new(path).call
        assert_equal %w[foo bar], actual.map(&:name)
      end
    end
  end

  def test_it_detects_unused_gems_based_on_required_path
    content = <<~CONTENT
      require 'foo/bar'
    CONTENT

    with_gemfile(gem_names: %w[foo foo-bar bar]) do |path|
      with_file(path: "app/services/baz.rb", content: content) do
        actual = Degem::FindUnused.new(path).call
        assert_equal %w[foo bar], actual.map(&:name)
      end
    end
  end

  def test_with_a_rails_bundle_it_excludes_rails
    with_gemfile(gem_names: %w[rails]) do |path|
      with_gem(name: "rails") do
        actual = Degem::FindUnused.new(path).call
        assert_empty actual.map(&:name)
      end
    end
  end

  def test_with_a_rails_bundle_it_excludes_gem_with_railtie
    %w[::Rails::Railtie Rails::Railtie ::Rails::Engine Rails::Engine].each do |super_|
      content = <<~CONTENT
        module Foo
          class Railtie < #{super_}
          end
        end
      CONTENT

      with_gemfile(gem_names: %w[rails foo]) do |path|
        with_gem(name: "rails", source_code: "") do
          with_gem(name: "foo", source_code: content) do
            actual = Degem::FindUnused.new(path).call
            assert_empty actual.map(&:name)
          end
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

    with_gemspec(gem_name: "foo", content: gemspec) do
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

      actual = Degem::Decorate.new.call(rubygems:, git_adapter:, host_adapter:)

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
        spec.name = "degem"
      end
    CONTENT

    with_gemspec(gem_name: "foo", content: gemspec) do
      rubygems = [Bundler::Dependency.new("foo", nil)]
      git_adapter = GitTestAdapter.new
      host_adapter = GithubTestAdapter.new
      actual = Degem::Decorate.new.call(rubygems:, git_adapter:, host_adapter:)

      assert_equal ["foo"], actual.map(&:name)
      assert_equal [nil], actual.map(&:autorequire)
      assert_equal [nil], actual.map(&:homepage)
      assert_equal [nil], actual.map(&:source_code_uri)
    end
  end
end
