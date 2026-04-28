import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});
  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  final _db = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;
  final _rupeeFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  // ── Generate random 4-char alphanumeric code ──────────────────────────────
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Create Split Room ─────────────────────────────────────────────────────
  void _showCreateSheet() {
    final billCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final fKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          Future<void> create() async {
            if (!fKey.currentState!.validate()) return;
            ss(() => saving = true);
            try {
              final code = _generateCode();
              await _db.collection('splits').doc(code).set({
                'billName': billCtrl.text.trim(),
                'totalAmount': double.parse(amtCtrl.text.trim()),
                'creatorEmail': _user?.email,
                'members': [_user?.email],
                'memberDetails': {}, // Will hold { email: { amount: 0, status: 'unpaid' } }
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _showCodeDialog(code, billCtrl.text.trim());
              }
            } catch (_) {
              ss(() => saving = false);
            }
          }

          return _BottomSheet(
            title: 'Create Split Room',
            subtitle: 'A unique room code will be generated for you',
            icon: Icons.group_add_outlined,
            saving: saving,
            onSave: create,
            formKey: fKey,
            fields: [
              TextFormField(
                controller: billCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Bill Name',
                  prefixIcon: Icon(Icons.description_outlined,
                      color: Color(0xFF7986CB)),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amtCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => create(),
                style: GoogleFonts.inter(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Total Amount',
                  prefixIcon: Icon(Icons.currency_rupee_rounded,
                      color: Color(0xFF7986CB)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final p = double.tryParse(v.trim());
                  if (p == null || p <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
            ],
            buttonLabel: 'Create Room',
          );
        },
      ),
    );
  }

  // ── Show generated code dialog ────────────────────────────────────────────
  void _showCodeDialog(String code, String billName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Room Created! 🎉',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Share this code with your group to split "$billName":',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              code,
              style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 10),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Code "$code" copied!',
                      style: GoogleFonts.inter()),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: Text('Copy Code',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Join Split Room ───────────────────────────────────────────────────────
  void _showJoinSheet() {
    final codeCtrl = TextEditingController();
    final fKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          Future<void> join() async {
            if (!fKey.currentState!.validate()) return;
            ss(() => saving = true);
            try {
              final code = codeCtrl.text.trim().toUpperCase();
              final docSnap = await _db.collection('splits').doc(code).get();
              
              if (!docSnap.exists) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Room "$code" not found.',
                          style: GoogleFonts.inter()),
                      backgroundColor: Colors.red.shade400,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
                return;
              }

              final data = docSnap.data()!;
              final members = List<String>.from(data['members'] ?? []);
              final email = _user!.email!;

              if (members.contains(email)) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('You are already in this room!',
                          style: GoogleFonts.inter()),
                      backgroundColor: Colors.orange.shade600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }

              // Add user to members array AND initialize their memberDetails
              await _db.collection('splits').doc(code).update({
                'members': FieldValue.arrayUnion([email]),
                FieldPath(['memberDetails', email]): {
                  'amount': 0.0,
                  'status': 'unpaid',
                }
              });

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Joined room "$code" successfully!',
                        style: GoogleFonts.inter()),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            } catch (_) {
              ss(() => saving = false);
            }
          }

          return _BottomSheet(
            title: 'Join a Room',
            subtitle: 'Enter the 4-character code shared by your group',
            icon: Icons.login_rounded,
            saving: saving,
            onSave: join,
            formKey: fKey,
            fields: [
              TextFormField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => join(),
                maxLength: 4,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: const Color(0xFF3F51B5)),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Room Code',
                  counterText: '',
                  prefixIcon: Icon(Icons.tag_rounded,
                      color: Color(0xFF7986CB)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length != 4) return 'Code must be 4 characters';
                  return null;
                },
              ),
            ],
            buttonLabel: 'Join Room',
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
        title: Text('Split Rooms',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        // ── Action Buttons ─────────────────────────────────────────────────
        Container(
          color: const Color(0xFF3F51B5),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(children: [
            Expanded(
              child: _ActionButton(
                label: 'Create Room',
                icon: Icons.add_circle_outline_rounded,
                onTap: _showCreateSheet,
                filled: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: 'Join Room',
                icon: Icons.login_rounded,
                onTap: _showJoinSheet,
                filled: false,
              ),
            ),
          ]),
        ),

        // ── Live Splits List ───────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('splits')
                .where('members', arrayContains: _user?.email)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF3F51B5)));
              }
              // Retrieve and locally sort docs to bypass missing composite index
              final docs = snap.data?.docs.toList() ?? [];
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime); // descending
              });
              
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_outlined,
                          size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No rooms yet',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400])),
                      const SizedBox(height: 6),
                      Text('Create or join a room to split bills',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final code = docs[i].id;
                  final isCreator = data['creatorEmail'] == _user?.email;

                  return _SplitCard(
                    code: code,
                    data: data,
                    isCreator: isCreator,
                    currentUserEmail: _user!.email!,
                    rupeeFmt: _rupeeFmt,
                    db: _db,
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Reusable Bottom Sheet wrapper ─────────────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.saving,
    required this.onSave,
    required this.formKey,
    required this.fields,
    required this.buttonLabel,
  });
  final String title, subtitle, buttonLabel;
  final IconData icon;
  final bool saving;
  final VoidCallback onSave;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF3F51B5), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(subtitle,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[500])),
                    ]),
              ),
            ]),
            const SizedBox(height: 24),
            ...fields,
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(buttonLabel),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: filled
              ? null
              : Border.all(color: Colors.white54, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 20,
              color: filled
                  ? const Color(0xFF3F51B5)
                  : Colors.white),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: filled ? const Color(0xFF3F51B5) : Colors.white,
              )),
        ]),
      ),
    );
  }
}

