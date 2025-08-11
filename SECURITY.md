# Security Policy

## Supported Versions

We actively support the following versions of GemGuard:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability within GemGuard, please submit a private report via GitHub Security Advisories:

https://github.com/wilburhimself/gem_guard/security/advisories/new

All security vulnerabilities will be promptly addressed through the advisory workflow.

**Please do not report security vulnerabilities through public GitHub issues.**

### What to include in your report

- A description of the vulnerability
- Steps to reproduce the issue
- Potential impact of the vulnerability
- Any suggested fixes (if you have them)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution**: We aim to resolve critical vulnerabilities within 30 days

### Disclosure Policy

- We follow responsible disclosure practices
- We will acknowledge your contribution in our security advisories (unless you prefer to remain anonymous)
- We may offer recognition in our contributors list for significant security reports

## Security Features

GemGuard itself implements several security best practices:

- **Input Validation**: All user inputs are validated and sanitized
- **API Security**: Secure communication with vulnerability databases
- **Dependency Management**: Regular updates to dependencies
- **Code Quality**: Comprehensive testing and static analysis

## Security Considerations for Users

When using GemGuard:

- **Keep GemGuard updated** to the latest version for security patches
- **Review vulnerability reports** carefully before applying fixes
- **Validate SBOM outputs** before sharing with external parties
- **Use secure channels** when transmitting security reports
- **Configure ignore lists** carefully to avoid missing critical vulnerabilities
- **Monitor CI/CD pipelines** for security scan failures

## Threat Model

GemGuard protects against:

- **Known Vulnerabilities**: CVEs in your dependency chain
- **Typosquat Attacks**: Malicious gems with similar names to popular packages
- **Supply Chain Attacks**: Compromised or malicious dependencies
- **Outdated Dependencies**: Gems with known security issues

## Data Handling

GemGuard:

- **Does not collect** personal or sensitive data
- **Queries public APIs** (OSV.dev) for vulnerability information
- **Processes locally** your Gemfile.lock and dependency information
- **Does not transmit** your code or proprietary information
- **Caches vulnerability data** temporarily for performance

## Security Updates

We provide security updates through:

- **GitHub Security Advisories** for critical vulnerabilities
- **RubyGems.org releases** with security patches
- **GitHub releases** with detailed changelogs

## Contact

For security-related inquiries and reports, use GitHub Security Advisories to contact maintainers privately:

https://github.com/wilburhimself/gem_guard/security/advisories/new

We do not monitor any dedicated security email inbox. Initial response within 48 hours.

---

*Last updated: January 2025*
- Use GemGuard in your CI/CD pipeline to catch vulnerabilities early
- Consider the source and severity of reported vulnerabilities

## Contact

For general questions, reach out via GitHub Discussions or issues as appropriate:
- GitHub: [@wilburhimself](https://github.com/wilburhimself)
