import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class ClientMetricsPage extends StatefulWidget {
  final String clientId;
  final String clientName;
  const ClientMetricsPage({super.key, required this.clientId, required this.clientName});

  @override
  State<ClientMetricsPage> createState() => _ClientMetricsPageState();
}

class _ClientMetricsPageState extends State<ClientMetricsPage> {
  bool busy = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

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
      final data = await Supabase.instance.client
          .from('daily_metrics')
          .select('id, metric_date, spend, sales, orders, leads')
          .eq('client_id', widget.clientId)
          .order('metric_date', ascending: false)
          .limit(60);
      if (mounted) setState(() => rows = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) setState(() => error = describeAuthError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  double get totalSpend => rows.fold(0.0, (s, r) => s + (r['spend'] as num).toDouble());
  double get totalSales => rows.fold(0.0, (s, r) => s + (r['sales'] as num).toDouble());
  double get roas => totalSpend > 0 ? totalSales / totalSpend : 0;

  Future<void> _addEntryDialog() async {
    DateTime date = DateTime.now();
    final spendCtrl = TextEditingController();
    final salesCtrl = TextEditingController();
    final ordersCtrl = TextEditingController(text: '0');
    final leadsCtrl = TextEditingController(text: '0');
    String? dialogError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة بيانات يوم'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => date = picked);
                    },
                    child: Text('التاريخ: ${date.toIso8601String().substring(0, 10)}'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: spendCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الإنفاق (Spend) *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: salesCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'المبيعات (Sales) *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ordersCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد الطلبات'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: leadsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد الليدز'),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(dialogError!, style: const TextStyle(color: Colors.orange)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  final spend = double.tryParse(spendCtrl.text.trim());
                  final sales = double.tryParse(salesCtrl.text.trim());
                  if (spend == null || sales == null) {
                    setDialogState(() => dialogError = 'الإنفاق والمبيعات أرقام مطلوبة');
                    return;
                  }
                  try {
                    await Supabase.instance.client.from('daily_metrics').upsert({
                      'client_id': widget.clientId,
                      'metric_date': date.toIso8601String().substring(0, 10),
                      'spend': spend,
                      'sales': sales,
                      'orders': int.tryParse(ordersCtrl.text.trim()) ?? 0,
                      'leads': int.tryParse(leadsCtrl.text.trim()) ?? 0,
                      'impressions': 0,
                      'clicks': 0,
                    }, onConflict: 'client_id,metric_date');
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
        appBar: AppBar(title: Text(widget.clientName)),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addEntryDialog,
          icon: const Icon(Icons.add),
          label: const Text('إضافة يوم'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: busy
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (error != null) Text(error!, style: const TextStyle(color: Colors.orange)),
                    Row(
                      children: [
                        Expanded(child: _kpi('إجمالي الإنفاق', totalSpend.toStringAsFixed(0), icon: Icons.attach_money, accent: Colors.orangeAccent)),
                        const SizedBox(width: 10),
                        Expanded(child: _kpi('إجمالي المبيعات', totalSales.toStringAsFixed(0), icon: Icons.point_of_sale, accent: Colors.greenAccent)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _kpi('ROAS (آخر 60 يوم مسجلة)', roas.toStringAsFixed(2), icon: Icons.trending_up, accent: const Color(0xFF42D7E8)),
                    const SizedBox(height: 18),
                    const Text('السجل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text('مفيش بيانات لسه. دوس "إضافة يوم" تحت.',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ),
                      )
                    else
                      ...rows.map((r) {
                        final spend = (r['spend'] as num).toDouble();
                        final sales = (r['sales'] as num).toDouble();
                        final dayRoas = spend > 0 ? sales / spend : 0;
                        return Card(
                          child: ListTile(
                            title: Text(r['metric_date'].toString()),
                            subtitle: Text(
                                'Spend: ${spend.toStringAsFixed(0)} • Sales: ${sales.toStringAsFixed(0)} • ROAS: ${dayRoas.toStringAsFixed(2)}'),
                            trailing: Text('${r['orders']} طلب'),
                          ),
                        );
                      }),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _kpi(String label, String value, {IconData icon = Icons.insights, Color accent = const Color(0xFF42D7E8)}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1725),
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
