require "spec_helper"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "BundleAlphabetically Integration" do
  def run_bundle_command(subcommand, gemfile_path)
    output = nil
    status = nil
    Bundler.with_unbundled_env do
      # Keep bundler state fully isolated per temp Gemfile so these integration
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

    project_root = File.expand_path("..", __dir__)

    # 1. Create a minimal Gemfile just to install the plugin
    #    This avoids network calls for other gems or resolution errors
    minimal_content = <<~RUBY
      source "https://rubygems.org"
      plugin 'bundle_alphabetically', path: '#{project_root}'
    RUBY
    File.write(gemfile_path, minimal_content)

    # 2. Run bundle install to register the plugin
    run_bundle_command("install", gemfile_path)

    # 3. Now overwrite with the actual fixture content (which may contain fake gems)
    fixture_path = File.join(__dir__, "fixtures", fixture_name)
    content = File.read(fixture_path)
    # Fixup path if it exists, otherwise prepend the plugin line if not present
    if content.include?("plugin 'bundle_alphabetically'")
      content.gsub!(/path: ['"](\.\.\/)+['"]/, "path: '#{project_root}'")
    else
      # If the fixture doesn't have the plugin (like the Rails one), prepend it
      content.prepend("plugin 'bundle_alphabetically', path: '#{project_root}'\n\n")
    end

    File.write(gemfile_path, content)

    yield(gemfile_path, dir)
  ensure
    FileUtils.remove_entry(dir) if dir
  end

  def fixture_content(fixture_name)
    path = File.join(__dir__, "fixtures", fixture_name)
    content = File.read(path)
    project_root = File.expand_path("..", __dir__)
    if content.include?("plugin 'bundle_alphabetically'")
      content.gsub(/path: ['"](\.\.\/)+['"]/, "path: '#{project_root}'")
    else
       "plugin 'bundle_alphabetically', path: '#{project_root}'\n\n" + content
    end
  end

  describe "bundle sort_gemfile" do
    it "sorts a simple unsorted Gemfile" do
      prepare_gemfile("Gemfile.unsorted") do |gemfile_path, _|
        run_bundle_command("sort_gemfile", gemfile_path)

        sorted_content = File.read(gemfile_path)
        expected_content = fixture_content("Gemfile.sorted")

        expect(sorted_content).to eq(expected_content)
      end
    end

    it "sorts a complex Gemfile with groups" do
      prepare_gemfile("Gemfile.complex_unsorted") do |gemfile_path, _|
        run_bundle_command("sort_gemfile", gemfile_path)

        sorted_content = File.read(gemfile_path)
        expected_content = fixture_content("Gemfile.complex_sorted")

        expect(sorted_content).to eq(expected_content)
      end
    end
    it "raises CheckFailed if unsorted with --check" do
      prepare_gemfile("Gemfile.unsorted") do |gemfile_path, _|
        expect {
          run_bundle_command("sort_gemfile --check", gemfile_path)
        }.to raise_error(/bundle sort_gemfile --check failed/)
      end
    end

    it "passes with --check if already sorted" do
      prepare_gemfile("Gemfile.sorted") do |gemfile_path, _|
        expect {
          run_bundle_command("sort_gemfile --check", gemfile_path)
        }.not_to raise_error
      end
    end
  end
end

