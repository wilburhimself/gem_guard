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

    desc "sbom", "Generate Software Bill of Materials (SBOM)"
    option :format, type: :string, default: "spdx", desc: "SBOM format (spdx, cyclone-dx)"
    option :lockfile, type: :string, default: "Gemfile.lock", desc: "Path to Gemfile.lock"
    option :output, type: :string, desc: "Output file path (default: stdout)"
    option :project, type: :string, default: "ruby-project", desc: "Project name for SBOM"
    def sbom
      lockfile_path = options[:lockfile]

      unless File.exist?(lockfile_path)
        puts "Error: #{lockfile_path} not found"
        exit 1
      end

      dependencies = Parser.new.parse(lockfile_path)
      generator = SbomGenerator.new

      sbom_data = case options[:format].downcase
      when "spdx"
        generator.generate_spdx(dependencies, options[:project])
      when "cyclone-dx", "cyclonedx"
        generator.generate_cyclone_dx(dependencies, options[:project])
      else
        puts "Error: Unsupported format '#{options[:format]}'. Use 'spdx' or 'cyclone-dx'"
        exit 1
      end

      output_json = JSON.pretty_generate(sbom_data)

      if options[:output]
        File.write(options[:output], output_json)
        puts "SBOM written to #{options[:output]}"
      else
        puts output_json
      end
    end

    desc "version", "Show gem_guard version"
    def version
      puts GemGuard::VERSION
    end
  end
end
