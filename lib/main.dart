
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'auth_service.dart';
import 'profile_service.dart';
import 'meta_settings_page.dart';
import 'ai_assistant_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'clients_page.dart';

const bg = Color(0xFF070D18), surface = Color(0xFF0D1725), cyan = Color(0xFF42D7E8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey);
  runApp(const PoostApp());
}

class PoostApp extends StatelessWidget {
  const PoostApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'poost Media Buying OS',
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark),
          cardTheme: const CardThemeData(color: surface),
        ),
        home: const AuthGate(),
      );
}

/// Gate #1: is there a Supabase session at all.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snap) =>
          client.auth.currentSession == null ? const LoginPage() : const ProfileGate(),
    );
  }
}

/// Gate #2: once signed in, load the profile row to know the role
/// (owner / media_buyer / client) and route to the right home screen.
/// This is what actually enforces "hide commission info from the client"
/// at the UI-routing level — see docs/PRODUCT_SPEC.md § Roles.
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<AppProfile?> _future;

  @override
  void initState() {
    super.initState();
    _future = ProfileService(Supabase.instance.client).currentProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppProfile?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _ProfileLoadError(
            message: describeAuthError(snap.error!),
            onRetry: () => setState(() => _future = ProfileService(Supabase.instance.client).currentProfile()),
          );
        }
        final profile = snap.data;
        if (profile == null) {
          // Signed in, but no profile row yet — either bootstrap didn't
          // finish or the account was created outside the app. Don't guess
          // a role; make it explicit and let the user retry or sign out.
          return _ProfileLoadError(
            message: 'تم تسجيل الدخول، لكن لا يوجد ملف مستخدم مرتبط بالحساب بعد.',
            onRetry: () => setState(() => _future = ProfileService(Supabase.instance.client).currentProfile()),
          );
        }
        switch (profile.role) {
          case AppRole.owner:
            return OwnerHomePage(profile: profile);
          case AppRole.mediaBuyer:
            return MediaBuyerHomePage(profile: profile);
          case AppRole.client:
            return ClientHomePage(profile: profile);
          case AppRole.unknown:
            return _ProfileLoadError(
              message: 'دور المستخدم غير معروف. تواصل مع صاحب الحساب.',
              onRetry: () => setState(() => _future = ProfileService(Supabase.instance.client).currentProfile()),
            );
        }
      },
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ProfileLoadError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.orange),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Supabase.instance.client.auth.signOut(),
                      child: const Text('تسجيل الخروج'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Intentionally empty: never pre-fill real credentials in source code.
  // See docs/CONNECT_NOW.md for the one-time bootstrap username to type in.
  final user = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? error;
  bool _isError = true;

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (user.text.trim().isEmpty || pass.text.isEmpty) {
      setState(() {
        error = 'من فضلك أدخل اسم المستخدم وكلمة المرور.';
        _isError = true;
      });
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppAuth(Supabase.instance.client).signIn(user.text, pass.text);
    } catch (e) {
      setState(() {
        error = describeAuthError(e);
        _isError = true;
      });
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> bootstrap() async {
    if (user.text.trim().isEmpty || pass.text.isEmpty) {
      setState(() {
        error = 'من فضلك أدخل اسم مستخدم وكلمة مرور قوية قبل التهيئة.';
        _isError = true;
      });
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await AppAuth(Supabase.instance.client).signUpOwner(user.text, pass.text);
      if (r.user == null) throw Exception('signup failed');
      await Supabase.instance.client.rpc('bootstrap_owner', params: {'p_username': user.text.trim()});
      if (mounted) {
        setState(() {
          error = 'تم تهيئة حساب Owner بنجاح. اضغط دخول.';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = describeAuthError(e);
          _isError = true;
        });
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('poost',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: cyan)),
                      const SizedBox(height: 8),
                      const Text('Media Buying OS', textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      TextField(
                        controller: user,
                        decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pass,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 18),
                      if (error != null)
                        Text(error!, style: TextStyle(color: _isError ? Colors.orange : Colors.greenAccent)),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'جارٍ الدخول...' : 'دخول')),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: busy ? null : bootstrap, child: const Text('تهيئة Owner لأول مرة')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Shared shell for the three role-specific home pages so the AppBar/logout
/// behavior isn't duplicated three times.
class _RoleScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  const _RoleScaffold({required this.title, required this.children, this.actions});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(title), actions: [
          ...?actions,
          IconButton(
            tooltip: 'المساعد الذكي',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const AiAssistantPage())),
          ),
          IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: children),
      );
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  const _Kpi(this.label, this.value, {this.icon = Icons.insights, this.accent = cyan});
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.08), blurRadius: 16, spreadRadius: 1)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
            ]),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: accent)),
          ],
        ),
      );
}

