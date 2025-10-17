import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as p;

import 'models.dart' as models;

/// Analyzes Dart packages and extracts their public API surface.
class PackageApiAnalyzer {
  /// Analyzes a Dart package and returns its public API.
  ///
  /// [packagePath] should be the root directory of the package to analyze.
  /// The package must contain a `pubspec.yaml` file.
  ///
  /// [copyToTemp] if true, copies the package to a temporary directory and
  /// runs `pub get` to ensure all dependencies are resolved. This is useful
  /// for packages in `.pub-cache` or read-only locations. Defaults to false.
  ///
  /// Returns a [models.PackageAnalysisResult] containing all public API elements.
  /// The result includes:
  /// - Classes with members, inheritance, and type parameters
  /// - Enums with their values and members
  /// - Top-level functions with parameters and return types
  /// - Top-level variables with their types and modifiers
  ///
  /// Each element includes metadata about where it can be imported from
  /// (`importableFrom`) and where it's defined (`definedIn`).
  ///
  /// Throws [ArgumentError] if the package path is invalid or doesn't contain
  /// a pubspec.yaml file.
  Future<models.PackageAnalysisResult> analyzePackage(String packagePath, {bool copyToTemp = false}) async {
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
        return models.PackageAnalysisResult(elements: []); // No lib directory, return empty result
      }

      // Read pubspec.yaml to get package name
      final pubspecContent = await pubspecFile.readAsString();
      final packageName = _extractPackageName(pubspecContent);

      // Find all public library files (exclude lib/src/** at any level)
      final publicLibraryFiles = await _findPublicLibraries(libDir);

      if (publicLibraryFiles.isEmpty) {
        return models.PackageAnalysisResult(elements: []); // No public libraries found
      }

      // Map to track which elements are exported by which package URIs
      // Key: Element object, Value: Set of package URIs that export this element
      final elementToUris = <Element, Set<String>>{};

      // Process each public library
      for (final libraryFile in publicLibraryFiles) {
        final context = collection.contextFor(libraryFile.path);
        final session = context.currentSession;
        final libraryResult = await session.getResolvedLibrary(libraryFile.path);

        if (libraryResult is! ResolvedLibraryResult) {
          print('Warning: Failed to resolve library: ${libraryFile.path}');
          continue;
        }

        final libraryElement = libraryResult.element;
        final exportNamespace = libraryElement.exportNamespace;

        // Construct package URI for this library
        final relativePath = p.relative(libraryFile.path, from: libDir.path);
        final packageUri = 'package:$packageName/$relativePath';

        // Iterate through all elements in the export namespace
        for (final entry in exportNamespace.definedNames2.entries) {
          final elementName = entry.key;
          final element = entry.value;

          // Skip private elements
          if (elementName.startsWith('_')) {
            continue;
          }

          // Track which package URIs export this element
          elementToUris.putIfAbsent(element, () => <String>{}).add(packageUri);
        }
      }

      // Build the final result structure
      // Group elements and add importableFrom/definedIn metadata
      final elementsData = <Map<String, dynamic>>[];

      // Track variables we've already processed to avoid duplicates
      final processedVariables = <TopLevelVariableElement>{};

      for (final entry in elementToUris.entries) {
        final element = entry.key;
        final importableFromUris = entry.value.toList()..sort();

        Map<String, dynamic>? elementData;

        if (element is ClassElement) {
          elementData = _extractClassApi(element);
          elementData['elementType'] = 'class';
        } else if (element is EnumElement) {
          elementData = _extractEnumApi(element);
          elementData['elementType'] = 'enum';
        } else if (element is TopLevelVariableElement) {
          elementData = _extractTopLevelVariableApi(element);
          elementData['elementType'] = 'variable';
          processedVariables.add(element);
        } else if (element is TopLevelFunctionElement) {
          elementData = _extractFunctionApi(element);
          elementData['elementType'] = 'function';
        } else if (element is PropertyAccessorElement) {
          // Top-level getters/setters for variables - extract the variable element
          final variable = element.variable;
          if (variable is TopLevelVariableElement && !processedVariables.contains(variable)) {
            elementData = _extractTopLevelVariableApi(variable);
            elementData['elementType'] = 'variable';
            processedVariables.add(variable);

            // Update the URIs to point to the variable's URIs (from the accessor)
            elementData['importableFrom'] = importableFromUris;
            elementData['definedIn'] = variable.library.uri.toString();
            elementsData.add(elementData);
            continue;
          } else {
            // Skip if already processed or not a top-level variable
            continue;
          }
        }

        if (elementData != null) {
          elementData['importableFrom'] = importableFromUris;
          elementData['definedIn'] = element.library?.uri.toString() ?? 'unknown';
          elementsData.add(elementData);
        }
      }

