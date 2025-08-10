require "spec_helper"
require "tempfile"

RSpec.describe GemGuard::Config do
  let(:temp_config_file) { Tempfile.new(["gemguard", ".yml"]) }
  let(:config_path) { temp_config_file.path }

  after do
    temp_config_file.close
    temp_config_file.unlink
  end

  describe "#initialize" do
    context "with no config file" do
      it "uses default configuration" do
        config = described_class.new("nonexistent.yml")
        expect(config.get("format")).to eq("table")
        expect(config.get("fail_on_vulnerabilities")).to be true
        expect(config.get("severity_threshold")).to eq("low")
      end
    end

    context "with valid config file" do
      before do
        config_content = {
          "format" => "json",
          "fail_on_vulnerabilities" => false,
          "severity_threshold" => "high",
          "ignore_vulnerabilities" => ["CVE-2023-1234"],
          "sbom" => {
            "format" => "cyclone-dx"
          }
        }
        temp_config_file.write(YAML.dump(config_content))
        temp_config_file.flush
      end

      it "loads and merges with defaults" do
        config = described_class.new(config_path)
        expect(config.get("format")).to eq("json")
        expect(config.get("fail_on_vulnerabilities")).to be false
        expect(config.get("severity_threshold")).to eq("high")
        expect(config.get("ignore_vulnerabilities")).to eq(["CVE-2023-1234"])
        expect(config.get("sbom.format")).to eq("cyclone-dx")
        expect(config.get("lockfile")).to eq("Gemfile.lock") # default value
      end
    end

    context "with invalid YAML" do
      before do
        temp_config_file.write("invalid: yaml: content: [")
        temp_config_file.flush
      end

      it "falls back to defaults and shows warning" do
        # Capture both the warning output and create the config in one expectation
        config = nil
        expect { config = described_class.new(config_path) }.to output(/Warning: Invalid YAML/).to_stdout
        expect(config.get("format")).to eq("table")
      end
    end
  end

  describe "#get and #set" do
    let(:config) { described_class.new(config_path) }

    it "gets nested values with dot notation" do
      # Create a fresh config to avoid test pollution
      fresh_config = described_class.new("nonexistent-config.yml")
      expect(fresh_config.get("sbom.format")).to eq("spdx")
      expect(fresh_config.get("scan.timeout")).to eq(30)
    end

    it "sets nested values with dot notation" do
      config.set("sbom.format", "cyclone-dx")
      config.set("custom.nested.value", "test")

      expect(config.get("sbom.format")).to eq("cyclone-dx")
      expect(config.get("custom.nested.value")).to eq("test")
    end
  end

  describe "convenience methods" do
    let(:config) { described_class.new(config_path) }

    before do
      config_content = {
        "lockfile" => "custom.lock",
        "format" => "json",
        "fail_on_vulnerabilities" => false,
        "severity_threshold" => "medium",
        "ignore_vulnerabilities" => ["CVE-2023-1234", "GHSA-xxxx-yyyy"],
        "ignore_gems" => ["test-gem", "dev-gem"],
        "output_file" => "report.json",
        "project_name" => "my-project",
        "sbom" => {
          "format" => "cyclone-dx",
          "include_dev_dependencies" => true
        },
        "scan" => {
          "sources" => ["osv"],
          "timeout" => 60
        }
      }
      temp_config_file.write(YAML.dump(config_content))
      temp_config_file.flush
      config.instance_variable_set(:@config, config.send(:load_config))
    end

    it "provides convenient access methods" do
      expect(config.lockfile_path).to eq("custom.lock")
      expect(config.output_format).to eq("json")
      expect(config.fail_on_vulnerabilities?).to be false
      expect(config.severity_threshold).to eq("medium")
      expect(config.ignored_vulnerabilities).to eq(["CVE-2023-1234", "GHSA-xxxx-yyyy"])
      expect(config.ignored_gems).to eq(["test-gem", "dev-gem"])
      expect(config.output_file).to eq("report.json")
      expect(config.project_name).to eq("my-project")
      expect(config.sbom_format).to eq("cyclone-dx")
      expect(config.include_dev_dependencies?).to be true
      expect(config.vulnerability_sources).to eq(["osv"])
      expect(config.scan_timeout).to eq(60)
    end
  end

  describe "#should_ignore_vulnerability?" do
    let(:config) { described_class.new(config_path) }

    before do
      config.set("ignore_vulnerabilities", ["CVE-2023-1234", "GHSA-xxxx-yyyy"])
    end

    it "returns true for ignored vulnerabilities" do
      expect(config.should_ignore_vulnerability?("CVE-2023-1234")).to be true
      expect(config.should_ignore_vulnerability?("GHSA-xxxx-yyyy")).to be true
    end

    it "returns false for non-ignored vulnerabilities" do
      expect(config.should_ignore_vulnerability?("CVE-2023-9999")).to be false
    end
  end

  describe "#should_ignore_gem?" do
    let(:config) { described_class.new(config_path) }

    before do
      config.set("ignore_gems", ["test-gem", "dev-gem"])
    end

    it "returns true for ignored gems" do
      expect(config.should_ignore_gem?("test-gem")).to be true
      expect(config.should_ignore_gem?("dev-gem")).to be true
    end

    it "returns false for non-ignored gems" do
      expect(config.should_ignore_gem?("production-gem")).to be false
    end
  end

  describe "#meets_severity_threshold?" do
    let(:config) { described_class.new(config_path) }

    context "with medium threshold" do
      before do
        config.set("severity_threshold", "medium")
      end

      it "allows medium and higher severities" do
        expect(config.meets_severity_threshold?("low")).to be false
        expect(config.meets_severity_threshold?("medium")).to be true
        expect(config.meets_severity_threshold?("high")).to be true
        expect(config.meets_severity_threshold?("critical")).to be true
      end

      it "handles nil and empty severities" do
        expect(config.meets_severity_threshold?(nil)).to be true
        expect(config.meets_severity_threshold?("")).to be true
      end

      it "handles unknown severities" do
        expect(config.meets_severity_threshold?("unknown")).to be true
      end
    end

    context "with critical threshold" do
      before do
        config.set("severity_threshold", "critical")
      end

      it "only allows critical severity" do
        expect(config.meets_severity_threshold?("low")).to be false
        expect(config.meets_severity_threshold?("medium")).to be false
        expect(config.meets_severity_threshold?("high")).to be false
        expect(config.meets_severity_threshold?("critical")).to be true
      end
    end
  end

  describe "#save" do
    let(:config) { described_class.new(config_path) }

    it "saves configuration to file" do
      config.set("format", "json")
      config.set("custom.value", "test")
      config.save

      # Load the file and verify contents
      saved_config = YAML.load_file(config_path)
      expect(saved_config["format"]).to eq("json")
      expect(saved_config["custom"]["value"]).to eq("test")
    end
  end

  describe "#exists?" do
    it "returns true when config file exists" do
      temp_config_file.write("format: json")
      temp_config_file.flush

      config = described_class.new(config_path)
      expect(config.exists?).to be true
    end

    it "returns false when config file doesn't exist" do
      config = described_class.new("nonexistent.yml")
      expect(config.exists?).to be false
    end
  end
end
