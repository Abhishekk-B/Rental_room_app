import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/advance_provider.dart';

class AdvanceLedgerScreen extends ConsumerStatefulWidget {
  final String tenancyId;
  final String tenantName;
  final String? initialAccountType;

  const AdvanceLedgerScreen({
    Key? key,
    required this.tenancyId,
    required this.tenantName,
    this.initialAccountType,
  }) : super(key: key);

  @override
  ConsumerState<AdvanceLedgerScreen> createState() => _AdvanceLedgerScreenState();
}

class _AdvanceLedgerScreenState extends ConsumerState<AdvanceLedgerScreen> {
  late String _selectedAccount;

  @override
  void initState() {
    super.initState();
    _selectedAccount = widget.initialAccountType ?? 'ALL';
  }

  @override
  Widget build(BuildContext context) {
    final filter = LedgerHistoryFilter(
      tenancyId: widget.tenancyId,
      accountType: _selectedAccount,
    );
    final historyAsync = ref.watch(advanceLedgerHistoryProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Advance Account Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.tenantName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All Accounts', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterChip('Rent Advance', 'RENT_ADVANCE'),
                const SizedBox(width: 8),
                _buildFilterChip('Elec. Advance', 'ELECTRICITY_ADVANCE'),
                const SizedBox(width: 8),
                _buildFilterChip('Security Deposit', 'SECURITY_DEPOSIT'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: historyAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Ledger Entries',
                    message: 'No transactions recorded for the selected advance account.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = entries[index];
                    final isCredit = item.transactionType == 'CREDIT_RECEIVED' || item.transactionType == 'TRANSFER_IN';
                    final color = isCredit ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                          child: Icon(
                            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              '${item.accountType.replaceAll('_', ' ')} • ${DateHelper.formatEpoch(item.entryDateEpoch)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Text(
                          '${isCredit ? "+" : "-"} ${CurrencyHelper.formatPaise(item.amountPaise)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: color,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedAccount == value,
      onSelected: (_) => setState(() => _selectedAccount = value),
    );
  }
}
