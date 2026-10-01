/// نموذج بيانات حساب المستخدم لتعدد الحسابات وعزل قواعد البيانات
class AppUserAccount {
  final String id;
  final String username;
  final String pin;
  final String bureauName;
  final String defaultCurrency;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const AppUserAccount({
    required this.id,
    required this.username,
    required this.pin,
    required this.bureauName,
    this.defaultCurrency = 'سعودي',
    required this.createdAt,
    this.lastLoginAt,
  });

  AppUserAccount copyWith({
    String? id,
    String? username,
    String? pin,
    String? bureauName,
    String? defaultCurrency,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return AppUserAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      pin: pin ?? this.pin,
      bureauName: bureauName ?? this.bureauName,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'pin': pin,
      'bureauName': bureauName,
      'defaultCurrency': defaultCurrency,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory AppUserAccount.fromMap(Map<dynamic, dynamic> map) {
    return AppUserAccount(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      pin: map['pin']?.toString() ?? '',
      bureauName: map['bureauName']?.toString() ?? 'نظام القسام للصرافة والتحويلات',
      defaultCurrency: map['defaultCurrency']?.toString() ?? 'سعودي',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.tryParse(map['lastLoginAt'].toString())
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserAccount && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
