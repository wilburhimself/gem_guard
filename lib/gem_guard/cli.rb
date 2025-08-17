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
      rescue GemGuard::InvalidLockfileError => e
        puts "Invalid Gemfile.lock: #{e.message}"
        puts "Tip: Run 'bundle install' to regenerate your lockfile."
        exit EXIT_ERROR
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

    desc "typosquat", "Check for potential typosquat dependencies"
    option :lockfile, type: :string, default: "Gemfile.lock", desc: "Path to Gemfile.lock"
    option :format, type: :string, default: "table", desc: "Output format (table, json)"
    option :output, type: :string, desc: "Output file path"
    option :config, type: :string, desc: "Config file path"
    def typosquat
      config = Config.new(options[:config] || ".gemguard.yml")

      lockfile_path = options[:lockfile] || config.lockfile_path
      format = options[:format] || config.output_format
      output_file = options[:output] || config.output_file

      unless File.exist?(lockfile_path)
        puts "Error: #{lockfile_path} not found"
        exit EXIT_ERROR
      end

      begin
        dependencies = Parser.new.parse(lockfile_path)
        checker = TyposquatChecker.new
        suspicious_gems = checker.check_dependencies(dependencies)

        if output_file
          output_content = format_typosquat_output(suspicious_gems, format)
          File.write(output_file, output_content)
          puts "Typosquat report written to #{output_file}"
        else
          display_typosquat_results(suspicious_gems, format)
        end

        # Exit with appropriate code
        if suspicious_gems.any? { |sg| sg[:risk_level] == "critical" || sg[:risk_level] == "high" }
          exit EXIT_VULNERABILITIES_FOUND
        else
          exit EXIT_SUCCESS
        end
      rescue => e
        puts "Error: #{e.message}"
        exit EXIT_ERROR
      end
    end

    desc "config", "Manage configuration"
    option :init, type: :boolean, desc: "Initialize default config file"
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

    desc "fix", "Automatically fix vulnerable dependencies"
    option :lockfile, type: :string, desc: "Path to Gemfile.lock"
    option :gemfile, type: :string, desc: "Path to Gemfile"
    option :dry_run, type: :boolean, desc: "Show planned fixes without applying them"
    option :interactive, type: :boolean, desc: "Ask for confirmation before applying fixes"
    option :no_backup, type: :boolean, desc: "Skip creating backup of Gemfile.lock"
    option :config, type: :string, desc: "Config file path"
    def fix
      config = Config.new(options[:config] || ".gemguard.yml")

      lockfile_path = options[:lockfile] || config.lockfile_path
      gemfile_path = options[:gemfile] || "Gemfile"
      dry_run = options[:dry_run] || false
      interactive = options[:interactive] || false
      create_backup = !options[:no_backup]

      unless File.exist?(lockfile_path)
        puts "Error: #{lockfile_path} not found"
        exit EXIT_ERROR
      end

      unless File.exist?(gemfile_path)
        puts "Error: #{gemfile_path} not found. Auto-fix requires a Gemfile."
        exit EXIT_ERROR
      end

      begin
        # First, scan for vulnerabilities
        dependencies = Parser.new.parse(lockfile_path)
        vulnerabilities = VulnerabilityFetcher.new.fetch_for(dependencies)
        analysis = Analyzer.new.analyze(dependencies, vulnerabilities)

        if analysis.vulnerable_dependencies.empty?
          puts "✅ No vulnerabilities found. Nothing to fix!"
          exit EXIT_SUCCESS
        end

        # Apply fixes
        auto_fixer = AutoFixer.new(lockfile_path, gemfile_path)
        result = auto_fixer.fix_vulnerabilities(
          analysis.vulnerable_dependencies,
          dry_run: dry_run,
          interactive: interactive,
          backup: create_backup
        )

        case result[:status]
        when :no_fixes_needed
          puts "ℹ️  #{result[:message]}"
          exit EXIT_SUCCESS
        when :dry_run
          puts "🔍 Dry run — no files will be modified."
          puts "=" * 40
          result[:fixes].each do |fix|
            puts "✅ Would update #{fix[:gem_name]} #{fix[:current_version]} → #{fix[:target_version]}"
          end
          puts "\n#{result[:message]}"
          puts "Run without --dry-run to apply these fixes."
          exit EXIT_SUCCESS
        when :cancelled
          puts "❌ #{result[:message]}"
          exit EXIT_SUCCESS
        when :completed
          puts "🎉 #{result[:message]}"
          puts "\n📋 Applied Fixes:"
          result[:fixes].each do |fix|
            puts "✅ #{fix[:gem_name]}: #{fix[:current_version]} → #{fix[:target_version]}"
          end
          puts "\n💡 Run 'gem_guard scan' to verify fixes."
          exit EXIT_SUCCESS
        else
          puts "❌ Unexpected error during fix operation"
          exit EXIT_ERROR
        end
      rescue => e
        puts "Error: #{e.message}"
        exit EXIT_ERROR
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
        config.meets_severity_threshold?(extract_severity_level(vuln_dep.vulnerability.severity))
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
      output = StringIO.new
      old_stdout = $stdout
      $stdout = output

      Reporter.new.report(analysis, format: format)

      $stdout = old_stdout
      output.string
    end

    def display_typosquat_results(suspicious_gems, format)
      if suspicious_gems.empty?
        puts "No potential typosquat dependencies found."
        return
      end

      case format.downcase
      when "json"
        puts JSON.pretty_generate(suspicious_gems)
      else
        display_typosquat_table(suspicious_gems)
      end
    end

    def display_typosquat_table(suspicious_gems)
      puts "\n🚨 Potential Typosquat Dependencies Found:"
      puts "=" * 80

      suspicious_gems.each do |gem_info|
        risk_emoji = case gem_info[:risk_level]
        when "critical" then "🔴"
        when "high" then "🟠"
        when "medium" then "🟡"
        else "🟢"
        end

        puts "\n#{risk_emoji} #{gem_info[:gem_name]} (#{gem_info[:version]})"
        puts "   Suspected target: #{gem_info[:suspected_target]}"
        puts "   Similarity: #{(gem_info[:similarity_score] * 100).round(1)}%"
        puts "   Risk level: #{gem_info[:risk_level].upcase}"
        puts "   Target downloads: #{number_with_commas(gem_info[:target_downloads])}"
      end

      puts "\n" + "=" * 80
      puts "💡 Review these dependencies carefully. Consider:"
      puts "   • Verifying the gem's legitimacy on rubygems.org"
      puts "   • Checking the gem's source code repository"
      puts "   • Looking for official documentation or endorsements"
      puts "   • Comparing with the suspected target gem"
    end

    def format_typosquat_output(suspicious_gems, format)
      case format.downcase
      when "json"
        JSON.pretty_generate(suspicious_gems)
      else
        output = StringIO.new
        old_stdout = $stdout
        $stdout = output

        display_typosquat_table(suspicious_gems)

        $stdout = old_stdout
        output.string
      end
    end

    def number_with_commas(number)
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end
end
