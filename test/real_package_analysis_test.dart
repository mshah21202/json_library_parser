import 'dart:convert';
import 'dart:io';
import 'package:json_library_parser/json_library_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Real Package Analysis', () {
    test('analyzes a real package and writes prettified JSON to file', () async {
      final analyzer = PackageApiAnalyzer();

      // Package in .pub-cache (read-only)
      const packagePath = '/Users/mohamadshahin/.pub-cache/hosted/pub.dev/shopify_flutter-2.6.0';
      const outputPath = 'analysis_output.json';

      print('\n${'=' * 80}');
      print('Analyzing package at: $packagePath');
      print('Using copyToTemp: true to resolve dependencies');
      print('=' * 80 + '\n');

      // Use copyToTemp=true to copy the package to a temp directory and run pub get
      final result = await analyzer.analyzePackage(packagePath, copyToTemp: true);

      // Convert to prettified JSON
      const encoder = JsonEncoder.withIndent('  ');
      final prettyJson = encoder.convert(result);

      // Write to file
      final outputFile = File(outputPath);
      await outputFile.writeAsString(prettyJson);

      print('\nAnalysis complete!');
      print('Result written to: ${outputFile.absolute.path}');

      // Count InvalidType occurrences
      final invalidTypeCount = prettyJson.split('"InvalidType"').length - 1;
      print('InvalidType occurrences: $invalidTypeCount');
      print('=' * 80 + '\n');

      // Basic assertion to ensure we got some result
      expect(result, isNotEmpty);
      expect(outputFile.existsSync(), isTrue);
    });
  });
}
