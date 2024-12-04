require "test_helper"

class TestE2e < Minitest::Test
  def setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(TEST_DIR)
  end

  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end

  def test_e2e__it_prints_unused_gems
    require "open3"

    # FileUtils.rm_rf(GEM_DIR) # Uncomment for the full E2E test
    skip = Dir.exist?(GEM_DIR)
    FileUtils.mkdir_p(GEM_DIR) unless skip

    Bundler.with_unbundled_env do
      Dir.chdir(GEM_DIR) do
        Open3.capture3("bundle gem myapp --test=minitest") unless skip

        Dir.chdir(File.join(GEM_DIR, "myapp")) do
          Open3.capture3("bundle config set --local path vendor") unless skip
          Open3.capture3("bundle install") unless skip
          Open3.capture3("git config --global user.email 'email@example.com'")
          Open3.capture3("git config --global user.name 'name'")
          Open3.capture3("git commit --all -m 'init'") unless skip
          Open3.capture3("bundle add favicon_factory") unless skip
          Open3.capture3("git commit --all -m 'add favicon_factory'") unless skip
          Open3.capture3("bundle add --path '../../..' degem") unless skip
          Open3.capture3('echo \'require "rubocop"\' >> lib/myapp.rb') unless skip

          _out, err, status = Open3.capture3("bundle exec degem Gemfile")

          assert_equal 0, status.exitstatus
          refute_includes err, "myapp" # required in tests
          assert_includes err, "rake"
          refute_includes err, "minitest" # required in tests
          refute_includes err, "rubocop" # required in lib/myapp.rb (see above)
          assert_includes err, "favicon_factory"
          refute_includes err, "degem"
        end
      end
    end
  end
end
