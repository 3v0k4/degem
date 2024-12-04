# frozen_string_literal: true

require_relative "lib/degem/version"

Gem::Specification.new do |spec|
  spec.name = "degem"
  spec.version = Degem::VERSION
  spec.authors = ["3v0k4"]
  spec.email = ["riccardo.odone@gmail.com"]

  spec.summary = "Find unused gems in the Ruby bundle"
  spec.description = "Degem finds unused gems in the Ruby bundle (ie, an app with a `Gemfile` or a gem with both a `Gemfile` and a gemspec)."
  spec.homepage = "https://github.com/3v0k4/degem"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/3v0k4/favicon_factory/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*") + Dir.glob("exe/*")
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
