# Copilot Instructions for json_library_parser

## Project Overview
A Dart package that performs **semantic analysis** of other Dart packages using the `analyzer` package. Extracts complete public API surfaces (classes, members, inheritance chains) as JSON with **export-aware metadata** tracking which package URIs expose each element.

## Core Architecture

### Single Entry Point Pattern
- `lib/json_library_parser.dart` exports only `PackageApiAnalyzer` from `src/`
- All implementation lives in `lib/src/json_library_parser_base.dart` (private by convention)
- This enforces a clean public API surface that mirrors what this tool analyzes

### Export Namespace Analysis (Core Workflow)
The analyzer uses **export namespaces** to determine visibility, not file locations:

1. **Scans all public libraries** (excludes `lib/src/**` via `_findPublicLibraries()`)
2. **Iterates each library's `exportNamespace.definedNames2`** to find exported elements
3. **Tracks multi-export elements** using `elementToUris` map: `<Element, Set<String>>`
   - Same class exported by multiple libraries gets multiple `importableFrom` URIs
   - Example: `AddressDetails` is importable from both `models.dart` and `shopify_flutter.dart`
4. **Builds final JSON** with `importableFrom` (where to import) and `definedIn` (source file) metadata

**Key distinction:**
- `importableFrom`: Package URIs that export this element (what users should import)
- `definedIn`: Actual source file URI (where code is written, often in `lib/src/`)

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
- **Files**: Exclude entire `lib/src/` directory via `_findPublicLibraries()` (multi-level: `lib/foo/src/` also excluded)
- **dart:core members**: Excludes inherited members from `dart:core` (e.g., `toString`, `hashCode`, `noSuchMethod`, `runtimeType`) to focus on the package's actual API surface
- Uses `classElement.interfaceMembers` to get **complete interface** (declared + inherited members from user code)

## Key Development Patterns

### Dart Analyzer Integration
- Creates `AnalysisContextCollection` with resolved SDK path (from Flutter cache via `which dart`)
- Uses `ResolvedLibraryResult` to get semantic information (not just AST)
- Accesses export namespace via `libraryElement.exportNamespace.definedNames2` (Map<String, Element>)
- Type formatting via `type.getDisplayString()` - handles generics automatically
- Distinguishes member kinds by `ElementKind.GETTER` vs parameters presence

### Member Location Tracking
Each member includes `location` field showing source URI:
```dart
memberData['location'] = member.library.uri.toString();
```
This allows tracking which library defines each member (especially important for inherited members).

**Note**: Members with `location: "dart:core"` are filtered out during extraction to focus on the package's actual API surface rather than inherited Object methods.

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
- **Scope**: Extracts classes, enums, top-level functions, and top-level variables
  - **Classes**: Full interface with members, inheritance chains, type parameters
  - **Enums**: Values, members, interfaces, and mixins
  - **Top-level functions**: Parameters, return types, type parameters
  - **Top-level variables**: Types, modifiers (const, final, late)
  - **Not yet supported**: Typedefs, extensions, extension types
- **Documentation**: `documentationComment` is stored for classes, enums, functions, and variables

## JSON Output Structure
**Current structure (export-aware):**
```json
{
  "elements": [
    {
      "name": "ClassName",
      "elementType": "class",
      "superclass": "BaseClass",
      "members": [
        {
          "name": "method",
          "kind": "method",
          "returnType": "void",
          "location": "package:example/src/some_file.dart"
        }
      ],
      "importableFrom": [
        "package:example/example.dart",
        "package:example/core.dart"
      ],
      "definedIn": "package:example/src/some_file.dart"
    },
    {
      "name": "MyEnum",
      "elementType": "enum",
      "values": [
        {"name": "value1"},
        {"name": "value2"}
      ],
      "importableFrom": ["package:example/example.dart"],
      "definedIn": "package:example/src/enums.dart"
    },
    {
      "name": "myFunction",
      "elementType": "function",
      "returnType": "String",
      "parameters": [
        {
          "name": "param",
          "type": "int",
          "isOptional": false,
          "isNamed": false
        }
      ],
      "importableFrom": ["package:example/example.dart"],
      "definedIn": "package:example/src/utils.dart"
    },
    {
      "name": "myVariable",
      "elementType": "variable",
      "type": "String",
      "isConst": true,
      "isFinal": false,
      "isLate": false,
      "importableFrom": ["package:example/example.dart"],
      "definedIn": "package:example/src/constants.dart"
    }
  ]
}
```

**Key fields:**
- `elementType`: Type of element (`class`, `enum`, `function`, or `variable`)
- `importableFrom`: Array of package URIs that export this element (what users import)
- `definedIn`: Source file URI where element is defined (often in `lib/src/`)
- `location`: Per-member source library (tracks inheritance source)
- Members include both declared and inherited (complete interface), with constructors first
