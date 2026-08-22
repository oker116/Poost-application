import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'auth_service.dart';

const _bg = Color(0xFF070D18), _surface = Color(0xFF0D1725), _cyan = Color(0xFF42D7E8);

class MyAccountsPage extends StatefulWidget {
  const MyAccountsPage({super.key});
  @override
  State<MyAccountsPage> createState() => _MyAccountsPageState();
}

class _MyAccountsPageState extends State<MyAccountsPage> {
  bool busy = true;
  String? error;
  double totalCommission = 0;
  double totalExpenses = 0;
  List<Map<String, dynamic>> expenses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final db = Supabase.instance.client;
      final commissions = await db.from('commissions').select('total_commission');
      double com = 0;
      for (final row in (commissions as List)) {
        com += (row['total_commission'] as num?)?.toDouble() ?? 0;
      }
      final expRows = await db.from('agency_expenses').select('id, expense_date, amount, note').order('expense_date', ascending: false);
      double exp = 0;
      for (final row in (expRows as List)) {
        exp += (row['amount'] as num).toDouble();
      }
      if (mounted) {
        setState(() {
          totalCommission = com;
          totalExpenses = exp;
          expenses = List<Map<String, dynamic>>.from(expRows);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = describeAuthError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  double get netProfit => totalCommission - totalExpenses;
  bool get profitable => netProfit >= 0;

  Future<void> _addExpenseDialog() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('مصروف جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                        context: ctx, initialDate: date, firstDate: DateTime(2023), lastDate: DateTime.now());
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: Text('التاريخ: ${date.toIso8601String().substring(0, 10)}'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ *'),
                ),
                const SizedBox(height: 10),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'وصف (اشتراكات، مرتبات، إعلانات...)')),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: const TextStyle(color: Colors.orange)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim());
                  if (amount == null) {
                    setDialogState(() => dialogError = 'المبلغ مطلوب');
                    return;
                  }
                  try {
                    final agencyRow = await Supabase.instance.client
                        .from('profiles')
                        .select('agency_id')
                        .eq('id', Supabase.instance.client.auth.currentUser!.id)
                        .single();
                    await Supabase.instance.client.from('agency_expenses').insert({
                      'agency_id': agencyRow['agency_id'],
                      'expense_date': date.toIso8601String().substring(0, 10),
                      'amount': amount,
                      'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    });
                    if (mounted) Navigator.pop(ctx);
                    _load();
                  } catch (e) {
                    setDialogState(() => dialogError = describeAuthError(e));
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('حساباتي — ربحية الوكالة')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addExpenseDialog,
          icon: const Icon(Icons.add),
          label: const Text('مصروف جديد'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: busy
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (error != null) Text(error!, style: const TextStyle(color: Colors.orange)),
                    // --- verdict banner ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: (profitable ? Colors.greenAccent : Colors.redAccent).withOpacity(0.1),
                        border: Border.all(color: (profitable ? Colors.greenAccent : Colors.redAccent).withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(profitable ? Icons.trending_up : Icons.trending_down,
                              size: 34, color: profitable ? Colors.greenAccent : Colors.redAccent),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profitable ? 'شركتك بتكسب' : 'شركتك بتخسر',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: profitable ? Colors.greenAccent : Colors.redAccent),
                                ),
                                const SizedBox(height: 4),
                                Text('صافي الربح: ${netProfit.toStringAsFixed(0)}',
                                    style: TextStyle(color: Colors.grey.shade300)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _kpi('إجمالي العمولات', totalCommission.toStringAsFixed(0), Icons.savings, Colors.purpleAccent)),
                        const SizedBox(width: 10),
                        Expanded(child: _kpi('إجمالي المصاريف', totalExpenses.toStringAsFixed(0), Icons.receipt_long, Colors.redAccent)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (totalCommission > 0 || totalExpenses > 0) ...[
                      const Text('مقارنة العمولات بالمصاريف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      Container(
                        height: 180,
                        padding: const EdgeInsets.fromLTRB(6, 16, 16, 6),
                        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
                        child: BarChart(
                          BarChartData(
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, meta) => Text(
                                    v == 0 ? 'عمولات' : 'مصاريف',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                            barGroups: [
                              BarChartGroupData(x: 0, barRods: [
                                BarChartRodData(toY: totalCommission, color: Colors.purpleAccent, width: 40, borderRadius: BorderRadius.circular(6)),
                              ]),
                              BarChartGroupData(x: 1, barRods: [
                                BarChartRodData(toY: totalExpenses, color: Colors.redAccent, width: 40, borderRadius: BorderRadius.circular(6)),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        profitable
                            ? 'ده معناه إن العمولات اللي جمعتها من عملائك أكتر من المصاريف اللي سجّلتها. لو الفرق صغير، خليك حذر لأن أي مصروف مفاجئ ممكن يقلب الوضع.'
                            : 'ده معناه إن المصاريف المسجّلة أكبر من العمولات اللي جمعتها لحد دلوقتي. ممكن يكون طبيعي في بداية الشهر لو العمولات بتتحصّل آخر الشهر، أو محتاج تراجع تسعيرك مع العملاء.',
                        style: TextStyle(color: Colors.grey.shade400, height: 1.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('سجل المصاريف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    if (expenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('مفيش مصاريف مسجلة لسه.', style: TextStyle(color: Colors.grey.shade500)),
                      )
                    else
                      ...expenses.map((e) => Card(
                            child: ListTile(
                              title: Text((e['amount'] as num).toStringAsFixed(0)),
                              subtitle: Text([e['expense_date'].toString(), if (e['note'] != null) e['note']].join(' • ')),
                            ),
                          )),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color accent) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
          ]),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accent)),
        ]),
      );
}
