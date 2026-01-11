import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/domain/models/receipt_parse_result.dart';

void main() {
  test('parses clean JSON response', () {
    const response =
        '{"amount": 12.34, "currency": "USD", "date": "2024-12-01", "merchant": "Cafe", "type": "expense", "confidence": 0.82}';
    final result = ReceiptParseResult.fromAiResponse(response);

    expect(result.amount, 12.34);
    expect(result.currency, 'USD');
    expect(result.date?.year, 2024);
    expect(result.date?.month, 12);
    expect(result.date?.day, 1);
    expect(result.merchant, 'Cafe');
    expect(result.type, ReceiptTransactionType.expense);
    expect(result.confidence, 0.82);
  });

  test('parses JSON wrapped in code fences', () {
    const response =
        '```json\n{"amount": "9.50", "currency": "EUR", "date": "2024-11-05", "merchant": "Bakery", "type": "expense"}\n```';
    final result = ReceiptParseResult.fromAiResponse(response);

    expect(result.amount, 9.50);
    expect(result.currency, 'EUR');
    expect(result.merchant, 'Bakery');
  });

  test('parses amounts with symbols', () {
    const response =
        r'{"amount": "$18.90", "currency": "$", "date": "2024-10-01"}';
    final result = ReceiptParseResult.fromAiResponse(response);

    expect(result.amount, 18.90);
    expect(result.currency, r'$');
  });

  test('throws on missing JSON', () {
    expect(
      () => ReceiptParseResult.fromAiResponse('No JSON here'),
      throwsA(isA<FormatException>()),
    );
  });

  test('applies time fields to date values', () {
    const response =
        '{"amount": "15.00", "currency": "USD", "date": "12/31/2024", "time": "11:30 PM", "type": "transfer"}';
    final result = ReceiptParseResult.fromAiResponse(response);

    expect(result.date, isNotNull);
    expect(result.date?.year, 2024);
    expect(result.date?.month, 12);
    expect(result.date?.day, 31);
    expect(result.date?.hour, 23);
    expect(result.date?.minute, 30);
    expect(result.type, ReceiptTransactionType.transfer);
  });

  test('parses date_time and credit type', () {
    const response =
        r'{"amount": "$1,234.50", "currency": "USD", "date_time": "2024-01-02T10:15:30", "type": "credit"}';
    final result = ReceiptParseResult.fromAiResponse(response);

    expect(result.amount, 1234.50);
    expect(result.date?.year, 2024);
    expect(result.date?.month, 1);
    expect(result.date?.day, 2);
    expect(result.date?.hour, 10);
    expect(result.date?.minute, 15);
    expect(result.type, ReceiptTransactionType.income);
  });
}
