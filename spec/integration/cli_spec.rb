require "spec_helper"
require "tempfile"

RSpec.describe "gem_guard CLI", type: :integration do
  before do
    # Mock the vulnerability fetcher to avoid real API calls
    allow_any_instance_of(GemGuard::VulnerabilityFetcher).to receive(:make_http_request).and_return(nil)
  end
  let(:sample_gemfile_lock) do
    <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:
          actionpack (6.1.0)
            actionview (= 6.1.0)
            activesupport (= 6.1.0)
          actionview (6.1.0)
            activesupport (= 6.1.0)
          activesupport (6.1.0)
            concurrent-ruby (~> 1.0, >= 1.0.2)
          concurrent-ruby (1.1.8)

      PLATFORMS
        ruby

      DEPENDENCIES
        actionpack

      BUNDLED WITH
         2.2.3
    LOCKFILE
  end

  describe "scan command" do
    it "scans a Gemfile.lock and reports vulnerabilities" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        output = `ruby -I lib exe/gem_guard scan --lockfile #{lockfile.path} 2>&1`
        exit_code = $?.exitstatus

        expect(output).to include("No vulnerabilities found!")
        expect(exit_code).to eq(0)
      end
    end

    it "reports no vulnerabilities when none are found" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        output = `ruby -I lib exe/gem_guard scan --lockfile #{lockfile.path} 2>&1`
        exit_code = $?.exitstatus

        expect(output).to include("No vulnerabilities found!")
        expect(exit_code).to eq(0)
      end
    end

    it "outputs JSON format when requested" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        output = `ruby -I lib exe/gem_guard scan --lockfile #{lockfile.path} --format json 2>&1`

        expect { JSON.parse(output) }.not_to raise_error
      end
    end
  end

  describe "version command" do
    it "displays the version" do
      output = `ruby -I lib exe/gem_guard version 2>&1`
      expect(output.strip).to eq(GemGuard::VERSION)
    end
  end
end