// ── Split Card ────────────────────────────────────────────────────────────────
class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.code,
    required this.data,
    required this.isCreator,
    required this.currentUserEmail,
    required this.rupeeFmt,
    required this.db,
  });
  
  final String code;
  final Map<String, dynamic> data;
  final bool isCreator;
  final String currentUserEmail;
  final NumberFormat rupeeFmt;
  final FirebaseFirestore db;

  // CREATOR ACTIONS
  void _manageSplits(BuildContext context) {
    final memberDetails = data['memberDetails'] as Map<String, dynamic>? ?? {};
    final members = List<String>.from(data['members'] ?? []);
    final joiners = members.where((e) => e != currentUserEmail).toList();

    // Controllers map for each joiner
    final controllers = <String, TextEditingController>{};
    for (var email in joiners) {
      final currentAmt = (memberDetails[email]?['amount'] as num?)?.toDouble() ?? 0.0;
      controllers[email] = TextEditingController(text: currentAmt > 0 ? currentAmt.toStringAsFixed(0) : '');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        bool saving = false;

        Future<void> save() async {
          setState(() => saving = true);
          Map<Object, dynamic> updates = {};
          for (var email in joiners) {
            final val = double.tryParse(controllers[email]!.text) ?? 0.0;
            updates[FieldPath(['memberDetails', email, 'amount'])] = val;
            // if amount changed and was paid, maybe reset to unpaid? keeping it simple for now.
          }
          await db.collection('splits').doc(code).update(updates);
          if (ctx.mounted) Navigator.pop(ctx);
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Manage Splits', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Assign how much each person owes you', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 16),
                
                if (joiners.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text("No one has joined yet.\nShare the code $code!", textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey[500])),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: joiners.length,
                      itemBuilder: (context, i) {
                        final email = joiners[i];
                        final status = memberDetails[email]?['status'] ?? 'unpaid';
                        final isPaid = status == 'paid';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPaid ? Colors.green.shade100 : const Color(0xFFF0F2FF),
                            child: Icon(isPaid ? Icons.check_circle : Icons.person, 
                                color: isPaid ? Colors.green : const Color(0xFF3F51B5), size: 20),
                          ),
                          title: Text(email.split('@')[0], style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(isPaid ? 'Paid' : 'Unpaid', style: GoogleFonts.inter(fontSize: 12, color: isPaid ? Colors.green : Colors.orange)),
                          trailing: SizedBox(
                            width: 100,
                            child: TextField(
                              controller: controllers[email],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving || joiners.isEmpty ? null : save,
                      child: saving 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Amounts'),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  void _deleteRoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Room?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('This will permanently delete this split room for everyone.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              db.collection('splits').doc(code).delete();
              Navigator.pop(ctx);
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }

  // JOINER ACTIONS
  void _markAsPaid(BuildContext context) {
    db.collection('splits').doc(code).update({
      FieldPath(['memberDetails', currentUserEmail, 'status']): 'paid'
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as paid!'), backgroundColor: Colors.green));
  }

  void _leaveRoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave Room?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to leave this room?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              db.collection('splits').doc(code).update({
                'members': FieldValue.arrayRemove([currentUserEmail]),
                FieldPath(['memberDetails', currentUserEmail]): FieldValue.delete(),
              });
              Navigator.pop(ctx);
            }, 
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }


  @override
  Widget build(BuildContext context) {
    final billName = data['billName'] ?? '';
    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    
    final memberDetails = data['memberDetails'] as Map<String, dynamic>? ?? {};
    final myDetails = memberDetails[currentUserEmail] as Map<String, dynamic>? ?? {};
    
    final myAmountOwe = (myDetails['amount'] as num?)?.toDouble() ?? 0.0;
    final myStatus = myDetails['status'] ?? 'unpaid';
    final isPaid = myStatus == 'paid';

    // Calculate total owed to creator
    double totalAssigned = 0;
    double totalCollected = 0;
    memberDetails.forEach((key, val) {
      final amt = (val['amount'] as num?)?.toDouble() ?? 0.0;
      totalAssigned += amt;
      if (val['status'] == 'paid') totalCollected += amt;
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        // ── Card header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(billName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('Total Bill: ${rupeeFmt.format(total)}', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                    ]),
              ),
              // Room code badge
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Code "$code" copied!'), behavior: SnackBarBehavior.floating),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text(code, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3)),
                    Text('tap to copy', style: GoogleFonts.inter(fontSize: 9, color: Colors.white60)),
                  ]),
                ),
              ),
            ],
          ),
        ),

        // ── Dynamic Body based on Role ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(18),
          child: isCreator ? _buildCreatorBody(totalAssigned, totalCollected) : _buildJoinerBody(myAmountOwe, isPaid),
        ),

        // ── Actions ──────────────────────────────────────────────────────
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: isCreator
                ? [
                    TextButton.icon(
                      onPressed: () => _manageSplits(context),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: Text('Manage Splits', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteRoom(context),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: Text('Delete Room', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red)),
                    ),
                  ]
                : [
                    TextButton.icon(
                      onPressed: (isPaid || myAmountOwe == 0) ? null : () => _markAsPaid(context),
                      icon: Icon(Icons.check_circle_outline, color: (isPaid || myAmountOwe == 0) ? Colors.grey : Colors.green),
                      label: Text(isPaid ? 'Paid' : 'Mark Paid', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: (isPaid || myAmountOwe == 0) ? Colors.grey : Colors.green)),
                    ),
                    TextButton.icon(
                      onPressed: () => _leaveRoom(context),
                      icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
                      label: Text('Leave Room', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red)),
                    ),
                  ],
          ),
        )
      ]),
    );
  }

  Widget _buildCreatorBody(double totalAssigned, double totalCollected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('You are owed', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(rupeeFmt.format(totalAssigned), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3F51B5))),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Collected', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(rupeeFmt.format(totalCollected), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.green)),
        ]),
      ],
    );
  }

  Widget _buildJoinerBody(double myAmountOwe, bool isPaid) {
    if (myAmountOwe == 0) {
      return Row(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.orange[400], size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text("Waiting for creator to assign your split amount.", style: GoogleFonts.inter(color: Colors.orange[700], fontSize: 13))),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('You Owe', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(rupeeFmt.format(myAmountOwe), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: isPaid ? Colors.green : const Color(0xFF3F51B5))),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isPaid ? Colors.green.shade200 : Colors.orange.shade200)
          ),
          child: Text(isPaid ? 'PAID' : 'UNPAID', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isPaid ? Colors.green.shade700 : Colors.orange.shade700)),
        ),
      ],
    );
  }
}