      result['elements'] = elementsData;

      // Convert the raw JSON to models
      return models.PackageAnalysisResult.fromJson(result);
    } catch (e) {
      throw Exception('Failed to analyze package: $e');
    } finally {
      // Clean up temp directory if it was created
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  String _extractPackageName(String pubspecContent) {
    final nameRegex = RegExp(r'^name:\s*(.+)$', multiLine: true);
    final match = nameRegex.firstMatch(pubspecContent);
    if (match == null) {
      throw ArgumentError('Package name not found in pubspec.yaml');
    }
    return match.group(1)!.trim();
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

  /// Finds all public library files in the lib directory.
  ///
  /// A library is considered public if its path does not contain 'src' as a
  /// directory component at any level. This properly excludes files in lib/src/,
  /// lib/foo/src/, etc.
  Future<List<File>> _findPublicLibraries(Directory libDir) async {
    final publicLibraries = <File>[];

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Get the relative path from lib directory
        final relativePath = p.relative(entity.path, from: libDir.path);

        // Split the path into components and check if any component is 'src'
        final pathParts = p.split(relativePath);

        // Exclude if 'src' appears as a directory component (not in the filename)
        // Check all parts except the last one (the filename)
        var containsSrc = false;
        for (var i = 0; i < pathParts.length - 1; i++) {
          if (pathParts[i] == 'src') {
            containsSrc = true;
            break;
          }
        }

        if (!containsSrc) {
          publicLibraries.add(entity);
        }
      }
    }

    return publicLibraries;
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

  /// Extracts the public API from a class element.
  Map<String, dynamic> _extractClassApi(ClassElement classElement) {
    final classData = <String, dynamic>{'name': classElement.name};

    // Add documentation if present
    if (classElement.documentationComment != null) {
      classData['documentation'] = classElement.documentationComment;
    }

    // Add type parameters for generic classes
    if (classElement.typeParameters.isNotEmpty) {
      classData['typeParameters'] = classElement.typeParameters
          .map((tp) => {'name': tp.name, 'bound': tp.bound?.getDisplayString()})
          .toList();
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

    // Extract all members from children
    final members = <Map<String, dynamic>>[];

    // Maps to track fields and their accessors
    final fieldElements = <String, FieldElement>{};
    final getters = <String, PropertyAccessorElement>{};
    final setters = <String, PropertyAccessorElement>{};
    final otherMembers = <Element>[];

    // First pass: categorize all children (declared members only)
    for (final child in classElement.children) {
      // Skip private members
      final childName = child.name;
      if (childName == null || childName.startsWith('_')) {
        continue;
      }

      // Skip members from dart:core
      final sourceUri = child.library?.uri.toString();
      if (sourceUri == 'dart:core') {
        continue;
      }

      if (child is FieldElement) {
        fieldElements[childName] = child;
      } else if (child is PropertyAccessorElement) {
        if (child.kind == ElementKind.GETTER) {
          getters[childName] = child;
        } else if (child.kind == ElementKind.SETTER) {
          // Setter names end with '=', remove it for matching
          final baseName = childName.endsWith('=') ? childName.substring(0, childName.length - 1) : childName;
          setters[baseName] = child;
        }
      } else {
        otherMembers.add(child);
      }
    }

    // Second pass: apply field rules and extract members
    // Process constructors first
    for (final member in otherMembers) {
      if (member is ConstructorElement) {
        members.add(_extractConstructorApi(member));
      }
    }

    // Track which members we've already processed
    final processedMemberNames = <String>{};

    // Process fields with their accessors (declared members only)
    final processedFields = <String>{};
    for (final entry in fieldElements.entries) {
      final fieldName = entry.key;
      final field = entry.value;

      final hasGetter = getters.containsKey(fieldName);
      final hasSetter = setters.containsKey(fieldName);

      if (hasGetter && hasSetter) {
        // Rule 1: Field has both getter and setter -> keep as field
        members.add(_extractFieldApi(field));
        processedFields.add(fieldName);
        processedMemberNames.add(fieldName);
      } else if (hasGetter) {
        // Rule 2: Field has only getter -> treat as getter, skip field
        members.add(_extractAccessorApi(getters[fieldName]!));
        processedFields.add(fieldName);
        processedMemberNames.add(fieldName);
      } else if (hasSetter) {
        // Rule 2: Field has only setter -> treat as setter, skip field
        members.add(_extractAccessorApi(setters[fieldName]!));
        processedFields.add(fieldName);
        processedMemberNames.add(fieldName);
      } else {
        // Field with no accessors (shouldn't normally happen, but handle it)
        members.add(_extractFieldApi(field));
        processedFields.add(fieldName);
        processedMemberNames.add(fieldName);
      }
    }

    // Add standalone getters/setters (those without corresponding fields)
    for (final entry in getters.entries) {
      if (!processedFields.contains(entry.key)) {
        members.add(_extractAccessorApi(entry.value));
        processedMemberNames.add(entry.key);
      }
    }

    for (final entry in setters.entries) {
      if (!processedFields.contains(entry.key)) {
        members.add(_extractAccessorApi(entry.value));
        processedMemberNames.add(entry.key);
      }
    }

    // Process other declared members (methods, etc.)
    for (final member in otherMembers) {
      if (member is! ConstructorElement) {
        if (member is MethodElement) {
          members.add(_extractMethodApi(member));
          if (member.name != null) {
            processedMemberNames.add(member.name!);
          }
        }
      }
    }

    // Now add inherited members from interfaceMembers (exclude already processed declared members)
    for (final member in classElement.interfaceMembers.values) {
      // Skip private members
      final memberName = member.name;
      if (memberName == null || memberName.startsWith('_')) {
        continue;
      }

      // Skip members from dart:core
      final sourceUri = member.library.uri.toString();
      if (sourceUri == 'dart:core') {
        continue;
      }

      // Skip if we already processed this member from children (it's declared, not inherited)
      if (processedMemberNames.contains(memberName)) {
        continue;
      }

      // This is an inherited member, extract it
      members.add(_extractMemberApi(member));
    }

    classData['members'] = members;

    return classData;
  }

  /// Extracts API information from a field element.
  Map<String, dynamic> _extractFieldApi(FieldElement field) {
    final fieldData = <String, dynamic>{
      'name': field.name,
      'kind': 'field',
      'type': _formatDartType(field.type),
      'isStatic': field.isStatic,
    };

    // Add source location if available
    final sourceUri = field.library.uri.toString();
    fieldData['location'] = sourceUri;

    // Add modifiers
    if (field.isFinal) {
      fieldData['isFinal'] = true;
    }
    if (field.isLate) {
      fieldData['isLate'] = true;
    }
    if (field.isConst) {
      fieldData['isConst'] = true;
    }

    return fieldData;
  }

  /// Extracts API information from a property accessor (getter or setter).
  Map<String, dynamic> _extractAccessorApi(PropertyAccessorElement accessor) {
    final isGetter = accessor.kind == ElementKind.GETTER;
    final accessorData = <String, dynamic>{'name': accessor.name, 'kind': isGetter ? 'getter' : 'setter', 'isStatic': accessor.isStatic};

    // Add source location if available
    final sourceUri = accessor.library.uri.toString();
    accessorData['location'] = sourceUri;

    if (isGetter) {
      accessorData['returnType'] = _formatDartType(accessor.returnType);
    } else {
      // Setter has a single parameter
      if (accessor.formalParameters.isNotEmpty) {
        accessorData['parameterType'] = _formatDartType(accessor.formalParameters.first.type);
      }
    }

    return accessorData;
  }

  /// Extracts API information from a method element.
  Map<String, dynamic> _extractMethodApi(MethodElement method) {
    final methodData = <String, dynamic>{
      'name': method.name,
      'kind': method.isOperator ? 'operator' : 'method',
      'isStatic': method.isStatic,
      'returnType': _formatDartType(method.returnType),
    };

    // Add source location if available
    final sourceUri = method.library.uri.toString();
    methodData['location'] = sourceUri;

    // Add parameters
    if (method.formalParameters.isNotEmpty) {
      methodData['parameters'] = method.formalParameters.map((p) {
        return {
          'name': p.name,
          'type': _formatDartType(p.type),
          'isOptional': p.isOptional,
          'isNamed': p.isNamed,
          'hasDefaultValue': p.hasDefaultValue,
        };
      }).toList();
    }

    // Add type parameters for generic methods
    if (method.typeParameters.isNotEmpty) {
      methodData['typeParameters'] = method.typeParameters.map((tp) => {'name': tp.name, 'bound': tp.bound?.getDisplayString()}).toList();
    }

    return methodData;
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

  /// Extracts the public API from an enum element.
  Map<String, dynamic> _extractEnumApi(EnumElement enumElement) {
    final enumData = <String, dynamic>{'name': enumElement.name};

    // Add documentation if present
    if (enumElement.documentationComment != null) {
      enumData['documentation'] = enumElement.documentationComment;
    }

    // Add enum values
    final values = <Map<String, dynamic>>[];
    for (final field in enumElement.fields) {
      // Only include enum constant values, not synthetic fields
      if (field.isEnumConstant) {
        values.add({'name': field.name, if (field.documentationComment != null) 'documentation': field.documentationComment});
      }
    }
    enumData['values'] = values;

    // Extract members (methods, getters, etc.) similar to classes
    final members = <Map<String, dynamic>>[];

    // Add constructors
    for (final constructor in enumElement.constructors) {
      // Skip private and synthetic constructors
      if (constructor.name != null && constructor.name!.startsWith('_')) {
        continue;
      }
      if (constructor.isSynthetic) {
        continue;
      }

      members.add(_extractConstructorApi(constructor));
    }

    // Get all members from the enum interface
    for (final member in enumElement.interfaceMembers.values) {
      // Skip private members
      final memberName = member.name;
      if (memberName == null || memberName.startsWith('_')) {
        continue;
      }

      // Skip members from dart:core
      final sourceUri = member.library.uri.toString();
      if (sourceUri == 'dart:core') {
        continue;
      }

      members.add(_extractMemberApi(member));
    }

    if (members.isNotEmpty) {
      enumData['members'] = members;
    }

    // Add interfaces
    if (enumElement.interfaces.isNotEmpty) {
      enumData['interfaces'] = enumElement.interfaces.map(_formatDartType).toList();
    }

    // Add mixins
    if (enumElement.mixins.isNotEmpty) {
      enumData['mixins'] = enumElement.mixins.map(_formatDartType).toList();
    }

    return enumData;
  }

  /// Extracts the public API from a top-level variable element.
  Map<String, dynamic> _extractTopLevelVariableApi(TopLevelVariableElement variable) {
    final variableData = <String, dynamic>{'name': variable.name, 'type': _formatDartType(variable.type)};

    // Add documentation if present
    if (variable.documentationComment != null) {
      variableData['documentation'] = variable.documentationComment;
    }

    variableData['isConst'] = variable.isConst;
    variableData['isFinal'] = variable.isFinal;
    variableData['isLate'] = variable.isLate;

    return variableData;
  }

  /// Extracts the public API from a top-level function element.
  Map<String, dynamic> _extractFunctionApi(TopLevelFunctionElement function) {
    final functionData = <String, dynamic>{'name': function.name, 'returnType': _formatDartType(function.returnType)};

    // Add documentation if present
    if (function.documentationComment != null) {
      functionData['documentation'] = function.documentationComment;
    }

    // Add type parameters for generic functions
    if (function.typeParameters.isNotEmpty) {
      functionData['typeParameters'] = function.typeParameters
          .map((tp) => {'name': tp.name, 'bound': tp.bound?.getDisplayString()})
          .toList();
    }

    // Add parameters
    if (function.formalParameters.isNotEmpty) {
      functionData['parameters'] = function.formalParameters.map((p) {
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

    return functionData;
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
