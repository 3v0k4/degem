# frozen_string_literal: true

require "test_helper"

class TestDegem < Minitest::Test
  TMP_DIR = File.join(Dir.pwd, "test", "tmp")

  def setup
    FileUtils.mkdir_p(TMP_DIR)
  end

  def teardown
    FileUtils.rm_rf(TMP_DIR)
  end

  def with_gemfile(gems:)
    content = <<~CONTENT
      # frozen_string_literal: true
      source "https://rubygems.org"
      #{gems.map { "gem '#{_1}'" }.join("\n")}
    CONTENT

    file = Tempfile.create("Gemfile", TMP_DIR)
    file.write(content)
    file.rewind

    yield file.path
  rescue StandardError => e
    puts e
    raise
  ensure
    file.close
  end

  def with_file(path:, content:)
    dir = File.join(TMP_DIR, File.dirname(path))
    FileUtils.mkdir_p(dir)

    name = File.basename(path)
    ext = File.extname(name)
    base = File.basename(name, ext)
    file = Tempfile.create([base, ext], dir)
    file.write(content)
    file.rewind

    yield file.path
  rescue StandardError => e
    puts e
    raise
  ensure
    file.close
    FileUtils.rm(file.path)
  end

  GemSpecification = Data.define(:full_gem_path)

  def with_gem(name:, source_code:, &block)
    with_file(path: "lib/#{name}.rb", content: source_code) do |path|
      with_stubbed_find_by_name(gem_name: name, full_gem_path: File.dirname(path)) do
        block.call(File.dirname(path))
      end
    end
  end

  def with_stubbed_find_by_name(gem_name:, full_gem_path: "")
    find_by_name = Gem::Specification.method(:find_by_name)

    Gem::Specification.singleton_class.class_eval do
      remove_method(:find_by_name)
      define_method(:find_by_name) do |name|
        return GemSpecification.new(full_gem_path: "/dev/null") if gem_name != name

        GemSpecification.new(full_gem_path: full_gem_path)
      end
    end

    yield
  ensure
    Gem::Specification.singleton_class.class_eval do
      if method_defined?(:find_by_name)
        remove_method(:find_by_name)
        define_method(:find_by_name, find_by_name)
      end
    end
  end

  def test_it_returns_the_parsed_gemfile
    with_gemfile(gems: ["foo"]) do |path|
      actual = Degem::ParseGemfile.new.call(path)
      assert_equal ["foo"], actual.gems.map(&:name)
    end
  end

  def test_it_detects_rails
    with_gemfile(gems: ["foo"]) do |path|
      actual = Degem::ParseGemfile.new.call(path)
      refute actual.rails?
    end

    with_gemfile(gems: ["rails"]) do |path|
      actual = Degem::ParseGemfile.new.call(path)
      assert actual.rails?
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_level_module
    content = <<~CONTENT
      Foo::Bar.new.call
    CONTENT

    with_gemfile(gems: %w[foo foo-bar bar]) do |path|
      with_file(path: "app/services/baz.rb", content: content) do
        actual = Degem::FindUnused.new(path).call
        assert_equal %w[foo bar], actual.map(&:name)
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_level_const
    content = <<~CONTENT
      FooBar.new.call
    CONTENT

    with_gemfile(gems: %w[foo foo-bar bar]) do |path|
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

    with_gemfile(gems: %w[foo foo-bar bar]) do |path|
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

    with_gemfile(gems: %w[foo foo-bar bar]) do |path|
      with_file(path: "app/services/baz.rb", content: content) do
        actual = Degem::FindUnused.new(path).call
        assert_equal %w[foo bar], actual.map(&:name)
      end
    end
  end

  def test_with_a_rails_bundle_it_excludes_rails
    with_gemfile(gems: %w[rails]) do |path|
      with_stubbed_find_by_name(gem_name: "rails") do
        actual = Degem::FindUnused.new(path).call
        assert_equal [], actual.map(&:name)
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

      with_gemfile(gems: %w[rails foo]) do |path|
        with_gem(name: "foo", source_code: content) do
          actual = Degem::FindUnused.new(path).call
          assert_equal [], actual.map(&:name)
        end
      end
    end
  end
end
