# dart-lsp Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that provides Dart/Flutter code intelligence via LSP, auto-formatting hooks, project analysis skill, and specialized code review agent.

**Architecture:** Monolithic plugin with two internal layers (LSP and Toolkit). All components are static config or Dart scripts — no build step. The only external dependency is `dart` in PATH.

**Tech Stack:** Claude Code plugin system, Dart Analysis Server (LSP), Dart scripting (`dart:io`, `dart:convert`)

**Spec:** `docs/superpowers/specs/2026-03-20-dart-lsp-plugin-design.md`

---

## File Map

| File | Action | Responsibility | Layer |
|------|--------|----------------|-------|
| `.claude-plugin/plugin.json` | Create | Plugin manifest — name, version, metadata | Meta |
| `.lsp.json` | Create | Dart Analysis Server LSP configuration | LSP |
| `hooks/hooks.json` | Create | PostToolUse hook wiring for auto-fix/format | Toolkit |
| `scripts/dart-post-edit.dart` | Create | Multiplatform hook script — dart fix + dart format | Toolkit |
| `skills/analyze/SKILL.md` | Create | Skill prompt for `/dart-lsp:analyze` | Toolkit |
| `agents/dart-reviewer.md` | Create | Agent prompt for Dart/Flutter code reviewer | Toolkit |
| `LICENSE` | Create | MIT license file | Meta |
| `README.md` | Create | Plugin documentation and install instructions | Meta |

---

## Task 1: Plugin Manifest and LSP Configuration (LSP Layer)

**Difficulty:** Easy — static JSON files, no logic
**Agent suitability:** Any agent (haiku-level sufficient)

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.lsp.json`

- [ ] **Step 1: Create plugin manifest**

Create `.claude-plugin/plugin.json`:

```json
{
  "name": "dart-lsp",
  "description": "Dart and Flutter code intelligence — LSP diagnostics, auto-formatting, project analysis, and specialized code review",
  "version": "1.0.0",
  "author": { "name": "Dariusz" },
  "keywords": ["dart", "flutter", "lsp", "code-intelligence", "analysis", "code-review"],
  "license": "MIT"
}
```

- [ ] **Step 2: Create LSP server configuration**

Create `.lsp.json`:

```json
{
  "dart": {
    "command": "dart",
    "args": ["language-server", "--protocol=lsp"],
    "extensionToLanguage": {
      ".dart": "dart"
    },
    "initializationOptions": {
      "suggestFromUnimportedLibraries": true,
      "closingLabels": true,
      "outline": true,
      "flutterOutline": true
    },
    "settings": {
      "dart.completeFunctionCalls": true,
      "dart.enableSnippets": true,
      "dart.showTodos": true,
      "dart.documentation": "full"
    },
    "restartOnCrash": true,
    "maxRestarts": 3
  }
}
```

- [ ] **Step 3: Validate JSON syntax and Dart availability**

Run: `dart help language-server`
Expected: Help output describing the `language-server` subcommand. Note: the LSP server itself cannot be tested without an LSP client — validation here just confirms the command is available.

Run: `python -m json.tool .claude-plugin/plugin.json && python -m json.tool .lsp.json`
Expected: Valid JSON output for both files

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/plugin.json .lsp.json
git commit -m "feat: add plugin manifest and LSP server configuration"
```

---

## Task 2: Hook Script — Auto Fix/Format (Toolkit Layer)

**Difficulty:** Medium — Dart scripting, stdin JSON parsing, cross-platform process execution
**Agent suitability:** Sonnet-level or above (logic + error handling)

**Files:**
- Create: `scripts/dart-post-edit.dart`
- Create: `hooks/hooks.json`

- [ ] **Step 1: Create the hook script**

Create `scripts/dart-post-edit.dart`:

```dart
import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    final input = await stdin.transform(utf8.decoder).join();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(input) as Map<String, dynamic>;
    } catch (_) {
      exit(0);
    }

    final toolInput = json['tool_input'] as Map<String, dynamic>?;
    final filePath = toolInput?['file_path'] as String?;

    if (filePath == null || !filePath.endsWith('.dart')) exit(0);

    final file = File(filePath);
    if (!file.existsSync()) exit(0);

    // Find the package root (directory containing pubspec.yaml)
    Directory? packageRoot;
    var dir = file.parent;
    while (dir.path != dir.parent.path) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) {
        packageRoot = dir;
        break;
      }
      dir = dir.parent;
    }

    // dart fix --apply on the package (if pubspec.yaml found)
    if (packageRoot != null) {
      final fixResult = await Process.run(
        'dart',
        ['fix', '--apply'],
        workingDirectory: packageRoot.path,
      );
      if (fixResult.exitCode != 0) {
        stderr.writeln('dart fix failed: ${fixResult.stderr}');
      }
    }

    // dart format on the specific file
    final formatResult = await Process.run('dart', ['format', filePath]);
    if (formatResult.exitCode != 0) {
      stderr.writeln('dart format failed: ${formatResult.stderr}');
    }
  } catch (e) {
    stderr.writeln('dart-post-edit error: $e');
  }

  exit(0);
}
```

