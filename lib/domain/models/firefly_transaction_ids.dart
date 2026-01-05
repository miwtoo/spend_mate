class FireflyTransactionIds {
  const FireflyTransactionIds({
    this.transactionId,
    this.transactionJournalId,
  });

  final String? transactionId;
  final String? transactionJournalId;

  bool get hasAny =>
      (transactionId?.trim().isNotEmpty ?? false) ||
      (transactionJournalId?.trim().isNotEmpty ?? false);

  FireflyTransactionIds copyWith({
    String? transactionId,
    String? transactionJournalId,
  }) {
    return FireflyTransactionIds(
      transactionId: transactionId ?? this.transactionId,
      transactionJournalId:
          transactionJournalId ?? this.transactionJournalId,
    );
  }
}
