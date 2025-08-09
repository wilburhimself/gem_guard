# GemGuard

[![Gem Version](https://badge.fury.io/rb/gem_guard.svg)](https://badge.fury.io/rb/gem_guard)
[![CI](https://github.com/wilburhimself/gem_guard/workflows/CI/badge.svg)](https://github.com/wilburhimself/gem_guard/actions/workflows/ci.yml)
[![Release](https://github.com/wilburhimself/gem_guard/workflows/Release/badge.svg)](https://github.com/wilburhimself/gem_guard/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Security](https://img.shields.io/badge/Security-Policy-blue.svg)](SECURITY.md)

Supply chain security and vulnerability management for Ruby gems. GemGuard provides developers with a comprehensive tool to detect, report, and remediate dependency-related security risks.

## Features

- 🔍 **Vulnerability Scanning**: Detect known CVEs in your dependencies
- 📊 **Multiple Output Formats**: Human-readable tables and JSON output
- 🌐 **Multiple Data Sources**: OSV.dev and Ruby Advisory Database
- 🔧 **Fix Recommendations**: Suggested commands to remediate vulnerabilities
- 🚀 **CI/CD Ready**: Exit codes for pipeline integration

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gem_guard'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install gem_guard

## Usage

### Basic Vulnerability Scan

Scan your project's dependencies for known vulnerabilities:

```bash
gem_guard scan
```

### Specify Custom Lockfile

```bash
gem_guard scan --lockfile path/to/Gemfile.lock
```

### JSON Output

```bash
gem_guard scan --format json
```

### Example Output

```
🚨 Security Vulnerabilities Found
==================================================

Summary:
  Total vulnerabilities: 2
  High/Critical severity: 1

Details:

📦 actionpack (6.1.0)
   🔍 Vulnerability: CVE-2021-22885
   ⚠️  Severity: HIGH
   📝 Summary: Possible Information Disclosure / Unintended Method Execution in Action Pack
   🔧 Fix: bundle update actionpack --to 6.1.3.1

📦 nokogiri (1.10.0)
   🔍 Vulnerability: CVE-2020-26247
   ⚠️  Severity: MEDIUM
   📝 Summary: XML External Entity vulnerability in Nokogiri
   🔧 Fix: bundle update nokogiri --to 1.11.0
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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wilburhimself/gem_guard.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Security

If you discover a security vulnerability within GemGuard, please send an email to security@example.com. All security vulnerabilities will be promptly addressed.
