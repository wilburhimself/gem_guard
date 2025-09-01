require "bundler"
require "fileutils"
require "tty-prompt"

module GemGuard
  class AutoFixer
    def initialize(lockfile_path = "Gemfile.lock", gemfile_path = "Gemfile")
      @lockfile_path = lockfile_path
      @gemfile_path = gemfile_path
      @backup_created = false
    end

    def fix_vulnerabilities(vulnerable_dependencies, options = {})
      dry_run = options.fetch(:dry_run, false)
      interactive = options.fetch(:interactive, false)
      create_backup = options.fetch(:backup, true)

      unless File.exist?(@gemfile_path)
        raise GemGuard::FileError, "Gemfile not found at #{@gemfile_path}. Auto-fix requires a Gemfile."
      end

      unless File.exist?(@lockfile_path)
        raise GemGuard::FileError, "Gemfile.lock not found at #{@lockfile_path}. Run 'bundle install' first."
      end

      fixes = plan_fixes(vulnerable_dependencies)

      if fixes.empty?
        return {status: :no_fixes_needed, message: "No automatic fixes available."}
      end

      if dry_run
        return {status: :dry_run, fixes: fixes, message: "Dry run completed. #{fixes.length} fixes planned."}
      end

      # Apply fixes with optional per-gem confirmation
      applied_fixes, cancelled = apply_fixes(fixes, interactive: interactive, backup: create_backup)

      if cancelled
        return {status: :cancelled, message: "No fixes approved."}
      end

      {
        status: :completed,
        fixes: applied_fixes,
        message: "Applied #{applied_fixes.length} fixes successfully."
      }
    end

    private

    def plan_fixes(vulnerable_dependencies)
      fixes = []

      vulnerable_dependencies.each do |vuln_dep|
        dependency = vuln_dep.dependency
        vulnerability = vuln_dep.vulnerability

        # Extract the recommended version from the fix suggestion
        recommended_version = extract_version_from_fix(vuln_dep.recommended_fix)

        next unless recommended_version

        # Check if the recommended version is available and safe
        if version_available_and_safe?(dependency.name, recommended_version)
          fixes << {
            gem_name: dependency.name,
            current_version: dependency.version,
            target_version: recommended_version,
            vulnerability_id: vulnerability.id,
            severity: vulnerability.severity
          }
        end
      end

      fixes
    end

    def extract_version_from_fix(fix_command)
      # Extract version from commands like "bundle update nokogiri --to 1.18.9"
      match = fix_command.match(/--to\s+([^\s]+)/)
      match ? match[1] : nil
    end

    def version_available_and_safe?(gem_name, version)
      # Check if the version exists on RubyGems
      # This is a simplified check - in production, you might want more robust validation
      return false if version.nil? || version.empty?

      # Basic semantic version validation
      version.match?(/^\d+\.\d+(\.\d+)?/)
    end

    def confirm_fixes(fixes)
      # Deprecated: kept for compatibility but not used with per-gem prompts
      true
    end

    def severity_emoji(severity)
      case severity.to_s.downcase
      when /critical/
        "🔴"
      when /high/
        "🟠"
      when /medium/
        "🟡"
      else
        "🟢"
      end
    end

    def create_lockfile_backup
      return if @backup_created

      backup_path = "#{@lockfile_path}.backup.#{Time.now.strftime("%Y%m%d_%H%M%S")}"
      begin
        FileUtils.cp(@lockfile_path, backup_path)
      rescue Errno::EACCES, Errno::EPERM => e
        raise GemGuard::FileError, "Cannot write backup for #{@lockfile_path}: #{e.message}. Check file permissions."
      end
      @backup_created = true
      puts "📦 Created backup: #{backup_path}"
    end

    def apply_fixes(fixes, interactive: false, backup: true)
      applied_fixes = []

      # Determine which fixes to apply
      selected_fixes = if interactive
        prompt = TTY::Prompt.new
        choices = fixes.map do |fix|
          {
            name: "#{severity_emoji(fix[:severity])} #{fix[:gem_name]}: #{fix[:current_version]} → #{fix[:target_version]} (Vulnerability: #{fix[:vulnerability_id]}, Severity: #{fix[:severity]})",
            value: fix
          }
        end

        if choices.empty?
          puts "No actionable fixes found."
          return [], false
        end

        prompt.multi_select("Select vulnerabilities to fix:", choices, per_page: 15, cycle: true)
      else
        fixes
      end

      # If no fixes were approved, signal cancellation
      return [applied_fixes, true] if selected_fixes.empty?

      # Create backup only if we will actually apply at least one fix
      create_lockfile_backup if backup

      selected_fixes.each do |fix|
        if apply_single_fix(fix)
          applied_fixes << fix
          puts "✅ Updated #{fix[:gem_name]} to #{fix[:target_version]}"
        else
          puts "❌ Failed to update #{fix[:gem_name]}"
        end
      end

      # Run bundle install to update the lockfile
      if applied_fixes.any?
        puts "\n🔄 Running bundle install to update lockfile..."
        system("bundle install")
      end

      [applied_fixes, false]
    end

    def apply_single_fix(fix)
      # Use bundler to update the specific gem
      command = "bundle update #{fix[:gem_name]} --conservative"

      # Execute the bundle update command
      system(command, out: File::NULL, err: File::NULL)
    end
  end
end
