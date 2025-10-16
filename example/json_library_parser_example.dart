import 'dart:convert';
import 'package:json_library_parser/json_library_parser.dart';

Future<void> main() async {
  final analyzer = PackageApiAnalyzer();

  // Analyze the current package
  final packagePath = '.';

  try {
    print('Analyzing package at: $packagePath');
    final result = await analyzer.analyzePackage(packagePath);

    // Pretty print the JSON result
    final jsonString = JsonEncoder.withIndent('  ').convert(result);
    print('\nPackage API Analysis Result:');
    print(jsonString);
  } catch (e) {
    print('Error analyzing package: $e');
  }
}
