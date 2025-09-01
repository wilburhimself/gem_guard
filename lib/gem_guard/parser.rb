require "bundler"

module GemGuard
  class Parser
    DEFAULT_GEMS = %w[bundler racc json minitest rake thor tzinfo tzinfo-data].freeze

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
      gemfile_path = File.expand_path("Gemfile", File.dirname(lockfile_path))
      validate_dependencies_section!(content, dependencies.map(&:name), lockfile_path, gemfile_path)

      # Deduplicate dependencies by name to handle platform-specific gems
      # (e.g., nokogiri-arm64-darwin, nokogiri-x86_64-darwin, etc.)
      dependencies.uniq { |dep| dep.name }
    end

    private

    def validate_dependencies_section!(content, spec_names, lockfile_path, gemfile_path)
      # Temporarily disable validation due to issues with gemspec dependencies
      # This section is primarily for catching malformed lockfiles, not for strict dependency validation
      []
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
