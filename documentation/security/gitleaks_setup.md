# Gitleaks Security Setup

## Overview

This document describes the implementation of Gitleaks secret scanning in the Children of Singularity project. Gitleaks is a SAST (Static Application Security Testing) tool that detects secrets, credentials, and other sensitive information in your codebase.

## Implementation

### 1. Pre-commit Hook

Gitleaks is integrated as a pre-commit hook that runs before each commit to scan staged files for secrets.

**Configuration**: `.pre-commit-config.yaml`
**Setup**: Pre-commit hooks are automatically installed when running `pre-commit install`

#### How it works:
- Runs on every commit attempt
- Scans only staged files
- Blocks commits if secrets are detected
- Uses the project's custom `.gitleaks.toml` configuration

#### Testing the pre-commit hook:
```bash
# Test all files
pre-commit run --all-files

# Test specific files
pre-commit run --files path/to/file.py
```

### 2. CI/CD Pipeline Integration

Gitleaks is integrated into the GitHub Actions workflow as a separate job that runs on every pull request and push to main.

**Configuration**: `.github/workflows/pr-quality-checks.yml`
**Job**: `gitleaks-scan`

#### Features:
- Scans entire repository history
- Generates JSON reports
- Uploads reports as artifacts
- Blocks PR merges if secrets are detected

#### Manual CI testing:
```bash
# Test locally with same configuration as CI
gitleaks detect --config .gitleaks.toml --verbose --report-format json --report-path gitleaks-report.json
```

## Configuration

### Gitleaks Configuration (`.gitleaks.toml`)

The configuration includes:

#### Custom Rules:
- **database-url**: PostgreSQL connection strings
- **fastapi-secret-key**: FastAPI secret keys
- **jwt-secret**: JWT secret keys
- **openai-api-key**: OpenAI API keys
- **generic-api-key**: Generic API key patterns
- **private-key**: Private key detection
- **godot-encryption-key**: Godot-specific encryption keys

#### Allowlist:
- Documentation files (`.md`)
- Test files (`*_test.py`, `test_*.py`)
- Sample/template files (`.sample`, `.example`)
- Generated files (`.godot/*`, `backend/venv/*`)
- Log files (`logs/*`)

#### Entropy Detection:
- Enabled for high-entropy strings
- Threshold: 4.0 (out of 8.0)
- Focuses on password/key/secret patterns

## Usage

### Local Development

1. **Install dependencies**:
   ```bash
   brew install gitleaks pre-commit
   ```

2. **Install pre-commit hooks**:
   ```bash
   pre-commit install
   ```

3. **Test configuration**:
   ```bash
   gitleaks detect --config .gitleaks.toml --verbose
   ```

### Manual Scanning

```bash
# Scan all files
gitleaks detect --config .gitleaks.toml --verbose

# Scan specific files
gitleaks detect --config .gitleaks.toml --verbose --no-git path/to/file.py

# Generate report
gitleaks detect --config .gitleaks.toml --report-format json --report-path report.json
```

### Handling False Positives

If gitleaks detects false positives:

1. **Add to allowlist** in `.gitleaks.toml`:
   ```toml
   [[allowlist.regexes]]
   description = "Allow specific pattern"
   regex = '''your-regex-pattern'''
   paths = [
       '''path/to/file.*''',
   ]
   ```

2. **Use inline comments** (temporary):
   ```python
   api_key = "not-a-real-key"  # gitleaks:allow
   ```

## Integration with Development Workflow

### Pre-commit Hook Flow:
1. Developer attempts to commit
2. Pre-commit runs gitleaks scan
3. If secrets detected → commit blocked
4. Developer removes/fixes secrets
5. Commit succeeds

### CI/CD Pipeline Flow:
1. PR created or updated
2. GitHub Actions triggers quality checks
3. Gitleaks scan runs on full repository
4. Results uploaded as artifacts
5. PR blocked if secrets detected

## Security Best Practices

### Secret Management:
- Use environment variables for sensitive data
- Store secrets in secure vaults (not in code)
- Use configuration files with placeholder values
- Implement proper secret rotation

### Development Guidelines:
- Never commit real credentials
- Use `.env` files (but never commit them)
- Use service account keys for CI/CD
- Regularly audit and rotate secrets

## Troubleshooting

### Common Issues:

1. **Gitleaks not found**:
   ```bash
   brew install gitleaks
   ```

2. **Pre-commit hook not running**:
   ```bash
   pre-commit install
   ```

3. **False positives**:
   - Review `.gitleaks.toml` allowlist
   - Add specific patterns to allowlist

4. **CI pipeline failing**:
   - Check GitHub Actions logs
   - Verify `.gitleaks.toml` syntax
   - Review uploaded artifacts

### Debug Commands:

```bash
# Check gitleaks version
gitleaks version

# Validate configuration
gitleaks detect --config .gitleaks.toml --verbose

# Test specific file
gitleaks detect --config .gitleaks.toml --no-git --verbose path/to/file

# Generate detailed report
gitleaks detect --config .gitleaks.toml --report-format json --report-path debug-report.json
```

## Maintenance

### Regular Tasks:
- Review and update rules in `.gitleaks.toml`
- Update gitleaks version in pre-commit config
- Monitor false positives and adjust allowlist
- Review CI/CD pipeline performance

### Updates:
- Update gitleaks version in `.pre-commit-config.yaml`
- Update version in GitHub Actions workflow
- Test new versions before deployment

## Resources

- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [Pre-commit Framework](https://pre-commit.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Children of Singularity Security Guidelines](../security/README.md)

---

**Last Updated**: July 14, 2024
**Version**: 1.0.0
**Maintainer**: Development Team
