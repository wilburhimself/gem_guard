require "yaml"

module GemGuard
  class Config
    DEFAULT_CONFIG = {
      "lockfile" => "Gemfile.lock",
      "format" => "table",
      "fail_on_vulnerabilities" => true,
      "severity_threshold" => "low",
      "ignore_vulnerabilities" => [],
      "ignore_gems" => [],
      "output_file" => nil,
      "project_name" => nil,
      "sbom" => {
        "format" => "spdx",
        "include_dev_dependencies" => false
      },
      "scan" => {
        "sources" => ["osv", "ruby_advisory_db", "ghsa", "nvd", "cu_advisory_db"],
        "timeout" => 30
      }
    }.freeze

    SEVERITY_LEVELS = %w[low medium high critical].freeze

    def initialize(config_path = ".gemguard.yml")
      @config_path = config_path
      @config = load_config
    end

    def get(key)
      keys = key.split(".")
      value = @config

      keys.each do |k|
        value = value[k] if value.is_a?(Hash)
      end

      value
    end

    def set(key, value)
      keys = key.split(".")
      target = @config

      keys[0..-2].each do |k|
        target[k] ||= {}
        target = target[k]
      end

      target[keys.last] = value
    end

    def save
      File.write(@config_path, YAML.dump(@config))
    end

    def exists?
      File.exist?(@config_path)
    end

    def lockfile_path
      get("lockfile")
    end

    def output_format
      get("format")
    end

    def fail_on_vulnerabilities?
      get("fail_on_vulnerabilities")
    end

    def severity_threshold
      get("severity_threshold")
    end

    def ignored_vulnerabilities
      get("ignore_vulnerabilities") || []
    end

    def ignored_gems
      get("ignore_gems") || []
    end

    def output_file
      get("output_file")
    end

    def project_name
      get("project_name") || detect_project_name
    end

    def sbom_format
      get("sbom.format")
    end

    def include_dev_dependencies?
      get("sbom.include_dev_dependencies")
    end

    def vulnerability_sources
      get("scan.sources")
    end

    def scan_timeout
      get("scan.timeout")
    end

    def should_ignore_vulnerability?(vulnerability_id)
      ignored_vulnerabilities.include?(vulnerability_id)
    end

    def should_ignore_gem?(gem_name)
      ignored_gems.include?(gem_name)
    end

    def meets_severity_threshold?(severity)
      return true if severity.nil? || severity.empty?

      severity_index = SEVERITY_LEVELS.index(severity.downcase)
      threshold_index = SEVERITY_LEVELS.index(severity_threshold.downcase)

      return true if severity_index.nil? || threshold_index.nil?

      severity_index >= threshold_index
    end

    private

    def load_config
      if File.exist?(@config_path)
        user_config = YAML.load_file(@config_path) || {}
        deep_merge(deep_dup(DEFAULT_CONFIG), user_config)
      else
        deep_dup(DEFAULT_CONFIG)
      end
    rescue Psych::SyntaxError => e
      puts "Warning: Invalid YAML in #{@config_path}: #{e.message}"
      puts "Using default configuration."
      deep_dup(DEFAULT_CONFIG)
    end

    def deep_dup(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(key, value), hash| hash[key] = deep_dup(value) }
      when Array
        obj.map { |item| deep_dup(item) }
      else
        begin
          obj.dup
        rescue
          obj
        end
      end
    end

    def deep_merge(hash1, hash2)
      result = hash1.dup

      hash2.each do |key, value|
        result[key] = if result[key].is_a?(Hash) && value.is_a?(Hash)
          deep_merge(result[key], value)
        else
          value
        end
      end

      result
    end

    def detect_project_name
      # Try to detect project name from various sources
      if File.exist?("Gemfile")
        gemfile_content = File.read("Gemfile")
        if gemfile_content =~ /gem\s+['"]([^'"]+)['"]/
          return $1
        end
      end

      if File.exist?("*.gemspec")
        gemspec_files = Dir.glob("*.gemspec")
        unless gemspec_files.empty?
          return File.basename(gemspec_files.first, ".gemspec")
        end
      end

      # Fallback to directory name
      File.basename(Dir.pwd)
    end
  end
end
