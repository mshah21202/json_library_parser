import 'dart:io';

import 'package:json_library_parser/json_library_parser.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PackageApiAnalyzer', () {
    Directory? tempDir;
    late PackageApiAnalyzer analyzer;

    setUp(() {
      analyzer = PackageApiAnalyzer();
    });

    tearDown(() async {
      if (tempDir != null && tempDir!.existsSync()) {
        await tempDir!.delete(recursive: true);
      }
    });

    test('throws ArgumentError when package path does not exist', () async {
      expect(() => analyzer.analyzePackage('/non/existent/path'), throwsA(isA<ArgumentError>()));
    });

    test('throws ArgumentError when pubspec.yaml is missing', () async {
      tempDir = await Directory.systemTemp.createTemp('test_package_');

      expect(() => analyzer.analyzePackage(tempDir!.path), throwsA(isA<ArgumentError>()));
    });

    test('returns empty result when lib directory does not exist', () async {
      tempDir = await Directory.systemTemp.createTemp('test_package_');
      final pubspecFile = File(p.join(tempDir!.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('name: test_package\n');

      final result = await analyzer.analyzePackage(tempDir!.path);

      expect(result, isEmpty);
    });

    test('analyzes a simple class with inherited members', () async {
      tempDir = await Directory.systemTemp.createTemp('test_package_');

      // Create pubspec.yaml
      final pubspecFile = File(p.join(tempDir!.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test_package
environment:
  sdk: ^3.0.0
''');

      // Create lib directory
      final libDir = Directory(p.join(tempDir!.path, 'lib'));
      await libDir.create();

      // Create a test library with inheritance
      final testFile = File(p.join(libDir.path, 'test.dart'));
      await testFile.writeAsString('''
/// A base class with some methods
class BaseClass {
  /// A method in the base class
  void baseMethod() {}
  
  /// A getter in the base class
  String get baseProp => 'base';
}

/// A derived class that extends BaseClass
class DerivedClass extends BaseClass {
  /// A method in the derived class
  void derivedMethod() {}
  
  /// A getter in the derived class
  int get derivedProp => 42;
}
''');

      final result = await analyzer.analyzePackage(tempDir!.path);

      expect(result, isNotEmpty);
      expect(result, contains('lib/test.dart'));

      final libraryData = result['lib/test.dart'] as Map<String, dynamic>;
      expect(libraryData, contains('classes'));

      final classes = libraryData['classes'] as List;
      expect(classes, hasLength(2));

      // Find DerivedClass
      final derivedClass = classes.firstWhere((c) => c['name'] == 'DerivedClass') as Map<String, dynamic>;

      expect(derivedClass['name'], equals('DerivedClass'));
      expect(derivedClass['superclass'], equals('BaseClass'));

      // Check that members include both declared and inherited methods
      final members = derivedClass['members'] as List;
      final memberNames = members.map((m) => m['name']).toSet();

      // Should have both declared members
      expect(memberNames, contains('derivedMethod'));
      expect(memberNames, contains('derivedProp'));

      // Should have inherited members from BaseClass
      expect(memberNames, contains('baseMethod'));
      expect(memberNames, contains('baseProp'));

      // Should have inherited members from Object (like toString, hashCode)
      expect(memberNames, contains('toString'));
      expect(memberNames, contains('hashCode'));

      // Check member details
      final derivedMethodMember = members.firstWhere((m) => m['name'] == 'derivedMethod') as Map<String, dynamic>;
      expect(derivedMethodMember['kind'], equals('method'));
      expect(derivedMethodMember['isStatic'], isFalse);
      expect(derivedMethodMember['returnType'], equals('void'));

      final derivedPropMember = members.firstWhere((m) => m['name'] == 'derivedProp') as Map<String, dynamic>;
      expect(derivedPropMember['kind'], equals('getter'));
      expect(derivedPropMember['isStatic'], isFalse);
      expect(derivedPropMember['returnType'], equals('int'));
    });

    test('excludes private classes and members', () async {
      tempDir = await Directory.systemTemp.createTemp('test_package_');

      // Create pubspec.yaml
      final pubspecFile = File(p.join(tempDir!.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test_package
environment:
  sdk: ^3.0.0
''');

      // Create lib directory
      final libDir = Directory(p.join(tempDir!.path, 'lib'));
      await libDir.create();

      // Create a test library with private elements
      final testFile = File(p.join(libDir.path, 'test.dart'));
      await testFile.writeAsString('''
class PublicClass {
  void publicMethod() {}
  void _privateMethod() {}
}

class _PrivateClass {
  void someMethod() {}
}
''');

      final result = await analyzer.analyzePackage(tempDir!.path);

      final libraryData = result['lib/test.dart'] as Map<String, dynamic>;
      final classes = libraryData['classes'] as List;

      // Should only have PublicClass
      expect(classes, hasLength(1));
      expect(classes[0]['name'], equals('PublicClass'));

      // PublicClass should not have _privateMethod in interfaceMembers
      final members = classes[0]['members'] as List;
      final memberNames = members.map((m) => m['name']).toSet();
      expect(memberNames, contains('publicMethod'));
      expect(memberNames, isNot(contains('_privateMethod')));
    });

    test('excludes files in lib/src/', () async {
      tempDir = await Directory.systemTemp.createTemp('test_package_');

      // Create pubspec.yaml
      final pubspecFile = File(p.join(tempDir!.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test_package
environment:
  sdk: ^3.0.0
''');

      // Create lib and lib/src directories
      final libDir = Directory(p.join(tempDir!.path, 'lib'));
      await libDir.create();
      final srcDir = Directory(p.join(libDir.path, 'src'));
      await srcDir.create();

      // Create public library
      final publicFile = File(p.join(libDir.path, 'public.dart'));
      await publicFile.writeAsString('class PublicClass {}');

      // Create private library in src
      final privateFile = File(p.join(srcDir.path, 'private.dart'));
      await privateFile.writeAsString('class PrivateClass {}');

      final result = await analyzer.analyzePackage(tempDir!.path);

      // Should only contain the public library
      expect(result, hasLength(1));
      expect(result, contains('lib/public.dart'));
      expect(result, isNot(contains('lib/src/private.dart')));
    });
  });
}
