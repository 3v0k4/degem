# frozen_string_literal: true

require "test_helper"

class TestParseRuby < Minitest::Test
  def setup
    @original_stderr = Degem.stderr
    Degem.stderr = StringIO.new
  end

  def teardown
    Degem.stderr = @original_stderr
  end

  def test_it_parses_requires
    content = <<~CONTENT
      require "foo"
      require 'bar'
      require('baz')
      Bundler.require
      require File.join()
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_array %w[foo bar baz], actual.requires
      assert_array %w[Bundler File], actual.consts
      assert_empty actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_class_class
    content = <<~CONTENT
      class Klass
        class KK
        end
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Klass Klass::KK], actual.consts
      assert_array %w[Klass Klass::KK], actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_module_class
    content = <<~CONTENT
      module M
        class K
        end
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[M M::K], actual.consts
      assert_array %w[M::K], actual.classes
      assert_array %w[M], actual.modules
    end
  end

  def test_it_parses_module_class_module_class
    content = <<~CONTENT
      module M1
        class K1
        end

        module M2
          class K2
          end
        end
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[M1 M1::K1 M1::M2 M1::M2::K2], actual.consts
      assert_array %w[M1::K1 M1::M2::K2], actual.classes
      assert_array %w[M1 M1::M2], actual.modules
    end
  end

  def test_it_parses_multiple_files
    content1 = "class Klass; end"
    content2 = "module M; end"

    with_file(content: content1) do |path1|
      with_file(content: content2) do |path2|
        actual = Degem::ParseRuby.new.call([path1, path2])
        assert_empty actual.requires
        assert_array %w[Klass M], actual.consts
        assert_array %w[Klass], actual.classes
        assert_array %w[M], actual.modules
      end
    end
  end

  def test_it_parses_empty_file
    with_file(content: "") do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_empty actual.consts
      assert_empty actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_class_superclass
    content = <<~CONTENT
      class Klass < SuperKlass
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Klass SuperKlass], actual.consts
      assert_array %w[Klass], actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_class_superclass_with_module
    content = <<~CONTENT
      class Klass < Module::SuperKlass
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Klass Module::SuperKlass Module], actual.consts
      assert_array %w[Klass], actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_class_superclass_with_module_module
    content = <<~CONTENT
      class Klass < Module::Nested::SuperKlass
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Klass Module::Nested::SuperKlass Module::Nested Module], actual.consts
      assert_array %w[Klass], actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_skips_require_with_call
    content = <<~CONTENT
      require call + "/path"
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_empty actual.consts
      assert_empty actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_module_module_module
    content = <<~CONTENT
      Module1::Module2::Module3
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Module1 Module1::Module2 Module1::Module2::Module3], actual.consts
      assert_empty actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_class_module_module_module
    content = <<~CONTENT
      class Klass
        Module1::Module2::Module3
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Klass Module1 Module1::Module2 Module1::Module2::Module3], actual.consts
      assert_array %w[Klass], actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_class_method
    content = <<~CONTENT
      class Foo
        def call
        end
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Foo], actual.consts
      assert_array %w[Foo], actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_const_new_call
    content = <<~CONTENT
      Foo.new.call
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Foo], actual.consts
      assert_empty actual.classes
      assert_empty actual.modules
    end
  end

  def test_it_parses_module_class_call_with_module_class
    content = <<~CONTENT
      module Module
        class Klass
          call Rack::Utm
        end
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Module Module::Klass Rack Rack::Utm], actual.consts
      assert_array %w[Module::Klass], actual.classes
      assert_array %w[Module], actual.modules
    end
  end

  def test_it_parses_module_class_with_superclass_call_with_module_class
    content = <<~CONTENT
      module Module
        class Klass < SuperKlass
          call Rack::Utm
        end
      end
    CONTENT

    with_file(content: content) do |path|
      actual = Degem::ParseRuby.new.call(path)
      assert_empty actual.requires
      assert_array %w[Module SuperKlass Module::Klass Rack Rack::Utm], actual.consts
      assert_array %w[Module::Klass], actual.classes
      assert_array %w[Module], actual.modules
    end
  end
end
