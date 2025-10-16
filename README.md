# json_library_parser

A Dart package that analyzes other Dart packages and extracts their public API surface as JSON.

## Features

- **Automatic API Extraction**: Analyzes Dart packages and extracts all public classes and their members
- **Inheritance Support**: Captures both declared and inherited members from the complete interface
- **Privacy Respecting**: Automatically excludes private elements (starting with `_`) and files in `lib/src/`
- **Rich Member Information**: Extracts methods, getters, setters with full type signatures and parameters
- **Type Information**: Includes superclasses, interfaces, mixins, and generic type parameters

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  json_library_parser: ^1.0.0
```

## Usage

```dart
import 'dart:convert';
import 'package:json_library_parser/json_library_parser.dart';

Future<void> main() async {
  final analyzer = PackageApiAnalyzer();
  
  // Analyze a Dart package
  final result = await analyzer.analyzePackage('/path/to/package');
  
  // Convert to JSON
  final jsonString = JsonEncoder.withIndent('  ').convert(result);
  print(jsonString);
}
```

### Example Output

For a simple class hierarchy:

```dart
class BaseClass {
  void baseMethod() {}
  String get baseProp => 'base';
}

class DerivedClass extends BaseClass {
  void derivedMethod() {}
  int get derivedProp => 42;
}
```

The analyzer produces:

```json
{
  "lib/example.dart": {
    "classes": [
      {
        "name": "BaseClass",
        "members": [
          {
            "name": "baseMethod",
            "kind": "method",
            "isStatic": false,
            "returnType": "void"
          },
          {
            "name": "baseProp",
            "kind": "getter",
            "isStatic": false,
            "returnType": "String"
          }
        ]
      },
      {
        "name": "DerivedClass",
        "superclass": "BaseClass",
        "members": [
          {
            "name": "derivedMethod",
            "kind": "method",
            "isStatic": false,
            "returnType": "void"
          },
          {
            "name": "derivedProp",
            "kind": "getter",
            "isStatic": false,
            "returnType": "int"
          },
          {
            "name": "baseMethod",
            "kind": "method",
            "isStatic": false,
            "returnType": "void"
          },
          {
            "name": "baseProp",
            "kind": "getter",
            "isStatic": false,
            "returnType": "String"
          }
        ]
      }
    ]
  }
}
```

Note how `DerivedClass` includes both its own members (`derivedMethod`, `derivedProp`) and inherited members from `BaseClass` (`baseMethod`, `baseProp`).

## API Reference

### `PackageApiAnalyzer`

The main class for analyzing Dart packages.

#### `analyzePackage(String packagePath)`

Analyzes a Dart package and returns its public API as JSON.

**Parameters:**
- `packagePath`: The root directory of the package to analyze (must contain `pubspec.yaml`)

**Returns:**
- `Future<Map<String, dynamic>>`: A map where keys are library file paths and values contain the API data

**Throws:**
- `ArgumentError`: If the package path doesn't exist or doesn't contain a `pubspec.yaml` file
- `Exception`: If analysis fails for any other reason

## Limitations

This initial version focuses on:
- Classes and their interface members (methods, getters, setters)
- Type information and inheritance relationships

Future versions may include:
- Top-level functions and variables
- Enums and their values
- Typedefs
- Extensions
- More detailed documentation extraction

## Additional information

This package uses the Dart `analyzer` package to perform semantic analysis of Dart code. It respects Dart's privacy conventions by excluding:
- Elements whose names start with `_`
- Files in the `lib/src/` directory

For issues, feature requests, or contributions, please visit the repository.

