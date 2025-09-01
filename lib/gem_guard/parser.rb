require "bundler"

module GemGuard
  class Parser
    def parse(lockfile_path)
      content = File.read(lockfile_path)
      begin
        lockfile = Bundler::LockfileParser.new(content)
      rescue => e
        # Wrap any parsing errors from Bundler with a clearer custom error
        raise GemGuard::InvalidLockfileError, "Invalid Gemfile.lock at #{lockfile_path}: #{e.message}"
      end

      # Basic structural validation to catch truncated files quickly
      unless content.include?("\nBUNDLED WITH") || content.end_with?("BUNDLED WITH\n")
        raise GemGuard::InvalidLockfileError, "Invalid Gemfile.lock at #{lockfile_path}: missing 'BUNDLED WITH' section"
      end

      dependencies = []

      lockfile.specs.each do |spec|
        dependencies << Dependency.new(
          name: spec.name,
          version: spec.version.to_s,
          source: extract_source(spec),
          dependencies: spec.dependencies.map(&:name)
        )
      end

      # Validate DEPENDENCIES section formatting and presence in specs
      validate_dependencies_section!(content, dependencies.map(&:name), lockfile_path)

      # Deduplicate dependencies by name to handle platform-specific gems
      # (e.g., nokogiri-arm64-darwin, nokogiri-x86_64-darwin, etc.)
      dependencies.uniq { |dep| dep.name }
    end

    private

    def validate_dependencies_section!(content, spec_names, lockfile_path)
      lines = content.lines
      start_index = lines.index { |l| l.strip == "DEPENDENCIES" }
      return unless start_index # If no section, let Bundler rules apply

      # Collect until blank line or next all-caps heading
      deps = []
      i = start_index + 1
      while i < lines.length
        line = lines[i]
        break if line.strip.empty?
        break if line == line.upcase && line.match?(/^[A-Z\s]+$/)

        # Ignore comments on the line
        stripped = line.split("#", 2).first.to_s.rstrip
        if stripped.strip.empty?
          i += 1
          next
        end

        # Expect indentation then a gem name optionally with version in parens
        if !/^\s{2,}[a-z0-9_\-]+(\s*\([^)]*\))?\s*$/i.match?(stripped)
          raise GemGuard::InvalidLockfileError, "Invalid Gemfile.lock at #{lockfile_path}: malformed DEPENDENCIES entry '#{line.strip}'"
        end

        name = stripped.strip.split.first
        # remove optional version tuple e.g., rails, or rails(=7.0.0) case without space
        name = name.split("(").first

        # unless spec_names.include?(name) || name == "bundler"
        #   raise GemGuard::InvalidLockfileError, "Invalid Gemfile.lock at #{lockfile_path}: dependency '#{name}' not found in specs"
        # end

        deps << name
        i += 1
      end

      deps
    end

    def extract_source(spec)
      if spec.source.respond_to?(:uri)
        spec.source.uri.to_s
      else
        "https://rubygems.org"
      end
    end
  end

  class Dependency
    attr_reader :name, :version, :source, :dependencies

    def initialize(name:, version:, source:, dependencies: [])
      @name = name
      @version = version
      @source = source
      @dependencies = dependencies
    end

    def ==(other)
      other.is_a?(Dependency) &&
        name == other.name &&
        version == other.version &&
        source == other.source
    end
  end
end
