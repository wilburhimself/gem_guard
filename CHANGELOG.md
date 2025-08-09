# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-08-08

### Added
- Initial release of GemGuard
- Core vulnerability scanning functionality
- Support for OSV.dev vulnerability database
- CLI interface with `scan` and `version` commands
- Table and JSON output formats
- Comprehensive test suite with RSpec
- Integration with Bundler for Gemfile.lock parsing
- Fix recommendations for vulnerable dependencies

### Features
- Parse Gemfile.lock and build dependency graph
- Fetch vulnerabilities from OSV.dev API
- Match dependencies against known vulnerabilities
- Generate human-readable and JSON reports
- Exit with non-zero status when vulnerabilities found
- Support for custom lockfile paths
