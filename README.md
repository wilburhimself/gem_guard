# GemGuard

[![Gem Version](https://badge.fury.io/rb/gem_guard.svg)](https://badge.fury.io/rb/gem_guard)
[![CI](https://github.com/wilburhimself/gem_guard/workflows/CI/badge.svg)](https://github.com/wilburhimself/gem_guard/actions/workflows/ci.yml)
[![Release](https://github.com/wilburhimself/gem_guard/workflows/Release/badge.svg)](https://github.com/wilburhimself/gem_guard/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Security](https://img.shields.io/badge/Security-Policy-blue.svg)](SECURITY.md)

**The comprehensive Ruby dependency security scanner and SBOM generator.**

GemGuard is your one-stop solution for Ruby supply chain security. Detect vulnerabilities, identify typosquats, generate SBOMs, and secure your dependencies with enterprise-grade tooling designed for modern DevOps workflows.

## ✨ Features

### 🔍 **Vulnerability Scanning**
- Detect known CVEs from OSV.dev and Ruby Advisory Database
- Smart deduplication handles platform-specific gems
- Severity-based filtering and thresholds
- Actionable fix recommendations with exact commands

### 🎯 **Typosquat Detection**
- Fuzzy matching against popular Ruby gems
- Configurable similarity thresholds
- Risk level classification (Critical/High/Medium/Low)
- Hardcoded fallback for reliable detection

### 📋 **SBOM Generation**
- Industry-standard SPDX 2.3 format
- CycloneDX 1.5 support
- Complete dependency metadata
- License and checksum information

### 🚀 **CI/CD Integration**
- Configurable exit codes for pipeline control
- JSON output for automated processing
- Config file support (`.gemguard.yml`)
- Multiple output formats and file export

### 🎨 **Developer Experience**
- Beautiful, colorful terminal output
- Progress indicators and clear error messages
- Comprehensive help and documentation
- Zero-config operation with sensible defaults

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gem_guard'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install gem_guard

## 🚀 Quick Start

```bash
# Install GemGuard
gem install gem_guard

# Scan for vulnerabilities
gem_guard scan

# Check for typosquats
gem_guard typosquat

# Generate SBOM
gem_guard sbom
```

## 📖 Usage

### 🔍 Vulnerability Scanning

**Basic scan:**
```bash
gem_guard scan
```

**Custom lockfile:**
```bash
gem_guard scan --lockfile path/to/Gemfile.lock
```

**JSON output for automation:**
```bash
gem_guard scan --format json --output vulnerabilities.json
```

**CI/CD integration with exit codes:**
```bash
gem_guard scan --fail-on-vulnerabilities --severity-threshold high
```

**Example output:**
```
🚨 Security Vulnerabilities Found
==================================================

Summary:
  Total vulnerabilities: 2
  High/Critical severity: 1

Details:

📦 nokogiri (1.18.8)
   🔍 Vulnerability: GHSA-353f-x4gh-cqq8
   ⚠️  Severity: UNKNOWN
   📝 Summary: Nokogiri patches vendored libxml2 to resolve multiple CVEs
   🔧 Fix: bundle update nokogiri --to 1.18.9

📦 thor (1.3.2)
   🔍 Vulnerability: GHSA-mqcp-p2hv-vw6x
   ⚠️  Severity: CVSS:3.1/AV:L/AC:H/PR:L/UI:N/S:C/C:H/I:H/A:H
   📝 Summary: Thor can construct an unsafe shell command from library input.
   🔧 Fix: bundle update thor --to 1.4.0
```

### 🎯 Typosquat Detection

**Basic typosquat check:**
```bash
gem_guard typosquat
```

**Custom similarity threshold:**
```bash
gem_guard typosquat --threshold 0.9
```

**JSON output:**
```bash
gem_guard typosquat --format json --output typosquats.json
```

**Example output:**
```
🎯 Potential Typosquat Dependencies Found
==========================================

📦 railz (7.0.0)
   🚨 Risk Level: CRITICAL
   📊 Similarity: 80.0% to 'rails'
   ⚠️  This gem name is suspiciously similar to the popular gem 'rails'
   🔧 Consider: Did you mean 'rails'? Review this dependency carefully.
```

### 📋 SBOM Generation

**Generate SPDX SBOM:**
```bash
gem_guard sbom
```

**Generate CycloneDX SBOM:**
```bash
gem_guard sbom --format cyclone-dx
```

**Custom project name and output:**
```bash
gem_guard sbom --project my-app --output sbom.json
```

**Example SPDX output:**
```json
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "my-app-sbom",
  "documentNamespace": "https://gem-guard.dev/my-app/2025-01-09T23:55:00Z",
  "creationInfo": {
    "created": "2025-01-09T23:55:00Z",
    "creators": ["Tool: gem_guard-1.0.0"]
  },
  "packages": [...],
  "relationships": [...]
}
```

## ⚙️ Configuration

GemGuard supports project-level configuration via `.gemguard.yml`:

```yaml
# .gemguard.yml
lockfile_path: "Gemfile.lock"
output_format: "table"  # table, json
fail_on_vulnerabilities: true
severity_threshold: "medium"  # low, medium, high, critical
output_file: null
ignore_vulnerabilities:
  - "CVE-2021-12345"  # Ignore specific CVEs
  - "GHSA-xxxx-xxxx-xxxx"
typosquat:
  similarity_threshold: 0.8
  enabled: true
sbom:
  format: "spdx"  # spdx, cyclone-dx
  project_name: "my-project"
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `lockfile_path` | Path to Gemfile.lock | `"Gemfile.lock"` |
| `output_format` | Output format (table/json) | `"table"` |
| `fail_on_vulnerabilities` | Exit with code 1 if vulnerabilities found | `true` |
| `severity_threshold` | Minimum severity to report | `"low"` |
| `output_file` | Write output to file | `null` |
| `ignore_vulnerabilities` | List of CVE/GHSA IDs to ignore | `[]` |
| `typosquat.similarity_threshold` | Typosquat detection sensitivity | `0.8` |
| `typosquat.enabled` | Enable typosquat detection | `true` |
| `sbom.format` | SBOM format (spdx/cyclone-dx) | `"spdx"` |
| `sbom.project_name` | Project name in SBOM | `"ruby-project"` |

## 🔄 CI/CD Integration

### Exit Codes

GemGuard uses standard exit codes for CI/CD integration:

- **0**: Success (no vulnerabilities or typosquats found)
- **1**: Vulnerabilities/typosquats found
- **2**: Error (invalid arguments, missing files, etc.)

### GitHub Actions

```yaml
name: Security Scan
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
      
      - name: Install GemGuard
        run: gem install gem_guard
      
      - name: Vulnerability Scan
        run: gem_guard scan --format json --output vulnerabilities.json
      
      - name: Typosquat Check
        run: gem_guard typosquat --format json --output typosquats.json
      
      - name: Generate SBOM
        run: gem_guard sbom --output sbom.json
      
      - name: Upload Security Reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: security-reports
          path: |
            vulnerabilities.json
            typosquats.json
            sbom.json
```

### GitLab CI

```yaml
security_scan:
  stage: test
  image: ruby:3.2
  before_script:
    - bundle install
    - gem install gem_guard
  script:
    - gem_guard scan --format json --output vulnerabilities.json
    - gem_guard typosquat --format json --output typosquats.json
    - gem_guard sbom --output sbom.json
  artifacts:
    reports:
      # GitLab can parse these for security dashboard
      dependency_scanning: vulnerabilities.json
    paths:
      - "*.json"
    when: always
  allow_failure: false
```

### CircleCI

```yaml
version: 2.1
jobs:
  security:
    docker:
      - image: cimg/ruby:3.2
    steps:
      - checkout
      - run: bundle install
      - run: gem install gem_guard
      - run: gem_guard scan --fail-on-vulnerabilities
      - run: gem_guard typosquat
      - run: gem_guard sbom --output sbom.json
      - store_artifacts:
          path: sbom.json
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bundle exec rake standard` to run the linter.

### Running Tests

```bash
bundle exec rspec          # Run all tests
bundle exec rake standard  # Run linter
bundle exec rake           # Run both tests and linter
```

### Releasing

Releases are automated via GitHub Actions. To create a new release:

1. Update the version number in `lib/gem_guard/version.rb`
2. Commit and push to the `main` branch
3. GitHub Actions will automatically:
   - Run tests across multiple Ruby versions
   - Create a git tag
   - Generate release notes
   - Create a GitHub release
   - Publish to RubyGems.org

The release workflow is triggered only when `lib/gem_guard/version.rb` changes.

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Write tests** for your changes (we use strict TDD)
4. **Run the test suite** (`bundle exec rspec`)
5. **Run the linter** (`bundle exec rake standard`)
6. **Commit your changes** (`git commit -am 'Add amazing feature'`)
7. **Push to the branch** (`git push origin feature/amazing-feature`)
8. **Open a Pull Request**

### Development Guidelines

- Follow pragmatic, intention-revealing, minimal abstractions
- Use strict outside-in TDD with RSpec
- Maintain 100% test coverage
- Follow StandardRB for code style
- Write clear, descriptive commit messages

## 📊 Roadmap

- [ ] **Enhanced Vulnerability Sources**: Additional security databases
- [ ] **Auto-Fix Suggestions**: Automated dependency updates
- [ ] **Web Dashboard**: Browser-based security monitoring
- [ ] **IDE Integrations**: VS Code, RubyMine plugins
- [ ] **Slack/Teams Notifications**: Real-time security alerts
- [ ] **Custom Rules Engine**: User-defined security policies

## 🏆 Why GemGuard?

| Feature | GemGuard | bundler-audit | Other Tools |
|---------|----------|---------------|-------------|
| **Vulnerability Scanning** | ✅ OSV.dev + Ruby Advisory | ✅ Ruby Advisory Only | ❌ Limited Sources |
| **Typosquat Detection** | ✅ Fuzzy Matching | ❌ | ❌ |
| **SBOM Generation** | ✅ SPDX + CycloneDX | ❌ | ❌ |
| **CI/CD Integration** | ✅ Full Support | ⚠️ Basic | ⚠️ Limited |
| **JSON Output** | ✅ | ✅ | ⚠️ Varies |
| **Configuration Files** | ✅ | ❌ | ⚠️ Limited |
| **Platform Deduplication** | ✅ | ❌ | ❌ |
| **Active Development** | ✅ | ⚠️ Maintenance | ⚠️ Varies |

## 📄 License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## 🔒 Security

If you discover a security vulnerability within GemGuard, please see our [Security Policy](SECURITY.md) for responsible disclosure guidelines.

## 🙏 Acknowledgments

- [OSV.dev](https://osv.dev/) for comprehensive vulnerability data
- [Ruby Advisory Database](https://github.com/rubysec/ruby-advisory-db) for Ruby-specific advisories
- The Ruby community for continuous feedback and contributions

---

**Made with ❤️ for the Ruby community**
