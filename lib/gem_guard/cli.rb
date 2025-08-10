require "thor"
require "stringio"

module GemGuard
  class CLI < Thor
    # Exit codes for CI/CD integration
    EXIT_SUCCESS = 0
    EXIT_VULNERABILITIES_FOUND = 1
    EXIT_ERROR = 2

    desc "scan", "Scan dependencies for known vulnerabilities"
    option :format, type: :string, desc: "Output format (table, json)"
    option :lockfile, type: :string, desc: "Path to Gemfile.lock"
    option :config, type: :string, default: ".gemguard.yml", desc: "Path to config file"
    option :fail_on_vulnerabilities, type: :boolean, desc: "Exit with code 1 if vulnerabilities found"
    option :severity_threshold, type: :string, desc: "Minimum severity level (low, medium, high, critical)"
    option :output, type: :string, desc: "Output file path"
    def scan
      config = Config.new(options[:config])

      # Override config with CLI options
      lockfile_path = options[:lockfile] || config.lockfile_path
      format = options[:format] || config.output_format
      fail_on_vulns = options[:fail_on_vulnerabilities].nil? ? config.fail_on_vulnerabilities? : options[:fail_on_vulnerabilities]
      severity_threshold = options[:severity_threshold] || config.severity_threshold
      output_file = options[:output] || config.output_file

      unless File.exist?(lockfile_path)
        puts "Error: #{lockfile_path} not found"
        exit EXIT_ERROR
      end

      begin
        dependencies = Parser.new.parse(lockfile_path)
        vulnerabilities = VulnerabilityFetcher.new.fetch_for(dependencies)

        # Filter vulnerabilities based on config
        filtered_vulnerabilities = filter_vulnerabilities(vulnerabilities, config)

        analysis = Analyzer.new.analyze(dependencies, filtered_vulnerabilities)

        # Filter analysis based on severity threshold
        filtered_analysis = filter_analysis_by_severity(analysis, severity_threshold, config)

        if output_file
          output_content = capture_report_output(filtered_analysis, format)
          File.write(output_file, output_content)
          puts "Report written to #{output_file}"
        else
          Reporter.new.report(filtered_analysis, format: format)
        end

        # Exit with appropriate code for CI/CD
        if filtered_analysis.has_vulnerabilities? && fail_on_vulns
          exit EXIT_VULNERABILITIES_FOUND
        else
          exit EXIT_SUCCESS
        end
      rescue => e
        puts "Error: #{e.message}"
        exit EXIT_ERROR
      end
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

    desc "config", "Manage configuration"
    option :init, type: :boolean, desc: "Initialize a new .gemguard.yml config file"
    option :show, type: :boolean, desc: "Show current configuration"
    option :path, type: :string, default: ".gemguard.yml", desc: "Config file path"
    def config
      config_file = Config.new(options[:path])

      if options[:init]
        if File.exist?(options[:path])
          puts "Config file #{options[:path]} already exists"
          exit EXIT_ERROR
        end

        # Create default config file
        default_config = {
          "lockfile" => "Gemfile.lock",
          "format" => "table",
          "fail_on_vulnerabilities" => true,
          "severity_threshold" => "low",
          "ignore_vulnerabilities" => [],
          "ignore_gems" => [],
          "output_file" => nil,
          "project_name" => config_file.send(:detect_project_name),
          "sbom" => {
            "format" => "spdx",
            "include_dev_dependencies" => false
          },
          "scan" => {
            "sources" => ["osv", "ruby_advisory_db"],
            "timeout" => 30
          }
        }

        File.write(options[:path], YAML.dump(default_config))
        puts "Created #{options[:path]} with default configuration"
      elsif options[:show]
        if config_file.exists?
          puts File.read(options[:path])
        else
          puts "No config file found at #{options[:path]}"
          puts "Run 'gem_guard config --init' to create one"
        end
      else
        puts "Usage: gem_guard config [--init|--show] [--path PATH]"
        puts "  --init  Create a new .gemguard.yml config file"
        puts "  --show  Display current configuration"
        puts "  --path  Specify config file path (default: .gemguard.yml)"
      end
    end

    desc "version", "Show gem_guard version"
    def version
      puts GemGuard::VERSION
    end

    private

    def filter_vulnerabilities(vulnerabilities, config)
      vulnerabilities.reject do |vuln|
        config.should_ignore_vulnerability?(vuln.id)
      end
    end

    def filter_analysis_by_severity(analysis, severity_threshold, config)
      return analysis unless severity_threshold

      filtered_vulnerable_deps = analysis.vulnerable_dependencies.select do |vuln_dep|
        vuln_dep.vulnerabilities.any? do |vuln|
          config.meets_severity_threshold?(extract_severity_level(vuln.severity))
        end
      end

      # Create new analysis with filtered vulnerabilities
      GemGuard::Analysis.new(filtered_vulnerable_deps)
    end

    def extract_severity_level(severity_string)
      return "unknown" if severity_string.nil? || severity_string.empty?

      # Extract severity from CVSS string or direct severity
      case severity_string.downcase
      when /critical/
        "critical"
      when /high/
        "high"
      when /medium/
        "medium"
      when /low/
        "low"
      else
        "unknown"
      end
    end

    def capture_report_output(analysis, format)
      old_stdout = $stdout
      $stdout = StringIO.new
      Reporter.new.report(analysis, format: format)
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end
end
