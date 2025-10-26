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

  /// Interfaces implemented by this class.
  final List<String>? interfaces;

  /// Mixins used by this class.
  final List<String>? mixins;

  /// Members of this class (constructors, methods, getters, setters).
  final List<MemberElement> members;

  const ClassElement({
    required super.name,
    required super.importableFrom,
    required super.definedIn,
    super.documentation,
    this.typeParameters,
    this.superclass,
    this.interfaces,
    this.mixins,
    required this.members,
  }) : super(elementType: 'class');

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'elementType': elementType,
      if (documentation != null) 'documentation': documentation,
      if (typeParameters != null && typeParameters!.isNotEmpty) 'typeParameters': typeParameters!.map((tp) => tp.toJson()).toList(),
      if (superclass != null) 'superclass': superclass,
      if (interfaces != null && interfaces!.isNotEmpty) 'interfaces': interfaces,
      if (mixins != null && mixins!.isNotEmpty) 'mixins': mixins,
      'members': members.map((m) => m.toJson()).toList(),
      'importableFrom': importableFrom,
      'definedIn': definedIn,
    };
  }

  factory ClassElement.fromJson(Map<String, dynamic> json) {
    return ClassElement(
      name: json['name'] as String,
      importableFrom: (json['importableFrom'] as List).cast<String>(),
      definedIn: json['definedIn'] as String,
      documentation: json['documentation'] as String?,
      typeParameters: (json['typeParameters'] as List?)?.map((tp) => TypeParameter.fromJson(tp as Map<String, dynamic>)).toList(),
      superclass: (json['superclass'] as List?)?.cast<String>(),
      interfaces: (json['interfaces'] as List?)?.cast<String>(),
      mixins: (json['mixins'] as List?)?.cast<String>(),
      members: (json['members'] as List).map((m) => MemberElement.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }
}

/// Represents an enum in the analyzed package.
class EnumElement extends ApiElement {
  /// The enum values.
  final List<EnumValue> values;

  /// Members of this enum (methods, getters, setters, constructors).
  final List<MemberElement>? members;

  /// Interfaces implemented by this enum.
  final List<String>? interfaces;

  /// Mixins used by this enum.
  final List<String>? mixins;

  const EnumElement({
    required super.name,
    required super.importableFrom,
    required super.definedIn,
    super.documentation,
    required this.values,
    this.members,
    this.interfaces,
    this.mixins,
  }) : super(elementType: 'enum');

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'elementType': elementType,
      if (documentation != null) 'documentation': documentation,
      'values': values.map((v) => v.toJson()).toList(),
      if (members != null && members!.isNotEmpty) 'members': members!.map((m) => m.toJson()).toList(),
      if (interfaces != null && interfaces!.isNotEmpty) 'interfaces': interfaces,
      if (mixins != null && mixins!.isNotEmpty) 'mixins': mixins,
      'importableFrom': importableFrom,
      'definedIn': definedIn,
    };
  }

  factory EnumElement.fromJson(Map<String, dynamic> json) {
    return EnumElement(
      name: json['name'] as String,
      importableFrom: (json['importableFrom'] as List).cast<String>(),
      definedIn: json['definedIn'] as String,
      documentation: json['documentation'] as String?,
      values: (json['values'] as List).map((v) => EnumValue.fromJson(v as Map<String, dynamic>)).toList(),
      members: (json['members'] as List?)?.map((m) => MemberElement.fromJson(m as Map<String, dynamic>)).toList(),
      interfaces: (json['interfaces'] as List?)?.cast<String>(),
      mixins: (json['mixins'] as List?)?.cast<String>(),
    );
  }
}

