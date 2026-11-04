import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guild_content.dart';

void main() => runApp(const GuildApp());

const ink = Color(0xff493a31);
const brown = Color(0xff75533d);
const cream = Color(0xfffff8e9);

class GuildApp extends StatelessWidget {
  const GuildApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '작은 모험 길드',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: brown, surface: cream),
            scaffoldBackgroundColor: const Color(0xfff6eedc),
            fontFamily: null),
        home: const GuildHome(),
      );
}

class GuildHome extends StatefulWidget {
  const GuildHome({super.key});
  @override
  State<GuildHome> createState() => _GuildHomeState();
}

class _GuildHomeState extends State<GuildHome> with WidgetsBindingObserver {
  final greeting = guildGreetings[Random().nextInt(guildGreetings.length)];
  SharedPreferences? prefs;
  Map<String, dynamic>? today;
  String? error;
  bool busy = false;
  Timer? dateTimer;
  Timer? greetingTimer;
  bool greetingFinished = false;

  String get dateKey {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    greetingTimer = Timer(
        Duration(milliseconds: max(3000, greeting.runes.length * 150 + 1000)),
        () {
      if (mounted) setState(() => greetingFinished = true);
    });
    dateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (today != null && today!['date'] != dateKey && !busy) load();
    });
  }

  @override
  void dispose() {
    greetingTimer?.cancel();
    dateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && today?['date'] != dateKey) load();
  }

  Future<void> load() async {
    try {
      final store = await SharedPreferences.getInstance();
      final raw = store.getString('today');
      Map<String, dynamic>? saved;
      if (raw != null) {
        saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (saved['quest'] is! int ||
            (saved['quest'] as int) < 0 ||
            (saved['quest'] as int) >= quests.length) {
          throw const FormatException('잘못된 퀘스트 기록');
        }
      }
      if (saved == null || saved['date'] != dateKey) {
        var index = Random().nextInt(quests.length);
        if (index == saved?['quest']) index = (index + 1) % quests.length;
        saved = {
          'date': dateKey,
          'quest': index,
          'opened': false,
          'completed': false
        };
        if (!await store.setString('today', jsonEncode(saved))) {
          throw Exception('저장 실패');
        }
      }
      if (mounted) {
        setState(() {
          prefs = store;
          today = saved;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = '오늘의 의뢰를 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }

  Future<void> update(String key) async {
    if (busy || today == null) return;
    if (today!['date'] != dateKey) {
      await load();
      return;
    }
    setState(() => busy = true);
    final next = {...today!, key: true};
    try {
      if (!await prefs!.setString('today', jsonEncode(next))) {
        throw Exception('저장 실패');
      }
      if (mounted) setState(() => today = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('기록을 저장하지 못했어요. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showInfo(bool support) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: PixelPanel(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(support ? '길드 지원하기' : '의뢰 제안하기',
                          style: const TextStyle(
                              color: ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800))),
                  IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: brown)),
                ]),
                const SizedBox(height: 8),
                Text(
                    support
                        ? '이 작은 모험들이 내일도 이어질 수 있도록, 원한다면 길드에 보급품을 보내주세요.'
                        : '다른 모험가들과 나누고 싶은 작은 경험이 있나요? 당신의 의뢰가 언젠가 오늘의 퀘스트가 될지도 모릅니다.',
                    style: const TextStyle(color: ink, height: 1.7)),
                const SizedBox(height: 18),
                if (support) ...[
                  for (final name in ['작은 보급품', '든든한 보급품', '특별 보급품'])
                    Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: Color(0xffc1a378), width: 2)),
                            child: Text(name,
                                style: const TextStyle(
                                    color: brown,
                                    fontWeight: FontWeight.w600)))),
                  const SizedBox(height: 4),
                  const Text('후원 기능은 준비 중이에요. 모든 퀘스트는 언제나 무료입니다.',
                      style:
                          TextStyle(color: brown, fontSize: 12, height: 1.6)),
                ] else ...[
                  const Text('의뢰 접수는 준비 중이에요. 후원 여부는 의뢰 채택에 영향을 주지 않습니다.',
                      style:
                          TextStyle(color: brown, fontSize: 12, height: 1.6)),
                ],
                const SizedBox(height: 18),
                GuildButton(
                    label: '돌아가기', onPressed: () => Navigator.pop(context)),
              ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = today == null ? null : quests[today!['quest'] as int];
    final opened = today?['opened'] == true;
    final completed = today?['completed'] == true;
    return Scaffold(
      backgroundColor: const Color(0xff291c15),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(padding: EdgeInsets.zero, children: [
          Stack(children: [
            AspectRatio(
                aspectRatio: 1.45,
                child: Image.asset('assets/guild_interior_v3.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.none)),
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                  Colors.black.withValues(alpha: .26),
                  Colors.transparent,
                  const Color(0xff291c15).withValues(alpha: .72)
                ],
                            stops: const [
                  0,
                  .38,
                  1
                ])))),
            Positioned(
                top: 12,
                left: 19,
                right: 12,
                child: Row(children: [
                  const Expanded(
                      child: Text('작은 모험 길드',
                          style: TextStyle(
                              color: Color(0xffffedc7),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .8,
                              shadows: [
                                Shadow(blurRadius: 5, color: Colors.black)
                              ]))),
                  PopupMenuButton<String>(
                      tooltip: '길드 메뉴',
                      color: cream,
                      iconColor: const Color(0xffffedc7),
                      shape: const RoundedRectangleBorder(),
                      onSelected: (v) => showInfo(v == 'support'),
                      itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'support', child: Text('길드 지원하기')),
                            PopupMenuItem(
                                value: 'suggest', child: Text('의뢰 제안하기')),
                          ]),
                ])),
          ]),
          Transform.translate(
              offset: const Offset(0, -18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PixelPanel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('길드주인',
                                style: TextStyle(
                                    color: Color(0xff926c49),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .5)),
                            const SizedBox(height: 7),
                            Text(greeting,
                                style: const TextStyle(
                                    color: ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.6)),
                          ])),
                      const SizedBox(height: 20),
                      if (error != null) ...[
                        Text(error!,
                            style: const TextStyle(color: Color(0xffffd3ae))),
                        TextButton(onPressed: load, child: const Text('다시 시도')),
                      ] else if (today == null)
                        const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xffe5c793)))
                      else if (!greetingFinished)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text('길드주인의 이야기를 듣고 있어요…',
                                    style: TextStyle(
                                        color: Color(0xffc8ae8b),
                                        fontSize: 12))))
                      else if (!opened) ...[
                        const Center(
                            child: Text('오늘의 의뢰가 도착했어요',
                                style: TextStyle(
                                    color: Color(0xffdbc49d), fontSize: 13))),
                        const SizedBox(height: 8),
                        Center(
                            child: Semantics(
                                button: true,
                                label: '양피지 열기',
                                child: InkWell(
                                    onTap: busy ? null : () => update('opened'),
                                    child: const SizedBox(
                                        width: 128,
                                        height: 108,
                                        child: CustomPaint(
                                            painter: ScrollPainter()))))),
                        Center(
                            child: SizedBox(
                                width: 180,
                                child: GuildButton(
                                    label: '양피지 열기',
                                    onPressed:
                                        busy ? null : () => update('opened')))),
                        const SizedBox(height: 9),
                        const Center(
                            child: Text('천천히 열어 보세요',
                                style: TextStyle(
                                    color: Color(0xffaa9275), fontSize: 12))),
                      ] else
                        PixelPanel(
                          parchment: true,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Center(
                                    child: Text('오늘의 사이드퀘스트',
                                        style: TextStyle(
                                            color: Color(0xff9a744f),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: .5))),
                                const SizedBox(height: 20),
                                Text(item!.$1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: ink,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        height: 1.4)),
                                const SizedBox(height: 12),
                                Text(item.$2,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xff70533a),
                                        fontSize: 15,
                                        height: 1.7)),
                                const SizedBox(height: 22),
                                GuildButton(
                                    label: completed ? '완료한 퀘스트' : '퀘스트 완료',
                                    onPressed: completed || busy
                                        ? null
                                        : () => update('completed')),
                                const SizedBox(height: 12),
                                Text(
                                    completed
                                        ? '오늘의 작은 모험을 함께해 주어 고마워요.'
                                        : '오늘 하지 않아도 괜찮아요. 마음이 가는 대로요.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xff957858),
                                        fontSize: 11,
                                        height: 1.5)),
                              ]),
                        ),
                      const SizedBox(height: 24),
                      const Center(
                          child: Text('평범한 하루에도 모험은 숨어 있으니까요.',
                              style: TextStyle(
                                  color: Color(0xff9e886d), fontSize: 11))),
                      const SizedBox(height: 20),
                    ]),
              )),
        ]),
      ))),
    );
  }
}

