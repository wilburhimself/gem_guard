require "json"

module GemGuard
  class Reporter
    def report(analysis, format: "table")
      case format.downcase
      when "json"
        puts generate_json_report(analysis)
      when "table"
        puts generate_table_report(analysis)
      else
        puts "Unknown format: #{format}. Supported formats: table, json"
      end
    end

    private

    def generate_table_report(analysis)
      return "✅ No vulnerabilities found!" unless analysis.has_vulnerabilities?

      report = []
      report << "🚨 Security Vulnerabilities Found"
      report << "=" * 50
      report << ""
      report << "Summary:"
      report << "  Total vulnerabilities: #{analysis.vulnerability_count}"
      report << "  High/Critical severity: #{analysis.high_severity_count}"
      report << ""
      report << "Details:"
      report << ""

      analysis.vulnerable_dependencies.each do |vuln_dep|
        dep = vuln_dep.dependency
        vuln = vuln_dep.vulnerability

        report << "📦 #{dep.name} (#{dep.version})"
        report << "   🔍 Vulnerability: #{vuln.id}"
        report << "   ⚠️  Severity: #{vuln.severity}"
        report << "   📝 Summary: #{vuln.summary}" unless vuln.summary.empty?
        report << "   🔧 Fix: #{vuln_dep.recommended_fix}"
        report << ""
      end

      report.join("\n")
    end

    def generate_json_report(analysis)
      report_data = {
        summary: {
          total_vulnerabilities: analysis.vulnerability_count,
          high_severity_count: analysis.high_severity_count,
          has_vulnerabilities: analysis.has_vulnerabilities?
        },
        vulnerabilities: analysis.vulnerable_dependencies.map do |vuln_dep|
          {
            gem: {
              name: vuln_dep.dependency.name,
              version: vuln_dep.dependency.version,
              source: vuln_dep.dependency.source
            },
            vulnerability: {
              id: vuln_dep.vulnerability.id,
              severity: vuln_dep.vulnerability.severity,
              summary: vuln_dep.vulnerability.summary,
              details: vuln_dep.vulnerability.details,
              affected_versions: vuln_dep.vulnerability.affected_versions,
              fixed_versions: vuln_dep.vulnerability.fixed_versions
            },
            recommended_fix: vuln_dep.recommended_fix
          }
        end
      }

      JSON.pretty_generate(report_data)
    end
  end
end
