class FireflyTransactionSummary {
  const FireflyTransactionSummary({
    required this.transactionId,
    required this.transactionJournalId,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.sourceName,
    required this.destinationName,
    this.currencyCode,
    this.isSplit = false,
  });

  final String transactionId;
  final String transactionJournalId;
  final String description;
  final double amount;
  final DateTime date;
  final String type;
  final String sourceName;
  final String destinationName;
  final String? currencyCode;
  final bool isSplit;
}
