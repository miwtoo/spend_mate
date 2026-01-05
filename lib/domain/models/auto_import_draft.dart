import 'package:spend_mate/domain/models/receipt_parse_result.dart';

enum AutoImportStatus {
  pending,
  confirmed,
  discarded,
  failed,
}

class AutoImportDraft {
  const AutoImportDraft({
    required this.id,
    required this.sourcePath,
    required this.detectedAt,
    required this.status,
    this.sourceHash,
    this.fireflyTransactionId,
    this.fireflyTransactionJournalId,
    this.merchant,
    this.amount,
    this.currency,
    this.date,
    this.note,
    this.categoryName,
    this.type = ReceiptTransactionType.unknown,
    this.confidence,
    this.assetAccountName,
    this.errorMessage,
  });

  final String id;
  final String sourcePath;
  final DateTime detectedAt;
  final AutoImportStatus status;
  final String? sourceHash;
  final String? fireflyTransactionId;
  final String? fireflyTransactionJournalId;
  final String? merchant;
  final double? amount;
  final String? currency;
  final DateTime? date;
  final String? note;
  final String? categoryName;
  final ReceiptTransactionType type;
  final double? confidence;
  final String? assetAccountName;
  final String? errorMessage;

  AutoImportDraft copyWith({
    AutoImportStatus? status,
    String? sourceHash,
    String? fireflyTransactionId,
    String? fireflyTransactionJournalId,
    String? merchant,
    double? amount,
    String? currency,
    DateTime? date,
    String? note,
    String? categoryName,
    ReceiptTransactionType? type,
    double? confidence,
    String? assetAccountName,
    String? errorMessage,
  }) {
    return AutoImportDraft(
      id: id,
      sourcePath: sourcePath,
      detectedAt: detectedAt,
      status: status ?? this.status,
      sourceHash: sourceHash ?? this.sourceHash,
      fireflyTransactionId:
          fireflyTransactionId ?? this.fireflyTransactionId,
      fireflyTransactionJournalId:
          fireflyTransactionJournalId ?? this.fireflyTransactionJournalId,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      note: note ?? this.note,
      categoryName: categoryName ?? this.categoryName,
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      assetAccountName: assetAccountName ?? this.assetAccountName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourcePath': sourcePath,
      'detectedAt': detectedAt.toIso8601String(),
      'status': status.name,
      'sourceHash': sourceHash,
      'fireflyTransactionId': fireflyTransactionId,
      'fireflyTransactionJournalId': fireflyTransactionJournalId,
      'merchant': merchant,
      'amount': amount,
      'currency': currency,
      'date': date?.toIso8601String(),
      'note': note,
      'categoryName': categoryName,
      'type': type.name,
      'confidence': confidence,
      'assetAccountName': assetAccountName,
      'errorMessage': errorMessage,
    };
  }

  factory AutoImportDraft.fromJson(Map<String, dynamic> json) {
    return AutoImportDraft(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      sourcePath: json['sourcePath']?.toString() ?? '',
      detectedAt: DateTime.tryParse(json['detectedAt']?.toString() ?? '') ??
          DateTime.now(),
      status: _parseStatus(json['status']),
      sourceHash: json['sourceHash']?.toString(),
      fireflyTransactionId: json['fireflyTransactionId']?.toString(),
      fireflyTransactionJournalId:
          json['fireflyTransactionJournalId']?.toString(),
      merchant: json['merchant']?.toString(),
      amount: _parseDouble(json['amount']),
      currency: json['currency']?.toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      note: json['note']?.toString(),
      categoryName: json['categoryName']?.toString(),
      type: _parseType(json['type']),
      confidence: _parseDouble(json['confidence']),
      assetAccountName: json['assetAccountName']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
    );
  }
}

AutoImportStatus _parseStatus(dynamic value) {
  if (value == null) return AutoImportStatus.pending;
  final text = value.toString().toLowerCase();
  return switch (text) {
    'confirmed' => AutoImportStatus.confirmed,
    'discarded' => AutoImportStatus.discarded,
    'failed' => AutoImportStatus.failed,
    _ => AutoImportStatus.pending,
  };
}

ReceiptTransactionType _parseType(dynamic value) {
  if (value == null) return ReceiptTransactionType.unknown;
  final text = value.toString().toLowerCase();
  return switch (text) {
    'expense' => ReceiptTransactionType.expense,
    'income' => ReceiptTransactionType.income,
    'transfer' => ReceiptTransactionType.transfer,
    _ => ReceiptTransactionType.unknown,
  };
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
