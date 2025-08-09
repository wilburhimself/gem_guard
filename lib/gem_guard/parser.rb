require "bundler"

module GemGuard
  class Parser
    def parse(lockfile_path)
      lockfile = Bundler::LockfileParser.new(File.read(lockfile_path))

      dependencies = []

      lockfile.specs.each do |spec|
        dependencies << Dependency.new(
          name: spec.name,
          version: spec.version.to_s,
          source: extract_source(spec),
          dependencies: spec.dependencies.map(&:name)
        )
      end

      dependencies
    end

    private

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
