import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'auth_service.dart';

const _surface = Color(0xFF0D1725);

class _ClientPnl {
  final String id;
  final String name;
  final double spend;
  final double sales;
  double get profit => sales - spend;
  double get roas => spend > 0 ? sales / spend : 0;
  _ClientPnl(this.id, this.name, this.spend, this.sales);
}

class ClientsProfitabilityPage extends StatefulWidget {
  const ClientsProfitabilityPage({super.key});
  @override
  State<ClientsProfitabilityPage> createState() => _ClientsProfitabilityPageState();
}

class _ClientsProfitabilityPageState extends State<ClientsProfitabilityPage> {
  bool busy = true;
  String? error;
  List<_ClientPnl> data = [];

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
      final clients = await db.from('clients').select('id, company_name');
      final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
      final metrics = await db.from('daily_metrics').select('client_id, spend, sales').gte('metric_date', since);

      final byClient = <String, Map<String, double>>{};
      for (final row in (metrics as List)) {
        final id = row['client_id'] as String;
        final m = byClient.putIfAbsent(id, () => {'spend': 0, 'sales': 0});
        m['spend'] = m['spend']! + (row['spend'] as num).toDouble();
        m['sales'] = m['sales']! + (row['sales'] as num).toDouble();
      }

      final list = <_ClientPnl>[];
      for (final c in (clients as List)) {
        final m = byClient[c['id']] ?? {'spend': 0, 'sales': 0};
        list.add(_ClientPnl(c['id'] as String, c['company_name'] as String, m['spend']!, m['sales']!));
      }
      list.sort((a, b) => b.profit.compareTo(a.profit));
      if (mounted) setState(() => data = list);
    } catch (e) {
      if (mounted) setState(() => error = describeAuthError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final profitable = data.where((d) => d.profit >= 0).length;
    final losing = data.length - profitable;
    final maxAbs = data.fold<double>(1, (m, d) => d.profit.abs() > m ? d.profit.abs() : m);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('أرباح العملاء')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: busy
              ? const Center(child: CircularProgressIndicator())
              : data.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 80),
                      Center(child: Text('مفيش بيانات كافية لسه.', style: TextStyle(color: Colors.grey.shade500))),
                    ])
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (error != null) Text(error!, style: const TextStyle(color: Colors.orange)),
                        Text('آخر 30 يوم', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
                                child: Column(children: [
                                  Text('$profitable', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                  const SizedBox(height: 4),
                                  Text('عميل بيكسب', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                ]),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                                child: Column(children: [
                                  Text('$losing', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                  const SizedBox(height: 4),
                                  Text('عميل بيخسر', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                ]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('مقارنة صافي الربح لكل عميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 10),
                        Container(
                          height: 220,
                          padding: const EdgeInsets.fromLTRB(6, 16, 16, 6),
                          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
                          child: BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              maxY: maxAbs * 1.2,
                              minY: -maxAbs * 1.2,
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 60,
                                    getTitlesWidget: (v, meta) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= data.length) return const SizedBox.shrink();
                                      final name = data[i].name;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Transform.rotate(
                                          angle: -0.6,
                                          child: Text(name.length > 8 ? '${name.substring(0, 8)}…' : name,
                                              style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (int i = 0; i < data.length; i++)
                                  BarChartGroupData(x: i, barRods: [
                                    BarChartRodData(
                                      toY: data[i].profit,
                                      color: data[i].profit >= 0 ? Colors.greenAccent : Colors.redAccent,
                                      width: 18,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('تفاصيل العملاء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        ...data.map((d) => Card(
                              child: ListTile(
                                leading: Icon(d.profit >= 0 ? Icons.trending_up : Icons.trending_down,
                                    color: d.profit >= 0 ? Colors.greenAccent : Colors.redAccent),
                                title: Text(d.name),
                                subtitle: Text('Spend: ${d.spend.toStringAsFixed(0)} • Sales: ${d.sales.toStringAsFixed(0)} • ROAS: ${d.roas.toStringAsFixed(2)}'),
                                trailing: Text(
                                  d.profit.toStringAsFixed(0),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: d.profit >= 0 ? Colors.greenAccent : Colors.redAccent),
                                ),
                              ),
                            )),
                      ],
                    ),
        ),
      ),
    );
  }
}
