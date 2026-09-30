import 'package:uuid/uuid.dart';

/// نوع القالب: وارد (حوالات إثيوبيا) أو صادر (شبكات الصرافة والتحويلات)
enum TemplateType {
  incoming,
  outgoing;

  String get label => this == TemplateType.incoming ? 'حوالات واردة' : 'حوالات صادرة وشبكات';
}

/// استراتيجية الاستخراج وتطابق الحقول
enum ExtractionStrategy {
  phoneIncluded, // اسم + حساب + هاتف + مبلغ
  equalSign,     // اسم = مبلغ ثم حساب
  singleLine,    // اسم حساب مبلغ في سطر واحد
  standardOrder, // اسم ثم حساب ثم مبلغ بأي ترتيب
  millionsFormat,// مبالغ بالملايين (مثلاً 2.5 مليون بر)
  outgoingNetwork,// كشوفات الشبكات (الأكوع، المحيط، النجم...)
  customRegex;   // تعبير نمطي مخصص يحدده المستخدم

  String get displayName {
    switch (this) {
      case ExtractionStrategy.phoneIncluded:
        return 'اسم + حساب + هاتف + مبلغ';
      case ExtractionStrategy.equalSign:
        return 'اسم = مبلغ (النمط الإثيوبي)';
      case ExtractionStrategy.singleLine:
        return 'سطر واحد مدمج';
      case ExtractionStrategy.standardOrder:
        return 'ترتيب مرن متعدد الأسطر';
      case ExtractionStrategy.millionsFormat:
        return 'صيغ الملايين والكلمات';
      case ExtractionStrategy.outgoingNetwork:
        return 'إشعار شبكة صرافة صادر';
      case ExtractionStrategy.customRegex:
        return 'تعبير نمطي مخصص (Regex)';
    }
  }
}

/// نموذج قاعدة القالب المالي لنظام القسام
class TemplateRule {
  final String id;
  final String name;
  final TemplateType type;
  final String description;
  final ExtractionStrategy strategy;
  final String sampleText;
  final String? customRegex;
  final List<String> keywords;
  final bool isEnabled;
  final bool isBuiltIn;
  final DateTime createdAt;

  const TemplateRule({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.strategy,
    required this.sampleText,
    this.customRegex,
    this.keywords = const [],
    this.isEnabled = true,
    this.isBuiltIn = false,
    required this.createdAt,
  });

  TemplateRule copyWith({
    String? id,
    String? name,
    TemplateType? type,
    String? description,
    ExtractionStrategy? strategy,
    String? sampleText,
    String? customRegex,
    List<String>? keywords,
    bool? isEnabled,
    bool? isBuiltIn,
    DateTime? createdAt,
  }) {
    return TemplateRule(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      strategy: strategy ?? this.strategy,
      sampleText: sampleText ?? this.sampleText,
      customRegex: customRegex ?? this.customRegex,
      keywords: keywords ?? this.keywords,
      isEnabled: isEnabled ?? this.isEnabled,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'description': description,
      'strategy': strategy.name,
      'sampleText': sampleText,
      'customRegex': customRegex,
      'keywords': keywords,
      'isEnabled': isEnabled,
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TemplateRule.fromMap(Map<dynamic, dynamic> map) {
    return TemplateRule(
      id: map['id']?.toString() ?? const Uuid().v4(),
      name: map['name']?.toString() ?? 'قالب بدون اسم',
      type: (map['type']?.toString() == 'outgoing') ? TemplateType.outgoing : TemplateType.incoming,
      description: map['description']?.toString() ?? '',
      strategy: ExtractionStrategy.values.firstWhere(
        (e) => e.name == map['strategy']?.toString(),
        orElse: () => ExtractionStrategy.standardOrder,
      ),
      sampleText: map['sampleText']?.toString() ?? '',
      customRegex: map['customRegex']?.toString(),
      keywords: (map['keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isEnabled: map['isEnabled'] as bool? ?? true,
      isBuiltIn: map['isBuiltIn'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
