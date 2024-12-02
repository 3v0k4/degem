require "test_helper"

class TestDegem < Minitest::Test
  TEST_DIR = File.join(Dir.pwd, "tmp", "test")
  GEM_DIR = File.join(Dir.pwd, "tmp", "gem")

  def setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(TEST_DIR)
  end

  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end

  def assert_array(xs, ys, msg = nil)
    assert_equal xs.sort, ys.sort, msg
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

  class TestableGitAdapter < Degem::GitAdapter
    require "ostruct"

    def initialize(origin_url = nil)
      @origin_url = origin_url
      @map = {}
    end

    def add_commit(gem_name, commit)
      @map[gem_name] ||= []
      @map[gem_name] += [OpenStruct.new(commit)]
    end

    private

    def git_remote_origin_url
      [@origin_url, nil, 0]
    end

    def git_log(gem_name)
      return [nil, nil, 1] unless @map.key?(gem_name)

      out = @map.fetch(gem_name).map do |commit|
        [commit.hash, commit.date, commit.title].join("\t")
      end.join("\n")

      [out, nil, 0]
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

  def test_it_returns_the_parsed_gemfile_including_its_gemspec
    gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name    = "bar"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
        spec.add_dependency "baz", "~> 1.0"
      end
    CONTENT

    with_gemfile do |gemfile_path|
      bundle_install(["foo"]) do
        File.write(gemfile_path, "\ngemspec", mode: "a")
        with_file(path: File.join("app", "bar.gemspec"), content: gemspec) do
          actual = Degem::ParseGemfile.new.call(gemfile_path)
          assert_array %w[foo bar baz], actual.rubygems.map(&:name)
        end
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

  def test_it_decorates_the_result_with_git_information
    gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name    = "foo"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
        spec.homepage = "http://example.com/homepage"
        spec.metadata["source_code_uri"] = "http://example.com/source"
      end
    CONTENT

    with_gemspec(gem_name: "foo", content: gemspec) do |foo_gemspec_path|
      rubygems = [Bundler::Dependency.new("foo", nil, "require" => true)]

      git_adapter = TestableGitAdapter.new("git@github.com:3v0k4/foo.git")
      git_adapter.add_commit("foo", {
        hash: "afb779653f324eb1c6b486c871402a504a8fda42",
        date: "2020-01-12",
        title: "initial commit"
      })

      gem_specification = TestableGemSpecification.new(foo_gemspec_path)

      decorateds = Degem::Decorate.new(gem_specification:).call(rubygems:, git_adapter:)

      assert_equal ["foo"], decorateds.map(&:name)
      assert_equal [[true]], decorateds.map(&:autorequire)
      assert_equal ["http://example.com/homepage"], decorateds.map(&:homepage)
      assert_equal ["http://example.com/source"], decorateds.map(&:source_code_uri)

      decorateds.each do |decorated|
        assert_equal ["afb779653f324eb1c6b486c871402a504a8fda42"], decorated.commits.map(&:hash)
        assert_equal ["2020-01-12"], decorated.commits.map(&:date)
        assert_equal ["initial commit"], decorated.commits.map(&:title)
        assert_equal(
          ["https://github.com/3v0k4/foo/commit/afb779653f324eb1c6b486c871402a504a8fda42"],
          decorated.commits.map(&:url)
        )
      end
    end
  end

  def test_with_minimal_gemspec_it_decorates_the_result_with_git_information
    gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name = "foo"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
      end
    CONTENT

    with_gemspec(gem_name: "foo", content: gemspec) do |foo_gemspec_path|
      rubygems = [Bundler::Dependency.new("foo", nil)]
      git_adapter = TestableGitAdapter.new
      gem_specification = TestableGemSpecification.new(foo_gemspec_path)

      actual = Degem::Decorate.new(gem_specification:).call(rubygems:, git_adapter:)

      assert_equal ["foo"], actual.map(&:name)
      assert_equal [nil], actual.map(&:autorequire)
      assert_equal [nil], actual.map(&:homepage)
      assert_equal [nil], actual.map(&:source_code_uri)
    end
  end

  def test_it_reports_with_git_information
    foo_gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name = "foo"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
        spec.homepage = "http://example.com/homepage"
        spec.metadata["source_code_uri"] = "https://github.com/3v0k4/foo"
      end
    CONTENT

    bar_gemspec = <<~CONTENT
      Gem::Specification.new do |spec|
        spec.name = "bar"
        spec.version = "1.0.0"
        spec.summary = "Gemspec summary"
        spec.files   = Dir.glob("lib/**/*") + Dir.glob("exe/*")
        spec.authors = ["Riccardo Odone"]
      end
    CONTENT

    with_gemspec(gem_name: "foo", content: foo_gemspec) do |foo_gemspec_path|
      with_gemspec(gem_name: "bar", content: bar_gemspec) do |bar_gemspec_path|
        rubygems = [
          Bundler::Dependency.new("foo", nil, "require" => true),
          Bundler::Dependency.new("bar", nil, "require" => true)
        ]

        git_adapter = TestableGitAdapter.new("git@github.com:3v0k4/foo.git")
        git_adapter.add_commit("foo", {
          hash: "afb779653f324eb1c6b486c871402a504a8fda42",
          date: "2020-01-12",
          title: "initial commit"
        })
        git_adapter.add_commit("foo", {
          hash: "f30156dd455d1f3f0b2b3e13de77ba5255096d61",
          date: "2020-01-14",
          title: "second commit"
        })

        gem_specification = TestableGemSpecification.new([foo_gemspec_path, bar_gemspec_path])

        decorated = Degem::Decorate.new(gem_specification:).call(rubygems:, git_adapter:)

        stderr = StringIO.new
        Degem::Report.new(stderr).call(decorated)

        assert_includes stderr.string, "foo: https://github.com/3v0k4/foo\n"
        assert_includes stderr.string, "=================================\n\n"

        assert_includes stderr.string, "afb7796 (2020-01-12) initial commit\n"
        assert_includes stderr.string, "https://github.com/3v0k4/foo/commit/afb779653f324eb1c6b486c871402a504a8fda42\n"
        assert_includes stderr.string, "f30156d (2020-01-14) second commit\n"
        assert_includes stderr.string, "https://github.com/3v0k4/foo/commit/f30156dd455d1f3f0b2b3e13de77ba5255096d61\n\n"

        assert_includes stderr.string, "bar\n"
        assert_includes stderr.string, "===\n\n\n"
      end
    end
  end

  def test_it_returns_parsed_commits
    testable_git_adapter = Class.new(Degem::GitAdapter) do
      def git_remote_origin_url
        out = " git@github.com:3v0k4/foo.git    "
        [out, nil, 0]
      end

      def git_log(_)
        out = [
          [
            "afb779653f324eb1c6b486c871402a504a8fda42",
            "2020-01-12",
            "initial commit"
          ]
            .join("\t")
        ]
          .join("\n")

        [out, nil, 0]
      end
    end

    actual = testable_git_adapter.new.call("foo")

    assert_equal ["afb779653f324eb1c6b486c871402a504a8fda42"], actual.map(&:hash)
    assert_equal ["2020-01-12"], actual.map(&:date)
    assert_equal ["initial commit"], actual.map(&:title)
    assert_equal ["https://github.com/3v0k4/foo/commit/afb779653f324eb1c6b486c871402a504a8fda42"], actual.map(&:url)
  end

  def test_within_repository_without_origin_it_returns_parsed_commits
    testable_git_adapter = Class.new(Degem::GitAdapter) do
      def git_remote_origin_url
        [nil, "error: No such remote 'origin'", 1]
      end

      def git_log(_)
        out = [
          [
            "afb779653f324eb1c6b486c871402a504a8fda42",
            "2020-01-12",
            "initial commit"
          ]
            .join("\t")
        ]
          .join("\n")

        [out, nil, 0]
      end
    end

    actual = testable_git_adapter.new.call("foo")

    assert_equal ["afb779653f324eb1c6b486c871402a504a8fda42"], actual.map(&:hash)
    assert_equal ["2020-01-12"], actual.map(&:date)
    assert_equal ["initial commit"], actual.map(&:title)
    assert_equal [""], actual.map(&:url)
  end

  def test_within_repository_with_unsupported_host_it_returns_parsed_commits
    testable_git_adapter = Class.new(Degem::GitAdapter) do
      def git_remote_origin_url
        out = "unsupported"
        [out, nil, 0]
      end

      def git_log(_)
        out = [
          [
            "afb779653f324eb1c6b486c871402a504a8fda42",
            "2020-01-12",
            "initial commit"
          ]
            .join("\t")
        ]
          .join("\n")

        [out, nil, 0]
      end
    end

    actual = testable_git_adapter.new.call("foo")

    assert_equal ["afb779653f324eb1c6b486c871402a504a8fda42"], actual.map(&:hash)
    assert_equal ["2020-01-12"], actual.map(&:date)
    assert_equal ["initial commit"], actual.map(&:title)
    assert_equal [""], actual.map(&:url)
  end

  def test_within_repository_without_commits_it_returns_parsed_commits
    testable_git_adapter = Class.new(Degem::GitAdapter) do
      def git_remote_origin_url
        out = " git@github.com:3v0k4/foo.git    "
        [out, nil, 0]
      end

      def git_log(_)
        [nil, "fatal: your current branch 'main' does not have any commits yet", 1]
      end
    end

    actual = testable_git_adapter.new.call("foo")

    assert_empty actual
  end

  def test_e2e__it_prints_unused_gems
    require "open3"

    # FileUtils.rm_rf(GEM_DIR) # Uncomment for the full E2E test
    skip = Dir.exist?(GEM_DIR)
    FileUtils.mkdir_p(GEM_DIR) unless skip

    Bundler.with_unbundled_env do
      Dir.chdir(GEM_DIR) do
        Open3.capture3("bundle gem myapp") unless skip

        Dir.chdir(File.join(GEM_DIR, "myapp")) do
          Open3.capture3("bundle config set --local path vendor") unless skip
          Open3.capture3("bundle install") unless skip
          Open3.capture3("git commit --all -m 'init'") unless skip
          Open3.capture3("bundle add favicon_factory") unless skip
          Open3.capture3("git commit --all -m 'add favicon_factory'") unless skip
          Open3.capture3("bundle add --path '../../..' degem") unless skip
          Open3.capture3('echo \'require "rubocop"\' >> lib/myapp.rb') unless skip

          out, err, status = Open3.capture3("bundle exec degem Gemfile")

          assert_equal 0, status.exitstatus
          refute_includes err, "myapp" # required in tests
          assert_includes err, "rake"
          refute_includes err, "minitest" # required in tests
          refute_includes err, "rubocop" # required in lib/myapp.rb (see above)
          assert_includes err, "favicon_factory"
          assert_includes err, "degem"
        end
      end
    end
  end

  def test_when_gemfile_does_not_exist_it_prints_an_error_and_exits_1
    testable_cli = Class.new(Degem::Cli) do
      def gemfile_exists?
        false
      end
    end

    stderr = StringIO.new

    actual = testable_cli.new(stderr).call

    assert_equal 1, actual
    assert_includes stderr.string, "Gemfile not found in the current directory"
  end
end
