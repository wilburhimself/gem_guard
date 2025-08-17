require "spec_helper"

RSpec.describe GemGuard::Parser do
  let(:parser) { described_class.new }
  let(:sample_lockfile_content) do
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

  describe "#parse" do
    it "parses a Gemfile.lock and returns dependencies" do
      allow(File).to receive(:read).with("Gemfile.lock").and_return(sample_lockfile_content)

      dependencies = parser.parse("Gemfile.lock")

      expect(dependencies).to be_an(Array)
      expect(dependencies.length).to eq(4)

      actionpack = dependencies.find { |dep| dep.name == "actionpack" }
      expect(actionpack).not_to be_nil
      expect(actionpack.version).to eq("6.1.0")
      expect(actionpack.source).to eq("https://rubygems.org")
    end

    it "handles missing lockfile gracefully" do
      allow(File).to receive(:read).and_raise(Errno::ENOENT)

      expect { parser.parse("nonexistent.lock") }.to raise_error(Errno::ENOENT)
    end

    it "raises InvalidLockfileError for malformed lockfile" do
      invalid_path = File.expand_path("../fixtures/invalid_gemfile.lock", __dir__)

      expect {
        parser.parse(invalid_path)
      }.to raise_error(GemGuard::InvalidLockfileError, /Invalid Gemfile\.lock/)
    end

    it "raises InvalidLockfileError for truncated lockfile" do
      invalid_path = File.expand_path("../fixtures/invalid_gemfile_truncated.lock", __dir__)

      expect {
        parser.parse(invalid_path)
      }.to raise_error(GemGuard::InvalidLockfileError)
    end

    it "raises InvalidLockfileError for bad dependencies formatting" do
      invalid_path = File.expand_path("../fixtures/invalid_gemfile_bad_dependencies.lock", __dir__)

      expect {
        parser.parse(invalid_path)
      }.to raise_error(GemGuard::InvalidLockfileError)
    end
  end
end

RSpec.describe GemGuard::Dependency do
  describe "#initialize" do
    it "creates a dependency with required attributes" do
      dep = described_class.new(
        name: "rails",
        version: "7.0.0",
        source: "https://rubygems.org",
        dependencies: ["actionpack", "activerecord"]
      )

      expect(dep.name).to eq("rails")
      expect(dep.version).to eq("7.0.0")
      expect(dep.source).to eq("https://rubygems.org")
      expect(dep.dependencies).to eq(["actionpack", "activerecord"])
    end
  end

  describe "#==" do
    it "compares dependencies by name, version, and source" do
      dep1 = described_class.new(name: "rails", version: "7.0.0", source: "https://rubygems.org")
      dep2 = described_class.new(name: "rails", version: "7.0.0", source: "https://rubygems.org")
      dep3 = described_class.new(name: "rails", version: "6.1.0", source: "https://rubygems.org")

      expect(dep1).to eq(dep2)
      expect(dep1).not_to eq(dep3)
    end
  end
end
