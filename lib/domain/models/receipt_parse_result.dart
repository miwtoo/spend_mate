import 'dart:convert';

enum ReceiptTransactionType {
  expense,
  income,
  transfer,
  unknown,
}

class ReceiptParseResult {
  const ReceiptParseResult({
    this.amount,
    this.currency,
    this.date,
    this.merchant,
    this.note,
    this.type = ReceiptTransactionType.unknown,
    this.confidence,
  });

  final double? amount;
  final String? currency;
  final DateTime? date;
  final String? merchant;
  final String? note;
  final ReceiptTransactionType type;
  final double? confidence;

  factory ReceiptParseResult.fromAiResponse(String raw) {
    final json = _extractJsonObject(raw);
    if (json == null) {
      throw const FormatException('No JSON object found in AI response.');
    }
    return ReceiptParseResult.fromJson(json);
  }

  factory ReceiptParseResult.fromJson(Map<String, dynamic> json) {
    final dateTime = _parseDate(json['date_time'] ?? json['datetime']);
    var date = dateTime ?? _parseDate(json['date']);
    if (dateTime == null) {
      date = _applyTime(
        date,
        _parseTime(
          json['time'] ?? json['transaction_time'] ?? json['time_local'],
        ),
      );
    }
    return ReceiptParseResult(
      amount: _parseAmount(json['amount']),
      currency: _parseString(json['currency'])?.toUpperCase(),
      date: date,
      merchant: _parseString(json['merchant']),
      note: _parseString(json['note'] ?? json['description']),
      type: _parseType(json['type']),
      confidence: _parseDouble(json['confidence']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'date': date?.toIso8601String(),
      'merchant': merchant,
      'note': note,
      'type': type.name,
      'confidence': confidence,
    };
  }
}

ReceiptTransactionType _parseType(dynamic value) {
  if (value == null) return ReceiptTransactionType.unknown;
  final text = value.toString().toLowerCase().trim();
  return switch (text) {
    'expense' || 'spend' || 'debit' => ReceiptTransactionType.expense,
    'income' || 'credit' => ReceiptTransactionType.income,
    'transfer' => ReceiptTransactionType.transfer,
    _ => ReceiptTransactionType.unknown,
  };
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed != null) return parsed;
  final match = RegExp(
    r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})'
    r'(?:[ T](\d{1,2})(?::(\d{2}))?(?::(\d{2}))?)?\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  final part1 = int.tryParse(match.group(1) ?? '');
  final part2 = int.tryParse(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  if (part1 == null || part2 == null || year == null) return null;
  final month = part1 > 12 ? part2 : part1;
  final day = part1 > 12 ? part1 : part2;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  var hour = int.tryParse(match.group(4) ?? '') ?? 0;
  final minute = int.tryParse(match.group(5) ?? '') ?? 0;
  final second = int.tryParse(match.group(6) ?? '') ?? 0;
  final ampm = match.group(7)?.toUpperCase();
  if (ampm == 'AM' && hour == 12) {
    hour = 0;
  } else if (ampm == 'PM' && hour < 12) {
    hour += 12;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return DateTime(year, month, day, hour, minute, second);
}

class _ParsedTime {
  const _ParsedTime({
    required this.hour,
    required this.minute,
    required this.second,
  });

  final int hour;
  final int minute;
  final int second;
}

_ParsedTime? _parseTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) {
    return _ParsedTime(
      hour: value.hour,
      minute: value.minute,
      second: value.second,
    );
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final match = RegExp(
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  var hour = int.tryParse(match.group(1) ?? '') ?? 0;
  final minute = int.tryParse(match.group(2) ?? '') ?? 0;
  final second = int.tryParse(match.group(3) ?? '') ?? 0;
  final ampm = match.group(4)?.toUpperCase();
  if (ampm == 'AM' && hour == 12) {
    hour = 0;
  } else if (ampm == 'PM' && hour < 12) {
    hour += 12;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return _ParsedTime(hour: hour, minute: minute, second: second);
}

DateTime? _applyTime(DateTime? date, _ParsedTime? time) {
  if (date == null || time == null) return date;
  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
    time.second,
  );
}

String? _parseString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

double? _parseAmount(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final cleaned = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

Map<String, dynamic>? _extractJsonObject(String raw) {
  var text = raw.trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '');
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3);
    }
  }
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) return null;
  final jsonStr = text.substring(start, end + 1);
  try {
    final decoded = jsonDecode(jsonStr);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
