require "spec_helper"
require "tmpdir"
require "stringio"

RSpec.describe "CLI scan formatted output snapshots" do
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  let(:dependency) do
    GemGuard::Dependency.new(
      name: "actionpack",
      version: "6.1.0",
      source: "https://rubygems.org"
    )
  end

  let(:vulnerability) do
    GemGuard::Vulnerability.new(
      id: "CVE-2021-22885",
      gem_name: "actionpack",
      severity: "HIGH",
      summary: "Possible Information Disclosure",
      details: "Detailed vulnerability information",
      fixed_versions: ["6.1.3.1"]
    )
  end

  before do
    allow_any_instance_of(GemGuard::Parser).to receive(:parse).and_return([dependency])
    allow_any_instance_of(GemGuard::VulnerabilityFetcher).to receive(:fetch_for).and_return([vulnerability])
  end

  it "matches JSON format snapshot" do
    Dir.mktmpdir do |dir|
      lockfile = File.join(dir, "Gemfile.lock")
      File.write(lockfile, "")

      output = capture_stdout do
        expect do
          GemGuard::CLI.start(["scan", "--lockfile", lockfile, "--format", "json"])
        end.to raise_error(SystemExit)
      end

      expect(output).to match_snapshot("cli_scan_json_output")
    end
  end

  it "matches table format snapshot" do
    Dir.mktmpdir do |dir|
      lockfile = File.join(dir, "Gemfile.lock")
      File.write(lockfile, "")

      output = capture_stdout do
        expect do
          GemGuard::CLI.start(["scan", "--lockfile", lockfile, "--format", "table"])
        end.to raise_error(SystemExit)
      end

      expect(output).to match_snapshot("cli_scan_table_output")
    end
  end
end
