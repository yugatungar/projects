import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _rupeeFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  
  final List<String> _categories = [
    'Food & Dining',
    'Transport',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBudget());
  }

  // ── Personal Budget Management ────────────────────────────────────────────
  String get _userEmail => _auth.currentUser?.email ?? 'unknown';

  Future<void> _checkBudget() async {
    final doc = await _db.collection('user_budgets').doc(_userEmail).get();
    if (!doc.exists && mounted) _showBudgetDialog();
  }

  void _showBudgetDialog() {
    final ctrl = TextEditingController();
    final key = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Set Personal Budget", style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              content: Form(
                key: key,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("Enter your personal monthly budget to track your spending.",
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: const InputDecoration(
                      labelText: "Monthly Budget (₹)",
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF7986CB)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                ]),
              ),
              actions: [
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!key.currentState!.validate()) return;
                          setState(() => saving = true);
                          await _db
                              .collection('user_budgets')
                              .doc(_userEmail)
                              .set({'amount': int.parse(ctrl.text.trim())});
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  child: saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Budget'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _deleteExpense(String id) => _db.collection('personal_expenses').doc(id).delete();

  // ── Add Expense Sheet ─────────────────────────────────────────────────────
  void _showAddSheet() {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String? selectedCat;
    final fKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          Future<void> save() async {
            if (!fKey.currentState!.validate() || selectedCat == null) {
              if (selectedCat == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select a category')));
              }
              return;
            }
            ss(() => saving = true);
            try {
              await _db.collection('personal_expenses').add({
                'title': titleCtrl.text.trim(),
                'amount': double.parse(amtCtrl.text.trim()),
                'category': selectedCat,
                'addedBy': _userEmail,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (_) {
              ss(() => saving = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Form(
                key: fKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(99))),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Add Personal Expense', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: const InputDecoration(labelText: 'Expense title', prefixIcon: Icon(Icons.edit_note_rounded, color: Color(0xFF7986CB))),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.currency_rupee_rounded, color: Color(0xFF7986CB))),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final p = double.tryParse(v.trim());
                      if (p == null || p <= 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCat,
                    hint: Text('Select Category', style: GoogleFonts.inter(fontSize: 15)),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF7986CB))),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 15)))).toList(),
                    onChanged: (v) => ss(() => selectedCat = v),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : save,
                      child: saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Save Expense'),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('My Budget', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              const Icon(Icons.person_outline, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(_userEmail, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_split_rounded),
            onPressed: () => Navigator.pushNamed(context, '/splits'),
            tooltip: 'Split Rooms',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('user_budgets').doc(_userEmail).snapshots(),
        builder: (context, budgetSnap) {
          final budgetData = budgetSnap.data?.data() as Map<String, dynamic>?;
          final budget = (budgetData?['amount'] as num?)?.toDouble() ?? 0.0;

          return StreamBuilder<QuerySnapshot>(
            stream: _db.collection('personal_expenses').where('addedBy', isEqualTo: _userEmail).snapshots(),
            builder: (context, expSnap) {
              if (expSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Locally sort expenses to bypass Firestore missing index on orderBy+where
              final docs = expSnap.data?.docs.toList() ?? [];
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              double totalSpent = 0;
              Map<String, double> categorySpends = {};
              for (var c in _categories) {
                categorySpends[c] = 0.0;
              }

              for (final d in docs) {
                final data = d.data() as Map<String, dynamic>;
                final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final cat = data['category'] as String? ?? 'Other';
                totalSpent += amt;
                if (categorySpends.containsKey(cat)) {
                  categorySpends[cat] = categorySpends[cat]! + amt;
                } else {
                  categorySpends['Other'] = (categorySpends['Other'] ?? 0) + amt;
                }
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _BudgetOverview(
                      budget: budget,
                      totalSpent: totalSpent,
                      categorySpends: categorySpends,
                      rupeeFmt: _rupeeFmt,
                      onEditBudget: () => _showBudgetDialog(),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Recent Expenses', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
                    ),
                  ),
                  if (docs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No personal expenses', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                        ]),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final doc = docs[i];
                          final data = doc.data() as Map<String, dynamic>;
                          final title = data['title'] ?? '';
                          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                          final cat = data['category'] ?? 'Other';
                          final ts = data['createdAt'] as Timestamp?;
                          final dateStr = ts != null ? DateFormat('dd MMM, hh:mm a').format(ts.toDate()) : '';

                          return Dismissible(
                            key: Key(doc.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                            ),
                            onDismissed: (_) => _deleteExpense(doc.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _ExpenseCard(title: title, amount: amount, category: cat, dateStr: dateStr, rupeeFmt: _rupeeFmt),
                            ),
                          );
                        },
                        childCount: docs.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)), // FAB padding
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Personal Budget Overview & Insights ─────────────────────────────────────
class _BudgetOverview extends StatelessWidget {
  const _BudgetOverview({
    required this.budget,
    required this.totalSpent,
    required this.categorySpends,
    required this.rupeeFmt,
    required this.onEditBudget,
  });

  final double budget, totalSpent;
  final Map<String, double> categorySpends;
  final NumberFormat rupeeFmt;
  final VoidCallback onEditBudget;

  String _getSmartSuggestion() {
    if (totalSpent == 0) return "Great start! Track your first expense.";
    if (totalSpent > budget) return "⚠️ You are over budget! Avoid any non-essential spending.";
    
    // Find highest spend category
    String maxCat = 'Other';
    double maxAmt = 0;
    categorySpends.forEach((key, value) {
      if (value > maxAmt) { maxAmt = value; maxCat = key; }
    });

    final percent = (maxAmt / totalSpent) * 100;
    
    if (percent > 50) {
      if (maxCat == 'Food & Dining') return "💡 You spent ${percent.toStringAsFixed(0)}% on Food. Try meal prepping to save more!";
      if (maxCat == 'Shopping') return "💡 ${percent.toStringAsFixed(0)}% went to Shopping. Consider a 30-day rule before buying.";
      if (maxCat == 'Entertainment') return "💡 High Entertainment spend. Look for free local activities!";
      if (maxCat == 'Transport') return "💡 High Transport costs. Could you carpool or use public transit?";
    }

    if (totalSpent > budget * 0.8) return "Careful! You've used 80% of your budget. Slow down spending.";
    
    return "You're doing great! Keep your spending balanced.";
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Food & Dining': return Colors.orange;
      case 'Transport': return Colors.blue;
      case 'Shopping': return Colors.pink;
      case 'Entertainment': return Colors.purple;
      case 'Bills & Utilities': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = budget - totalSpent;
    final isOver = remaining < 0;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Monthly Overview', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey[600])),
            GestureDetector(
              onTap: onEditBudget,
              child: Text('Edit Budget', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF3F51B5), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Text(budget == 0 
              ? 'Budget not set' 
              : (isOver ? '${rupeeFmt.format(remaining.abs())} Over Budget' : '${rupeeFmt.format(remaining)} Left'),
            style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: budget == 0 ? Colors.grey[400] : (isOver ? Colors.red : const Color(0xFF1A1A2E)))),
        Text(budget == 0 
              ? 'Tap "Edit Budget" to get started' 
              : '${rupeeFmt.format(totalSpent)} spent out of ${rupeeFmt.format(budget)}',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
        
        const SizedBox(height: 20),

        // ── Visual Spending Bar Chart ──────────────────────────────────────
        if (totalSpent > 0) ...[
          Text('Spending by Category', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 16,
              child: Row(
                children: categorySpends.entries.where((e) => e.value > 0).map((e) {
                  final flex = (e.value * 1000).toInt();
                  return Expanded(
                    flex: flex,
                    child: Container(color: _getCategoryColor(e.key), margin: const EdgeInsets.only(right: 2)),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12, runSpacing: 8,
            children: categorySpends.entries.where((e) => e.value > 0).map((e) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _getCategoryColor(e.key), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${e.key} (${((e.value/totalSpent)*100).toStringAsFixed(0)}%)', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
                ],
              );
            }).toList(),
          ),
        ] else ...[
          LinearProgressIndicator(value: 0, minHeight: 12, backgroundColor: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
        ],

        const SizedBox(height: 24),

        // ── Smart Suggestion Box ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isOver ? Colors.red.shade50 : const Color(0xFFF0F2FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isOver ? Colors.red.shade200 : const Color(0xFFD9DEFF)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(isOver ? Icons.warning_amber_rounded : Icons.lightbulb_outline_rounded, 
                   color: isOver ? Colors.red : const Color(0xFF3F51B5), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_getSmartSuggestion(),
                    style: GoogleFonts.inter(fontSize: 13, color: isOver ? Colors.red.shade900 : const Color(0xFF3F51B5), fontWeight: FontWeight.w500, height: 1.4)),
              ),
            ],
          ),
        )
      ]),
    );
  }
}

// ── Expense Card ──────────────────────────────────────────────────────────────
class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.title, required this.amount, required this.category, required this.dateStr, required this.rupeeFmt});
  final String title, category, dateStr;
  final double amount;
  final NumberFormat rupeeFmt;

  IconData _getIcon() {
    switch(category) {
      case 'Food & Dining': return Icons.restaurant;
      case 'Transport': return Icons.directions_car;
      case 'Shopping': return Icons.shopping_bag;
      case 'Entertainment': return Icons.movie;
      case 'Bills & Utilities': return Icons.receipt;
      default: return Icons.money;
    }
  }

  Color _getColor() {
    switch(category) {
      case 'Food & Dining': return Colors.orange;
      case 'Transport': return Colors.blue;
      case 'Shopping': return Colors.pink;
      case 'Entertainment': return Colors.purple;
      case 'Bills & Utilities': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _getColor().withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(_getIcon(), color: _getColor(), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Text(category, style: GoogleFonts.inter(fontSize: 11, color: _getColor(), fontWeight: FontWeight.w600)),
                if (dateStr.isNotEmpty) ...[
                  Text(' • ', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  Text(dateStr, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                ]
              ]),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(rupeeFmt.format(amount), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E))),
      ]),
    );
  }
}