/// Represents a top-level function in the analyzed package.
class FunctionElement extends ApiElement {
  /// Return type of the function.
  final String returnType;

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
    this.typeParameters,
    this.parameters,
  }) : super(elementType: 'function');

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'elementType': elementType,
      if (documentation != null) 'documentation': documentation,
      'returnType': returnType,
      if (typeParameters != null && typeParameters!.isNotEmpty) 'typeParameters': typeParameters!.map((tp) => tp.toJson()).toList(),
      if (parameters != null && parameters!.isNotEmpty) 'parameters': parameters!.map((p) => p.toJson()).toList(),
      'importableFrom': importableFrom,
      'definedIn': definedIn,
    };
  }

  factory FunctionElement.fromJson(Map<String, dynamic> json) {
    return FunctionElement(
      name: json['name'] as String,
      importableFrom: (json['importableFrom'] as List).cast<String>(),
      definedIn: json['definedIn'] as String,
      documentation: json['documentation'] as String?,
      returnType: json['returnType'] as String,
      typeParameters: (json['typeParameters'] as List?)?.map((tp) => TypeParameter.fromJson(tp as Map<String, dynamic>)).toList(),
      parameters: (json['parameters'] as List?)?.map((p) => Parameter.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

/// Represents a top-level variable in the analyzed package.
class VariableElement extends ApiElement {
  /// The type of the variable.
  final String type;

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
    required this.isConst,
    required this.isFinal,
    required this.isLate,
  }) : super(elementType: 'variable');

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'elementType': elementType,
      if (documentation != null) 'documentation': documentation,
      'type': type,
      'isConst': isConst,
      'isFinal': isFinal,
      'isLate': isLate,
      'importableFrom': importableFrom,
      'definedIn': definedIn,
    };
  }

  factory VariableElement.fromJson(Map<String, dynamic> json) {
    return VariableElement(
      name: json['name'] as String,
      importableFrom: (json['importableFrom'] as List).cast<String>(),
      definedIn: json['definedIn'] as String,
      documentation: json['documentation'] as String?,
      type: json['type'] as String,
      isConst: json['isConst'] as bool? ?? false,
      isFinal: json['isFinal'] as bool? ?? false,
      isLate: json['isLate'] as bool? ?? false,
    );
  }
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

  const ConstructorMember({required super.name, required super.location, this.parameters}) : super(kind: 'constructor');

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'kind': kind,
      'location': location,
      if (parameters != null && parameters!.isNotEmpty) 'parameters': parameters!.map((p) => p.toJson()).toList(),
    };
  }

  factory ConstructorMember.fromJson(Map<String, dynamic> json) {
    return ConstructorMember(
      name: json['name'] as String,
      location: json['location'] as String,
      parameters: (json['parameters'] as List?)?.map((p) => Parameter.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

/// Represents a method or operator.
class MethodMember extends MemberElement {
  /// Whether the method is static.
  final bool isStatic;

  /// Return type of the method.
  final String returnType;

  /// Parameters of the method.
  final List<Parameter>? parameters;

  const MethodMember({
    required super.name,
    required super.kind,
    required super.location,
    required this.isStatic,
    required this.returnType,
    this.parameters,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'kind': kind,
      'location': location,
      'isStatic': isStatic,
      'returnType': returnType,
      if (parameters != null && parameters!.isNotEmpty) 'parameters': parameters!.map((p) => p.toJson()).toList(),
    };
  }

  factory MethodMember.fromJson(Map<String, dynamic> json) {
    return MethodMember(
      name: json['name'] as String,
      kind: json['kind'] as String,
      location: json['location'] as String,
      isStatic: json['isStatic'] as bool? ?? false,
      returnType: json['returnType'] as String,
      parameters: (json['parameters'] as List?)?.map((p) => Parameter.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

/// Represents a getter.
class GetterMember extends MemberElement {
  /// Whether the getter is static.
  final bool isStatic;

  /// Return type of the getter.
  final String returnType;

  const GetterMember({required super.name, required super.location, required this.isStatic, required this.returnType})
    : super(kind: 'getter');

  @override
  Map<String, dynamic> toJson() {
    return {'name': name, 'kind': kind, 'location': location, 'isStatic': isStatic, 'returnType': returnType};
  }

  factory GetterMember.fromJson(Map<String, dynamic> json) {
    return GetterMember(
      name: json['name'] as String,
      location: json['location'] as String,
      isStatic: json['isStatic'] as bool? ?? false,
      returnType: json['returnType'] as String,
    );
  }
}

/// Represents a setter.
class SetterMember extends MemberElement {
  /// Whether the setter is static.
  final bool isStatic;

  /// Type of the parameter.
  final String parameterType;

  const SetterMember({required super.name, required super.location, required this.isStatic, required this.parameterType})
    : super(kind: 'setter');

  @override
  Map<String, dynamic> toJson() {
    return {'name': name, 'kind': kind, 'location': location, 'isStatic': isStatic, 'parameterType': parameterType};
  }

  factory SetterMember.fromJson(Map<String, dynamic> json) {
    return SetterMember(
      name: json['name'] as String,
      location: json['location'] as String,
      isStatic: json['isStatic'] as bool? ?? false,
      parameterType: json['parameterType'] as String,
    );
  }
}

/// Represents a field.
class FieldMember extends MemberElement {
  /// Whether the field is static.
  final bool isStatic;

  /// Type of the field.
  final String type;

  /// Whether the field is final.
  final bool isFinal;

  /// Whether the field is const.
  final bool isConst;

  const FieldMember({
    required super.name,
    required super.location,
    required this.isStatic,
    required this.type,
    required this.isFinal,
    required this.isConst,
  }) : super(kind: 'field');

  @override
  Map<String, dynamic> toJson() {
    return {'name': name, 'kind': kind, 'location': location, 'isStatic': isStatic, 'type': type, 'isFinal': isFinal, 'isConst': isConst};
  }

  factory FieldMember.fromJson(Map<String, dynamic> json) {
    return FieldMember(
      name: json['name'] as String,
      location: json['location'] as String,
      isStatic: json['isStatic'] as bool? ?? false,
      type: json['type'] as String,
      isFinal: json['isFinal'] as bool? ?? false,
      isConst: json['isConst'] as bool? ?? false,
    );
  }
}

/// Represents a type parameter.
class TypeParameter {
  /// Name of the type parameter.
  final String name;

  /// Bound of the type parameter (if any).
  final String? bound;

  const TypeParameter({required this.name, this.bound});

  Map<String, dynamic> toJson() {
    return {'name': name, if (bound != null) 'bound': bound};
  }

  factory TypeParameter.fromJson(Map<String, dynamic> json) {
    return TypeParameter(name: json['name'] as String, bound: json['bound'] as String?);
  }
}

/// Represents a function or method parameter.
class Parameter {
  /// Name of the parameter.
  final String name;

  /// Type of the parameter.
  final String type;

  /// Whether the parameter is optional.
  final bool isOptional;

  /// Whether the parameter is named.
  final bool isNamed;

  /// Whether the parameter has a default value.
  final bool hasDefaultValue;

  /// Whether the parameter is required (for named parameters).
  final bool? isRequired;

  const Parameter({
    required this.name,
    required this.type,
    required this.isOptional,
    required this.isNamed,
    required this.hasDefaultValue,
    this.isRequired,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'isOptional': isOptional,
      'isNamed': isNamed,
      'hasDefaultValue': hasDefaultValue,
      if (isRequired != null) 'isRequired': isRequired,
    };
  }

  factory Parameter.fromJson(Map<String, dynamic> json) {
    return Parameter(
      name: json['name'] as String,
      type: json['type'] as String,
      isOptional: json['isOptional'] as bool? ?? false,
      isNamed: json['isNamed'] as bool? ?? false,
      hasDefaultValue: json['hasDefaultValue'] as bool? ?? false,
      isRequired: json['isRequired'] as bool?,
    );
  }
}

/// Represents an enum value.
class EnumValue {
  /// Name of the enum value.
  final String name;

  /// Documentation for the enum value.
  final String? documentation;

  const EnumValue({required this.name, this.documentation});

  Map<String, dynamic> toJson() {
    return {'name': name, if (documentation != null) 'documentation': documentation};
  }

  factory EnumValue.fromJson(Map<String, dynamic> json) {
    return EnumValue(name: json['name'] as String, documentation: json['documentation'] as String?);
  }
}

/// Represents the analysis result for a package.
class PackageAnalysisResult {
  /// All API elements in the package.
  final List<ApiElement> elements;

  const PackageAnalysisResult({required this.elements});

  Map<String, dynamic> toJson() {
    return {'elements': elements.map((e) => e.toJson()).toList()};
  }

  factory PackageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return PackageAnalysisResult(elements: (json['elements'] as List).map((e) => ApiElement.fromJson(e as Map<String, dynamic>)).toList());
  }
}
