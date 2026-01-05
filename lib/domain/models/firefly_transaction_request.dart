class FireflyTransactionRequest {
  const FireflyTransactionRequest({
    required this.transactions,
    this.applyRules = true,
    this.fireWebhooks = true,
    this.errorIfDuplicateHash,
    this.groupTitle,
  });

  final bool applyRules;
  final bool fireWebhooks;
  final bool? errorIfDuplicateHash;
  final String? groupTitle;
  final List<FireflyTransactionSplit> transactions;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'apply_rules': applyRules,
      'fire_webhooks': fireWebhooks,
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };

    if (errorIfDuplicateHash != null) {
      payload['error_if_duplicate_hash'] = errorIfDuplicateHash;
    }
    if (groupTitle != null && groupTitle!.trim().isNotEmpty) {
      payload['group_title'] = groupTitle!.trim();
    }

    return payload;
  }
}

enum FireflyTransactionType {
  withdrawal,
  deposit,
  transfer,
}

class FireflyTransactionSplit {
  const FireflyTransactionSplit({
    required this.type,
    required this.date,
    required this.amount,
    required this.description,
    required this.sourceName,
    required this.destinationName,
    this.transactionJournalId,
    this.currencyCode,
    this.notes,
    this.categoryName,
  });

  final FireflyTransactionType type;
  final String date;
  final String amount;
  final String description;
  final String sourceName;
  final String destinationName;
  final String? transactionJournalId;
  final String? currencyCode;
  final String? notes;
  final String? categoryName;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'type': type.name,
      'date': date,
      'amount': amount,
      'description': description,
      'source_name': sourceName,
      'destination_name': destinationName,
    };

    if (transactionJournalId != null &&
        transactionJournalId!.trim().isNotEmpty) {
      payload['transaction_journal_id'] = transactionJournalId!.trim();
    }
    if (currencyCode != null && currencyCode!.trim().isNotEmpty) {
      payload['currency_code'] = currencyCode!.trim();
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      payload['notes'] = notes!.trim();
    }
    if (categoryName != null && categoryName!.trim().isNotEmpty) {
      payload['category_name'] = categoryName!.trim();
    }

    return payload;
  }
}
