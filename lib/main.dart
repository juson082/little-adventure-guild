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
    title: '작은 모험 길드', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: brown, surface: cream),
      scaffoldBackgroundColor: const Color(0xfff6eedc), fontFamily: null),
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

  String get dateKey {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); load(); dateTimer = Timer.periodic(const Duration(seconds: 30), (_) { if (today != null && today!['date'] != dateKey && !busy) load(); }); }
  @override
  void dispose() { dateTimer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
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
        if (saved['quest'] is! int || (saved['quest'] as int) < 0 || (saved['quest'] as int) >= quests.length) {
          throw const FormatException('잘못된 퀘스트 기록');
        }
      }
      if (saved == null || saved['date'] != dateKey) {
        var index = Random().nextInt(quests.length);
        if (index == saved?['quest']) index = (index + 1) % quests.length;
        saved = {'date': dateKey, 'quest': index, 'opened': false, 'completed': false};
        if (!await store.setString('today', jsonEncode(saved))) throw Exception('저장 실패');
      }
      if (mounted) setState(() { prefs = store; today = saved; error = null; });
    } catch (_) {
      if (mounted) setState(() => error = '오늘의 의뢰를 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }
  Future<void> update(String key) async {
    if (busy || today == null) return;
    if (today!['date'] != dateKey) { await load(); return; }
    setState(() => busy = true);
    final next = {...today!, key: true};
    try {
      if (!await prefs!.setString('today', jsonEncode(next))) throw Exception('저장 실패');
      if (mounted) setState(() => today = next);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기록을 저장하지 못했어요. 다시 시도해 주세요.')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  void showInfo(bool support) => showModalBottomSheet<void>(context: context, showDragHandle: true,
    backgroundColor: cream, builder: (context) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(support ? '길드 지원하기' : '의뢰 제안하기', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: ink)),
        const SizedBox(height: 16),
        Text(support ? '이 작은 모험들이 내일도 이어질 수 있도록, 원한다면 길드에 보급품을 보내주세요.' : '다른 모험가들과 나누고 싶은 작은 경험이 있나요? 당신의 의뢰가 언젠가 오늘의 퀘스트가 될지도 모릅니다.', style: const TextStyle(height: 1.7, color: ink)),
        const SizedBox(height: 18),
        Text(support ? '후원 기능은 준비 중이에요. 모든 퀘스트는 언제나 무료입니다.' : '의뢰 접수는 준비 중이에요. 후원 여부는 의뢰 채택에 영향을 주지 않습니다.', style: const TextStyle(color: brown, height: 1.6)),
      ]))));
  @override
  Widget build(BuildContext context) {
    final item = today == null ? null : quests[today!['quest'] as int];
    final opened = today?['opened'] == true;
    final completed = today?['completed'] == true;
    return Scaffold(body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child:
      ListView(padding: const EdgeInsets.fromLTRB(24, 22, 24, 30), children: [
        Row(children: [const Icon(Icons.auto_awesome, color: brown, size: 23), const SizedBox(width: 9),
          const Expanded(child: Text('작은 모험 길드', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800))),
          PopupMenuButton<String>(tooltip: '길드 메뉴', onSelected: (v) => showInfo(v == 'support'), itemBuilder: (_) => const [
            PopupMenuItem(value: 'support', child: Text('길드 지원하기')),
            PopupMenuItem(value: 'suggest', child: Text('의뢰 제안하기')),
          ])]),
        const SizedBox(height: 38),
        Text(greeting, style: const TextStyle(color: ink, fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('오늘도 작은 모험 하나가 기다리고 있어요.', style: TextStyle(color: brown, height: 1.6)),
        const SizedBox(height: 28),
        Container(height: 150, decoration: BoxDecoration(color: const Color(0xffded4b7), border: Border.all(color: brown, width: 3)),
          child: const CustomPaint(painter: GuildScenePainter())),
        const SizedBox(height: 27),
        if (error != null) ...[Text(error!, style: const TextStyle(color: Colors.red)), TextButton(onPressed: load, child: const Text('다시 시도'))]
        else if (today == null) const Center(child: CircularProgressIndicator())
        else Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: const Color(0xfffff9e9), border: Border.all(color: const Color(0xff9c7955), width: 2), boxShadow: const [BoxShadow(color: Color(0x2275533d), offset: Offset(4, 4))]), child:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('오늘의 사이드퀘스트', style: TextStyle(color: brown, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 24),
            if (!opened) ...[
              Center(child: Semantics(button: true, label: '양피지 열기', child: GestureDetector(onTap: busy ? null : () => update('opened'), child: const SizedBox(width: 76, height: 86, child: CustomPaint(painter: ScrollPainter()))))), const SizedBox(height: 18),
              const Text('길드에서 양피지가 도착했어요', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink)),
              const SizedBox(height: 8), const Text('살짝 열어 오늘의 의뢰를 확인해 보세요.', textAlign: TextAlign.center, style: TextStyle(color: brown, height: 1.5)),
              const SizedBox(height: 25), FilledButton(onPressed: busy ? null : () => update('opened'), child: const Text('양피지 열기')),
            ] else ...[
              Text(item!.$1, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 15),
              Text(item.$2, style: const TextStyle(fontSize: 16, color: ink, height: 1.7)), const SizedBox(height: 26),
              FilledButton(onPressed: completed || busy ? null : () => update('completed'), child: Text(completed ? '완료한 퀘스트' : '퀘스트 완료')),
              const SizedBox(height: 10), Text(completed ? '오늘의 작은 모험을 함께해 주어 고마워요.' : '오늘 하지 않아도 괜찮아요. 마음이 가는 대로요.', textAlign: TextAlign.center, style: const TextStyle(color: brown, fontSize: 12, height: 1.5)),
            ],
          ])),
        const SizedBox(height: 30), const Center(child: Text('평범한 하루에도 모험은 숨어 있으니까요.', style: TextStyle(color: brown, fontSize: 12))),
      ])))));
  }
}






class GuildScenePainter extends CustomPainter {
  const GuildScenePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24, sy = size.height / 12;
    void box(int x, int y, int w, int h, Color color) => canvas.drawRect(Rect.fromLTWH(x*sx,y*sy,w*sx,h*sy), Paint()..color=color);
    const dark = Color(0xff76533d), roof = Color(0xffae7954), wall = Color(0xffffefd0), green = Color(0xff7e936a);
    box(0, 10, 24, 2, green); box(3, 5, 2, 5, dark); box(1, 3, 6, 3, green); box(2, 2, 4, 1, green);
    box(18, 5, 2, 5, dark); box(16, 3, 6, 3, green); box(17, 2, 4, 1, green);
    box(9, 6, 7, 4, wall); box(8, 5, 9, 1, dark); box(9, 4, 7, 1, roof); box(10, 3, 5, 1, roof); box(11, 2, 3, 1, roof);
    box(12, 7, 2, 3, dark); box(10, 7, 1, 1, roof); box(15, 7, 1, 1, roof);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScrollPainter extends CustomPainter {
  const ScrollPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 12, y = size.height / 14;
    void box(int left, int top, int width, int height, Color color) => canvas.drawRect(Rect.fromLTWH(left*x,top*y,width*x,height*y), Paint()..color=color);
    const edge = Color(0xff76533d), paper = Color(0xffecd8aa), line = Color(0xffb18d64);
    box(2,1,8,12,edge); box(3,2,6,10,paper); box(1,1,2,3,edge); box(9,10,2,3,edge);
    box(4,4,4,1,line); box(4,6,4,1,line); box(4,8,3,1,line);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
