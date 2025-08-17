require_relative "lib/gem_guard/version"

Gem::Specification.new do |spec|
  spec.name = "gem_guard"
  spec.version = GemGuard::VERSION
  spec.authors = ["Wilbur Suero"]
  spec.email = ["wilbur@example.com"]

  spec.summary = "Supply chain security and vulnerability management for Ruby gems"
  spec.description = "A comprehensive tool to detect, report, and remediate dependency-related security risks in Ruby projects. Includes CVE scanning, SBOM generation, and CI/CD integration."
  spec.homepage = "https://github.com/wilburhimself/gem_guard"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/wilburhimself/gem_guard"
  spec.metadata["changelog_uri"] = "https://github.com/wilburhimself/gem_guard/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "json", "~> 2.0"
  spec.add_dependency "tty-prompt", "~> 0.23"

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standard", "~> 1.39"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
