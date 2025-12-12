require "spec_helper"

RSpec.describe BundleAlphabetically::GemfileSorter do
  describe ".sort_contents" do
    it "sorts top-level gem declarations alphabetically" do
      input = <<~GEMFILE
        source "https://rubygems.org"

        gem "rails"
        gem "bootsnap"
        gem "puma"
      GEMFILE

      expected = <<~GEMFILE
        source "https://rubygems.org"

        gem "bootsnap"
        gem "puma"
        gem "rails"
      GEMFILE

      expect(described_class.sort_contents(input)).to eq(expected)
    end

    it "sorts gems within each group independently" do
      input = <<~GEMFILE
        source "https://rubygems.org"

        gem "zeitwerk"
        gem "rails"

        group :development do
          gem "web-console"
          gem "annotate"
        end

        group :test do
          gem "rspec-rails"
          gem "factory_bot_rails"
        end
      GEMFILE

      expected = <<~GEMFILE
        source "https://rubygems.org"

        gem "rails"
        gem "zeitwerk"

        group :development do
          gem "annotate"
          gem "web-console"
        end

        group :test do
          gem "factory_bot_rails"
          gem "rspec-rails"
        end
      GEMFILE

      expect(described_class.sort_contents(input)).to eq(expected)
    end

    it "keeps multi-line gem entries together" do
      input = <<~GEMFILE
        gem "rails",
            "~> 7.0",
            require: false
        gem "bootsnap", require: false
      GEMFILE

      expected = <<~GEMFILE
        gem "bootsnap", require: false
        gem "rails",
            "~> 7.0",
            require: false
      GEMFILE

      expect(described_class.sort_contents(input)).to eq(expected)
    end

    it "preserves comments and blank lines around gem entries" do
      input = <<~GEMFILE
        # Core gems
        gem "rails"

        # Performance
        gem "bootsnap"
      GEMFILE

      expected = <<~GEMFILE
        # Core gems
        gem "bootsnap"

        # Performance
        gem "rails"
      GEMFILE

      expect(described_class.sort_contents(input)).to eq(expected)
    end
  end
end


