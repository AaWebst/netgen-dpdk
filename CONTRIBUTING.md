# Contributing to NetGen Pro VEP1445

First off, thank you for considering contributing to NetGen Pro! It's people like you that make this tool better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (config files, screenshots, logs)
- **Describe the behavior you observed and what you expected**
- **Include environment details** (OS, DPDK version, hardware)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **List any alternative solutions** you've considered

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code follows the existing style
6. Issue that pull request!

## Development Setup

```bash
# Clone your fork
git clone https://github.com/your-username/netgen-pro-vep1445.git
cd netgen-pro-vep1445

# Install dependencies
sudo apt-get install dpdk dpdk-dev libjson-c-dev

# Build
make

# Run tests
make test
```

## Coding Standards

### C++ (DPDK Engine)

- Use C++17 features
- Follow existing naming conventions
- Comment complex algorithms
- Keep functions focused and small
- Use RAII for resource management

### Python (Control Server)

- Follow PEP 8 style guide
- Use type hints where appropriate
- Document functions with docstrings
- Keep functions under 50 lines when possible

### JavaScript (GUI)

- Use ES6+ features
- Follow existing code style
- Comment non-obvious code
- Keep functions pure when possible

## Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters
- Reference issues and pull requests after the first line

Example:
```
Add IPv6 support to packet builder

- Implement IPv6 header construction
- Add ICMPv6 support
- Update tests for IPv6 flows

Fixes #123
```

## Project Structure

```
netgen-pro-vep1445/
├── src/              # DPDK engine C++ source
├── web/              # Python control server
│   ├── templates/    # HTML templates
│   └── static/       # CSS, JS, images
├── scripts/          # Installation and setup scripts
├── config/           # Configuration files
├── docs/             # Documentation
└── tests/            # Test files
```

## Testing

- Write unit tests for new features
- Ensure all tests pass before submitting PR
- Add integration tests for complex features
- Test on actual VEP1445 hardware when possible

## Documentation

- Update README.md for new features
- Add docstrings to Python functions
- Comment C++ code, especially DPDK interactions
- Update user guides in docs/ folder

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

Thank you for contributing! 🎉
