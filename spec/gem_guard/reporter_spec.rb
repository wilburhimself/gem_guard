require "spec_helper"

RSpec.describe GemGuard::Reporter do
  let(:reporter) { described_class.new }
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
  let(:vulnerable_dependency) do
    GemGuard::VulnerableDependency.new(
      dependency: dependency,
      vulnerability: vulnerability,
      recommended_fix: "bundle update actionpack --to 6.1.3.1"
    )
  end

  describe "#report" do
    context "with vulnerabilities found" do
      let(:analysis) { GemGuard::Analysis.new([vulnerable_dependency]) }

      it "generates table format report" do
        expect { reporter.report(analysis, format: "table") }.to output(
          a_string_including("Security Vulnerabilities Found")
            .and(including("actionpack"))
            .and(including("CVE-2021-22885"))
            .and(including("HIGH"))
            .and(including("bundle update actionpack"))
        ).to_stdout
      end

      it "generates JSON format report" do
        expect { reporter.report(analysis, format: "json") }.to output(
          a_string_that_is_valid_json
            .and(including("actionpack"))
            .and(including("CVE-2021-22885"))
        ).to_stdout
      end
    end

    context "with no vulnerabilities" do
      let(:analysis) { GemGuard::Analysis.new([]) }

      it "reports no vulnerabilities found" do
        expect { reporter.report(analysis, format: "table") }.to output(
          "✅ No vulnerabilities found!\n"
        ).to_stdout
      end

      it "generates empty JSON report" do
        output = capture_stdout { reporter.report(analysis, format: "json") }
        parsed = JSON.parse(output)

        expect(parsed["summary"]["has_vulnerabilities"]).to be false
        expect(parsed["vulnerabilities"]).to be_empty
      end
    end

    it "handles unknown format gracefully" do
      analysis = GemGuard::Analysis.new([])

      expect { reporter.report(analysis, format: "unknown") }.to output(
        "Unknown format: unknown. Supported formats: table, json\n"
      ).to_stdout
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  def a_string_that_is_valid_json
    satisfy { |string|
      JSON.parse(string)
      begin
        true
      rescue
        false
      end
    }
  end
end
