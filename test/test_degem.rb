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

    yield
  rescue StandardError => e
    puts e
    raise
  ensure
    file.close
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
        actual = Degem::FindUnused.new.call(path)
        assert_equal %w[foo bar], actual.map(&:name)
      end
    end
  end
end
