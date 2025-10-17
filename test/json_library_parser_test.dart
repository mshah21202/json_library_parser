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

      expect(result.elements, isEmpty);
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

      expect(result.elements, isNotEmpty);

      final classes = result.elements.whereType<ClassElement>().toList();
      expect(classes, hasLength(2));

      // Find DerivedClass
      final derivedClass = classes.firstWhere((c) => c.name == 'DerivedClass');

      expect(derivedClass.name, equals('DerivedClass'));
      expect(derivedClass.superclass, equals('BaseClass'));

      // Check that members include both declared and inherited methods
      final members = derivedClass.members;
      final memberNames = members.map((m) => m.name).toSet();

      // Should have both declared members
      expect(memberNames, contains('derivedMethod'));
      expect(memberNames, contains('derivedProp'));

      // Should have inherited members from BaseClass
      expect(memberNames, contains('baseMethod'));
      expect(memberNames, contains('baseProp'));

      // Should NOT have inherited members from Object (like toString, hashCode) - dart:core members are excluded
      expect(memberNames, isNot(contains('toString')));
      expect(memberNames, isNot(contains('hashCode')));
      expect(memberNames, isNot(contains('noSuchMethod')));
      expect(memberNames, isNot(contains('runtimeType')));

      // Check member details
      final derivedMethodMember = members.firstWhere((m) => m.name == 'derivedMethod') as MethodMember;
      expect(derivedMethodMember.kind, equals('method'));
      expect(derivedMethodMember.isStatic, isFalse);
      expect(derivedMethodMember.returnType, equals('void'));

      final derivedPropMember = members.firstWhere((m) => m.name == 'derivedProp') as GetterMember;
      expect(derivedPropMember.kind, equals('getter'));
      expect(derivedPropMember.isStatic, isFalse);
      expect(derivedPropMember.returnType, equals('int'));
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

      final classes = result.elements.whereType<ClassElement>().toList();

      // Should only have PublicClass
      expect(classes, hasLength(1));
      expect(classes[0].name, equals('PublicClass'));

      // PublicClass should not have _privateMethod in interfaceMembers
      final members = classes[0].members;
      final memberNames = members.map((m) => m.name).toSet();
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

      // Should have elements with only public class
      expect(result.elements, isNotEmpty);

      final publicClass = result.elements.whereType<ClassElement>().firstWhere((e) => e.name == 'PublicClass');
      expect(publicClass.importableFrom, contains('package:test_package/public.dart'));

      // Should not contain PrivateClass
      expect(result.elements.any((e) => e.name == 'PrivateClass'), isFalse);
    });

    test('analyzes top-level variables with various modifiers', () async {
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

      // Create a test library with various top-level variables
      final testFile = File(p.join(libDir.path, 'variables.dart'));
      await testFile.writeAsString('''
/// A constant string value
const String apiKey = 'secret_key_123';

/// A final integer value
final int maxRetries = 3;

/// A late-initialized configuration
late String configPath;

/// A mutable counter
int counter = 0;

/// A constant list
const List<String> supportedFormats = ['json', 'xml', 'yaml'];

/// A final map
final Map<String, dynamic> defaultSettings = {'timeout': 30, 'retries': 3};

// Private variable should not be exposed
const String _privateKey = 'hidden';

/// A late final variable
late final String computedValue;
''');

      final result = await analyzer.analyzePackage(tempDir!.path);

      expect(result.elements, isNotEmpty);

      final variables = result.elements.whereType<VariableElement>().toList();

      // Should have 7 public variables (excluding _privateKey)
      expect(variables, hasLength(7));

      // Test const string variable
      final apiKey = variables.firstWhere((v) => v.name == 'apiKey');
      expect(apiKey.type, equals('String'));
      expect(apiKey.isConst, isTrue);
      expect(apiKey.isFinal, isFalse);
      expect(apiKey.isLate, isFalse);
      expect(apiKey.documentation, isNotNull);
      expect(apiKey.documentation, contains('A constant string value'));
      expect(apiKey.importableFrom, isList);
      expect(apiKey.importableFrom, contains('package:test_package/variables.dart'));
      expect(apiKey.definedIn, isNotNull);

      // Test final integer variable
      final maxRetries = variables.firstWhere((v) => v.name == 'maxRetries');
      expect(maxRetries.type, equals('int'));
      expect(maxRetries.isConst, isFalse);
      expect(maxRetries.isFinal, isTrue);
      expect(maxRetries.isLate, isFalse);
      expect(maxRetries.documentation, contains('A final integer value'));

      // Test late variable
      final configPath = variables.firstWhere((v) => v.name == 'configPath');
      expect(configPath.type, equals('String'));
      expect(configPath.isConst, isFalse);
      expect(configPath.isFinal, isFalse);
      expect(configPath.isLate, isTrue);
      expect(configPath.documentation, contains('A late-initialized configuration'));

      // Test mutable variable
      final counter = variables.firstWhere((v) => v.name == 'counter');
      expect(counter.type, equals('int'));
      expect(counter.isConst, isFalse);
      expect(counter.isFinal, isFalse);
      expect(counter.isLate, isFalse);
      expect(counter.documentation, contains('A mutable counter'));

      // Test const list with generic type
      final supportedFormats = variables.firstWhere((v) => v.name == 'supportedFormats');
      expect(supportedFormats.type, equals('List<String>'));
      expect(supportedFormats.isConst, isTrue);
      expect(supportedFormats.isFinal, isFalse);
      expect(supportedFormats.isLate, isFalse);

      // Test final map with generic type
      final defaultSettings = variables.firstWhere((v) => v.name == 'defaultSettings');
      expect(defaultSettings.type, equals('Map<String, dynamic>'));
      expect(defaultSettings.isConst, isFalse);
      expect(defaultSettings.isFinal, isTrue);
      expect(defaultSettings.isLate, isFalse);

      // Test late final variable
      final computedValue = variables.firstWhere((v) => v.name == 'computedValue');
      expect(computedValue.type, equals('String'));
      expect(computedValue.isConst, isFalse);
      expect(computedValue.isFinal, isTrue);
      expect(computedValue.isLate, isTrue);
      expect(computedValue.documentation, contains('A late final variable'));

      // Ensure private variable is not included
      expect(variables.any((v) => v.name == '_privateKey'), isFalse);
    });
  });
}
