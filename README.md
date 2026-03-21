# dart-lsp

A Claude Code plugin providing Dart and Flutter code intelligence.

## Features

- **LSP Integration** — Dart Analysis Server providing real-time diagnostics, go-to-definition, find-references, hover information, and code completion
- **Auto Fix/Format** — Runs `dart format` after every `.dart` file edit, and `dart fix --apply` when the agent finishes responding. This prevents `dart fix` from removing imports mid-work while still applying fixes before completion.
- **Project Analysis** — `/dart-lsp:analyze` skill for deep project health assessment (dependencies, static analysis, code metrics)
- **Code Review** — Specialized Dart/Flutter code review agent (`dart-reviewer`) with knowledge of Effective Dart, Flutter best practices, and common pitfalls

## Requirements

- Claude Code 1.0.33+
- Dart SDK 3.x+ in PATH (`dart --version` to verify)

## Installation

### From marketplace (recommended)

Add the marketplace and install the plugin:

```shell
/plugin marketplace add malcolmpl/dart-lsp
/plugin install dart-lsp@dart-lsp-marketplace
```

### From local directory (development)

Clone the repo and load it directly:

```bash
git clone https://github.com/malcolmpl/dart-lsp.git
claude --plugin-dir ./dart-lsp
```

After installing, run `/reload-plugins` to activate without restarting Claude Code.

## Usage

### LSP Diagnostics (automatic)

Once installed, LSP diagnostics work automatically. Edit any `.dart` file and Claude sees type errors, missing imports, and warnings instantly — no tool calls needed. Press **Ctrl+O** to see the diagnostics indicator.

### Auto Fix/Format (automatic)

The plugin runs formatting and fixes in two phases:
1. **After each edit** — `dart format` on the edited `.dart` file (safe, never removes code)
2. **When agent stops** — `dart fix --apply` on affected packages (removes unused imports, applies safe fixes)

This two-phase approach prevents `dart fix` from removing imports that the agent hasn't used yet.

### Project Analysis

Run the analyze skill to get a full project health report:

```shell
/dart-lsp:analyze
```

Narrow the scope to a subdirectory:

```shell
/dart-lsp:analyze lib/src/models
```

The analysis covers:
- Dependency check (`dart pub outdated`)
- Static analysis (`dart analyze`)
- Code metrics (file count, lines of code, error/warning counts)
- Flutter-specific checks (if applicable)
- Health score and actionable recommendations

### Code Review Agent

The `dart-reviewer` agent is available for specialized Dart/Flutter code review. It appears in `/agents` and Claude can invoke it automatically when reviewing Dart code.

The agent focuses on:
- Null safety, async patterns, Effective Dart style
- Flutter widget decomposition, state management, performance
- Skips generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`)

## Compatibility

- Windows, macOS, Linux
- Dart and Flutter projects (auto-detected via `pubspec.yaml`)

## Architecture

The plugin is internally divided into two layers for future separation:

- **LSP Layer** (`.lsp.json`) — Dart Analysis Server configuration, zero dependencies on Toolkit
- **Toolkit Layer** (`hooks/`, `scripts/`, `skills/`, `agents/`) — automation and intelligence features, zero dependencies on LSP

## Development

After cloning, enable git hooks for auto version bumping:

```bash
git config core.hooksPath githooks
```

The `post-commit` hook automatically:
- Bumps version in `plugin.json` and `marketplace.json` based on conventional commits (`feat:` → minor, `fix:`/`chore:` → patch, `BREAKING CHANGE` → major)
- Only triggers when plugin files change (not docs/README)
- Tags releases for `feat:` and `BREAKING CHANGE` commits
- `[release]` in commit message forces a tag on any bump type
- `[skip-bump]` skips version bumping entirely

## Documentation

- `docs/superpowers/specs/` — design specification with architectural decisions
- `docs/superpowers/plans/` — implementation plan with task breakdown

## License

MIT — see [LICENSE](LICENSE)
