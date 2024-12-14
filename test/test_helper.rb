# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "degem"

require "minitest/autorun"
require "securerandom"

TEST_DIR = File.join(Dir.pwd, "tmp", "test")
GEM_DIR = File.join(Dir.pwd, "tmp", "gem")

def random_string
  SecureRandom.uuid
end

def with_file(content:, path: random_string)
  test_path = File.join(TEST_DIR, path)
  dir = File.dirname(test_path)
  FileUtils.mkdir_p(dir)
  file = File.new(test_path, "w")
  file.write(content)
  file.rewind
  yield(file.path)
ensure
  file.close
  FileUtils.rm_rf(File.join(TEST_DIR, path.split(File::SEPARATOR).first))
end

def with_gemfile(&)
  content = <<~CONTENT
    # frozen_string_literal: true
    source "https://rubygems.org"
  CONTENT

  with_file(path: File.join("app", "Gemfile"), content: content, &)
end

def bundle_install(rubygems, gemspec_paths = [], &block)
  return yield(gemspec_paths) if rubygems == []

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

def with_gem(name:, source_code: "")
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
      yield(parts.join(File::SEPARATOR), gemspec_path)
    end
  end
end

def with_gemspec(gem_name:, content:, &block)
  with_file(path: File.join("specifications", "#{gem_name}-1.0.0.gemspec"), content: content, &block)
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

def assert_array(xs, ys, msg = nil)
  assert_equal xs.sort, ys.sort, msg
end
