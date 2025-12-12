require_relative "lib/bundle_alphabetically/version"

Gem::Specification.new do |spec|
  spec.name          = "bundle_alphabetically"
  spec.version       = BundleAlphabetically::VERSION
  spec.authors       = ["Elijah Rogers"]

  spec.summary       = "Bundler plugin that alphabetizes gem entries"
  spec.description   = "A Bundler plugin that keeps your Gemfile organized by alphabetizing gem declarations within each group automatically."
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/elijahrogers/bundle_alphabetically"
  spec.metadata      = {
    "source_code_uri" => "https://github.com/elijahrogers/bundle_alphabetically",
    "changelog_uri"   => "https://github.com/elijahrogers/bundle_alphabetically/blob/main/CHANGELOG.md"
  }

  spec.files         = Dir["lib/**/*", "plugins.rb", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"
  spec.add_dependency "bundler", ">= 2.2"
  spec.add_development_dependency "rspec", ">= 3.0"
end


