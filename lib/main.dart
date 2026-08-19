
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'auth_service.dart';
import 'profile_service.dart';
import 'meta_settings_page.dart';

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
          IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: children),
      );
}

class _Kpi extends StatelessWidget {
  final String a, b;
  const _Kpi(this.a, this.b);
  @override
  Widget build(BuildContext c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a),
            const SizedBox(height: 8),
            Text(b, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

/// Owner: full agency visibility, including finance/commission — per
/// docs/PRODUCT_SPEC.md § Roles → Owner.
class OwnerHomePage extends StatelessWidget {
  final AppProfile profile;
  const OwnerHomePage({super.key, required this.profile});
  @override
  Widget build(BuildContext c) => _RoleScaffold(
        title: 'poost Command Center',
        actions: [
          IconButton(
            tooltip: 'Meta Ads',
            icon: const Icon(Icons.campaign),
            onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const MetaSettingsPage())),
          ),
        ],
        children: [
          Text('أهلًا ${profile.fullName}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Kpi('Ad Spend', '—')),
            const SizedBox(width: 10),
            Expanded(child: _Kpi('Sales', '—')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _Kpi('ROAS', '—')),
            const SizedBox(width: 10),
            Expanded(child: _Kpi('Commission', '—')), // owner-only KPI
          ]),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('سيتم تحميل بيانات العملاء والحملات من Supabase بعد اكتمال مزامنة الحسابات.'),
            ),
          ),
        ],
      );
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
