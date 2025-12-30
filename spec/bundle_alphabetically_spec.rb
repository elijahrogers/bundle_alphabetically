require "spec_helper"
require "helpers/fixtures_helper"

RSpec.describe "BundleAlphabetically Integration" do
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

    it "sorts the Rails Gemfile correctly" do
      prepare_gemfile("Gemfile.rails_unsorted") do |gemfile_path, _|
        run_bundle_command("sort_gemfile", gemfile_path)

        sorted_content = File.read(gemfile_path)
        expected_content = fixture_content("Gemfile.rails_sorted")

        # When comparing large files, strip and maybe normalize newlines
        expect(sorted_content.strip).to eq(expected_content.strip)
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

  describe "bundle install hook" do
    it "sorts the Gemfile automatically after bundle install" do
      prepare_gemfile("Gemfile.unsorted") do |gemfile_path, dir|
        gems_dir = File.join(dir, "gems")
        FileUtils.mkdir_p(gems_dir)

        create_dummy_gem("alpha", gems_dir)
        create_dummy_gem("beta", gems_dir)
        create_dummy_gem("zebra", gems_dir)

        # Start from the existing fixture, then make the gems resolvable offline.
        content = fixture_content("Gemfile.unsorted")
        content = content.gsub(/^gem "alpha"$/, 'gem "alpha", path: "gems/alpha"')
        content = content.gsub(/^gem "zebra"$/, 'gem "zebra", path: "gems/zebra"')

        # Simulate "adding a gem" (in an unsorted position) before running install.
        content << %(gem "beta", path: "gems/beta"\n)

        File.write(gemfile_path, content)

        before = File.read(gemfile_path)
        expect(before.index('gem "zebra"')).to be < before.index('gem "alpha"')

        output = run_bundle_command("install --local", gemfile_path)

        after = File.read(gemfile_path)
        alpha_index = after.index('gem "alpha"')
        beta_index = after.index('gem "beta"')
        zebra_index = after.index('gem "zebra"')

        expect(alpha_index).to be < beta_index
        expect(beta_index).to be < zebra_index

        # Prove the hook ran (not just that bundler succeeded).
        expect(output).to include("Gemfile gems alphabetized by bundle_alphabetically")
      end
    end
  end
end

