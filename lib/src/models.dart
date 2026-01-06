/// Models representing the analyzed API elements.
library;

/// Base class for all API elements.
sealed class ApiElement {
  /// The name of the element.
  final String name;

  /// The type of the element (class, enum, function, variable).
  final String elementType;

  /// Package URIs that export this element (what users should import).
  final List<String> importableFrom;

  /// Source file URI where element is defined (often in lib/src/).
  final String definedIn;

  /// Documentation comment for this element.
  final String? documentation;

  const ApiElement({
    required this.name,
    required this.elementType,
    required this.importableFrom,
    required this.definedIn,
    this.documentation,
  });

  /// Converts this element to JSON.
  Map<String, dynamic> toJson();

  /// Creates an ApiElement from JSON.
  factory ApiElement.fromJson(Map<String, dynamic> json) {
    final elementType = json['elementType'] as String;
    return switch (elementType) {
      'class' => ClassElement.fromJson(json),
      'enum' => EnumElement.fromJson(json),
      'function' => FunctionElement.fromJson(json),
      'variable' => VariableElement.fromJson(json),
      'extension' => ExtensionElement.fromJson(json),
      _ => throw ArgumentError('Unknown element type: $elementType'),
    };
  }
}

/// Represents a class in the analyzed package.
class ClassElement extends ApiElement {
  /// Type parameters for generic classes.
  final List<TypeParameter>? typeParameters;

  /// The inheritance chain (list of superclasses, excluding Object).
  /// For example, if a class extends StatelessWidget, this would be
  /// [StatelessWidget, Widget] showing the full inheritance chain.
  final List<String>? superclass;
  final List<Type>? superclassRef;

  /// Interfaces implemented by this class.
  final List<String>? interfaces;
  final List<Type>? interfacesRef;

  /// Mixins used by this class.
  final List<String>? mixins;
  final List<Type>? mixinsRef;

  /// Whether this class is abstract.
  final bool isAbstract;

  /// Members of this class (constructors, methods, getters, setters).
  final List<MemberElement> members;

  const ClassElement({
    required super.name,
    required super.importableFrom,
    required super.definedIn,
    super.documentation,
    this.typeParameters,
    this.superclass,
    this.superclassRef,
    this.interfaces,
    this.interfacesRef,
    this.mixins,
    this.mixinsRef,
    required this.isAbstract,
    required this.members,
  }) : super(elementType: 'class');

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'elementType': elementType,
    if (documentation != null) 'documentation': documentation,
    if (typeParameters != null && typeParameters!.isNotEmpty) 'typeParameters': typeParameters!.map((tp) => tp.toJson()).toList(),
    if (superclass != null) 'superclass': superclass,
    if (interfaces != null && interfaces!.isNotEmpty) 'interfaces': interfaces,
    if (mixins != null && mixins!.isNotEmpty) 'mixins': mixins,
    'isAbstract': isAbstract,
    'members': members.map((m) => m.toJson()).toList(),
    'importableFrom': importableFrom,
    'definedIn': definedIn,
    if (superclassRef != null && superclassRef!.isNotEmpty) 'superclassRef': superclassRef!.map((s) => s.toJson()).toList(),
    if (interfacesRef != null && interfacesRef!.isNotEmpty) 'interfacesRef': interfacesRef!.map((i) => i.toJson()).toList(),
    if (mixinsRef != null && mixinsRef!.isNotEmpty) 'mixinsRef': mixinsRef!.map((m) => m.toJson()).toList(),
  };

  factory ClassElement.fromJson(Map<String, dynamic> json) => ClassElement(
    name: json['name'] as String,
    importableFrom: (json['importableFrom'] as List).cast<String>(),
    definedIn: json['definedIn'] as String,
    documentation: json['documentation'] as String?,
    typeParameters: (json['typeParameters'] as List?)?.map((tp) => TypeParameter.fromJson(tp as Map<String, dynamic>)).toList(),
    superclass: (json['superclass'] as List?)?.cast<String>(),
    interfaces: (json['interfaces'] as List?)?.cast<String>(),
    mixins: (json['mixins'] as List?)?.cast<String>(),
    isAbstract: json['isAbstract'] as bool? ?? false,
    members: (json['members'] as List).map((m) => MemberElement.fromJson(m as Map<String, dynamic>)).toList(),
    superclassRef: (json['superclassRef'] as List?)?.map((s) => Type.fromJson(s as Map<String, dynamic>)).toList(),
    interfacesRef: (json['interfacesRef'] as List?)?.map((i) => Type.fromJson(i as Map<String, dynamic>)).toList(),
    mixinsRef: (json['mixinsRef'] as List?)?.map((m) => Type.fromJson(m as Map<String, dynamic>)).toList(),
  );
}

