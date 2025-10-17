import 'dart:convert';
import 'package:json_library_parser/json_library_parser.dart';

Future<void> main() async {
  final analyzer = PackageApiAnalyzer();

  // Analyze the current package
  final packagePath = '.';

  try {
    print('Analyzing package at: $packagePath');
    final result = await analyzer.analyzePackage(packagePath);

    // Print analysis summary
    print('\n=== Analysis Summary ===');
    print('Total elements: ${result.elements.length}');
    print('Classes: ${result.elements.whereType<ClassElement>().length}');
    print('Enums: ${result.elements.whereType<EnumElement>().length}');
    print('Functions: ${result.elements.whereType<FunctionElement>().length}');
    print('Variables: ${result.elements.whereType<VariableElement>().length}');

    // Example: Print all class names
    print('\n=== Classes ===');
    for (final classElement in result.elements.whereType<ClassElement>()) {
      print('- ${classElement.name}');
      print('  Members: ${classElement.members.length}');
      if (classElement.superclass != null) {
        print('  Extends: ${classElement.superclass}');
      }
    }

    // Convert to JSON if needed
    final jsonString = JsonEncoder.withIndent('  ').convert(result.toJson());
    print('\n=== JSON Output (truncated) ===');
    print(jsonString.substring(0, jsonString.length > 500 ? 500 : jsonString.length));
    if (jsonString.length > 500) print('...(truncated)');
  } catch (e) {
    print('Error analyzing package: $e');
  }
}
