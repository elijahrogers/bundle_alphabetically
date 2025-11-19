require "bundler"
require "bundler/plugin/api"

require_relative "bundle_alphabetically/version"
require_relative "bundle_alphabetically/gemfile_sorter"

module BundleAlphabetically
  class SortGemfileCommand < Bundler::Plugin::API
    command "sort_gemfile"

    def exec(_command, args)
      check = args.include?("--check") || args.include?("-c")
      GemfileSorter.run!(check: check)
    rescue Bundler::BundlerError => e
      Bundler.ui.error(e.message)
      raise
    end
  end
end

Bundler::Plugin.add_hook("after-install-all") do |_dependencies|
  begin
    BundleAlphabetically::GemfileSorter.run!
  rescue Bundler::BundlerError => e
    Bundler.ui.error("bundle_alphabetically: #{e.message}")
  end
end