/// Represents an enum in the analyzed package.
class EnumElement extends ApiElement {
  /// The enum values.
  final List<EnumValue> values;

  /// Members of this enum (methods, getters, setters, constructors).
  final List<MemberElement>? members;

  /// Interfaces implemented by this enum.
  final List<String>? interfaces;
  final List<Type>? interfacesRef;

  /// Mixins used by this enum.
  final List<String>? mixins;
  final List<Type>? mixinsRef;

  const EnumElement({
    required super.name,
    required super.importableFrom,
    required super.definedIn,
    super.documentation,
    required this.values,
    this.members,
    this.interfaces,
    this.interfacesRef,
    this.mixins,
    this.mixinsRef,
  }) : super(elementType: 'enum');

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'elementType': elementType,
    if (documentation != null) 'documentation': documentation,
    'values': values.map((v) => v.toJson()).toList(),
    if (members != null && members!.isNotEmpty) 'members': members!.map((m) => m.toJson()).toList(),
    if (interfaces != null && interfaces!.isNotEmpty) 'interfaces': interfaces,
    if (mixins != null && mixins!.isNotEmpty) 'mixins': mixins,
    'importableFrom': importableFrom,
    'definedIn': definedIn,
    if (interfacesRef != null && interfacesRef!.isNotEmpty) 'interfacesRef': interfacesRef!.map((i) => i.toJson()).toList(),
    if (mixinsRef != null && mixinsRef!.isNotEmpty) 'mixinsRef': mixinsRef!.map((m) => m.toJson()).toList(),
  };

  factory EnumElement.fromJson(Map<String, dynamic> json) => EnumElement(
    name: json['name'] as String,
    importableFrom: (json['importableFrom'] as List).cast<String>(),
    definedIn: json['definedIn'] as String,
    documentation: json['documentation'] as String?,
    values: (json['values'] as List).map((v) => EnumValue.fromJson(v as Map<String, dynamic>)).toList(),
    members: (json['members'] as List?)?.map((m) => MemberElement.fromJson(m as Map<String, dynamic>)).toList(),
    interfaces: (json['interfaces'] as List?)?.cast<String>(),
    mixins: (json['mixins'] as List?)?.cast<String>(),
    interfacesRef: (json['interfacesRef'] as List?)?.map((i) => Type.fromJson(i as Map<String, dynamic>)).toList(),
    mixinsRef: (json['mixinsRef'] as List?)?.map((m) => Type.fromJson(m as Map<String, dynamic>)).toList(),
  );
}

/// Represents a top-level function in the analyzed package.
class FunctionElement extends ApiElement {
  /// Return type of the function.
  final String returnType;
  final Type? returnTypeRef;

  /// Type parameters for generic functions.
  final List<TypeParameter>? typeParameters;

  /// Function parameters.
  final List<Parameter>? parameters;