/// Owner: full agency visibility, including finance/commission — per
/// docs/PRODUCT_SPEC.md § Roles → Owner. KPIs and the trend chart are
/// computed live from daily_metrics/commissions.
class OwnerHomePage extends StatefulWidget {
  final AppProfile profile;
  const OwnerHomePage({super.key, required this.profile});
  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _DayPoint {
  final DateTime date;
  final double spend;
  final double sales;
  _DayPoint(this.date, this.spend, this.sales);
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  bool busy = true;
  String? error;
  double spend = 0, sales = 0, commission = 0;
  int clientCount = 0;
  List<_DayPoint> trend = [];

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  Future<void> _loadKpis() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final db = Supabase.instance.client;
      final clientRows = await db.from('clients').select('id');
      final clientIds = (clientRows as List).map((r) => r['id'] as String).toList();

      double s = 0, sa = 0, com = 0;
      final byDate = <String, _DayPoint>{};
      final now = DateTime.now();
      for (int i = 13; i >= 0; i--) {
        final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        byDate[d.toIso8601String().substring(0, 10)] = _DayPoint(d, 0, 0);
      }

      if (clientIds.isNotEmpty) {
        final since30 = now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
        final metrics = await db
            .from('daily_metrics')
            .select('metric_date, spend, sales')
            .inFilter('client_id', clientIds)
            .gte('metric_date', since30);
        for (final row in (metrics as List)) {
          final sp = (row['spend'] as num).toDouble();
          final sl = (row['sales'] as num).toDouble();
          s += sp;
          sa += sl;
          final key = row['metric_date'].toString();
          final existing = byDate[key];
          if (existing != null) {
            byDate[key] = _DayPoint(existing.date, existing.spend + sp, existing.sales + sl);
          }
        }
        final commissions = await db.from('commissions').select('total_commission').inFilter('client_id', clientIds);
        for (final row in (commissions as List)) {
          com += (row['total_commission'] as num?)?.toDouble() ?? 0;
        }
      }

      final sortedTrend = byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
      if (mounted) {
        setState(() {
          spend = s;
          sales = sa;
          commission = com;
          clientCount = clientIds.length;
          trend = sortedTrend;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = describeAuthError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  double get roas => spend > 0 ? sales / spend : 0;

  @override
  Widget build(BuildContext c) => _RoleScaffold(
        title: 'poost Command Center',
        actions: [
          IconButton(
            tooltip: 'العملاء',
            icon: const Icon(Icons.groups),
            onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const ClientsPage())).then((_) => _loadKpis()),
          ),
          IconButton(
            tooltip: 'Meta Ads',
            icon: const Icon(Icons.campaign),
            onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const MetaSettingsPage())),
          ),
        ],
        children: [
          // --- header banner ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [cyan.withOpacity(0.18), surface],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              border: Border.all(color: cyan.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: cyan.withOpacity(0.15)),
                  child: Icon(Icons.workspace_premium, color: cyan, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أهلًا ${widget.profile.fullName}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$clientCount عميل • آخر 30 يوم', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.orange)),
          if (!busy) ...[
            Row(children: [
              Expanded(child: _Kpi('Ad Spend', spend.toStringAsFixed(0), icon: Icons.attach_money, accent: Colors.orangeAccent)),
              const SizedBox(width: 10),
              Expanded(child: _Kpi('Sales', sales.toStringAsFixed(0), icon: Icons.point_of_sale, accent: Colors.greenAccent)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Kpi('ROAS', roas.toStringAsFixed(2), icon: Icons.trending_up, accent: cyan)),
              const SizedBox(width: 10),
              Expanded(child: _Kpi('Commission', commission.toStringAsFixed(0), icon: Icons.savings, accent: Colors.purpleAccent)), // owner-only KPI
            ]),
            const SizedBox(height: 20),
            if (trend.any((p) => p.spend > 0 || p.sales > 0)) ...[
              const Text('اتجاه آخر 14 يوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              Container(
                height: 190,
                padding: const EdgeInsets.fromLTRB(6, 16, 16, 6),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
                child: _TrendChart(points: trend),
              ),
              Row(
                children: [
                  _legendDot(Colors.orangeAccent, 'Spend'),
                  const SizedBox(width: 16),
                  _legendDot(Colors.greenAccent, 'Sales'),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ],
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups),
              title: const Text('العملاء وبيانات الأداء'),
              subtitle: const Text('أضف عميل جديد أو حدّث بيانات الإنفاق والمبيعات يدويًا'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(c)
                  .push(MaterialPageRoute(builder: (_) => const ClientsPage()))
                  .then((_) => _loadKpis()),
            ),
          ),
        ],
      );

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      );
}

class _TrendChart extends StatelessWidget {
  final List<_DayPoint> points;
  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxY = points
            .map((p) => p.spend > p.sales ? p.spend : p.sales)
            .fold<double>(0, (m, v) => v > m ? v : m) *
        1.2;
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY,
        gridData: FlGridData(show: true, horizontalInterval: (maxY <= 0 ? 10 : maxY) / 4, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1)),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 3,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                final d = points[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${d.day}/${d.month}', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].spend)],
            isCurved: true,
            color: Colors.orangeAccent,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.orangeAccent.withOpacity(0.08)),
          ),
          LineChartBarData(
            spots: [for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].sales)],
            isCurved: true,
            color: Colors.greenAccent,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.greenAccent.withOpacity(0.08)),
          ),
        ],
      ),
    );
  }
}

