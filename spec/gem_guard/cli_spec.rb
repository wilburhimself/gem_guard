require "spec_helper"
require "tmpdir"

RSpec.describe GemGuard::CLI do
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  describe "scan error handling" do
    it "prints friendly message and exits 2 on InvalidLockfileError" do
      allow_any_instance_of(GemGuard::Parser).to receive(:parse)
        .and_raise(GemGuard::InvalidLockfileError.new("malformed lockfile"))

      Dir.mktmpdir do |dir|
        lockfile = File.join(dir, "Gemfile.lock")
        File.write(lockfile, "")

        expect do
          expect do
            GemGuard::CLI.start(["scan", "--lockfile", lockfile])
          end.to raise_error(SystemExit) { |e| expect(e.status).to eq(2) }
        end.to output(/Invalid Gemfile\.lock: malformed lockfile/).to_stdout
      end
    end

    it "prints file error and exits 2 on FileError" do
      allow_any_instance_of(GemGuard::Parser).to receive(:parse)
        .and_raise(GemGuard::FileError.new("cannot read lockfile"))

      Dir.mktmpdir do |dir|
        lockfile = File.join(dir, "Gemfile.lock")
        File.write(lockfile, "")

        expect do
          expect do
            GemGuard::CLI.start(["scan", "--lockfile", lockfile])
          end.to raise_error(SystemExit) { |e| expect(e.status).to eq(2) }
        end.to output(/File error: cannot read lockfile/).to_stdout
      end
    end
  end

  describe "typosquat error handling" do
    it "prints friendly message and exits 2 on InvalidLockfileError" do
      allow_any_instance_of(GemGuard::Parser).to receive(:parse)
        .and_raise(GemGuard::InvalidLockfileError.new("bad lockfile"))

      Dir.mktmpdir do |dir|
        lockfile = File.join(dir, "Gemfile.lock")
        File.write(lockfile, "")

        expect do
          expect do
            GemGuard::CLI.start(["typosquat", "--lockfile", lockfile])
          end.to raise_error(SystemExit) { |e| expect(e.status).to eq(2) }
        end.to output(/Invalid Gemfile\.lock: bad lockfile/).to_stdout
      end
    end

    it "prints file error and exits 2 on FileError" do
      allow_any_instance_of(GemGuard::Parser).to receive(:parse)
        .and_raise(GemGuard::FileError.new("locked out"))

      Dir.mktmpdir do |dir|
        lockfile = File.join(dir, "Gemfile.lock")
        File.write(lockfile, "")

        expect do
          expect do
            GemGuard::CLI.start(["typosquat", "--lockfile", lockfile])
          end.to raise_error(SystemExit) { |e| expect(e.status).to eq(2) }
        end.to output(/File error: locked out/).to_stdout
      end
    end
  end

  describe "fix error handling" do
    it "prints friendly message and exits 2 on InvalidLockfileError" do
      allow_any_instance_of(GemGuard::Parser).to receive(:parse)
        .and_raise(GemGuard::InvalidLockfileError.new("invalid format"))

      Dir.mktmpdir do |dir|
        lockfile = File.join(dir, "Gemfile.lock")
        gemfile = File.join(dir, "Gemfile")
        File.write(lockfile, "")
        File.write(gemfile, "source 'https://rubygems.org'\n")

        expect do
          expect do
            GemGuard::CLI.start(["fix", "--lockfile", lockfile, "--gemfile", gemfile])
          end.to raise_error(SystemExit) { |e| expect(e.status).to eq(2) }
        end.to output(/Invalid Gemfile\.lock: invalid format/).to_stdout
      end
    end

    it "prints file error and exits 2 on FileError" do
      allow_any_instance_of(GemGuard::Parser).to receive(:parse)
        .and_raise(GemGuard::FileError.new("no permission"))

      Dir.mktmpdir do |dir|
        lockfile = File.join(dir, "Gemfile.lock")
        gemfile = File.join(dir, "Gemfile")
        File.write(lockfile, "")
        File.write(gemfile, "source 'https://rubygems.org'\n")

        expect do
          expect do
            GemGuard::CLI.start(["fix", "--lockfile", lockfile, "--gemfile", gemfile])
          end.to raise_error(SystemExit) { |e| expect(e.status).to eq(2) }
        end.to output(/File error: no permission/).to_stdout
      end
    end
  end
end
