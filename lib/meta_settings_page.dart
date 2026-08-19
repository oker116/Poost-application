import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';

class MetaSettingsPage extends StatefulWidget {
  const MetaSettingsPage({super.key});

  @override
  State<MetaSettingsPage> createState() => _MetaSettingsPageState();
}

class _MetaSettingsPageState extends State<MetaSettingsPage> {
  bool busy = false;
  String? error;
  Map<String, dynamic>? connection;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final row = await Supabase.instance.client
          .from('meta_connections')
          .select('status, external_user_id, last_sync_at, error_message')
          .eq('provider', 'meta')
          .maybeSingle();
      if (mounted) setState(() => connection = row);
    } catch (e) {
      if (mounted) setState(() => error = describeAuthError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _connect() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke('meta-oauth-start');
      final url = (res.data as Map?)?['url'] as String?;
      if (url == null) throw Exception('لم يتم إرجاع رابط الاتصال');
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('تعذر فتح المتصفح');
    } catch (e) {
      if (mounted) setState(() => error = describeAuthError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  bool get connected => connection?['status'] == 'connected';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meta Ads'),
          actions: [
            IconButton(
              tooltip: 'تحديث الحالة',
              onPressed: busy ? null : _loadStatus,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign, size: 30),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Meta Ads Connection',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        Icon(connected ? Icons.check_circle : Icons.cloud_off,
                            color: connected ? Colors.green : Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      connected
                          ? 'الحساب متصل. رقم حساب Meta: ${connection?['external_user_id'] ?? '—'}'
                          : 'اربط حساب Meta عشان تقدر تشوف الإنفاق والنتائج تلقائيًا جوه poost.',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    if (connection?['error_message'] != null) ...[
                      const SizedBox(height: 8),
                      Text('آخر خطأ: ${connection!['error_message']}',
                          style: const TextStyle(color: Colors.orange)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Colors.orange)),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: busy ? null : _connect,
              icon: const Icon(Icons.link),
              label: Text(busy
                  ? 'جارٍ الفتح...'
                  : connected
                      ? 'إعادة ربط / تحديث الصلاحية'
                      : 'ربط حساب Meta'),
            ),
            const SizedBox(height: 10),
            Text(
              'هيفتح المتصفح لصفحة تسجيل الدخول والموافقة على Meta. بعد ما توافق، ارجع للتطبيق ودوس تحديث الحالة (فوق يمين).',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 8),
            const Text('ملاحظة أمان:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'الـ Access Token بتاع Meta بيتخزن على السيرفر فقط (Supabase) ومش بيتحط جوه التطبيق أبدًا. سحب بيانات الحملات (spend/ROAS) بشكل يومي هي الخطوة الجاية بعد الربط.',
              style: TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
