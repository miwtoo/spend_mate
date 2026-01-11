import 'package:flutter/material.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_transaction_repository.dart';
import 'package:spend_mate/data/services/firefly/firefly_api_service.dart';
import 'package:spend_mate/domain/models/firefly_transaction_summary.dart';
import 'package:spend_mate/ui/features/ai_chat/ai_chat_screen.dart';
import 'package:spend_mate/ui/features/auto_import/auto_import_screen.dart';
import 'package:spend_mate/ui/features/transactions/view_models/transactions_view_model.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.configRepository,
    required this.fireflyConfigRepository,
  });

  final AiProviderConfigRepository configRepository;
  final FireflyConfigRepository fireflyConfigRepository;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final TransactionsViewModel _vm;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _vm = TransactionsViewModel(
      configRepository: widget.fireflyConfigRepository,
      transactionRepository: FireflyTransactionRepository(
        configRepository: widget.fireflyConfigRepository,
        apiService: FireflyApiService(),
      ),
    );
    _initFuture = _vm.loadTransactions();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _openAiChat(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiChatScreen(
          configRepository: widget.configRepository,
        ),
      ),
    );
  }

  Future<void> _openAutoImport(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AutoImportScreen(
          configRepository: widget.configRepository,
          fireflyConfigRepository: widget.fireflyConfigRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          return AnimatedBuilder(
            animation: _vm,
            builder: (context, _) {
              if (_vm.error != null) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick actions',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _openAutoImport(context),
                                  icon: const Icon(
                                      Icons.auto_awesome_motion_outlined),
                                  label: const Text('Auto Import'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _openAiChat(context),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('AI Chat'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    MaterialBanner(
                      content: Text(_vm.error!),
                      leading: const Icon(Icons.error_outline),
                      actions: [
                        TextButton(
                          onPressed: _vm.refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return RefreshIndicator(
                onRefresh: _vm.refresh,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick actions',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _openAutoImport(context),
                                  icon: const Icon(
                                      Icons.auto_awesome_motion_outlined),
                                  label: const Text('Auto Import'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _openAiChat(context),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('AI Chat'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All transactions',
                          style: theme.textTheme.titleMedium,
                        ),
                        if (_vm.isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_vm.transactions.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.receipt_long),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No transactions yet. Connect to Firefly III and import transactions to see them here.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._buildTransactionList(context, _vm.transactions),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildTransactionList(
      BuildContext context, List<FireflyTransactionSummary> transactions) {
    final widgets = <Widget>[];
    DateTime? currentMonth;
    final theme = Theme.of(context);

    for (final transaction in transactions) {
      final monthKey = DateTime(transaction.date.year, transaction.date.month);
      final monthChanged =
          currentMonth == null || !_sameMonth(currentMonth, monthKey);

      if (monthChanged) {
        if (currentMonth != null) {
          widgets.add(const SizedBox(height: 16));
        }
        widgets.add(
          Text(
            _formatMonthYear(monthKey),
            style: theme.textTheme.titleSmall,
          ),
        );
        widgets.add(const SizedBox(height: 8));
        currentMonth = monthKey;
      }

      widgets.add(_TransactionCard(transaction: transaction));
    }

    return widgets;
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final FireflyTransactionSummary transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

    final dateLabel = localizations.formatShortDate(transaction.date);
    final amountLabel =
        _formatAmount(transaction.amount, transaction.currencyCode);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _getIconForType(transaction.type),
        title: Text(transaction.description),
        subtitle: Text(
          '$dateLabel • ${transaction.sourceName} → ${transaction.destinationName}',
        ),
        trailing: Text(
          amountLabel,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'withdrawal':
        return const Icon(Icons.arrow_upward, color: Colors.red);
      case 'deposit':
        return const Icon(Icons.arrow_downward, color: Colors.green);
      case 'transfer':
        return const Icon(Icons.swap_horiz, color: Colors.blue);
      default:
        return const Icon(Icons.help_outline);
    }
  }

  String _formatAmount(double amount, String? currency) {
    final value = amount.abs().toStringAsFixed(2);
    final prefix = amount < 0 ? '-' : '+';
    if (currency == null || currency.trim().isEmpty) {
      return '$prefix$value';
    }
    return '$prefix$value ${currency.trim()}';
  }
}
