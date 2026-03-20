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
