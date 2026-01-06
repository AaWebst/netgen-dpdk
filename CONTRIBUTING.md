# Contributing to NetGen Pro - DPDK Edition

Thank you for your interest in contributing to NetGen Pro! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow:

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

Before contributing, ensure you have:

1. Read the README.md and understand the project
2. Set up a development environment
3. Familiarized yourself with DPDK concepts
4. Reviewed existing issues and pull requests

### Development Environment

```bash
# Clone the repository
git clone https://github.com/yourusername/netgen-dpdk.git
cd netgen-dpdk

# Install dependencies
./scripts/install.sh

# Build the project
make

# Run tests (if available)
make test
```

## How to Contribute

### Types of Contributions

We welcome:

- **Bug fixes**: Fix issues in the codebase
- **Features**: Add new functionality
- **Documentation**: Improve or add documentation
- **Performance**: Optimize code performance
- **Tests**: Add or improve test coverage
- **Examples**: Add usage examples

### Finding Something to Work On

1. Check the [Issues](https://github.com/yourusername/netgen-dpdk/issues) page
2. Look for issues tagged with `good-first-issue` or `help-wanted`
3. Comment on the issue to let others know you're working on it
4. If you have a new idea, open an issue to discuss it first

## Coding Standards

### C++ Code Style

Follow these guidelines for C++ code:

```cpp
// Use 4 spaces for indentation (no tabs)
// Use descriptive variable names
// Add comments for complex logic
// Use RAII for resource management

class ExampleClass {
public:
    ExampleClass();  // Constructor
    ~ExampleClass(); // Destructor
    
    void doSomething(int param);  // Public methods
    
private:
    int m_member_variable;  // Member variables with m_ prefix
    
    void helperFunction();  // Private helper
};
```

### Python Code Style

Follow PEP 8 for Python code:

```python
# Use 4 spaces for indentation
# Follow PEP 8 naming conventions
# Add docstrings to functions and classes
# Use type hints where appropriate

def process_packet(packet_data: bytes) -> dict:
    """
    Process a packet and return statistics.
    
    Args:
        packet_data: Raw packet data
        
    Returns:
        Dictionary with packet statistics
    """
    # Implementation
    pass
```

### Commit Messages

Write clear, concise commit messages:

```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.

- Bullet points are okay
- Use present tense ("Add feature" not "Added feature")
- Reference issues: "Fixes #123" or "Related to #456"
```

Examples:
- `Fix hugepage detection on Ubuntu 24.04`
- `Add support for IPv6 packet generation`
- `Improve error handling in DPDK initialization`

## Testing

### Running Tests

```bash
# Build with debug symbols
make DEBUG=1

# Run unit tests (when available)
make test

# Run specific test
./tests/test_packet_gen

# Test with valgrind for memory leaks
valgrind --leak-check=full ./build/dpdk_engine
```

### Adding Tests

When adding new features, include tests:

```bash
# Create test file
touch tests/test_new_feature.cpp

# Add to Makefile
# Update tests/Makefile or main Makefile
```

### Manual Testing

Before submitting:

1. Test on a clean system
2. Verify documentation accuracy
3. Test with different configurations
4. Check for memory leaks
5. Verify performance hasn't regressed

## Pull Request Process

### Before Submitting

- [ ] Code follows project style guidelines
- [ ] All tests pass
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] No merge conflicts with main branch

### Submission Steps

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/netgen-dpdk.git
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/my-new-feature
   # or
   git checkout -b fix/issue-123
   ```

3. **Make your changes**
   ```bash
   # Edit files
   # Test changes
   # Commit with good messages
   git add .
   git commit -m "Add new feature"
   ```

4. **Push to your fork**
   ```bash
   git push origin feature/my-new-feature
   ```

5. **Open a Pull Request**
   - Go to GitHub and open a PR
   - Fill out the PR template
   - Link related issues
   - Request review

### PR Template

When opening a PR, include:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

## Testing
How has this been tested?

## Checklist
- [ ] Code follows style guidelines
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
```

### Review Process

1. Maintainers will review your PR
2. Address any feedback or requested changes
3. Once approved, your PR will be merged
4. Your contribution will be credited in CHANGELOG.md

## Issue Reporting

### Bug Reports

When reporting bugs, include:

```markdown
## Description
Clear description of the bug

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS: Ubuntu 22.04
- DPDK Version: 23.11
- NIC: Intel X710
- Kernel: 5.15.0

## Logs
```
Paste relevant logs here
```

## Additional Context
Any other relevant information
```

### Feature Requests

When requesting features:

```markdown
## Problem
What problem does this solve?

## Proposed Solution
How should this work?

## Alternatives Considered
What other options did you consider?

## Additional Context
Any mockups, examples, or references
```

## Development Guidelines

### DPDK-Specific Guidelines

When working with DPDK code:

- Always check return values
- Use DPDK memory allocation functions
- Be aware of NUMA node affinity
- Use appropriate RTE log levels
- Follow DPDK coding conventions
- Test on actual hardware when possible

### Performance Considerations

- Profile code changes
- Avoid unnecessary allocations in fast path
- Use DPDK best practices (burst processing, etc.)
- Document performance implications
- Include benchmark results for performance changes

### Documentation

Update documentation when:

- Adding new features
- Changing API behavior
- Fixing significant bugs
- Adding configuration options
- Changing requirements

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Pull Requests**: Code contributions

### Getting Help

If you need help:

1. Check existing documentation
2. Search closed issues
3. Open a new discussion
4. Be specific and provide context

## Recognition

Contributors will be:

- Listed in CHANGELOG.md
- Credited in release notes
- Added to CONTRIBUTORS.md (when created)

## License

By contributing, you agree that your contributions will be licensed under the same MIT License that covers the project.

---

Thank you for contributing to NetGen Pro - DPDK Edition! 🚀
