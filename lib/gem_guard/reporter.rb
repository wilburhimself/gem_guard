require "json"
require "tty-table"

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

      table = TTY::Table.new(
        header: ["Gem", "Version", "Vulnerability", "Severity", "Fix"],
        rows: analysis.vulnerable_dependencies.map do |vuln_dep|
          [
            vuln_dep.dependency.name,
            vuln_dep.dependency.version,
            vuln_dep.vulnerability.id,
            vuln_dep.vulnerability.severity,
            vuln_dep.recommended_fix
          ]
        end
      )

      summary = "Summary: Total vulnerabilities: #{analysis.vulnerability_count}, High/Critical severity: #{analysis.high_severity_count}"

      "🚨 Security Vulnerabilities Found\n#{table.render(:unicode, width: 80)}\n\n#{summary}"
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
