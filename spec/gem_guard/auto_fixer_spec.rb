require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe GemGuard::AutoFixer do
  let(:temp_dir) { Dir.mktmpdir }
  let(:lockfile_path) { File.join(temp_dir, "Gemfile.lock") }
  let(:gemfile_path) { File.join(temp_dir, "Gemfile") }
  let(:auto_fixer) { described_class.new(lockfile_path, gemfile_path) }

  let(:vulnerable_dependency) do
    dependency = GemGuard::Dependency.new(
      name: "nokogiri",
      version: "1.18.8",
      source: "https://rubygems.org",
      dependencies: []
    )

    vulnerability = GemGuard::Vulnerability.new(
      id: "GHSA-353f-x4gh-cqq8",
      gem_name: "nokogiri",
      severity: "HIGH",
      summary: "Nokogiri patches vendored libxml2 to resolve multiple CVEs",
      details: "Security vulnerability details"
    )

    GemGuard::VulnerableDependency.new(
      dependency: dependency,
      vulnerability: vulnerability,
      recommended_fix: "bundle update nokogiri --to 1.18.9"
    )
  end

  let(:sample_gemfile) do
    <<~GEMFILE
      source "https://rubygems.org"
      
      gem "nokogiri", "~> 1.18.0"
      gem "rails", "~> 7.0.0"
    GEMFILE
  end

  let(:sample_lockfile) do
    <<~LOCKFILE
      GEM
        remote: https://rubygems.org/
        specs:
          nokogiri (1.18.8)
          rails (7.0.4)

      PLATFORMS
        ruby

      DEPENDENCIES
        nokogiri (~> 1.18.0)
        rails (~> 7.0.0)

      BUNDLED WITH
         2.4.10
    LOCKFILE
  end

  before do
    File.write(gemfile_path, sample_gemfile)
    File.write(lockfile_path, sample_lockfile)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#fix_vulnerabilities" do
    context "with valid vulnerable dependencies" do
      it "plans fixes correctly in dry run mode" do
        result = auto_fixer.fix_vulnerabilities([vulnerable_dependency], dry_run: true)

        expect(result[:status]).to eq(:dry_run)
        expect(result[:fixes]).to be_an(Array)
        expect(result[:fixes].first[:gem_name]).to eq("nokogiri")
        expect(result[:fixes].first[:current_version]).to eq("1.18.8")
        expect(result[:fixes].first[:target_version]).to eq("1.18.9")
      end

      it "returns no fixes needed when no vulnerable dependencies" do
        result = auto_fixer.fix_vulnerabilities([], dry_run: true)

        expect(result[:status]).to eq(:no_fixes_needed)
        expect(result[:message]).to include("No automatic fixes available")
      end

      it "creates backup when applying fixes" do
        allow(auto_fixer).to receive(:apply_single_fix).and_return(true)
        allow(auto_fixer).to receive(:system).and_return(true)

        auto_fixer.fix_vulnerabilities([vulnerable_dependency], backup: true)

        backup_files = Dir.glob("#{lockfile_path}.backup.*")
        expect(backup_files).not_to be_empty
      end

      it "skips backup when requested" do
        allow(auto_fixer).to receive(:apply_single_fix).and_return(true)
        allow(auto_fixer).to receive(:system).and_return(true)

        auto_fixer.fix_vulnerabilities([vulnerable_dependency], backup: false)

        backup_files = Dir.glob("#{lockfile_path}.backup.*")
        expect(backup_files).to be_empty
      end
    end

    context "with missing files" do
      it "raises error when Gemfile is missing" do
        FileUtils.rm(gemfile_path)

        expect {
          auto_fixer.fix_vulnerabilities([vulnerable_dependency])
        }.to raise_error(/Gemfile not found/)
      end

      it "raises error when Gemfile.lock is missing" do
        FileUtils.rm(lockfile_path)

        expect {
          auto_fixer.fix_vulnerabilities([vulnerable_dependency])
        }.to raise_error(/Gemfile\.lock not found/)
      end
    end
  end

  describe "private methods" do
    describe "#extract_version_from_fix" do
      it "extracts version from bundle update command" do
        fix_command = "bundle update nokogiri --to 1.18.9"
        version = auto_fixer.send(:extract_version_from_fix, fix_command)
        expect(version).to eq("1.18.9")
      end

      it "returns nil for invalid fix command" do
        fix_command = "invalid command"
        version = auto_fixer.send(:extract_version_from_fix, fix_command)
        expect(version).to be_nil
      end
    end

    describe "#version_available_and_safe?" do
      it "returns true for valid semantic versions" do
        expect(auto_fixer.send(:version_available_and_safe?, "nokogiri", "1.18.9")).to be true
        expect(auto_fixer.send(:version_available_and_safe?, "rails", "7.0.4.1")).to be true
      end

      it "returns false for invalid versions" do
        expect(auto_fixer.send(:version_available_and_safe?, "nokogiri", "")).to be false
        expect(auto_fixer.send(:version_available_and_safe?, "nokogiri", nil)).to be false
        expect(auto_fixer.send(:version_available_and_safe?, "nokogiri", "invalid")).to be false
      end
    end

    describe "#severity_emoji" do
      it "returns correct emojis for different severities" do
        expect(auto_fixer.send(:severity_emoji, "CRITICAL")).to eq("🔴")
        expect(auto_fixer.send(:severity_emoji, "HIGH")).to eq("🟠")
        expect(auto_fixer.send(:severity_emoji, "MEDIUM")).to eq("🟡")
        expect(auto_fixer.send(:severity_emoji, "LOW")).to eq("🟢")
        expect(auto_fixer.send(:severity_emoji, "UNKNOWN")).to eq("🟢")
      end
    end
  end
end
