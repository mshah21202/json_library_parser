# Copilot Instructions for json_library_parser

## Project Overview
A Dart package that performs **semantic analysis** of other Dart packages using the `analyzer` package. Extracts complete public API surfaces (classes, members, inheritance chains) as JSON.

## Core Architecture

### Single Entry Point Pattern
- `lib/json_library_parser.dart` exports only `PackageApiAnalyzer` from `src/`
- All implementation lives in `lib/src/json_library_parser_base.dart` (private by convention)
- This enforces a clean public API surface that mirrors what this tool analyzes

### Critical Workflow: `copyToTemp` for Pub Cache Packages
The analyzer has two modes:
1. **Direct analysis** (default): Analyzes package in-place
2. **Copy to temp** (`copyToTemp: true`): Required for read-only packages (`.pub-cache`)
   - Copies entire package to temp directory
   - Runs `dart pub get` to resolve dependencies
   - Prevents "InvalidType" issues from unresolved dependencies
   - Auto-cleans temp directory in `finally` block

**Example from `test/real_package_analysis_test.dart`:**
```dart
await analyzer.analyzePackage(packagePath, copyToTemp: true);
```

### Privacy Convention Implementation
The package enforces Dart's privacy rules:
- **Classes/members**: Skip if name starts with `_`
- **Files**: Exclude entire `lib/src/` directory via `_findPublicLibraries()`
- Uses `classElement.interfaceMembers` to get **complete interface** (declared + inherited members)

## Key Development Patterns

### Dart Analyzer Integration
- Creates `AnalysisContextCollection` with resolved SDK path (from Flutter cache via `which dart`)
- Uses `ResolvedLibraryResult` to get semantic information (not just AST)
- Type formatting via `type.getDisplayString()` - handles generics automatically
- Distinguishes member kinds by `ElementKind.GETTER` vs parameters presence

### Constructor Handling Edge Case
Unnamed constructors may return `'new'` as name - normalize to empty string:
```dart
var constructorName = constructor.name ?? '';
if (constructorName == 'new') {
  constructorName = '';
}
```

### Type Resolution Debugging
When encountering `InvalidType`:
1. Check if `copyToTemp: true` was used (most common cause)
2. Debug output includes: type, runtime type, element (see `_formatDartType()`)
3. Falls back to element name if available

## Testing Strategy

### Test Structure
- `json_library_parser_test.dart`: Unit tests with synthetic packages in temp directories
- `real_package_analysis_test.dart`: Integration test against real pub package, writes to `analysis_output.json`

### Temp Package Creation Pattern
All tests follow this pattern:
```dart
tearDown(() async {
  if (tempDir != null && tempDir!.existsSync()) {
    await tempDir!.delete(recursive: true);
  }
});
```

## Running Common Tasks

```bash
# Run all tests
dart test

# Run specific test file
dart test test/real_package_analysis_test.dart

# Run example (analyzes itself)
dart run example/json_library_parser_example.dart

# Analyze code quality
dart analyze

# Format code
dart format .
```

## Important Constraints

- **SDK Requirement**: `^3.9.0` (uses new analyzer fragments API)
- **Platform**: macOS-centric SDK resolution (`which dart` → Flutter cache path)
- **Scope Limitation**: Currently only extracts classes - no top-level functions, enums, typedefs, or extensions
- **Documentation**: `documentationComment` is available but only stored for classes, not members

## JSON Output Structure
```json
{
  "lib/example.dart": {
    "classes": [{
      "name": "ClassName",
      "superclass": "BaseClass",
      "members": [
        {"name": "method", "kind": "method", "returnType": "void"},
        {"name": "getter", "kind": "getter", "returnType": "String"}
      ]
    }]
  }
}
```

Members include both declared and inherited (complete interface), ordered with constructors first.