- [ ] **Step 2: Create the hook configuration**

Create `hooks/hooks.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultilineEdit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "dart run ${CLAUDE_PLUGIN_ROOT}/scripts/dart-post-edit.dart"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Test the hook script manually**

Create a temporary Dart package for testing:
```bash
dart create test_pkg
```

Create a badly formatted test file (`test_pkg/lib/bad.dart`):
```dart
void main(){var x=1;if(x==1){print("hello");}}
```

Test with a valid Dart file inside a package:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"'$(pwd)'/test_pkg/lib/bad.dart"},"tool_response":"ok"}' | dart run scripts/dart-post-edit.dart
```
Expected: Script exits 0. Verify `test_pkg/lib/bad.dart` is now properly formatted (indented, line breaks).

Test with a non-dart file:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"readme.md"},"tool_response":"ok"}' | dart run scripts/dart-post-edit.dart
```
Expected: Script exits 0 immediately (skips non-dart files).

Test with invalid JSON:
```bash
echo 'not json' | dart run scripts/dart-post-edit.dart
```
Expected: Script exits 0 (graceful handling).

Clean up:
```bash
rm -rf test_pkg
```

- [ ] **Step 4: Commit**

```bash
git add scripts/dart-post-edit.dart hooks/hooks.json
git commit -m "feat: add PostToolUse hook for auto dart fix and format"
```

---

## Task 3: Analyze Skill (Toolkit Layer)

**Difficulty:** Easy — markdown file with prompt instructions
**Agent suitability:** Any agent (haiku-level sufficient, but Sonnet recommended for prompt quality)

**Files:**
- Create: `skills/analyze/SKILL.md`

- [ ] **Step 1: Create the analyze skill**

Create `skills/analyze/SKILL.md`:

```markdown
---
name: analyze
description: Deep analysis of Dart/Flutter project — diagnostics, dependencies, structure overview. Use when user asks to analyze a Dart project, check for issues, or get a project health overview.
---

# Dart Project Analysis

Perform a comprehensive analysis of the current Dart/Flutter project.

## Scope

Use $ARGUMENTS as an optional path filter. If provided, narrow the analysis to that subdirectory. If not provided, analyze the full project.

## Steps

1. **Project detection** — find `pubspec.yaml` in the working directory or parent directories. If not found, inform the user this is not a Dart project and stop.

2. **Dependency check** — read `pubspec.yaml` and run:
   - `dart pub get` (if `pubspec.lock` is missing or outdated)
   - `dart pub outdated` to identify outdated dependencies

3. **Static analysis** — run `dart analyze $ARGUMENTS` (or `dart analyze` for full project). Collect all errors, warnings, and info-level diagnostics. Group results by severity.

4. **Code metrics** — summarize:
   - Number of `.dart` files (excluding generated `*.g.dart`, `*.freezed.dart`)
   - Approximate lines of code
   - Count of errors / warnings / info hints from step 3

5. **Flutter-specific** (if `flutter` is listed in `pubspec.yaml` dependencies):
   - Check for deprecated widget usage in analysis output
   - Note if `flutter analyze` provides additional diagnostics

6. **Report** — present findings as a structured summary:
   - **Health score**: good (0 errors, <5 warnings) / needs attention (errors or many warnings) / critical (many errors)
   - **Top issues**: list the most impactful problems to fix first
   - **Dependencies**: any outdated or vulnerable packages
   - **Recommendations**: actionable next steps
```

- [ ] **Step 2: Validate SKILL.md frontmatter**

Run: `python -c "import yaml; yaml.safe_load(open('skills/analyze/SKILL.md').read().split('---')[1])"`
Expected: No errors (valid YAML frontmatter with `name` and `description` fields).

If `pyyaml` is not available, manually verify the frontmatter between the `---` delimiters is valid YAML.

- [ ] **Step 3: Commit**

```bash
git add skills/analyze/SKILL.md
git commit -m "feat: add /dart-lsp:analyze skill for project analysis"
```

---

## Task 4: Code Review Agent (Toolkit Layer)

**Difficulty:** Easy-Medium — markdown file, but requires careful prompt engineering for Dart/Flutter expertise
**Agent suitability:** Sonnet-level or above (prompt quality matters for agent behavior)

**Files:**
- Create: `agents/dart-reviewer.md`

- [ ] **Step 1: Create the code review agent**

Create `agents/dart-reviewer.md`:

```markdown
---
name: dart-reviewer
description: Specialized Dart/Flutter code reviewer. Use when reviewing Dart code for best practices, Flutter widget patterns, performance issues, and Dart idioms. Invoked automatically when Claude detects a code review task in a Dart project.
---

