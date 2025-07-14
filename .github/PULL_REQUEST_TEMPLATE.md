## 🚀 Pull Request Checklist

### Pre-submission Requirements
- [ ] I have run `./scripts/quality_check.sh` locally and all checks pass
- [ ] I have tested the changes in both Godot and backend API
- [ ] I have updated documentation if necessary
- [ ] I have added appropriate logging for debugging

### Changes Made
<!-- Describe the changes you made and why -->

### Testing
<!-- Describe how you tested these changes -->

### Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)  
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Code quality improvement

### Related Issues
<!-- Link any related issues: Fixes #123, Related to #456 -->

### Screenshots (if applicable)
<!-- Add screenshots for UI changes or visual features -->

---

### 🤖 Automated Quality Gates
This PR will automatically run the following checks:
- ✅ Godot project validation
- ✅ Python backend quality (Black, Flake8, MyPy)
- ✅ API endpoint testing
- ✅ Code quality analysis
- ✅ Security scanning
- ✅ Performance checks
- ✅ Documentation validation
- ✅ Full integration testing

### 🔍 Manual Review Focus
Please pay special attention to:
- [ ] Game logic and physics
- [ ] API security and data validation
- [ ] Database schema changes
- [ ] Performance implications
- [ ] User experience impact
