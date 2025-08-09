require "spec_helper"

RSpec.describe GemGuard::Analyzer do
  let(:analyzer) { described_class.new }
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
      summary: "Test vulnerability",
      fixed_versions: ["6.1.3.1"]
    )
  end

  describe "#analyze" do
    it "identifies vulnerable dependencies" do
      dependencies = [dependency]
      vulnerabilities = [vulnerability]

      analysis = analyzer.analyze(dependencies, vulnerabilities)

      expect(analysis.has_vulnerabilities?).to be true
      expect(analysis.vulnerability_count).to eq(1)
      expect(analysis.vulnerable_dependencies.first.dependency).to eq(dependency)
      expect(analysis.vulnerable_dependencies.first.vulnerability).to eq(vulnerability)
    end

    it "suggests appropriate fixes" do
      dependencies = [dependency]
      vulnerabilities = [vulnerability]

      analysis = analyzer.analyze(dependencies, vulnerabilities)
      vuln_dep = analysis.vulnerable_dependencies.first

      expect(vuln_dep.recommended_fix).to include("bundle update actionpack")
      expect(vuln_dep.recommended_fix).to include("6.1.3.1")
    end

    it "returns empty analysis when no vulnerabilities match" do
      other_dependency = GemGuard::Dependency.new(
        name: "rails",
        version: "7.0.0",
        source: "https://rubygems.org"
      )
      dependencies = [other_dependency]
      vulnerabilities = [vulnerability]

      analysis = analyzer.analyze(dependencies, vulnerabilities)

      expect(analysis.has_vulnerabilities?).to be false
      expect(analysis.vulnerability_count).to eq(0)
    end
  end
end

RSpec.describe GemGuard::Analysis do
  let(:vulnerable_dependency) do
    GemGuard::VulnerableDependency.new(
      dependency: double("dependency"),
      vulnerability: double("vulnerability", severity: "HIGH"),
      recommended_fix: "bundle update gem"
    )
  end

  describe "#has_vulnerabilities?" do
    it "returns true when vulnerabilities exist" do
      analysis = described_class.new([vulnerable_dependency])
      expect(analysis.has_vulnerabilities?).to be true
    end

    it "returns false when no vulnerabilities exist" do
      analysis = described_class.new([])
      expect(analysis.has_vulnerabilities?).to be false
    end
  end

  describe "#high_severity_count" do
    it "counts high and critical severity vulnerabilities" do
      high_vuln = GemGuard::VulnerableDependency.new(
        dependency: double("dependency"),
        vulnerability: double("vulnerability", severity: "HIGH"),
        recommended_fix: "fix"
      )
      critical_vuln = GemGuard::VulnerableDependency.new(
        dependency: double("dependency"),
        vulnerability: double("vulnerability", severity: "CRITICAL"),
        recommended_fix: "fix"
      )
      low_vuln = GemGuard::VulnerableDependency.new(
        dependency: double("dependency"),
        vulnerability: double("vulnerability", severity: "LOW"),
        recommended_fix: "fix"
      )

      analysis = described_class.new([high_vuln, critical_vuln, low_vuln])

      expect(analysis.high_severity_count).to eq(2)
    end
  end
end
