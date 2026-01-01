# Contributing to casbin-ex

Thank you for your interest in contributing to casbin-ex! This document provides guidelines and information about the development workflow.

## Development Setup

### Prerequisites

- Elixir 1.14.2 or higher
- Erlang/OTP 25.1.1 or higher

### Getting Started

1. Fork and clone the repository
2. Install dependencies:
   ```bash
   mix deps.get
   ```
3. Run tests to ensure everything is working:
   ```bash
   mix test
   ```

## Code Quality

### Formatting

We use the standard Elixir formatter. Before submitting a PR, ensure your code is properly formatted:

```bash
mix format
```

### Testing

All new features and bug fixes should include tests. Run the test suite with:

```bash
mix test
```

## Continuous Integration

### CI Workflow

Every pull request automatically triggers our CI workflow which:

- Sets up Elixir and Erlang environment
- Installs dependencies
- Checks code formatting with `mix format --check-formatted`
- Runs the full test suite with `mix test`

All checks must pass before a PR can be merged.

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/) for automatic versioning and changelog generation.

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: A new feature (triggers a minor version bump)
- **fix**: A bug fix (triggers a patch version bump)
- **docs**: Documentation only changes
- **style**: Changes that don't affect the meaning of the code
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **perf**: A code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **chore**: Changes to the build process or auxiliary tools

### Breaking Changes

To trigger a major version bump, include `BREAKING CHANGE:` in the commit footer or add `!` after the type:

```
feat!: remove deprecated API

BREAKING CHANGE: The old API has been removed in favor of the new one.
```

### Examples

```
feat: add support for keyMatch3 function

fix: correct RBAC domain policy matching

docs: update README with installation instructions

chore: update dependencies
```

## Release Process

Releases are automated using [semantic-release](https://semantic-release.gitbook.io/):

1. When a PR is merged to the `master` or `main` branch, the release workflow is triggered
2. Semantic-release analyzes commit messages since the last release
3. If releasable commits are found:
   - A new version is determined based on commit types
   - A Git tag is created
   - A GitHub release is published
   - The package is published to [Hex.pm](https://hex.pm/packages/acx)

### Hex.pm Publishing

The release workflow automatically publishes new versions to Hex.pm. This requires a `HEX_API_KEY` secret to be configured in the repository settings:

1. Generate an API key from your Hex.pm account
2. Add it as a repository secret named `HEX_API_KEY`
3. The workflow will use this key to authenticate and publish the package

## Pull Request Process

1. Create a feature branch from `master`
2. Make your changes following the guidelines above
3. Ensure all tests pass and code is formatted
4. Write clear, conventional commit messages
5. Open a pull request with a clear description
6. Wait for CI checks to pass
7. Address any review feedback
8. Once approved, a maintainer will merge your PR

## Questions?

If you have questions or need help, feel free to:
- Open an issue for discussion
- Reach out to the maintainers

Thank you for contributing! 🎉