  const FunctionElement({
    required super.name,
    required super.importableFrom,
    required super.definedIn,
    super.documentation,
    required this.returnType,
    this.returnTypeRef,
    this.typeParameters,
    this.parameters,
  }) : super(elementType: 'function');

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'elementType': elementType,
    if (documentation != null) 'documentation': documentation,
    'returnType': returnType,
    if (returnTypeRef != null) 'returnTypeRef': returnTypeRef!.toJson(),
    if (typeParameters != null && typeParameters!.isNotEmpty) 'typeParameters': typeParameters!.map((tp) => tp.toJson()).toList(),
    if (parameters != null && parameters!.isNotEmpty) 'parameters': parameters!.map((p) => p.toJson()).toList(),
    'importableFrom': importableFrom,
    'definedIn': definedIn,
  };

  factory FunctionElement.fromJson(Map<String, dynamic> json) => FunctionElement(
    name: json['name'] as String,
    importableFrom: (json['importableFrom'] as List).cast<String>(),
    definedIn: json['definedIn'] as String,
    documentation: json['documentation'] as String?,
    returnType: json['returnType'] as String,
    returnTypeRef: json['returnTypeRef'] == null ? null : Type.fromJson(json['returnTypeRef'] as Map<String, dynamic>),
    typeParameters: (json['typeParameters'] as List?)?.map((tp) => TypeParameter.fromJson(tp as Map<String, dynamic>)).toList(),
    parameters: (json['parameters'] as List?)?.map((p) => Parameter.fromJson(p as Map<String, dynamic>)).toList(),
  );
}

/// Represents a top-level variable in the analyzed package.
class VariableElement extends ApiElement {
  /// The type of the variable.
  final String type;
  final Type? typeRef;

  /// Whether the variable is const.
  final bool isConst;

  /// Whether the variable is final.
  final bool isFinal;

  /// Whether the variable is late.
  final bool isLate;

  const VariableElement({
    required super.name,
    required super.importableFrom,
    required super.definedIn,
    super.documentation,
    required this.type,
    this.typeRef,
    required this.isConst,
    required this.isFinal,
    required this.isLate,
  }) : super(elementType: 'variable');

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'elementType': elementType,
    if (documentation != null) 'documentation': documentation,
    'type': type,
    if (typeRef != null) 'typeRef': typeRef!.toJson(),
    'isConst': isConst,
    'isFinal': isFinal,
    'isLate': isLate,
    'importableFrom': importableFrom,
    'definedIn': definedIn,
  };

  factory VariableElement.fromJson(Map<String, dynamic> json) => VariableElement(
    name: json['name'] as String,
    importableFrom: (json['importableFrom'] as List).cast<String>(),
    definedIn: json['definedIn'] as String,
    documentation: json['documentation'] as String?,
    type: json['type'] as String,
    typeRef: json['typeRef'] == null ? null : Type.fromJson(json['typeRef'] as Map<String, dynamic>),
    isConst: json['isConst'] as bool? ?? false,
    isFinal: json['isFinal'] as bool? ?? false,
    isLate: json['isLate'] as bool? ?? false,
  );
}

/// Represents a member of a class or enum.
sealed class MemberElement {
  /// The name of the member.
  final String name;

  /// The kind of member (constructor, method, getter, setter, operator).
  final String kind;

  /// Source library URI where this member is defined.
  final String location;

  const MemberElement({required this.name, required this.kind, required this.location});

  /// Converts this member to JSON.
  Map<String, dynamic> toJson();

  /// Creates a MemberElement from JSON.
  factory MemberElement.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    return switch (kind) {
      'constructor' => ConstructorMember.fromJson(json),
      'method' || 'operator' => MethodMember.fromJson(json),
      'getter' => GetterMember.fromJson(json),
      'setter' => SetterMember.fromJson(json),
      'field' => FieldMember.fromJson(json),
      _ => throw ArgumentError('Unknown member kind: $kind'),
    };
  }
}

/// Represents a constructor.
class ConstructorMember extends MemberElement {
  /// Parameters of the constructor.
  final List<Parameter>? parameters;

  final bool isConst;

  const ConstructorMember({required super.name, required super.location, this.parameters, required this.isConst})
    : super(kind: 'constructor');

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'location': location,
    'isConst': isConst,
    if (parameters != null && parameters!.isNotEmpty) 'parameters': parameters!.map((p) => p.toJson()).toList(),
  };

  factory ConstructorMember.fromJson(Map<String, dynamic> json) => ConstructorMember(
    name: json['name'] as String,
    location: json['location'] as String,
    parameters: (json['parameters'] as List?)?.map((p) => Parameter.fromJson(p as Map<String, dynamic>)).toList(),
    isConst: json['isConst'] as bool? ?? false,
  );
}

/// Represents a method or operator.
class MethodMember extends MemberElement {
  /// Whether the method is static.
  final bool isStatic;