class PixelPanel extends StatelessWidget {
  final Widget child;
  final bool parchment;
  const PixelPanel({super.key, required this.child, this.parchment = false});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: PixelPanelPainter(parchment: parchment),
        child: Padding(
            padding: EdgeInsets.fromLTRB(parchment ? 28 : 20,
                parchment ? 27 : 15, parchment ? 28 : 20, parchment ? 26 : 17),
            child: child),
      );
}

class PixelPanelPainter extends CustomPainter {
  final bool parchment;
  const PixelPanelPainter({this.parchment = false});
  @override
  void paint(Canvas canvas, Size size) {
    void rect(double l, double t, double r, double b, Color color) =>
        canvas.drawRect(Rect.fromLTRB(l, t, r, b), Paint()..color = color);
    final w = size.width, h = size.height;
    rect(5, 6, w + 4, h + 5, const Color(0xff160f0b));
    rect(0, 0, w, h, const Color(0xff67452f));
    rect(3, 3, w - 3, h - 3, const Color(0xffb28a5b));
    rect(6, 6, w - 6, h - 6, const Color(0xfff4e6c5));
    if (parchment) {
      rect(9, 9, w - 9, h - 9, const Color(0xfff8edcf));
      rect(10, 11, 24, 14, const Color(0xffd2b588));
      rect(w - 24, 11, w - 10, 14, const Color(0xffd2b588));
      rect(10, h - 14, 24, h - 11, const Color(0xffd2b588));
      rect(w - 24, h - 14, w - 10, h - 11, const Color(0xffd2b588));
    }
  }

