# dart-lsp Plugin — Design Spec

## Overview

A monolithic Claude Code plugin providing full Dart/Flutter code intelligence. Internally divided into two layers (LSP and Toolkit) designed for easy future separation into independent plugins.

## Layers

### LSP Layer (`dart-lsp`)
- Dart Analysis Server configuration in LSP mode
- Passive diagnostics after every edit
- Navigation: go-to-definition, find-references, hover, completions
- Only dependency: `dart` in PATH

### Toolkit Layer (`dart-toolkit`)
- `PostToolUse` hook — auto `dart fix --apply` + `dart format` after `.dart` edits
- Skill `/dart-lsp:analyze` — deep Dart/Flutter project analysis
- Agent `dart-reviewer` — specialized Dart/Flutter code review

## Directory Structure

```
dart-lsp/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── .lsp.json                    # LSP: Dart Analysis Server
├── hooks/
│   └── hooks.json               # Toolkit: PostToolUse hook
├── scripts/
│   └── dart-post-edit.dart      # Toolkit: fix/format script (multiplatform)
├── skills/
│   └── analyze/
│       └── SKILL.md             # Toolkit: /dart-lsp:analyze
├── agents/
│   └── dart-reviewer.md         # Toolkit: Dart/Flutter code reviewer
├── LICENSE
└── README.md
```

## Components — Details

### 1. LSP Server (`.lsp.json`)

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

Note: `restartOnCrash` and `maxRestarts` are Claude Code plugin-specific fields (not standard LSP). The `settings` block uses Dart Analysis Server configuration keys passed via `workspace/didChangeConfiguration`.

### 2. Hook — auto-fix/format (`hooks/hooks.json`)

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

### 3. Hook Script (`scripts/dart-post-edit.dart`)

Multiplatform Dart script (Windows/macOS/Linux):
- Reads JSON from stdin (Claude Code hook input)
- Filters by `.dart` extension
- Runs `dart fix --apply` on the package directory (not on a single file — `dart fix` operates at package level)
- Runs `dart format` on the edited file
- Errors logged to stderr (Claude Code may surface them), always exits 0 — does not block Claude

**Hook input JSON format (Claude Code hook payload):**
```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/absolute/path/to/file.dart",
    "content": "..."
  },
  "tool_response": "..."
}
```
The script reads `tool_input.file_path` for extension filtering and passing to `dart format`.

**Note:** `${CLAUDE_PLUGIN_ROOT}` is an environment variable automatically set by Claude Code for installed plugins — it points to the absolute path of the plugin directory.

### 4. Skill — `/dart-lsp:analyze` (`skills/analyze/SKILL.md`)

Deep project analysis:
1. Project detection (`pubspec.yaml`)
2. Dependency check (`dart pub outdated`)
3. Static analysis (`dart analyze`)
4. Code metrics (files, lines, errors)
5. Flutter-specific checks (if applicable)
6. Report with project health assessment

Accepts `$ARGUMENTS` as an optional scope filter:
- No arguments → full project analysis (directory containing `pubspec.yaml`)
- Relative path → subdirectory analysis (e.g., `/dart-lsp:analyze lib/src/models`)
- Passed as path argument to `dart analyze <path>`

### 5. Agent — `dart-reviewer` (`agents/dart-reviewer.md`)

Specialized code reviewer:
- Dart: null safety, async patterns, Effective Dart style, error handling
- Flutter: widget decomposition, state management, performance, lifecycle
- Excludes generated files from review (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) — hard exclusion, these files are skipped entirely
- Output format: issues by severity, file:line, fix suggestions, summary

### 6. Manifest (`.claude-plugin/plugin.json`)

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

## Dependencies

- `dart` in PATH (only external dependency)
- Dart SDK 3.x+ (`dart fix --apply` operates on package, `dart format` on file)

## Compatibility

- Windows, macOS, Linux — scripts in Dart, zero shell dependencies
- Dart and Flutter projects — automatic detection via `pubspec.yaml`

## Future Separation

To split into 2 plugins:
- **dart-lsp**: `.lsp.json` + minimal `plugin.json`
- **dart-toolkit**: `hooks/`, `scripts/`, `skills/`, `agents/` + own `plugin.json`

The layers have no functional dependencies between each other. Splitting requires:
1. Copying respective files to new directories
2. Creating separate `plugin.json` for each plugin (new names, descriptions, keywords)
3. `dart-toolkit` would get its own name with a description focused on hooks/skills/agents
