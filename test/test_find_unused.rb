require "test_helper"

class TestFindUnused < Minitest::Test
  def setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(TEST_DIR)
  end

  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end

  def padding
    ["", " "].sample
  end

  def test_it_detects_unused_gems_based_on_the_top_module_1
    content = "class Base < Baz::Foo::Bar".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_2
    content = "Foobar::Baz".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_3
    content = "XFoobar::Baz".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_4
    content = "Baz::Foo::Bar".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_5
    content = "class Base < Foo::Bar".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_module_6
    content = "class Base < XFoo::Bar".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_1
    content = "Foobar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_2
    content = "XFooBar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_3
    content = "Baz::FooBar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foobar foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_4
    content = "Foo::Bar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal ["bar"], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_the_top_call_5
    content = "XFoo::Bar.new.call".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foo-bar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_require
    content = "require 'foo-bar'".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo foobar foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[foo foobar bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_required_path
    content = "require 'foo/bar'".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo-bar bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [f] }).call
          assert_equal %w[bar], actual.map(&:name)
        end
      end
    end
  end

  def test_it_detects_unused_gems_based_on_required_prefix_path
    content = "require 'foo/bar'".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do |f|
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

    content = "require 'foo/bar'".prepend(padding).concat(padding)

    with_gemfile do |gemfile_path|
      bundle_install(%w[foo bar]) do |gemspec_paths|
        with_file(path: File.join("app", "services", "baz.rb"), content: content) do
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
        assert_empty actual.map(&:name)
      end
    end
  end

  def test_with_a_rails_bundle_it_excludes_gem_with_railtie
    %w[::Rails::Railtie Rails::Railtie ::Rails::Engine Rails::Engine].each do |klass|
      railtie = <<~CONTENT.prepend(padding).concat(padding)
        module Foo
          class Railtie < #{klass}
          end
        end
      CONTENT

      with_gemfile do |gemfile_path|
        bundle_install(["rails", { "foo" => railtie }]) do |gemspec_paths|
          gem_specification = TestableGemSpecification.new(gemspec_paths)
          actual = Degem::FindUnused.new(gemfile_path:, gem_specification:, bundle_paths: ->(_) { [] }).call
          assert_empty actual.map(&:name)
        end
      end
    end
  end

end