  /// Return type of the method.
  final String returnType;
  final Type? returnTypeRef;

  /// Parameters of the method.
  final List<Parameter>? parameters;

  const MethodMember({
    required super.name,
    required super.kind,
    required super.location,
    required this.isStatic,
    required this.returnType,
    this.returnTypeRef,
    this.parameters,
  });

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'location': location,
    'isStatic': isStatic,
    'returnType': returnType,
    if (returnTypeRef != null) 'returnTypeRef': returnTypeRef!.toJson(),
    if (parameters != null && parameters!.isNotEmpty) 'parameters': parameters!.map((p) => p.toJson()).toList(),
  };

  factory MethodMember.fromJson(Map<String, dynamic> json) => MethodMember(
    name: json['name'] as String,
    kind: json['kind'] as String,
    location: json['location'] as String,
    isStatic: json['isStatic'] as bool? ?? false,
    returnType: json['returnType'] as String,
    returnTypeRef: json['returnTypeRef'] == null ? null : Type.fromJson(json['returnTypeRef'] as Map<String, dynamic>),
    parameters: (json['parameters'] as List?)?.map((p) => Parameter.fromJson(p as Map<String, dynamic>)).toList(),
  );
}

/// Represents a getter.
class GetterMember extends MemberElement {
  /// Whether the getter is static.
  final bool isStatic;

  /// Return type of the getter.
  final String returnType;
  final Type? returnTypeRef;

  const GetterMember({
    required super.name,
    required super.location,
    required this.isStatic,
    required this.returnType,
    required this.returnTypeRef,
  }) : super(kind: 'getter');

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'location': location,
    'isStatic': isStatic,
    'returnType': returnType,
    if (returnTypeRef != null) 'returnTypeRef': returnTypeRef!.toJson(),
  };

  factory GetterMember.fromJson(Map<String, dynamic> json) => GetterMember(
    name: json['name'] as String,
    location: json['location'] as String,
    isStatic: json['isStatic'] as bool? ?? false,
    returnType: json['returnType'] as String,
    returnTypeRef: json['returnTypeRef'] == null ? null : Type.fromJson(json['returnTypeRef'] as Map<String, dynamic>),
  );
}

/// Represents a setter.
class SetterMember extends MemberElement {
  /// Whether the setter is static.
  final bool isStatic;

  /// Type of the parameter.
  final String parameterType;
  final Type? parameterTypeRef;

  const SetterMember({
    required super.name,
    required super.location,
    required this.isStatic,
    required this.parameterType,
    this.parameterTypeRef,
  }) : super(kind: 'setter');

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'location': location,
    'isStatic': isStatic,
    'parameterType': parameterType,
    if (parameterTypeRef != null) 'parameterTypeRef': parameterTypeRef!.toJson(),
  };

  factory SetterMember.fromJson(Map<String, dynamic> json) => SetterMember(
    name: json['name'] as String,
    location: json['location'] as String,
    isStatic: json['isStatic'] as bool? ?? false,
    parameterType: json['parameterType'] as String,
    parameterTypeRef: json['parameterTypeRef'] == null ? null : Type.fromJson(json['parameterTypeRef'] as Map<String, dynamic>),
  );
}

/// Represents a field.
class FieldMember extends MemberElement {
  /// Whether the field is static.
  final bool isStatic;

  /// Type of the field.
  final String type;
  final Type? typeRef;

  /// Whether the field is final.
  final bool isFinal;

  /// Whether the field is const.
  final bool isConst;

  const FieldMember({
    required super.name,
    required super.location,
    required this.isStatic,
    required this.type,
    this.typeRef,
    required this.isFinal,
    required this.isConst,
  }) : super(kind: 'field');

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'location': location,
    'isStatic': isStatic,
    'type': type,
    'isFinal': isFinal,
    'isConst': isConst,
    if (typeRef != null) 'typeRef': typeRef!.toJson(),
  };

  factory FieldMember.fromJson(Map<String, dynamic> json) => FieldMember(
    name: json['name'] as String,
    location: json['location'] as String,
    isStatic: json['isStatic'] as bool? ?? false,
    type: json['type'] as String,
    typeRef: json['typeRef'] == null ? null : Type.fromJson(json['typeRef'] as Map<String, dynamic>),
    isFinal: json['isFinal'] as bool? ?? false,
    isConst: json['isConst'] as bool? ?? false,
  );
}