/// Media buyer: assigned clients only, no finance/commission — per
/// docs/PRODUCT_SPEC.md § Roles → Media Buyer.
class MediaBuyerHomePage extends StatelessWidget {
  final AppProfile profile;
  const MediaBuyerHomePage({super.key, required this.profile});
  @override
  Widget build(BuildContext c) => _RoleScaffold(
        title: 'poost — Media Buyer',
        children: [
          Text('أهلًا ${profile.fullName}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Kpi('Ad Spend', '—')),
            const SizedBox(width: 10),
            Expanded(child: _Kpi('ROAS', '—')),
          ]),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('سيتم عرض العملاء المُسندين إليك هنا فقط، بدون بيانات العمولة المالية.'),
            ),
          ),
        ],
      );
}

/// Client: own company only, performance + approved reports, explicitly
/// NO commission/internal notes/other clients — per
/// docs/PRODUCT_SPEC.md § Roles → Client. This screen must never render
/// a Commission KPI card.
class ClientHomePage extends StatelessWidget {
  final AppProfile profile;
  const ClientHomePage({super.key, required this.profile});
  @override
  Widget build(BuildContext c) => _RoleScaffold(
        title: 'poost — Client Portal',
        children: [
          Text('أهلًا ${profile.fullName}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Kpi('Ad Spend', '—')),
            const SizedBox(width: 10),
            Expanded(child: _Kpi('ROAS', '—')),
          ]),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('سيتم عرض تقارير الأداء المعتمدة هنا فور توفرها.'),
            ),
          ),
        ],
      );
}
