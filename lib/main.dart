
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'auth_service.dart';

const bg=Color(0xFF070D18), surface=Color(0xFF0D1725), cyan=Color(0xFF42D7E8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey);
  runApp(const PoostApp());
}

class PoostApp extends StatelessWidget {
  const PoostApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'poost Media Buying OS',
    theme: ThemeData.dark(useMaterial3:true).copyWith(
      scaffoldBackgroundColor:bg,
      colorScheme: ColorScheme.fromSeed(seedColor:cyan, brightness:Brightness.dark),
      cardTheme: const CardThemeData(color:surface),
    ),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override Widget build(BuildContext context) {
    final client=Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder:(context,snap)=> client.auth.currentSession==null ? const LoginPage() : const HomePage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final user=TextEditingController(text:'yosef aped');
  final pass=TextEditingController(text:'162007');
  bool busy=false;
  String? error;
  Future<void> login() async {
    setState(()=>busy=true);
    try { await AppAuth(Supabase.instance.client).signIn(user.text,pass.text); }
    catch(e){ setState(()=>error='بيانات الدخول غير صحيحة أو الحساب لم يتم تهيئته بعد.'); }
    if(mounted)setState(()=>busy=false);
  }
  Future<void> bootstrap() async {
    setState(()=>busy=true); setState(()=>error=null);
    try {
      final r=await AppAuth(Supabase.instance.client).signUpOwner(user.text,pass.text);
      if (r.user == null) throw Exception('signup failed');
      await Supabase.instance.client.rpc('bootstrap_owner', params:{'p_username':user.text.trim()});
      if(mounted) setState(()=>error='تم تهيئة حساب Owner. اضغط دخول.');
    } catch(e) {
      if(mounted)setState(()=>error='تعذر التهيئة. تأكد أن هذه أول مرة وأن Email confirmation مغلق في Supabase Auth.');
    }
    if(mounted)setState(()=>busy=false);
  }
  @override Widget build(BuildContext c)=>Scaffold(
    body: Center(child: ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Padding(
      padding:const EdgeInsets.all(24),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          const Text('poost',textAlign:TextAlign.center,style:TextStyle(fontSize:40,fontWeight:FontWeight.w800,color:cyan)),
          const SizedBox(height:8), const Text('Media Buying OS',textAlign:TextAlign.center),
          const SizedBox(height:28),
          TextField(controller:user,decoration:const InputDecoration(labelText:'Username',border:OutlineInputBorder())),
          const SizedBox(height:12),
          TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Password',border:OutlineInputBorder())),
          const SizedBox(height:18),
          if(error!=null) Text(error!,style:const TextStyle(color:Colors.orange)),
          const SizedBox(height:8),
          FilledButton(onPressed:busy?null:login,child:Text(busy?'جارٍ الدخول...':'دخول')),
          const SizedBox(height:8),
          OutlinedButton(onPressed:busy?null:bootstrap,child:const Text('تهيئة Owner لأول مرة')),
        ],
      ))))),
    ));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override Widget build(BuildContext c)=>Scaffold(
    appBar:AppBar(title:const Text('poost Command Center'),actions:[
      IconButton(onPressed:()=>Supabase.instance.client.auth.signOut(),icon:const Icon(Icons.logout))
    ]),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Agency Performance',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),
      const SizedBox(height:16),
      Row(children:[
        Expanded(child:_Kpi('Ad Spend','—')),const SizedBox(width:10),Expanded(child:_Kpi('Sales','—'))
      ]),
      const SizedBox(height:10),
      Row(children:[
        Expanded(child:_Kpi('ROAS','—')),const SizedBox(width:10),Expanded(child:_Kpi('Commission','—'))
      ]),
      const SizedBox(height:20),
      const Card(child:Padding(padding:EdgeInsets.all(18),child:Text(
        'تم تسجيل الدخول بنجاح. سيتم تحميل بيانات العملاء والحملات من Supabase بعد اكتمال مزامنة الحسابات.'
      )))
    ])
  );
}
class _Kpi extends StatelessWidget {
  final String a,b; const _Kpi(this.a,this.b);
  @override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a),const SizedBox(height:8),Text(b,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold))])));
}
