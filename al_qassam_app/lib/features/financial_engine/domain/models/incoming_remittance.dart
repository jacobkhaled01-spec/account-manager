import 'dart:convert';

/// نموذج الحوالة الواردة (Incoming Remittance Model)
class IncomingRemittance {
  final String id;
  final String batchId;
  final int seq;
  final String date;
  final String name;
  final String account;
  final double amount;
  final String currency;
  final double rate;
  final double birrEquivalent;
  final double cutCents;
  final DateTime createdAt;

  IncomingRemittance({
    required this.id,
    required this.batchId,
    required this.seq,
    required this.date,
    required this.name,
    required this.account,
    required this.amount,
    this.currency = 'ريال سعودي',
    required this.rate,
    required this.birrEquivalent,
    this.cutCents = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// بصمة فريدة للسجل لمنع التكرار (رقم الحساب + المبلغ + اسم المستفيد)
  String get fingerprint {
    final cleanAcc = account.trim().replaceAll(RegExp(r'\s+'), '');
    final cleanAmt = amount.toStringAsFixed(2);
    final cleanName = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return '${cleanAcc}_${cleanAmt}_$cleanName';
  }

  /// هل الحوالة كبرى (100,000 بر فأكثر)؟
  bool get isLarge => birrEquivalent >= 100000;

  int get sequence => seq;
  int get birr => birrEquivalent.toInt();

  IncomingRemittance copyWith({
    String? id,
    String? batchId,
    int? seq,
    String? date,
    String? name,
    String? account,
    double? amount,
    String? currency,
    double? rate,
    double? birrEquivalent,
    double? cutCents,
    DateTime? createdAt,
  }) {
    return IncomingRemittance(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      seq: seq ?? this.seq,
      date: date ?? this.date,
      name: name ?? this.name,
      account: account ?? this.account,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      rate: rate ?? this.rate,
      birrEquivalent: birrEquivalent ?? this.birrEquivalent,
      cutCents: cutCents ?? this.cutCents,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'seq': seq,
      'date': date,
      'name': name,
      'account': account,
      'amount': amount,
      'currency': currency,
      'rate': rate,
      'birrEquivalent': birrEquivalent,
      'cutCents': cutCents,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory IncomingRemittance.fromMap(Map<String, dynamic> map) {
    return IncomingRemittance(
      id: map['id'] ?? '',
      batchId: map['batchId'] ?? '',
      seq: (map['seq'] as num?)?.toInt() ?? 0,
      date: map['date'] ?? '',
      name: map['name'] ?? '',
      account: map['account'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'ريال سعودي',
      rate: (map['rate'] as num?)?.toDouble() ?? 48.0,
      birrEquivalent: (map['birrEquivalent'] as num?)?.toDouble() ?? 0.0,
      cutCents: (map['cutCents'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory IncomingRemittance.fromJson(String source) =>
      IncomingRemittance.fromMap(json.decode(source));
}
