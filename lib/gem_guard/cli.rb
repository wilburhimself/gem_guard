require "thor"

module GemGuard
  class CLI < Thor
    desc "scan", "Scan dependencies for known vulnerabilities"
    option :format, type: :string, default: "table", desc: "Output format (table, json)"
    option :lockfile, type: :string, default: "Gemfile.lock", desc: "Path to Gemfile.lock"
    def scan
      lockfile_path = options[:lockfile]

      unless File.exist?(lockfile_path)
        puts "Error: #{lockfile_path} not found"
        exit 1
      end

      dependencies = Parser.new.parse(lockfile_path)
      vulnerabilities = VulnerabilityFetcher.new.fetch_for(dependencies)
      analysis = Analyzer.new.analyze(dependencies, vulnerabilities)

      Reporter.new.report(analysis, format: options[:format])

      exit 1 if analysis.has_vulnerabilities?
    end

    desc "version", "Show gem_guard version"
    def version
      puts GemGuard::VERSION
    end
  end
end
