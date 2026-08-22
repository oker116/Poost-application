import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth_service.dart';

enum _OrbState { idle, listening, thinking, speaking }

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  const _ChatMessage(this.role, this.content);
}

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  String? _error;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechReady = false;
  bool _voiceMode = false; // once on, replies are read aloud and mic reopens automatically

  _OrbState _state = _OrbState.idle;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _initTts();
  }

  Future<void> _initSpeech() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _error = status.isPermanentlyDenied
              ? 'صلاحية الميكروفون مرفوضة بشكل دائم. روح إعدادات التطبيق وفعّلها يدويًا.'
              : 'محتاجين صلاحية الميكروفون عشان الوضع الصوتي يشتغل.';
        });
      }
      return;
    }
    _speechReady = await _speech.initialize(
      onError: (e) => setState(() => _error = 'خطأ في الميكروفون: ${e.errorMsg}'),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_state == _OrbState.listening) setState(() => _state = _OrbState.idle);
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('ar-EG');
    } catch (_) {
      await _tts.setLanguage('ar');
    }
    await _tts.setSpeechRate(0.48);
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _state = _OrbState.idle);
      if (_voiceMode) _startListening();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _anim.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_speechReady) {
      await _initSpeech();
    }
    if (!_speechReady) {
      return; // _initSpeech already set a clear error message
    }
    setState(() {
      _state = _OrbState.listening;
      _error = null;
    });
    await _speech.listen(
      localeId: 'ar_EG',
      onResult: (result) {
        _input.text = result.recognizedWords;
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _send(fromVoice: true);
        }
      },
    );
  }

  Future<void> _toggleVoiceMode() async {
    setState(() => _voiceMode = !_voiceMode);
    if (_voiceMode) {
      await _startListening();
    } else {
      await _speech.stop();
      await _tts.stop();
      setState(() => _state = _OrbState.idle);
    }
  }

  Future<void> _send({bool fromVoice = false}) async {
    final text = _input.text.trim();
    if (text.isEmpty || _state == _OrbState.thinking) return;
    await _speech.stop();
    setState(() {
      _messages.add(_ChatMessage('user', text));
      _input.clear();
      _state = _OrbState.thinking;
      _error = null;
    });
    _scrollToBottom();
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ai-assistant',
        body: {'messages': _messages.map((m) => {'role': m.role, 'content': m.content}).toList()},
      );
      final reply = (res.data as Map?)?['reply'] as String?;
      if (reply == null || reply.isEmpty) throw Exception('لم يصل رد من المساعد');
      setState(() => _messages.add(_ChatMessage('assistant', reply)));
      if (fromVoice || _voiceMode) {
        setState(() => _state = _OrbState.speaking);
        await _tts.speak(reply);
      } else {
        setState(() => _state = _OrbState.idle);
      }
    } catch (e) {
      setState(() {
        _error = describeAuthError(e);
        _state = _OrbState.idle;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المساعد الذكي')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _Orb(state: _state, animation: _anim),
            ),
            Text(_stateLabel(), style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            const SizedBox(height: 6),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'اسألني عن أداء حملاتك، أو اطلب مني أصيغلك رسالة أو عرض لعميل. دوس على الميكروفون للكلام الصوتي.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(14),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final isUser = m.role == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.white10 : const Color(0xFF13324A),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(m.content),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(_error!, style: const TextStyle(color: Colors.orange)),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _toggleVoiceMode,
                      icon: Icon(_voiceMode ? Icons.mic : Icons.mic_none),
                      color: _voiceMode ? Colors.redAccent : null,
                      tooltip: _voiceMode ? 'إيقاف الوضع الصوتي' : 'تشغيل الوضع الصوتي',
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'اكتب سؤالك هنا...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _state == _OrbState.thinking ? null : () => _send(),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stateLabel() {
    switch (_state) {
      case _OrbState.idle:
        return _voiceMode ? 'الوضع الصوتي شغال — قول أي حاجة' : 'جاهز';
      case _OrbState.listening:
        return 'بسمعك...';
      case _OrbState.thinking:
        return 'بفكر...';
      case _OrbState.speaking:
        return 'بيتكلم...';
    }
  }
}

/// Simple animated "face": a pulsing glowing orb that changes rhythm/color
/// based on the assistant's current state, drawn with pure Flutter
/// animation APIs (no extra image/lottie assets needed).
class _Orb extends StatelessWidget {
  final _OrbState state;
  final Animation<double> animation;
  const _Orb({required this.state, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        double scale;
        Color color;
        switch (state) {
          case _OrbState.idle:
            scale = 1.0 + 0.04 * sin(t * 2 * pi);
            color = const Color(0xFF42D7E8);
            break;
          case _OrbState.listening:
            scale = 1.0 + 0.14 * sin(t * 2 * pi * 3);
            color = Colors.redAccent;
            break;
          case _OrbState.thinking:
            scale = 1.0 + 0.06 * sin(t * 2 * pi * 5);
            color = Colors.amber;
            break;
          case _OrbState.speaking:
            scale = 1.0 + 0.1 * sin(t * 2 * pi * 6);
            color = Colors.greenAccent;
            break;
        }
        return SizedBox(
          height: 120,
          width: 120,
          child: Center(
            child: Container(
              width: 90 * scale,
              height: 90 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [color.withOpacity(0.9), color.withOpacity(0.15)]),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 30, spreadRadius: 6)],
              ),
            ),
          ),
        );
      },
    );
  }
}
