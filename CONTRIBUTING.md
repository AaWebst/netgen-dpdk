# Contributing to NetGen Pro VEP1445

Thank you for your interest in contributing to NetGen Pro! This document provides guidelines and instructions for contributing.

---

## 🤝 How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/YOUR_USERNAME/netgen-pro-vep1445/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - System information (OS, DPDK version, hardware)
   - Relevant logs

### Suggesting Features

1. Check if the feature has been requested in [Issues](https://github.com/YOUR_USERNAME/netgen-pro-vep1445/issues)
2. Create a new issue with:
   - Clear description of the feature
   - Use case / motivation
   - Possible implementation approach
   - Any relevant examples

### Submitting Pull Requests

1. **Fork the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/netgen-pro-vep1445.git
   cd netgen-pro-vep1445
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the code style guide (see below)
   - Add tests if applicable
   - Update documentation

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add feature: your feature description"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**
   - Provide clear description
   - Reference any related issues
   - Include screenshots if UI changes

---

## 📝 Code Style Guide

### C/C++ Code

- **Indentation:** 4 spaces (no tabs)
- **Naming:**
  - Functions: `snake_case` (e.g., `dpdk_get_link_status`)
  - Variables: `snake_case` (e.g., `port_id`)
  - Constants: `UPPER_CASE` (e.g., `MAX_PORTS`)
  - Structs: `snake_case` (e.g., `struct discovered_device`)
- **Braces:** K&R style
  ```c
  if (condition) {
      // code
  }
  ```
- **Comments:** Descriptive comments for functions and complex logic
  ```c
  /*
   * Get link status for a DPDK port
   * Returns: 1 = link up, 0 = link down, -1 = error
   */
  int dpdk_get_link_status(uint16_t port_id, struct rte_eth_link *link)
  ```

### Python Code

- **Follow PEP 8**
- **Indentation:** 4 spaces
- **Naming:**
  - Functions: `snake_case`
  - Classes: `PascalCase`
  - Constants: `UPPER_CASE`
- **Docstrings:** For all functions and classes
  ```python
  def send_dpdk_command(command_dict, timeout=10):
      """Send command to DPDK engine via Unix socket"""
      # implementation
  ```

### JavaScript Code

- **Indentation:** 2 spaces
- **Naming:**
  - Variables: `camelCase`
  - Classes: `PascalCase`
  - Constants: `UPPER_CASE`
- **Modern JS:** ES6+ features preferred
- **Comments:** JSDoc style for functions

---

## 🧪 Testing

### Before Submitting

1. **Build the project**
   ```bash
   make clean
   make
   ```

2. **Test basic functionality**
   ```bash
   sudo bash scripts/start-dpdk-engine.sh
   # Test traffic generation via GUI
   ```

3. **Run diagnostic script**
   ```bash
   sudo bash scripts/diagnostics.sh
   ```

### Adding Tests

- Add unit tests for new C/C++ functions
- Add API tests for new endpoints
- Document test procedures in PR

---

## 📚 Documentation

### Required Documentation

- **Code comments:** For complex logic
- **API documentation:** For new endpoints
- **README updates:** For new features
- **Changelog entries:** Following Keep a Changelog format

### Documentation Style

- Clear and concise
- Include code examples
- Use proper markdown formatting
- Add diagrams for complex features

---

## 🔍 Review Process

### What We Look For

- ✅ Code follows style guide
- ✅ Changes are well-tested
- ✅ Documentation is updated
- ✅ Commit messages are clear
- ✅ No breaking changes (or clearly documented)

### Review Timeline

- Initial review: Within 3-5 days
- Follow-up reviews: Within 1-2 days
- Merge: After approval from maintainer

---

## 🚀 Release Process

### Version Numbering

We use [Semantic Versioning](https://semver.org/):
- **MAJOR:** Breaking changes
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes

### Release Checklist

- [ ] Update version in `VERSION` file
- [ ] Update `CHANGELOG.md`
- [ ] Update documentation
- [ ] Tag release: `git tag -a v4.1.0 -m "Release v4.1.0"`
- [ ] Push tags: `git push origin v4.1.0`
- [ ] Create GitHub release

---

## 💬 Communication

### Channels

- **Issues:** Bug reports, feature requests
- **Pull Requests:** Code contributions
- **Discussions:** General questions, ideas

### Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the code, not the person
- Help others learn and grow

---

## 🎯 Priority Areas

### High Priority

- Performance improvements
- Bug fixes
- Security enhancements
- Documentation improvements

### Medium Priority

- New traffic patterns
- GUI enhancements
- API expansions
- Testing infrastructure

### Low Priority

- Code refactoring (without functional changes)
- Minor UI tweaks
- Convenience features

---

## 📋 Checklist Before Submitting PR

- [ ] Code follows style guide
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Changelog updated
- [ ] No merge conflicts
- [ ] Commits are clear and atomic
- [ ] PR description is complete

---

## 🙏 Thank You!

Your contributions make NetGen Pro better for everyone. We appreciate your time and effort!

---

**Questions?** Open an issue or discussion on GitHub.
