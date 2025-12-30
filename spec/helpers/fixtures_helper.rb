require "fileutils"
require "open3"
require "tmpdir"

def run_bundle_command(subcommand, gemfile_path)
  output = nil
  status = nil
  Bundler.with_unbundled_env do
    # Keep bundler state fully isolated per temp Gemfile so integration
    # specs don't depend on (or write to) the user's home directory.
    bundle_root = File.dirname(gemfile_path)
    home = File.join(bundle_root, ".bundle_home")
    FileUtils.mkdir_p(home)

    env = {
      "BUNDLE_GEMFILE" => gemfile_path,
      "HOME" => home,
      "BUNDLE_APP_CONFIG" => File.join(bundle_root, ".bundle"),
      "BUNDLE_PATH" => File.join(bundle_root, "vendor", "bundle"),
      "BUNDLE_DISABLE_VERSION_CHECK" => "true",
    }
    command = "#{Gem.ruby} -S bundle #{subcommand}"
    output, status = Open3.capture2e(env, command)
  end

  unless status.success?
    # Capture the output for debugging
    raise "bundle #{subcommand} failed: #{output}"
  end

  output
end

def prepare_gemfile(fixture_name)
  dir = Dir.mktmpdir
  gemfile_path = File.join(dir, "Gemfile")

  project_root = File.expand_path("../../", __dir__)

  # Create a minimal Gemfile just to install the plugin to avoid network
  # calls for other gems or resolution errors.
  minimal_content = <<~RUBY
    source "https://rubygems.org"
    plugin 'bundle_alphabetically', path: '#{project_root}'
  RUBY

  File.write(gemfile_path, minimal_content)
  run_bundle_command("install", gemfile_path)

  # Overwrite with the actual fixture content
  fixture_path = File.join(__dir__, "../fixtures", fixture_name)
  content = File.read(fixture_path)

  content = set_plugin_path(content, project_root)

  File.write(gemfile_path, content)

  yield(gemfile_path, dir)
ensure
  FileUtils.remove_entry(dir) if dir
end

def fixture_content(fixture_name)
  path = File.join(__dir__, "../fixtures", fixture_name)
  content = File.read(path)
  project_root = File.expand_path("../../", __dir__)

  set_plugin_path(content, project_root)
end

def set_plugin_path(content, project_root)
  if content.include?("plugin 'bundle_alphabetically'")
    content.gsub(/path: ['"](\.\.\/)+['"]/, "path: '#{project_root}'")
  else
    "plugin 'bundle_alphabetically', path: '#{project_root}'\n\n" + content
  end
end

def create_dummy_gem(name, gems_dir)
  gem_dir = File.join(gems_dir, name)
  FileUtils.mkdir_p(File.join(gem_dir, "lib"))

  File.write(File.join(gem_dir, "lib", "#{name}.rb"), "module #{name.capitalize}\nend\n")

  File.write(File.join(gem_dir, "#{name}.gemspec"), <<~GEMSPEC)
    Gem::Specification.new do |spec|
      spec.name = "#{name}"
      spec.version = "0.1.0"
      spec.summary = "#{name}"
      spec.authors = ["bundle_alphabetically spec"]
      spec.files = ["lib/#{name}.rb"]
      spec.require_paths = ["lib"]
    end
  GEMSPEC
end
