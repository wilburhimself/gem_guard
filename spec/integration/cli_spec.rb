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

  describe "sbom command" do
    before do
      # Create a test Gemfile.lock with some dependencies
      File.write("test_gemfile.lock", test_gemfile_lock_content)
    end

    after do
      File.delete("test_gemfile.lock") if File.exist?("test_gemfile.lock")
      File.delete("test_sbom.json") if File.exist?("test_sbom.json")
    end

    it "generates SPDX SBOM by default" do
      output = capture_output { GemGuard::CLI.start(["sbom", "--lockfile", "test_gemfile.lock"]) }

      expect(output).to include('"spdxVersion"')
      expect(output).to include('"packages"')
      expect(output).to include("rack")
    end

    it "generates CycloneDX SBOM when requested" do
      output = capture_output { GemGuard::CLI.start(["sbom", "--lockfile", "test_gemfile.lock", "--format", "cyclone-dx"]) }

      expect(output).to include('"bomFormat": "CycloneDX"')
      expect(output).to include('"components"')
      expect(output).to include("rack")
    end

    it "writes SBOM to file when output option is provided" do
      capture_output { GemGuard::CLI.start(["sbom", "--lockfile", "test_gemfile.lock", "--output", "test_sbom.json"]) }

      expect(File.exist?("test_sbom.json")).to be true

      content = File.read("test_sbom.json")
      expect(content).to include('"spdxVersion"')
      expect(content).to include("rack")
    end

    it "uses custom project name when provided" do
      output = capture_output { GemGuard::CLI.start(["sbom", "--lockfile", "test_gemfile.lock", "--project", "my-app"]) }

      expect(output).to include("my-app")
    end

    it "handles missing lockfile gracefully" do
      expect do
        capture_output { GemGuard::CLI.start(["sbom", "--lockfile", "nonexistent.lock"]) }
      end.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    end
  end

  describe "typosquat command" do
    before do
      # Create a test Gemfile.lock with potentially suspicious dependencies
      File.write("test_typosquat.lock", typosquat_test_lockfile_content)

      # Mock the TyposquatChecker to avoid real API calls
      allow_any_instance_of(GemGuard::TyposquatChecker).to receive(:check_dependencies).and_return(
        [
          {
            gem_name: "railz",
            version: "7.0.0",
            suspected_target: "rails",
            similarity_score: 0.9,
            target_downloads: 100_000_000,
            risk_level: "high"
          }
        ]
      )
    end

    after do
      File.delete("test_typosquat.lock") if File.exist?("test_typosquat.lock")
      File.delete("typosquat_report.json") if File.exist?("typosquat_report.json")
    end

    it "detects potential typosquat dependencies" do
      output = capture_output { GemGuard::CLI.start(["typosquat", "--lockfile", "test_typosquat.lock"]) }

      expect(output).to include("Potential Typosquat Dependencies Found")
      expect(output).to include("railz")
      expect(output).to include("rails")
      expect(output).to include("HIGH")
    end

    it "outputs JSON format when requested" do
      output = capture_output { GemGuard::CLI.start(["typosquat", "--lockfile", "test_typosquat.lock", "--format", "json"]) }

      expect { JSON.parse(output) }.not_to raise_error
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.first["gem_name"]).to eq("railz")
    end

    it "writes report to file when output option is provided" do
      capture_output { GemGuard::CLI.start(["typosquat", "--lockfile", "test_typosquat.lock", "--output", "typosquat_report.json"]) }

      expect(File.exist?("typosquat_report.json")).to be true
      content = File.read("typosquat_report.json")
      expect(content).to include("railz")
    end

    it "exits with appropriate code for high-risk findings" do
      expect do
        capture_output { GemGuard::CLI.start(["typosquat", "--lockfile", "test_typosquat.lock"]) }
      end.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1) # EXIT_VULNERABILITIES_FOUND
      end
    end

    it "handles no suspicious dependencies found" do
      allow_any_instance_of(GemGuard::TyposquatChecker).to receive(:check_dependencies).and_return([])

      output = capture_output { GemGuard::CLI.start(["typosquat", "--lockfile", "test_typosquat.lock"]) }
      expect(output).to include("No potential typosquat dependencies found")
    end

    it "handles missing lockfile gracefully" do
      expect do
        capture_output { GemGuard::CLI.start(["typosquat", "--lockfile", "nonexistent.lock"]) }
      end.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(2)
      end
    end
  end

  describe "version command" do
    it "displays the version" do
      output = capture_output { GemGuard::CLI.start(["version"]) }
      expect(output.strip).to eq(GemGuard::VERSION)
    end
  end

  private

  def test_gemfile_lock_content
    <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:
          rack (2.2.3)
          json (2.6.1)

      PLATFORMS
        ruby

      DEPENDENCIES
        rack
        json

      BUNDLED WITH
         2.3.0
    LOCKFILE
  end

  def typosquat_test_lockfile_content
    <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:
          railz (7.0.0)
          nokogir (1.13.0)
          rack (2.2.3)

      PLATFORMS
        ruby

      DEPENDENCIES
        railz
        nokogir
        rack

      BUNDLED WITH
         2.3.0
    LOCKFILE
  end
end
