require "test_helper"

class TestFindUnused < Minitest::Test
  def test_it_detects_unused_gems_based_on_the_top_module_1
    with_gemfile do |gemfile_path|
      bundle_install(["foo" => "module Foo; end"]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "foo.rb"), content: "class Base < Foo::Bar") do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_empty actual
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_2
    with_gemfile do |gemfile_path|
      bundle_install(["bar" => "module Bar; end"]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "bar.rb"), content: "class Base < Foo::Bar") do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal ["bar"], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_3
    with_gemfile do |gemfile_path|
      bundle_install(["foo" => "module Foo; end"]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "foo.rb"), content: "Foo::Bar") do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_empty actual
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_4
    with_gemfile do |gemfile_path|
      bundle_install(["bar" => "module Bar; end"]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "bar.rb"), content: "Foo::Bar") do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal ["bar"], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call
    with_gemfile do |gemfile_path|
      bundle_install(["foo" => "class Foo; def call; end; end"]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "foo.rb"), content: "Foo.new.call") do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_empty actual
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_require
    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "foo.rb"), content: "require 'foo-bar'") do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foobar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_required_path
    with_gemfile do |gemfile_path|
      bundle_install(%w[foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "foo.rb"), content: "require 'foo/bar'") do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_required_prefix_path
    with_gemfile do |gemfile_path|
      bundle_install(%w[foo bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "foo.rb"), content: "require 'foo/bar'") do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[bar], actual.map(&:name)
        end
      end
    end
  end

  def test_when_bundle_paths_fails_it_detects_unused_gems_based_on_required_prefix_path
    bundle_paths = Class.new(Degem::GitLsFiles) do
      def git_ls
        [nil, nil, 1]
      end
    end

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "foo.rb"), content: "require 'foo/bar'") do
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: bundle_paths.new).call
          assert_equal %w[bar], actual.map(&:name)
        end
      end
    end
  end

  def test_with_a_rails_bundle_it_excludes_rails
    with_gemfile do |gemfile_path|
      bundle_install(%w[rails]) do |gemspec_paths|
        gem_specification = TestableGemSpecification.new(gemspec_paths)
        actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [] }).call
        assert_empty actual
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

      with_gemfile do |gemfile_path|
        bundle_install(["rails", { "foo" => railtie }]) do |gemspec_paths|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [] }).call
          assert_empty actual
        end
      end
    end
  end
end