You are a senior Dart/Flutter code reviewer. Review code with focus on:

## Dart-specific
- Null safety correctness — unnecessary nullable types, missing null checks
- Effective Dart style — naming conventions, library organization, documentation
- Async patterns — proper use of Future/Stream, avoiding unawaited futures
- Collection patterns — prefer collection-if/for over imperative building
- Type inference — avoid redundant type annotations, use `final` where possible
- Error handling — typed catches, proper Error vs Exception usage

## Flutter-specific (when applicable)
- Widget decomposition — extract widgets when build() exceeds ~50 lines
- State management — proper use of setState, avoid rebuilding unnecessary subtrees
- Performance — const constructors, RepaintBoundary, avoid allocations in build()
- Keys — proper use of ValueKey/ObjectKey in lists
- Lifecycle — proper dispose() of controllers, streams, animations

## Exclusions
Do NOT review generated files. Skip entirely any file matching:
- `*.g.dart`
- `*.freezed.dart`
- `*.mocks.dart`

## Review format
1. List issues by severity: errors > warnings > suggestions
2. For each issue: file:line, what's wrong, how to fix (with code snippet)
3. End with a summary: what's good, what needs work, overall assessment

Use the LSP diagnostics and dart analyze results as input when available.
```

- [ ] **Step 2: Commit**

```bash
git add agents/dart-reviewer.md
git commit -m "feat: add dart-reviewer agent for specialized code review"
```

---

## Task 5: Documentation and License (Meta)

**Difficulty:** Easy — static files
**Agent suitability:** Any agent (haiku-level sufficient)

**Files:**
- Create: `LICENSE`
- Create: `README.md`

- [ ] **Step 1: Create MIT license**

Create `LICENSE` with MIT license text, copyright 2026 Dariusz.

- [ ] **Step 2: Create README**

Create `README.md`:

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add LICENSE README.md
git commit -m "docs: add LICENSE and README"
```

---

## Task 6: Integration Test — Load Plugin in Claude Code

**Difficulty:** Easy — manual verification
**Agent suitability:** Must be run by user or main agent (requires Claude Code session)

- [ ] **Step 1: Validate plugin structure**

Run from the plugin root directory (`dart-lsp/`):
```bash
find . -type f | sort
```

Expected output (paths relative to plugin root):
```
./.claude-plugin/plugin.json
./.lsp.json
./agents/dart-reviewer.md
./hooks/hooks.json
./LICENSE
./README.md
./scripts/dart-post-edit.dart
./skills/analyze/SKILL.md
```

- [ ] **Step 2: Test plugin loading**

```bash
claude --plugin-dir .
```

Expected: Claude Code starts without errors. Run `/help` — should show `/dart-lsp:analyze` in available skills.

- [ ] **Step 3: Verify LSP server starts**

Open a Dart project directory and edit a `.dart` file. Check that diagnostics appear (Ctrl+O for diagnostics indicator).

- [ ] **Step 4: Verify hook fires**

Edit a `.dart` file with intentional formatting issues (e.g., remove indentation or add extra spaces). After the edit, verify the file is actually reformatted — open it and confirm proper indentation/spacing. This confirms both that `${CLAUDE_PLUGIN_ROOT}` is correctly expanded by Claude Code and that the script executes.

Note: On Windows, Claude Code handles `${CLAUDE_PLUGIN_ROOT}` expansion internally before passing to the shell — it is not dependent on OS-level env var expansion.

- [ ] **Step 5: Verify agent is available**

Run `/agents` — `dart-reviewer` should appear in the list.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore: plugin ready for testing"
```

---

## Task Summary

| Task | Component | Difficulty | Agent Level | Est. Steps |
|------|-----------|------------|-------------|------------|
| 1 | Manifest + LSP config | Easy | Haiku | 4 |
| 2 | Hook script + config | Medium | Sonnet | 4 |
| 3 | Analyze skill | Easy | Haiku/Sonnet | 3 |
| 4 | Code review agent | Easy-Medium | Sonnet | 2 |
| 5 | README + LICENSE | Easy | Haiku | 3 |
| 6 | Integration test | Easy | User/Main | 6 |

**Dependencies:**
- Tasks 1-5 are independent — can be executed in parallel
- Task 6 depends on all previous tasks (integration test)

**Parallel execution strategy:**
- Group A (parallel): Tasks 1, 3, 5 — easy, independent, static files
- Group B (parallel after A or independent): Tasks 2, 4 — medium, need more care
- Group C (sequential, last): Task 6 — integration test after all files exist
