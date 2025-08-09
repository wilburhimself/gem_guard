# Supply Chain Security & Vulnerability Management Gem – Plan

## 1. Overview

**Working Name:** `gem_guard`  
**Goal:** Provide Ruby developers with a one-stop tool to detect, report, and remediate dependency-related security risks.  
**Core Capabilities:**
- Scan dependency tree (including transient deps)
- Detect known CVEs from public and private vulnerability databases
- Suggest safe upgrades and patches
- Generate SBOM (Software Bill of Materials) in SPDX/CycloneDX format
- Integrate with CI/CD to prevent unsafe deployments

---

## 2. Problems Being Solved

1. **Typosquatting & brand-jacking detection** – accidental installs of malicious gems with similar names.
2. **Unpatched dependencies** – gems with known vulnerabilities not updated.
3. **Lack of visibility** – no SBOM or complete dependency inventory.
4. **CI/CD security gap** – insecure builds proceed unnoticed.

---

## 3. Target Users

- Ruby and Rails developers
- DevOps engineers managing Ruby apps in production
- Security-conscious teams using Ruby for internal tooling

---

## 4. Features & Requirements

### Phase 1 – Core CLI Scanner
- Command: `gem_guard scan`
- Parse `Gemfile.lock` and detect:
  - Direct & transitive dependencies
  - Gem source URLs
- Query vulnerability sources:
  - [OSV.dev](https://osv.dev)
  - [Ruby Advisory Database](https://github.com/rubysec/ruby-advisory-db)
- Output:
  - Table of vulnerable gems, CVE IDs, severity, fixed versions
  - Recommended fix commands (e.g., `bundle update <gem>`)

### Phase 2 – SBOM Generation
- Command: `gem_guard sbom`
- Output formats:
  - SPDX JSON
  - CycloneDX JSON
- Include metadata:
  - Gem name, version, source URL, license, checksum

### Phase 3 – CI/CD Integration
- Exit with non-zero status if vulnerabilities above a severity threshold are found
- Optional GitHub Action and GitLab CI template
- Config file `.gem_guard.yml` to set:
  - Allowed severity levels
  - Ignored CVEs
  - Output format

### Phase 4 – Typosquat Detection
- Fuzzy matching gem names against known gems in RubyGems API
- Flag suspicious dependencies

### Phase 5 – Auto-Fix Mode
- Command: `gem_guard fix`
- Automatically updates vulnerable gems within safe version constraints

---

## 5. Architecture

### Modules
1. **Parser**
   - Reads `Gemfile.lock`
   - Builds dependency graph
2. **VulnerabilityFetcher**
   - Fetches advisories from APIs or local DB
3. **Analyzer**
   - Matches dependencies with advisories
   - Assesses severity and suggests fixes
4. **Reporter**
   - Formats output (table, JSON, markdown, SBOM)
5. **CIAdapter**
   - Reads config
   - Sets exit codes for pipelines
6. **TyposquatChecker**
   - Fuzzy matches gem names
7. **Updater**
   - Runs safe updates for vulnerable gems

---

## 6. Implementation Stack

- **Language:** Ruby (≥ 3.0)
- **Key Libraries:**
  - `bundler` – parsing Gemfile.lock
  - `json` / `oj` – output formatting
  - `net/http` or `httpx` – API calls
  - `thor` – CLI interface
  - `fuzzy_match` – typosquat detection
- **Test Framework:** RSpec
- **Static Analysis:** RuboCop

---

## 7. Development Roadmap

### Milestone 1 – MVP Scanner
- Parse Gemfile.lock
- Fetch & match CVEs
- CLI with human-readable output
- Tests + RuboCop

### Milestone 2 – SBOM Output
- Generate SPDX and CycloneDX JSON
- CLI flags for format selection

### Milestone 3 – CI/CD Integration
- Config file support
- Exit codes for severity thresholds
- GitHub Action template

### Milestone 4 – Typosquat Detection
- Implement fuzzy match against RubyGems API
- Add to scan output

### Milestone 5 – Auto-Fix Mode
- Implement safe dependency update logic

---

## 8. Distribution & Adoption

- Publish to RubyGems.org
- Create GitHub repo with:
  - Badges (Gem Version, Build Status, License)
  - README with quickstart and examples
  - Security policy
- Write blog post on Ruby security gaps
- Submit to Ruby Weekly
- Post to dev.to and Hacker News for feedback

---

## 9. License

MIT or Apache 2.0 (lean towards MIT for broad adoption)

---

## 10. Risks & Mitigation

- **API rate limits** – cache advisories locally
- **False positives** – allow ignore list in config
- **Slow scans** – async fetching with caching

---

## 11. Success Criteria

- MVP used in CI by at least 10 open source projects within 3 months
- Detects >95% of known vulnerabilities from Ruby Advisory DB
- SBOM passes validation in major tools (e.g., CycloneDX CLI)