/// Represents a type parameter.
class TypeParameter {
  /// Name of the type parameter.
  final String name;

  /// Bound of the type parameter (if any).
  final String? bound;
  final Type? boundRef;

  const TypeParameter({required this.name, this.bound, this.boundRef});

  Map<String, dynamic> toJson() => {'name': name, if (bound != null) 'bound': bound, if (boundRef != null) 'boundRef': boundRef!.toJson()};

  factory TypeParameter.fromJson(Map<String, dynamic> json) => TypeParameter(
    name: json['name'] as String,
    bound: json['bound'] as String?,
    boundRef: json['boundRef'] == null ? null : Type.fromJson(json['boundRef'] as Map<String, dynamic>),
  );
}

/// Represents a function or method parameter.
class Parameter {
  /// Name of the parameter.
  final String name;

  /// Type of the parameter.
  final String type;
  final Type? typeRef;

  /// Whether the parameter is optional.
  final bool isOptional;

  /// Whether the parameter is named.
  final bool isNamed;

  /// Whether the parameter has a default value.
  final bool hasDefaultValue;

  /// Whether the parameter is required (for named parameters).
  final bool? isRequired;

  /// Code representing the default value (if any).
  final String? defaultValueCode;

  const Parameter({
    required this.name,
    required this.type,
    required this.isOptional,
    required this.isNamed,
    required this.hasDefaultValue,
    this.isRequired,
    this.typeRef,
    this.defaultValueCode,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'isOptional': isOptional,
    'isNamed': isNamed,
    'hasDefaultValue': hasDefaultValue,
    if (defaultValueCode != null) 'defaultValueCode': defaultValueCode,
    if (isRequired != null) 'isRequired': isRequired,
    if (typeRef != null) 'typeRef': typeRef!.toJson(),
  };

  factory Parameter.fromJson(Map<String, dynamic> json) => Parameter(
    name: json['name'] as String,
    type: json['type'] as String,
    isOptional: json['isOptional'] as bool? ?? false,
    isNamed: json['isNamed'] as bool? ?? false,
    hasDefaultValue: json['hasDefaultValue'] as bool? ?? false,
    isRequired: json['isRequired'] as bool?,
    defaultValueCode: json['defaultValueCode'] as String?,
    typeRef: json['typeRef'] == null ? null : Type.fromJson(json['typeRef'] as Map<String, dynamic>),
  );
}

/// Represents an enum value.
class EnumValue {
  /// Name of the enum value.
  final String name;

  /// Documentation for the enum value.
  final String? documentation;

  const EnumValue({required this.name, this.documentation});

  Map<String, dynamic> toJson() => {'name': name, if (documentation != null) 'documentation': documentation};

  factory EnumValue.fromJson(Map<String, dynamic> json) =>
      EnumValue(name: json['name'] as String, documentation: json['documentation'] as String?);
}

class ExtensionElement extends ApiElement {
  ExtensionElement({
    required this.onType,
    required this.onTypeRef,
    required this.members,
    required super.name,
    required super.importableFrom,
    required super.definedIn,
    super.documentation,
  }) : super(elementType: 'extension');

  final String onType;
  final Type onTypeRef;
  final List<MemberElement> members;

  factory ExtensionElement.fromJson(Map<String, dynamic> json) => ExtensionElement(
    name: json['name'] as String,
    importableFrom: (json['importableFrom'] as List).cast<String>(),
    definedIn: json['definedIn'] as String,
    documentation: json['documentation'] as String?,
    onType: json['onType'] as String,
    onTypeRef: Type.fromJson(json['onTypeRef'] as Map<String, dynamic>),
    members: (json['members'] as List).map((m) => MemberElement.fromJson(m as Map<String, dynamic>)).toList(),
  );

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'elementType': elementType,
    if (documentation != null) 'documentation': documentation,
    'onType': onType,
    'onTypeRef': onTypeRef.toJson(),
    'members': members.map((m) => m.toJson()).toList(),
    'importableFrom': importableFrom,
    'definedIn': definedIn,
  };
}

