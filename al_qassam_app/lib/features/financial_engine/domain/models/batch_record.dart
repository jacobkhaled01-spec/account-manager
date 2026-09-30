import 'dart:convert';

enum BatchType { incoming, outgoing }

/// دفعة كشف مستقلة لكل عملية لصق (Isolated Paste Batch)
class BatchRecord {
  final String id;
  final String title;
  final BatchType type;
  final DateTime createdAt;
  final double exchangeRate;
  final int count;
  final double totalAmount;
  final double totalBirr;
  final double totalCutCents;
  final double smallBirrTotal;
  final double largeBirrTotal;
  final String rawText;

  BatchRecord({
    required this.id,
    required this.title,
    required this.type,
    DateTime? createdAt,
    required this.exchangeRate,
    this.count = 0,
    this.totalAmount = 0.0,
    this.totalBirr = 0.0,
    this.totalCutCents = 0.0,
    this.smallBirrTotal = 0.0,
    this.largeBirrTotal = 0.0,
    this.rawText = '',
  }) : createdAt = createdAt ?? DateTime.now();

  String get label => title;
  DateTime get timestamp => createdAt;
  String get date =>
      '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}';
  int get totalCount => count;
  double get totalAmountOrig => totalAmount;
  int get smallBirr => smallBirrTotal.toInt();
  int get largeBirr => largeBirrTotal.toInt();
  int get smallCount => 0;
  int get largeCount => 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type == BatchType.incoming ? 'incoming' : 'outgoing',
      'createdAt': createdAt.toIso8601String(),
      'exchangeRate': exchangeRate,
      'count': count,
      'totalAmount': totalAmount,
      'totalBirr': totalBirr,
      'totalCutCents': totalCutCents,
      'smallBirrTotal': smallBirrTotal,
      'largeBirrTotal': largeBirrTotal,
      'rawText': rawText,
    };
  }

  factory BatchRecord.fromMap(Map<String, dynamic> map) {
    return BatchRecord(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      type: map['type'] == 'outgoing' ? BatchType.outgoing : BatchType.incoming,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      exchangeRate: (map['exchangeRate'] as num?)?.toDouble() ?? 48.0,
      count: (map['count'] as num?)?.toInt() ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalBirr: (map['totalBirr'] as num?)?.toDouble() ?? 0.0,
      totalCutCents: (map['totalCutCents'] as num?)?.toDouble() ?? 0.0,
      smallBirrTotal: (map['smallBirrTotal'] as num?)?.toDouble() ?? 0.0,
      largeBirrTotal: (map['largeBirrTotal'] as num?)?.toDouble() ?? 0.0,
      rawText: map['rawText'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory BatchRecord.fromJson(String source) =>
      BatchRecord.fromMap(json.decode(source));
}
