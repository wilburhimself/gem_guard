module GemGuard
  class Analyzer
    def analyze(dependencies, vulnerabilities)
      vulnerable_dependencies = []

      dependencies.each do |dependency|
        matching_vulns = vulnerabilities.select { |vuln| vuln.gem_name == dependency.name }

        next if matching_vulns.empty?

        matching_vulns.each do |vulnerability|
          if version_affected?(dependency.version, vulnerability)
            vulnerable_dependencies << VulnerableDependency.new(
              dependency: dependency,
              vulnerability: vulnerability,
              recommended_fix: suggest_fix(dependency, vulnerability)
            )
          end
        end
      end

      Analysis.new(vulnerable_dependencies)
    end

    private

    def version_affected?(version, vulnerability)
      # Simple version check - in a real implementation, this would be more sophisticated
      # For now, assume all versions are affected if vulnerability exists
      true
    end

    def suggest_fix(dependency, vulnerability)
      if vulnerability.fixed_versions.any?
        latest_fix = vulnerability.fixed_versions.last
        "bundle update #{dependency.name} --to #{latest_fix}"
      else
        "bundle update #{dependency.name}"
      end
    end
  end

  class Analysis
    attr_reader :vulnerable_dependencies

    def initialize(vulnerable_dependencies)
      @vulnerable_dependencies = vulnerable_dependencies
    end

    def has_vulnerabilities?
      vulnerable_dependencies.any?
    end

    def vulnerability_count
      vulnerable_dependencies.length
    end

    def high_severity_count
      vulnerable_dependencies.count { |vd| high_severity?(vd.vulnerability.severity) }
    end

    private

    def high_severity?(severity)
      case severity.to_s.upcase
      when /HIGH|CRITICAL/
        true
      else
        false
      end
    end
  end

  class VulnerableDependency
    attr_reader :dependency, :vulnerability, :recommended_fix

    def initialize(dependency:, vulnerability:, recommended_fix:)
      @dependency = dependency
      @vulnerability = vulnerability
      @recommended_fix = recommended_fix
    end
  end
end
