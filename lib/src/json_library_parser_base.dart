import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as p;

/// Analyzes Dart packages and extracts their public API surface as JSON.
class PackageApiAnalyzer {
  /// Analyzes a Dart package and returns its public API as JSON.
  ///
  /// [packagePath] should be the root directory of the package to analyze.
  /// The package must contain a `pubspec.yaml` file.
  ///
  /// [copyToTemp] if true, copies the package to a temporary directory and
  /// runs `pub get` to ensure all dependencies are resolved. This is useful
  /// for packages in `.pub-cache` or read-only locations. Defaults to false.
  ///
  /// Returns a Map containing the JSON representation of the package's public API.
  /// The structure is:
  /// ```json
  /// {
  ///   "lib/some_library.dart": {
  ///     "classes": [...]
  ///   }
  /// }
  /// ```
  ///
  /// Throws [ArgumentError] if the package path is invalid or doesn't contain
  /// a pubspec.yaml file.
  Future<Map<String, dynamic>> analyzePackage(String packagePath, {bool copyToTemp = false}) async {
    // Validate package path
    final packageDir = Directory(packagePath);
    if (!await packageDir.exists()) {
      throw ArgumentError('Package path does not exist: $packagePath');
    }

    final pubspecFile = File(p.join(packagePath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw ArgumentError('Package path does not contain a pubspec.yaml file: $packagePath');
    }

    Directory? tempDir;
    String analysisPath = packagePath;

    try {
      // If copyToTemp is true, copy the package to a temp directory and resolve dependencies
      if (copyToTemp) {
        print('Copying package to temporary directory...');
        tempDir = await Directory.systemTemp.createTemp('pkg_analysis_');

        // Copy the entire package to temp directory
        await _copyDirectory(packageDir, tempDir);
        analysisPath = tempDir.path;

        print('Running pub get to resolve dependencies...');
        final pubGetResult = await Process.run('dart', ['pub', 'get'], workingDirectory: analysisPath);

        if (pubGetResult.exitCode != 0) {
          print('Warning: pub get failed: ${pubGetResult.stderr}');
          print('Continuing with analysis, but some types may be unresolved.');
        } else {
          print('Dependencies resolved successfully.');
        }
      }

      // Resolve Dart SDK path
      final sdkPath = await _resolveDartSdkPath();

      // Create analysis context
      final collection = AnalysisContextCollection(includedPaths: [analysisPath], sdkPath: sdkPath);

      final result = <String, dynamic>{};

      // Find all public library files
      final libDir = Directory(p.join(analysisPath, 'lib'));
      if (!await libDir.exists()) {
        return result; // No lib directory, return empty result
      }

      // Get all top-level Dart files that export the public API, make sure to replace the temp path if used
      final exportingFiles = (await _getTopLevelExportingFiles(libDir, collection)).map((file) {
        if (tempDir != null) {
          return file.replaceFirst(tempDir.path, analysisPath);
        }
        return file;
      }).toList();

      for (final file in exportingFiles) {
        result[file] = {'classes': [], 'functions': []};
      }

      // Analyze each exporting file
      for (final filePath in exportingFiles) {
        final context = collection.contextFor(filePath);
        final session = context.currentSession;
        final resolvedResult = await session.getResolvedLibrary(filePath);
        if (resolvedResult is! ResolvedLibraryResult) {
          print('Warning: Could not resolve library for $filePath');
          continue;
        }

        final library = resolvedResult.element;
        final libraryApi = _extractLibraryApi(library);
        result[filePath] = libraryApi;
      }

      return result;
    } catch (e) {
      throw Exception('Failed to analyze package: $e');
    } finally {
      // Clean up temp directory if it was created
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// Returns a list of top-level Dart files that export the public API. This means
  /// they are in the 'lib' directory and include export directives.
  Future<List<String>> _getTopLevelExportingFiles(Directory libDir, AnalysisContextCollection collection) async {
    final exportingFiles = <String>[];

    await for (final entity in libDir.list(recursive: false, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart') && !p.basename(entity.path).startsWith("_")) {
        final context = collection.contextFor(entity.path);
        final session = context.currentSession;
        final result = await session.getResolvedLibrary(entity.path);

        if (result is ResolvedLibraryResult) {
          final libraryElement = result.element;

          // Check if the library has any export directives
          if (_isExportingLibrary(libraryElement)) {
            exportingFiles.add(entity.path);
          }
        }
      }
    }

    return exportingFiles;
  }

  bool _isExportingLibrary(LibraryElement library) {
    // A library is considered exporting if it has any export directives
    return library.exportedLibraries.isNotEmpty;
  }

  /// Copies a directory recursively.
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false)) {
      final name = p.basename(entity.path);

      // Skip .dart_tool and .packages as they'll be regenerated
      if (name == '.dart_tool' || name == '.packages') {
        continue;
      }

      if (entity is Directory) {
        final newDirectory = Directory(p.join(destination.path, name));
        await newDirectory.create(recursive: true);
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, name));
      }
    }
  }

  /// Resolves the Dart SDK path from the Flutter installation.
  ///
  /// Executes `which dart` to find the Dart executable, then derives the SDK path
  /// from the Flutter cache directory.
  Future<String> _resolveDartSdkPath() async {
    try {
      final result = await Process.run('which', ['dart']);

      if (result.exitCode != 0) {
        throw Exception('Failed to locate dart executable: ${result.stderr}');
      }

      final dartPath = (result.stdout as String).trim();

      // Convert path like /path/to/flutter/bin/dart
      // to /path/to/flutter/bin/cache/dart-sdk
      final dartFile = File(dartPath);
      final flutterBinDir = dartFile.parent;
      final sdkPath = p.join(flutterBinDir.path, 'cache', 'dart-sdk');

      // Verify the SDK path exists
      if (!await Directory(sdkPath).exists()) {
        throw Exception('Dart SDK not found at expected location: $sdkPath');
      }

      return sdkPath;
    } catch (e) {
      throw Exception('Failed to resolve Dart SDK path: $e');
    }
  }

  /// Extracts the public API from a library element.
  Map<String, dynamic> _extractLibraryApi(LibraryElement library) {
    final result = <String, dynamic>{};

    final classes = <Map<String, dynamic>>[];

    // Extract all top-level class declarations from all fragments
    for (final fragment in library.fragments) {
      for (final classFragment in fragment.classes) {
        final element = classFragment.element;
        // Only process public elements (not starting with underscore)
        if (element.name == null || element.name!.startsWith('_')) {
          continue;
        }

        classes.add(_extractClassApi(element));
      }
    }

    result['classes'] = classes;
    return result;
  }

  /// A distributing function that uses the appropriate extractor based on element type. Returns null for unsupported types.
  Map<String, dynamic>? _tryExtractElement(Element element) => switch (element) {
    ClassElement() => _extractClassApi(element),
    ConstructorElement() => _extractConstructorApi(element),
    TypeParameterElement() => _extractTypeParameterApi(element),
    ExecutableElement() => _extractMemberApi(element),
    _ => null, // Unsupported element type
  };

  /// Extracts API information from a type parameter.
  Map<String, dynamic> _extractTypeParameterApi(TypeParameterElement typeParam) => {
    'name': typeParam.name,
    'bound': typeParam.bound?.getDisplayString(),
  };

  /// Extracts the public API from a class element.
  Map<String, dynamic> _extractClassApi(ClassElement classElement) {
    final classData = <String, dynamic>{'name': classElement.name};

    // Add documentation if present
    if (classElement.documentationComment != null) {
      classData['documentation'] = classElement.documentationComment;
    }

    // Add type parameters for generic classes
    if (classElement.typeParameters.isNotEmpty) {
      classData['typeParameters'] = classElement.typeParameters.map(_extractTypeParameterApi).toList();
    }

    // Add superclass
    final supertype = classElement.supertype;
    if (supertype != null && !supertype.isDartCoreObject) {
      classData['superclass'] = _formatDartType(supertype);
    }

    // Add interfaces
    if (classElement.interfaces.isNotEmpty) {
      classData['interfaces'] = classElement.interfaces.map(_formatDartType).toList();
    }

    // Add mixins
    if (classElement.mixins.isNotEmpty) {
      classData['mixins'] = classElement.mixins.map(_formatDartType).toList();
    }

    // Extract all interface members (both declared and inherited)
    final members = <Map<String, dynamic>>[];

    // First, add constructors
    for (final constructor in classElement.constructors) {
      // Skip private constructors
      if (constructor.name != null && constructor.name!.startsWith('_')) {
        continue;
      }

      members.add(_extractConstructorApi(constructor));
    }

    // Get all members from the class interface (includes inherited members)
    // interfaceMembers is a Map<Name, ExecutableElement>
    for (final member in classElement.interfaceMembers.values) {
      // Skip private members
      final memberName = member.name;
      if (memberName == null || memberName.startsWith('_')) {
        continue;
      }

      members.add(_extractMemberApi(member));
    }

    classData['members'] = members;

    return classData;
  }

  /// Extracts API information from a class member.
  Map<String, dynamic> _extractMemberApi(ExecutableElement member) {
    final memberData = <String, dynamic>{'name': member.name};

    // Add source location if available
    final sourceUri = member.library.uri.toString();
    memberData['location'] = sourceUri;

    if (member is MethodElement) {
      memberData['kind'] = member.isOperator ? 'operator' : 'method';
      memberData['isStatic'] = member.isStatic;
      memberData['returnType'] = _formatDartType(member.returnType);

      if (member.formalParameters.isNotEmpty) {
        memberData['parameters'] = member.formalParameters.map((p) {
          return {
            'name': p.name,
            'type': _formatDartType(p.type),
            'isOptional': p.isOptional,
            'isNamed': p.isNamed,
            'hasDefaultValue': p.hasDefaultValue,
          };
        }).toList();
      }
    } else if (member is PropertyAccessorElement) {
      // Check if it's a getter or setter based on the element's kind
      final isGetter = member.kind == ElementKind.GETTER;
      memberData['kind'] = isGetter ? 'getter' : 'setter';
      memberData['isStatic'] = member.isStatic;

      if (isGetter) {
        memberData['returnType'] = _formatDartType(member.returnType);
      } else {
        memberData['parameterType'] = _formatDartType(member.formalParameters.first.type);
      }
    }

    return memberData;
  }

  /// Extracts API information from a constructor.
  Map<String, dynamic> _extractConstructorApi(ConstructorElement constructor) {
    // Constructor name without the class prefix (empty string for unnamed constructors)
    // Note: unnamed constructors may return 'new', so we normalize to empty string
    var constructorName = constructor.name ?? '';
    if (constructorName == 'new') {
      constructorName = '';
    }

    final constructorData = <String, dynamic>{'name': constructorName, 'kind': 'constructor'};

    // Add source location if available
    final sourceUri = constructor.library.uri.toString();
    constructorData['location'] = sourceUri;

    // Add parameters
    if (constructor.formalParameters.isNotEmpty) {
      constructorData['parameters'] = constructor.formalParameters.map((p) {
        return {
          'name': p.name,
          'type': _formatDartType(p.type),
          'isOptional': p.isOptional,
          'isNamed': p.isNamed,
          'hasDefaultValue': p.hasDefaultValue,
          'isRequired': p.isRequired,
        };
      }).toList();
    }

    return constructorData;
  }

  /// Formats a DartType into a string representation with type arguments.
  String _formatDartType(DartType type) {
    final displayString = type.getDisplayString();

    // If we got InvalidType, try to get more information
    if (displayString == 'InvalidType') {
      // Try to get the element name if available
      final element = type.element;
      if (element != null && element.name != null) {
        return element.name!;
      }

      // Log for debugging
      print('DEBUG: InvalidType encountered');
      print('  Type: $type');
      print('  Runtime type: ${type.runtimeType}');
      print('  Element: ${type.element}');

      return 'InvalidType';
    }

    return displayString;
  }
}
