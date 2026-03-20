# dart-lsp

A Claude Code plugin providing Dart and Flutter code intelligence.

## Features

- **LSP Integration** — Dart Analysis Server providing real-time diagnostics, go-to-definition, find-references, hover information, and code completion
- **Auto Fix/Format** — Automatically runs `dart fix --apply` and `dart format` after every `.dart` file edit. Note: `dart fix` runs on the full package and may take several seconds on large projects.
- **Project Analysis** — `/dart-lsp:analyze` skill for deep project health assessment (dependencies, static analysis, code metrics)
- **Code Review** — Specialized Dart/Flutter code review agent (`dart-reviewer`) with knowledge of Effective Dart, Flutter best practices, and common pitfalls

## Requirements

- Claude Code 1.0.33+
- Dart SDK 3.x+ in PATH (`dart --version` to verify)

## Installation

### From local directory (development)

```bash
claude --plugin-dir ./dart-lsp
```

### Usage

Once installed:

- **LSP diagnostics** work automatically — edit any `.dart` file and Claude sees errors/warnings instantly
- **Auto-formatting** triggers after every Write/Edit on `.dart` files
- **Analyze**: run `/dart-lsp:analyze` or `/dart-lsp:analyze lib/src`
- **Code review**: the `dart-reviewer` agent is available in `/agents`

## Compatibility

- Windows, macOS, Linux
- Dart and Flutter projects (auto-detected via `pubspec.yaml`)

## Architecture

The plugin is internally divided into two layers for future separation:

- **LSP Layer** (`.lsp.json`) — Dart Analysis Server configuration, zero dependencies on Toolkit
- **Toolkit Layer** (`hooks/`, `scripts/`, `skills/`, `agents/`) — automation and intelligence features, zero dependencies on LSP
