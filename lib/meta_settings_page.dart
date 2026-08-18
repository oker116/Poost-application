
import 'package:flutter/material.dart';

class MetaConnection {
  final String appId;
  final String adAccountId;
  final bool connected;
  const MetaConnection({
    this.appId = '',
    this.adAccountId = '',
    this.connected = false,
  });
}

class MetaSettingsPage extends StatefulWidget {
  const MetaSettingsPage({super.key});

  @override
  State<MetaSettingsPage> createState() => _MetaSettingsPageState();
}

class _MetaSettingsPageState extends State<MetaSettingsPage> {
  final appId = TextEditingController();
  final accountId = TextEditingController();
  final token = TextEditingController();
  bool obscure = true;
  bool connected = false;

  @override
  void dispose() {
    appId.dispose();
    accountId.dispose();
    token.dispose();
    super.dispose();
  }

  void connect() {
    // UI-only V5:
    // Never ship a long-lived Meta access token inside the APK.
    // In the production integration, this button starts OAuth and the
    // backend stores/refreshes credentials securely.
    setState(() => connected = appId.text.trim().isNotEmpty &&
        accountId.text.trim().isNotEmpty &&
        token.text.trim().isNotEmpty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(connected
            ? 'تم تجهيز الاتصال. الربط الفعلي يتم عبر Backend/OAuth.'
            : 'أكمل بيانات الاتصال أولاً.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Meta Ads')),
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
                      'اربط حساب الإعلانات ثم اسحب الحملات والإنفاق والنتائج تلقائيًا.',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: appId,
              decoration: const InputDecoration(
                labelText: 'Meta App ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountId,
              decoration: const InputDecoration(
                labelText: 'Ad Account ID',
                hintText: 'مثال: act_123456789',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: token,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Access Token (للتجربة فقط)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ في النسخة النهائية لن نخزن Access Token داخل التطبيق. سيتم استخدام OAuth وتخزين الاعتماديات بشكل آمن على الـ Backend.',
              style: TextStyle(color: Colors.orange, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: connect,
              icon: const Icon(Icons.link),
              label: Text(connected ? 'الاتصال مُجهّز' : 'حفظ وتجهيز الاتصال'),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 8),
            const Text('بعد الربط الفعلي سيصبح المسار:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Connect → اختيار Ad Account → Sync → Campaigns → Ad Sets → Ads → Spend → Results → Dashboard',
              style: TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