  @override
  bool shouldRepaint(covariant PixelPanelPainter oldDelegate) =>
      oldDelegate.parchment != parchment;
}

class GuildButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GuildButton({super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
            color: onPressed == null
                ? const Color(0xffbaa47f)
                : const Color(0xff63432f),
            border: Border.all(color: const Color(0xff3e2a1d), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0xff160f0b), offset: Offset(3, 4))
            ]),
        child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xffffefd1),
                disabledForegroundColor: const Color(0xffe6dbc5),
                shape: const RoundedRectangleBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700))),
      ));
}

class ScrollPainter extends CustomPainter {
  const ScrollPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 20, y = size.height / 16;
    void box(int l, int t, int w, int h, Color c) => canvas.drawRect(
        Rect.fromLTWH(l * x, t * y, w * x, h * y), Paint()..color = c);
    const edge = Color(0xff684530),
        mid = Color(0xffb48c64),
        paper = Color(0xfff0dfb9),
        seal = Color(0xffa54c38);
    box(3, 2, 14, 12, edge);
    box(4, 3, 12, 10, mid);
    box(5, 4, 10, 8, paper);
    box(2, 2, 3, 3, edge);
    box(15, 11, 3, 3, edge);
    box(6, 5, 8, 1, mid);
    box(6, 7, 6, 1, mid);
    box(6, 9, 4, 1, mid);
    box(12, 9, 2, 2, seal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
