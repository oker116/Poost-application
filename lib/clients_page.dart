import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'client_metrics_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  bool busy = true;
  String? error;
  List<Map<String, dynamic>> clients = [];

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
      final rows = await Supabase.instance.client
          .from('clients')
          .select('id, company_name, contact_name, status, industry')
          .order('created_at', ascending: false);
      if (mounted) setState(() => clients = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (mounted) setState(() => error = describeAuthError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _addClientDialog() async {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final industryCtrl = TextEditingController();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('عميل جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة *')),
                const SizedBox(height: 10),
                TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'اسم المسؤول')),
                const SizedBox(height: 10),
                TextField(controller: industryCtrl, decoration: const InputDecoration(labelText: 'المجال (تجميل، أزياء...)')),
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
                  if (nameCtrl.text.trim().isEmpty) {
                    setDialogState(() => dialogError = 'اسم الشركة مطلوب');
                    return;
                  }
                  try {
                    final agencyRow = await Supabase.instance.client
                        .from('profiles')
                        .select('agency_id')
                        .eq('id', Supabase.instance.client.auth.currentUser!.id)
                        .single();
                    await Supabase.instance.client.from('clients').insert({
                      'agency_id': agencyRow['agency_id'],
                      'company_name': nameCtrl.text.trim(),
                      'contact_name': contactCtrl.text.trim().isEmpty ? null : contactCtrl.text.trim(),
                      'industry': industryCtrl.text.trim().isEmpty ? null : industryCtrl.text.trim(),
                      'status': 'active',
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

  Future<void> _deleteClient(Map<String, dynamic> client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف العميل؟'),
          content: Text('هيتم حذف "${client['company_name']}" وكل بياناته (الإنفاق والمبيعات المسجلة). الإجراء ده مش قابل للتراجع.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف نهائيًا'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.from('clients').delete().eq('id', client['id']);
      _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = describeAuthError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('العملاء')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addClientDialog,
          icon: const Icon(Icons.add),
          label: const Text('عميل جديد'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: busy
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)))
                  : clients.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text('مفيش عملاء لسه. دوس "عميل جديد" تحت عشان تضيف أول عميل.',
                                  style: TextStyle(color: Colors.grey.shade500)),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: clients.length,
                          itemBuilder: (context, i) {
                            final c = clients[i];
                            return Card(
                              child: ListTile(
                                title: Text(c['company_name'] ?? ''),
                                subtitle: Text([
                                  if (c['contact_name'] != null) c['contact_name'],
                                  if (c['industry'] != null) c['industry'],
                                  c['status'],
                                ].whereType<String>().join(' • ')),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'حذف',
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _deleteClient(c),
                                    ),
                                    const Icon(Icons.chevron_left),
                                  ],
                                ),
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ClientMetricsPage(
                                    clientId: c['id'] as String,
                                    clientName: c['company_name'] as String,
                                  ),
                                )),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
