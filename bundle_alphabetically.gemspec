require_relative "lib/bundle_alphabetically/version"

Gem::Specification.new do |spec|
  spec.name          = "bundle_alphabetically"
  spec.version       = BundleAlphabetically::VERSION
  spec.authors       = ["bundle_alphabetically"]
  spec.email         = ["change-me@example.com"]

  spec.summary       = "Bundler plugin that alphabetizes gem entries in Gemfile groups"
  spec.description   = "A Bundler plugin that keeps your Gemfile organized by alphabetizing gem declarations within each group, automatically after installs or manually via a command."
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*", "plugins.rb", "README.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"
  spec.add_dependency "bundler", ">= 2.2"
  spec.add_development_dependency "rspec", ">= 3.0"
end


