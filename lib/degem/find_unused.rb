# frozen_string_literal: true

module Degem
  class FindUnused
    def initialize(gemfile_path:, gem_specification:, grep: Grep.new, bundle_paths: GitLsFiles.new)
      @gemfile_path = gemfile_path
      @gem_specification = gem_specification
      @grep = grep
      @bundle_paths = bundle_paths.call(File.dirname(gemfile_path))
    end

    def call
      rubygems = gemfile.rubygems.reject { _1.name == "degem" }
      rubygems = reject_railties(rubygems) if rails?
      reject_used(rubygems)
    end

    private

    attr_reader :gemfile_path

    def reject_railties(rubygems)
      rubygems
        .reject { _1.name == "rails" }
        .reject do |rubygem|
          gem_path = @gem_specification.find_by_name(rubygem.name).full_gem_path
          @grep.match?(/(Rails::Railtie|Rails::Engine)/, gem_path)
        end
    end

    def reject_used(rubygems)
      candidates = rubygems.map { Matcher.new(rubygem: _1, matchers: matchers) }
      @grep.inverse_many(candidates, @bundle_paths).map(&:rubygem)
    end

    def matchers
      [
        method(:based_on_top_module),
        method(:based_on_top_composite_module),
        method(:based_on_top_call),
        method(:based_on_top_composite_call),
        method(:based_on_require),
        method(:based_on_require_prefix_path),
        method(:based_on_require_path)
      ].compact
    end

    def gemfile
      @gemfile ||= ParseGemfile.new.call(gemfile_path)
    end

    def rails?
      @rails ||= gemfile.rails?
    end

    # gem foo -> Foo:: (but not XFoo:: or X::Foo)
    def based_on_top_module(rubygem, line)
      return false if rubygem.name.include?("-")

      regex = %r{
        (?<!\w::) # Do not match if :: before
        (?<!\w) # Do not match if \w before
        #{rubygem.name.capitalize}
        ::
      }x
      regex.match?(line)
    end

    # gem foo-bar -> Foo::Bar (but not XFoo::Bar or X::Foo::Bar)
    def based_on_top_composite_module(rubygem, line)
      return false unless rubygem.name.include?("-")

      regex = %r{
        (?<!\w::) # Do not match if :: before
        (?<!\w) # Do not match if \w before
        #{rubygem.name.split("-").map(&:capitalize).join("::")}
      }x
      regex.match?(line)
    end

    # gem foo -> Foo. (but not X::Foo. or XBar.)
    def based_on_top_call(rubygem, line)
      return false if rubygem.name.include?("-")

      regex = %r{
        (?<!\w::) # Do not match if :: before
        (?<!\w) # Do not match if \w before
        #{rubygem.name.capitalize}
        \.
      }x
      regex.match?(line)
    end

    # gem foo-bar -> FooBar. (but not X::FooBar. or XFooBar.)
    def based_on_top_composite_call(rubygem, line)
      return false unless rubygem.name.include?("-")

      regex = %r{
        (?<!\w::) # Do not match if :: before
        (?<!\w) # Do not match if \w before
        #{rubygem.name.split("-").map(&:capitalize).join}
        \.
      }x
      regex.match?(line)
    end

    # gem foo-bar -> require 'foo-bar'
    def based_on_require(rubygem, line)
      regex = %r{
        ^
        \s*
        require
        \s+
        ['"]
        #{rubygem.name}
        ['"]
      }x
      regex.match?(line)
    end

    # gem foo-bar -> require 'foo/bar'
    def based_on_require_path(rubygem, line)
      return false unless rubygem.name.include?("-")

      regex = %r{
        ^
        \s*
        require
        \s+
        ['"]
        #{rubygem.name.tr("-", "/")} # match foo/bar when rubygem is foo-bar
        ['"]
      }x
      regex.match?(line)
    end

    # gem foo -> require 'foo/'
    def based_on_require_prefix_path(rubygem, line)
      return false if rubygem.name.include?("-")

      regex = %r{
        ^
        \s*
        require
        \s+
        ['"]
        #{rubygem.name}
        /
      }x
      regex.match?(line)
    end
  end
end
