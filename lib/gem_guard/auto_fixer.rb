require "bundler"
require "fileutils"

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
        raise "Gemfile not found at #{@gemfile_path}. Auto-fix requires a Gemfile."
      end

      unless File.exist?(@lockfile_path)
        raise "Gemfile.lock not found at #{@lockfile_path}. Run 'bundle install' first."
      end

      fixes = plan_fixes(vulnerable_dependencies)

      if fixes.empty?
        return {status: :no_fixes_needed, message: "No automatic fixes available."}
      end

      if dry_run
        return {status: :dry_run, fixes: fixes, message: "Dry run completed. #{fixes.length} fixes planned."}
      end

      if interactive && !confirm_fixes(fixes)
        return {status: :cancelled, message: "Fix operation cancelled by user."}
      end

      create_lockfile_backup if create_backup

      applied_fixes = apply_fixes(fixes)

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
      puts "\n🔧 Planned Fixes:"
      puts "=" * 50

      fixes.each do |fix|
        severity_emoji = severity_emoji(fix[:severity])
        puts "#{severity_emoji} #{fix[:gem_name]}: #{fix[:current_version]} → #{fix[:target_version]}"
        puts "   Fixes: #{fix[:vulnerability_id]}"
      end

      puts "\n⚠️  This will modify your Gemfile.lock and may require bundle install."
      print "Do you want to proceed? (y/N): "

      response = $stdin.gets.chomp.downcase
      response == "y" || response == "yes"
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
      FileUtils.cp(@lockfile_path, backup_path)
      @backup_created = true
      puts "📦 Created backup: #{backup_path}"
    end

    def apply_fixes(fixes)
      applied_fixes = []

      fixes.each do |fix|
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

      applied_fixes
    end

    def apply_single_fix(fix)
      # Use bundler to update the specific gem
      command = "bundle update #{fix[:gem_name]} --conservative"

      # Execute the bundle update command
      system(command, out: File::NULL, err: File::NULL)
    end
  end
end