sealed class Type {
  Type({required this.name, this.libraryUri, this.isNullable = false, required this.kind});

  factory Type.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    return switch (kind) {
      'class' => ClassType.fromJson(json),
      'function' => FunctionType.fromJson(json),
      'generic' => GenericType.fromJson(json),
      'dynamic' => DynamicType.fromJson(json),
      'void' => VoidType.fromJson(json),
      _ => throw ArgumentError('Unknown type kind: $kind'),
    };
  }

  final String name;
  final String? libraryUri;
  final bool isNullable;
  final String kind;

  Map<String, dynamic> toJson();
}

class ClassType extends Type {
  ClassType({required super.name, super.libraryUri, super.isNullable, this.arguments}) : super(kind: 'class');

  factory ClassType.fromJson(Map<String, dynamic> json) => ClassType(
    name: json['name'] as String,
    libraryUri: json['libraryUri'] as String?,
    isNullable: json['isNullable'] as bool? ?? false,
    arguments: (json['arguments'] as List?)?.map((a) => Type.fromJson(a as Map<String, dynamic>)).toList(),
  );

  final List<Type>? arguments;

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'libraryUri': libraryUri,
    'isNullable': isNullable,
    'kind': kind,
    if (arguments != null && arguments!.isNotEmpty) 'arguments': arguments!.map((a) => a.toJson()).toList(),
  };
}

class FunctionType extends Type {
  FunctionType({super.libraryUri, super.isNullable, this.returnType, this.parameters}) : super(name: "Function", kind: 'function');

  factory FunctionType.fromJson(Map<String, dynamic> json) => FunctionType(
    libraryUri: json['libraryUri'] as String?,
    isNullable: json['isNullable'] as bool? ?? false,
    returnType: json['returnType'] == null ? null : Type.fromJson(json['returnType'] as Map<String, dynamic>),
    parameters: (json['parameters'] as List?)?.map((p) => Parameter.fromJson(p as Map<String, dynamic>)).toList(),
  );

  final Type? returnType;
  final List<Parameter>? parameters;

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'libraryUri': libraryUri,
    'isNullable': isNullable,
    'kind': kind,
    if (returnType != null) 'returnType': returnType!.toJson(),
    if (parameters != null && parameters!.isNotEmpty) 'parameters': parameters!.map((p) => p.toJson()).toList(),
  };
}

class GenericType extends Type {
  GenericType({required super.name, super.isNullable, this.bound}) : super(kind: 'generic', libraryUri: null);

  factory GenericType.fromJson(Map<String, dynamic> json) => GenericType(
    name: json['name'] as String,
    isNullable: json['isNullable'] as bool? ?? false,
    bound: json['bound'] == null ? null : Type.fromJson(json['bound'] as Map<String, dynamic>),
  );

  final Type? bound;

  @override
  Map<String, dynamic> toJson() => {'name': name, 'isNullable': isNullable, 'kind': kind, if (bound != null) 'bound': bound!.toJson()};
}

class DynamicType extends Type {
  DynamicType() : super(name: 'dynamic', kind: 'dynamic');

  @override
  Map<String, dynamic> toJson() => {'name': name, 'kind': kind};

  factory DynamicType.fromJson(Map<String, dynamic> json) => DynamicType();
}

class VoidType extends Type {
  VoidType() : super(name: 'void', kind: 'void');

  @override
  Map<String, dynamic> toJson() => {'name': name, 'kind': kind};

  factory VoidType.fromJson(Map<String, dynamic> json) => VoidType();
}

/// Represents the analysis result for a package.
class PackageAnalysisResult {
  /// All API elements in the package.
  final List<ApiElement> elements;

  const PackageAnalysisResult({required this.elements});

  Map<String, dynamic> toJson() => {'elements': elements.map((e) => e.toJson()).toList()};

  factory PackageAnalysisResult.fromJson(Map<String, dynamic> json) =>
      PackageAnalysisResult(elements: (json['elements'] as List).map((e) => ApiElement.fromJson(e as Map<String, dynamic>)).toList());
}
