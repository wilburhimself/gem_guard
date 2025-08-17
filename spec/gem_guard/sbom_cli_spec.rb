require "spec_helper"

RSpec.describe "gem_guard sbom", type: :integration do
  it "exits 2 when lockfile is missing" do
    Dir.mktmpdir do |dir|
      missing_lockfile = File.join(dir, "Gemfile.lock")

      expect do
        expect do
          GemGuard::CLI.start(["sbom", "--lockfile", missing_lockfile])
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(2) }
      end.to output(/Error: .*Gemfile\.lock.* not found/).to_stdout
    end
  end

  it "exits 2 on unsupported format" do
    Dir.mktmpdir do |dir|
      lockfile = File.join(dir, "Gemfile.lock")
      File.write(lockfile, "")

      allow_any_instance_of(GemGuard::Parser).to receive(:parse).and_return([])

      expect do
        expect do
          GemGuard::CLI.start(["sbom", "--lockfile", lockfile, "--format", "unknown"])
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(2) }
      end.to output(/Unsupported format 'unknown'/).to_stdout
    end
  end
end
