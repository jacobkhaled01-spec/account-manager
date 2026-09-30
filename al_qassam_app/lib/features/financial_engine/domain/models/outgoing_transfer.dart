import 'dart:convert';

/// نموذج الحوالة الصادرة - شبكات الصرافة (Outgoing Transfer Model)
class OutgoingTransfer {
  final String id;
  final String batchId;
  final int seq;
  final String recipient;
  final String sender;
  final double amount;
  final String currency;
  final String commission;
  final String network;
  final String transferNo;
  final String date;
  final String notes;
  final DateTime createdAt;

  OutgoingTransfer({
    required this.id,
    required this.batchId,
    this.seq = 1,
    required this.recipient,
    required this.sender,
    required this.amount,
    this.currency = 'ريال سعودي',
    this.commission = '-',
    this.network = '-',
    this.transferNo = '-',
    required this.date,
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get sequence => seq;

  /// بصمة فريدة للحوالة الصادرة لمنع التكرار
  String get fingerprint {
    final cleanRec = recipient.trim().toLowerCase();
    final cleanAmt = amount.toStringAsFixed(2);
    final cleanRef = transferNo.trim().toLowerCase();
    return '${cleanRec}_${cleanAmt}_$cleanRef';
  }

  OutgoingTransfer copyWith({
    String? id,
    String? batchId,
    String? recipient,
    String? sender,
    double? amount,
    String? currency,
    String? commission,
    String? network,
    String? transferNo,
    String? date,
    String? notes,
    DateTime? createdAt,
  }) {
    return OutgoingTransfer(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      recipient: recipient ?? this.recipient,
      sender: sender ?? this.sender,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      commission: commission ?? this.commission,
      network: network ?? this.network,
      transferNo: transferNo ?? this.transferNo,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'recipient': recipient,
      'sender': sender,
      'amount': amount,
      'currency': currency,
      'commission': commission,
      'network': network,
      'transferNo': transferNo,
      'date': date,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OutgoingTransfer.fromMap(Map<String, dynamic> map) {
    return OutgoingTransfer(
      id: map['id'] ?? '',
      batchId: map['batchId'] ?? '',
      recipient: map['recipient'] ?? '',
      sender: map['sender'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'ريال سعودي',
      commission: map['commission'] ?? '-',
      network: map['network'] ?? '-',
      transferNo: map['transferNo'] ?? '-',
      date: map['date'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory OutgoingTransfer.fromJson(String source) =>
      OutgoingTransfer.fromMap(json.decode(source));
}
