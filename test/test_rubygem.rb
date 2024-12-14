# frozen_string_literal: true

require "test_helper"

class TestRubygem < Minitest::Test
  def test_with_one_word_gem_it_returns_consts
    with_gemfile do
      bundle_install(["foo" => "module Foo; class Bar; end; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["Foo"], actual.own_consts
        assert_array ["Foo", "Foo::Bar"], actual.consts
      end
    end
  end

  def test_with_underscored_gem_it_returns_consts_1
    with_gemfile do
      bundle_install(["foo_bar_baz" => "class FooBarBaz; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo_bar_baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["FooBarBaz"], actual.own_consts
        assert_array ["FooBarBaz"], actual.consts
      end
    end
  end

  def test_with_underscored_gem_it_returns_consts_2
    with_gemfile do
      bundle_install(["foo_bar_baz" => "module Foo; module Bar; class Baz; end; end; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo_bar_baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["Foo::Bar", "Foo::Bar::Baz"], actual.own_consts
        assert_array ["Foo", "Foo::Bar", "Foo::Bar::Baz"], actual.consts
      end
    end
  end

  def test_with_underscored_gem_it_returns_consts_3
    with_gemfile do
      bundle_install(["foo_bar_baz" => "module Foo; class Bar; end; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo_bar_baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["Foo::Bar"], actual.own_consts
        assert_array ["Foo", "Foo::Bar"], actual.consts
      end
    end

    with_gemfile do
      bundle_install(["foo_bar_baz" => "module Bar; class Baz; end; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo_bar_baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["Bar::Baz"], actual.own_consts
        assert_array ["Bar", "Bar::Baz"], actual.consts
      end
    end
  end

  def test_with_underscored_gem_it_returns_consts_4
    with_gemfile do
      bundle_install(["foo_bar_baz" => "class FooBar; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo_bar_baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["FooBar"], actual.own_consts
        assert_array ["FooBar"], actual.consts
      end
    end
  end

  def test_with_dashed_gem_it_returns_consts_1
    with_gemfile do
      bundle_install(["foo-bar-baz" => "module FooBarBaz; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo-bar-baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["FooBarBaz"], actual.own_consts
        assert_array ["FooBarBaz"], actual.consts
      end
    end
  end

  def test_with_dashed_gem_it_returns_consts_2
    with_gemfile do
      bundle_install(["foo-bar-baz" => "module Foo; module Bar; class Baz; end; end; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo-bar-baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["Foo::Bar", "Foo::Bar::Baz"], actual.own_consts
        assert_array ["Foo", "Foo::Bar", "Foo::Bar::Baz"], actual.consts
      end
    end
  end

  def test_with_dashed_gem_it_returns_consts_3
    with_gemfile do
      bundle_install(["foo-bar-baz" => "module Foo; class Bar; end; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo-bar-baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["Foo::Bar"], actual.own_consts
        assert_array ["Foo", "Foo::Bar"], actual.consts
      end
    end

    with_gemfile do
      bundle_install(["foo-bar-baz" => "module Bar; class Baz; end; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo-bar-baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["Bar::Baz"], actual.own_consts
        assert_array ["Bar", "Bar::Baz"], actual.consts
      end
    end
  end

  def test_with_dashed_gem_it_returns_consts_4
    with_gemfile do
      bundle_install(["foo-bar-baz" => "class FooBar; end"]) do |gemspec_paths|
        rubygem = Bundler::Dependency.new("foo-bar-baz", nil)
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::Rubygem.new(rubygem:, gem_specification:)
        assert_array ["FooBar"], actual.own_consts
        assert_array ["FooBar"], actual.consts
      end
    end
  end
end
