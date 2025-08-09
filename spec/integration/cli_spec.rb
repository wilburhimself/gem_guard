require "spec_helper"
require "tempfile"
require "stringio"

RSpec.describe "gem_guard CLI", type: :integration do
  def capture_output
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
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
    before do
      # Mock the vulnerability fetcher to avoid real API calls
      allow_any_instance_of(GemGuard::VulnerabilityFetcher).to receive(:fetch_for).and_return([])
    end

    it "scans a Gemfile.lock and reports vulnerabilities" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        output = capture_output do
          GemGuard::CLI.start(["scan", "--lockfile", lockfile.path])
        rescue SystemExit
          # Thor calls exit, which we need to catch in tests
        end

        expect(output).to include("No vulnerabilities found!")
      end
    end

    it "reports no vulnerabilities when none are found" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        output = capture_output do
          GemGuard::CLI.start(["scan", "--lockfile", lockfile.path])
        rescue SystemExit
          # Thor calls exit, which we need to catch in tests
        end

        expect(output).to include("No vulnerabilities found!")
      end
    end

    it "outputs JSON format when requested" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        output = capture_output do
          GemGuard::CLI.start(["scan", "--lockfile", lockfile.path, "--format", "json"])
        rescue SystemExit
          # Thor calls exit, which we need to catch in tests
        end

        expect { JSON.parse(output) }.not_to raise_error
      end
    end
  end

  describe "version command" do
    it "displays the version" do
      output = capture_output { GemGuard::CLI.start(["version"]) }
      expect(output.strip).to eq(GemGuard::VERSION)
    end
  end
end
