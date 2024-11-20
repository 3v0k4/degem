# frozen_string_literal: true

require "test_helper"

class TestDegem < Minitest::Test
  def with_gemfile(gems:)
    content = <<~CONTENT
      # frozen_string_literal: true
      source "https://rubygems.org"
      #{gems.map { "gem '#{_1}'" }.join("\n")}
    CONTENT

    file = Tempfile.create("Gemfile")
    file.write(content)
    file.rewind

    yield file.path
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
end
