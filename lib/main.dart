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

  void showInfo(bool support) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cream,
      builder: (context) => SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(support ? '길드 지원하기' : '의뢰 제안하기',
                        style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: ink)),
                    const SizedBox(height: 16),
                    Text(
                        support
                            ? '이 작은 모험들이 내일도 이어질 수 있도록, 원한다면 길드에 보급품을 보내주세요.'
                            : '다른 모험가들과 나누고 싶은 작은 경험이 있나요? 당신의 의뢰가 언젠가 오늘의 퀘스트가 될지도 모릅니다.',
                        style: const TextStyle(height: 1.7, color: ink)),
                    const SizedBox(height: 18),
                    Text(
                        support
                            ? '후원 기능은 준비 중이에요. 모든 퀘스트는 언제나 무료입니다.'
                            : '의뢰 접수는 준비 중이에요. 후원 여부는 의뢰 채택에 영향을 주지 않습니다.',
                        style: const TextStyle(color: brown, height: 1.6)),
                  ]))));

  @override
  Widget build(BuildContext context) {
    final item = today == null ? null : quests[today!['quest'] as int];
    final opened = today?['opened'] == true;
    final completed = today?['completed'] == true;
    return Scaffold(
      backgroundColor: const Color(0xff211711),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(children: [
                  AspectRatio(
                    aspectRatio: 1.35,
                    child: Image.asset('assets/guild_interior.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.none),
                  ),
                  Positioned.fill(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                        Colors.black.withValues(alpha: .35),
                        Colors.transparent,
                        const Color(0xff211711).withValues(alpha: .75)
                      ],
                                  stops: const [
                        0,
                        .30,
                        1
                      ])))),
                  Positioned(
                      top: 18,
                      left: 20,
                      right: 16,
                      child: Row(children: [
                        const Expanded(
                            child: Text('작은 모험 길드',
                                style: TextStyle(
                                    color: Color(0xfffff1d0),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    shadows: [
                                      Shadow(blurRadius: 5, color: Colors.black)
                                    ]))),
                        PopupMenuButton<String>(
                            tooltip: '길드 메뉴',
                            iconColor: const Color(0xfffff1d0),
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
                    offset: const Offset(0, -24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 15, 20, 17),
                              decoration: BoxDecoration(
                                  color: const Color(0xfff3e6c8),
                                  border: Border.all(
                                      color: const Color(0xff9c754d), width: 3),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0xff130e0a),
                                        offset: Offset(4, 5))
                                  ]),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('길드주인',
                                        style: TextStyle(
                                            color: Color(0xff866042),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1)),
                                    const SizedBox(height: 8),
                                    Text(greeting,
                                        style: const TextStyle(
                                            color: Color(0xff3f3025),
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            height: 1.6)),
                                  ]),
                            ),
                            const SizedBox(height: 25),
                            if (error != null) ...[
                              Text(error!,
                                  style: const TextStyle(
                                      color: Color(0xffffd3ae))),
                              TextButton(
                                  onPressed: load, child: const Text('다시 시도')),
                            ] else if (today == null)
                              const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xffe5c793)))
                            else if (!greetingFinished)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                    child: Text('길드주인의 이야기를 듣고 있어요…',
                                        style: TextStyle(
                                            color: Color(0xffc8ae8b),
                                            fontSize: 12))),
                              )
                            else if (!opened) ...[
                              const Center(
                                  child: Text('오늘의 의뢰가 도착했어요',
                                      style: TextStyle(
                                          color: Color(0xffe8d3ae),
                                          fontSize: 13,
                                          letterSpacing: .4))),
                              const SizedBox(height: 16),
                              Center(
                                  child: Semantics(
                                      button: true,
                                      label: '양피지 열기',
                                      child: GestureDetector(
                                          onTap: busy
                                              ? null
                                              : () => update('opened'),
                                          child: const SizedBox(
                                              width: 112,
                                              height: 112,
                                              child: CustomPaint(
                                                  painter: ScrollPainter()))))),
                              const SizedBox(height: 12),
                              TextButton(
                                  onPressed:
                                      busy ? null : () => update('opened'),
                                  child: const Text('양피지 열기',
                                      style: TextStyle(
                                          color: Color(0xfff4ddaf),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold))),
                              const Center(
                                  child: Text('천천히 열어 보세요',
                                      style: TextStyle(
                                          color: Color(0xffad9474),
                                          fontSize: 12))),
                            ] else
                              Container(
                                padding:
                                    const EdgeInsets.fromLTRB(23, 22, 23, 20),
                                decoration: BoxDecoration(
                                    color: const Color(0xfff3e6c8),
                                    border: Border.all(
                                        color: const Color(0xffa47d52),
                                        width: 3),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Color(0xff130e0a),
                                          offset: Offset(4, 5))
                                    ]),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text('오늘의 사이드퀘스트',
                                          style: TextStyle(
                                              color: Color(0xff92704c),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1)),
                                      const SizedBox(height: 14),
                                      Text(item!.$1,
                                          style: const TextStyle(
                                              color: Color(0xff3f3025),
                                              fontSize: 21,
                                              fontWeight: FontWeight.bold,
                                              height: 1.4)),
                                      const SizedBox(height: 12),
                                      Text(item.$2,
                                          style: const TextStyle(
                                              color: Color(0xff614b38),
                                              fontSize: 15,
                                              height: 1.7)),
                                      const SizedBox(height: 22),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xff6d4933),
                                            foregroundColor:
                                                const Color(0xfffff0d3),
                                            disabledBackgroundColor:
                                                const Color(0xffd5c4a4),
                                            shape:
                                                const RoundedRectangleBorder(),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14)),
                                        onPressed: completed || busy
                                            ? null
                                            : () => update('completed'),
                                        child: Text(
                                            completed ? '완료한 퀘스트' : '퀘스트 완료'),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                          completed
                                              ? '오늘의 작은 모험을 함께해 주어 고마워요.'
                                              : '오늘 하지 않아도 괜찮아요. 마음이 가는 대로요.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Color(0xff8a6f51),
                                              fontSize: 11,
                                              height: 1.5)),
                                    ]),
                              ),
                            const SizedBox(height: 24),
                            const Center(
                                child: Text('평범한 하루에도 모험은 숨어 있으니까요.',
                                    style: TextStyle(
                                        color: Color(0xff9e886d),
                                        fontSize: 11))),
                          ]),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScrollPainter extends CustomPainter {
  const ScrollPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 16, y = size.height / 16;
    void box(int left, int top, int width, int height, Color color) =>
        canvas.drawRect(Rect.fromLTWH(left * x, top * y, width * x, height * y),
            Paint()..color = color);
    const edge = Color(0xff6a4934),
        paper = Color(0xffead6ad),
        line = Color(0xffb48c64),
        seal = Color(0xffa54c38);
    box(3, 3, 10, 10, edge);
    box(4, 4, 8, 8, paper);
    box(2, 3, 2, 3, edge);
    box(12, 10, 2, 3, edge);
    box(5, 5, 6, 1, line);
    box(5, 7, 5, 1, line);
    box(5, 9, 3, 1, line);
    box(10, 9, 2, 2, seal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
