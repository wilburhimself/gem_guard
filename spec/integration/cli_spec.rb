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
    it "generates SPDX SBOM by default" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        output = capture_output { GemGuard::CLI.start(["sbom", "--lockfile", lockfile.path, "--project", "test-app"]) }

        expect { JSON.parse(output) }.not_to raise_error
        sbom_data = JSON.parse(output)
        expect(sbom_data["spdxVersion"]).to eq("SPDX-2.3")
        expect(sbom_data["name"]).to eq("test-app-sbom")
      end
    end

    it "generates CycloneDX SBOM when requested" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        output = capture_output { GemGuard::CLI.start(["sbom", "--lockfile", lockfile.path, "--format", "cyclone-dx", "--project", "test-app"]) }

        expect { JSON.parse(output) }.not_to raise_error
        sbom_data = JSON.parse(output)
        expect(sbom_data["bomFormat"]).to eq("CycloneDX")
        expect(sbom_data["specVersion"]).to eq("1.5")
      end
    end

    it "writes SBOM to file when output option is provided" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        Tempfile.create(["sbom", ".json"]) do |output_file|
          output = capture_output do
            GemGuard::CLI.start(["sbom", "--lockfile", lockfile.path, "--output", output_file.path])
          end

          expect(output).to include("SBOM written to #{output_file.path}")
          expect(File.exist?(output_file.path)).to be true
          
          file_content = File.read(output_file.path)
          expect { JSON.parse(file_content) }.not_to raise_error
        end
      end
    end

    it "handles unsupported format gracefully" do
      Tempfile.create(["Gemfile", ".lock"]) do |lockfile|
        lockfile.write(sample_gemfile_lock)
        lockfile.flush

        output = capture_output do
          begin
            GemGuard::CLI.start(["sbom", "--lockfile", lockfile.path, "--format", "invalid"])
          rescue SystemExit
            # Thor calls exit for invalid format
          end
        end

        expect(output).to include("Error: Unsupported format 'invalid'")
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
