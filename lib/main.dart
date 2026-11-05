import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guild_content.dart';
import 'translations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Galmuri'],
        await rootBundle.loadString('assets/fonts/Galmuri-LICENSE.txt'));
  });
  runApp(const GuildApp());
}

const ink = Color(0xff493a31);
const brown = Color(0xff75533d);
const cream = Color(0xfffff8e9);

class GuildApp extends StatefulWidget {
  const GuildApp({super.key});
  @override
  State<GuildApp> createState() => _GuildAppState();
}

class _GuildAppState extends State<GuildApp> {
  String? languageOverride;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((store) {
      if (mounted) {
        setState(() => languageOverride = store.getString('language_override'));
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Hvildir',
        locale: languageOverride == null ? null : Locale(languageOverride!),
        supportedLocales: const [
          Locale('en'),
          Locale('ko'),
          Locale('ja'),
          Locale('zh'),
          Locale('hi'),
          Locale('es')
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        localeResolutionCallback: (locale, supported) => supported.firstWhere(
            (v) => v.languageCode == locale?.languageCode,
            orElse: () => const Locale('en')),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: brown, surface: cream),
            scaffoldBackgroundColor: const Color(0xfff6eedc),
            fontFamily: 'Galmuri'),
        home: GuildHome(
            onLanguageChanged: (value) =>
                setState(() => languageOverride = value)),
      );
}

class GuildHome extends StatefulWidget {
  final ValueChanged<String?>? onLanguageChanged;
  const GuildHome({super.key, this.onLanguageChanged});
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
  Timer? tutorialPauseTimer;
  bool tutorialPaused = false;
  bool greetingFinished = false;
  bool? tutorialComplete;
  String? languageOverride;
  String get language {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final code = languageOverride ??
        (dispatcher.locales.isEmpty ? 'en' : dispatcher.locale.languageCode);
    return const ['ko', 'en', 'ja', 'zh', 'hi', 'es'].contains(code)
        ? code
        : 'en';
  }

  String t(String text) => translate(language, text);
  int tutorialStep = 0;

  String get dateKey {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    dateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (today != null && today!['date'] != dateKey && !busy) load();
    });
  }

  @override
  void dispose() {
    greetingTimer?.cancel();
    tutorialPauseTimer?.cancel();
    dateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted && languageOverride == null) setState(() {});
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
        if (saved['catalogVersion'] == null && saved['date'] == dateKey) {
          const legacyQuests = <(String, String)>[
            ('잠시 하늘을 올려다보기', '잠시 걸음을 멈추고 구름이나 별이 떠 있는 하늘을 바라봐.'),
            ('오래된 사진 꺼내 보기', '마음에 남은 오래된 사진 한 장을 꺼내 천천히 들여다봐.'),
            ('안부 한 줄 보내기', '문득 떠오르는 사람에게 가볍게 안부를 전해 봐.'),
          ];
          final oldIndex = saved['quest'];
          if (oldIndex is int &&
              oldIndex >= 0 &&
              oldIndex < legacyQuests.length) {
            saved['legacyTitle'] = legacyQuests[oldIndex].$1;
            saved['legacyDescription'] = legacyQuests[oldIndex].$2;
            saved['catalogVersion'] = 1;
            if (!await store.setString('today', jsonEncode(saved))) {
              throw Exception('저장 실패');
            }
          }
        }
        if (saved['quest'] is! int ||
            (saved['quest'] as int) < 0 ||
            (saved['quest'] as int) >= quests.length) {
          throw const FormatException('잘못된 퀘스트 기록');
        }
      }
      if (saved == null || saved['date'] != dateKey) {
        final index = Random().nextInt(quests.length);
        saved = {
          'gold': saved?['gold'] ?? 0,
          'unlocked': saved?['unlocked'] ?? <String>[],
          'active': saved?['active'] ?? '',
          'failed': false,
          'date': dateKey,
          'quest': index,
          'catalogVersion': 1,
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
          tutorialComplete ??= store.getBool('tutorial_complete') ?? false;
          languageOverride = store.getString('language_override');
        });
      }
      if (tutorialComplete == true &&
          !greetingFinished &&
          greetingTimer == null) {
        startGreeting();
      }
    } catch (_) {
      if (mounted) setState(() => error = t('오늘의 의뢰를 불러오지 못했어요. 다시 시도해 주세요.'));
    }
  }

  void startGreeting() {
    greetingTimer?.cancel();
    greetingTimer = Timer(
        Duration(milliseconds: max(3000, greeting.runes.length * 150 + 1000)),
        () {
      if (mounted) setState(() => greetingFinished = true);
    });
  }

  Future<void> advanceTutorial() async {
    if (busy || tutorialPaused || prefs == null) return;
    if (tutorialStep < guildTutorial.length - 1) {
      if (tutorialStep == tutorialPauseAfterStep) {
        setState(() => tutorialPaused = true);
        tutorialPauseTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              tutorialStep++;
              tutorialPaused = false;
            });
          }
        });
      } else {
        setState(() => tutorialStep++);
      }
      return;
    }
    setState(() => busy = true);
    try {
      if (!await prefs!.setBool('tutorial_complete', true)) {
        throw Exception('저장 실패');
      }
      if (mounted) {
        setState(() {
          tutorialComplete = true;
          greetingFinished = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('안내 진행 상태를 저장하지 못했어요. 다시 시도해 주세요.'))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> update(String key) async {
    if (busy || today == null) return;
    if (today!['date'] != dateKey) {
      await load();
      return;
    }
    if ((key == 'completed' || key == 'failed') &&
        (today!['completed'] == true ||
            today!['failed'] == true ||
            today!['opened'] != true)) {
      return;
    }
    setState(() => busy = true);
    final next = {...today!, key: true};
    if (key == 'completed') next['gold'] = (today!['gold'] as int? ?? 0) + 10;
    try {
      if (!await prefs!.setString('today', jsonEncode(next))) {
        throw Exception('저장 실패');
      }
      if (mounted) setState(() => today = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('기록을 저장하지 못했어요. 다시 시도해 주세요.'))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static const decorations = <(String, String, int)>[
    ('plant', '작은 화분', 10),
    ('banner', '길드 깃발', 20),
    ('lantern', '따뜻한 등불', 30),
  ];

  Future<bool> selectDecoration(String id, int price) async {
    if (busy || today == null || prefs == null) return false;
    if (today!['date'] != dateKey) {
      await load();
      return false;
    }
    final owned = List<String>.from(today!['unlocked'] as List? ?? []);
    var gold = today!['gold'] as int? ?? 0;
    if (!owned.contains(id)) {
      if (gold < price) return false;
      gold -= price;
      owned.add(id);
    }
    final active = today!['active'] == id ? '' : id;
    final next = {...today!, 'gold': gold, 'unlocked': owned, 'active': active};
    setState(() => busy = true);
    try {
      if (!await prefs!.setString('today', jsonEncode(next))) {
        throw Exception('저장 실패');
      }
      if (mounted) setState(() => today = next);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('꾸미기 기록을 저장하지 못했어요.'))));
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showDecorations() {
    showDialog<void>(
        context: context,
        builder: (dialogContext) =>
            StatefulBuilder(builder: (context, refresh) {
              final owned =
                  List<String>.from(today?['unlocked'] as List? ?? []);
              final gold = today?['gold'] as int? ?? 0;
              return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                      child: PixelPanel(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                        Row(children: [
                          Expanded(
                              child: Text(t('길드 꾸미기'),
                                  style: TextStyle(
                                      color: ink,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800))),
                          IconButton(
                              tooltip: t('닫기'),
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close, color: brown))
                        ]),
                        Text('${t("보유 골드")}  $gold G',
                            style: const TextStyle(
                                color: brown, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(t('모험으로 모은 골드로 길드를 꾸며 보세요. 장식은 하나씩 놓을 수 있어요.'),
                            style: TextStyle(
                                color: ink, height: 1.6, fontSize: 13)),
                        const SizedBox(height: 16),
                        for (final (id, name, price) in decorations
                            .map((d) => (d.$1, t(d.$2), d.$3))) ...[
                          GuildButton(
                              label: owned.contains(id)
                                  ? (today?['active'] == id
                                      ? '$name · ${t("치우기")}'
                                      : '$name · ${t("놓기")}')
                                  : '$name · $price G',
                              onPressed:
                                  busy || (!owned.contains(id) && gold < price)
                                      ? null
                                      : () async {
                                          await selectDecoration(id, price);
                                          if (context.mounted) refresh(() {});
                                        }),
                          const SizedBox(height: 7),
                        ],
                        const SizedBox(height: 8),
                        GuildButton(
                            label: t('돌아가기'),
                            onPressed: () => Navigator.pop(dialogContext)),
                      ]))));
            }));
  }

  Future<void> showLanguageSettings() async {
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                  child: PixelPanel(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                    Text(t('언어'),
                        style: const TextStyle(
                            color: ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    for (final (code, name) in [
                      ('device', t('기기 설정 따르기')),
                      ('ko', '한국어'),
                      ('en', 'English'),
                      ('ja', '日本語'),
                      ('zh', '简体中文'),
                      ('hi', 'हिन्दी'),
                      ('es', 'Español')
                    ]) ...[
                      GuildButton(
                          label:
                              '${(languageOverride ?? 'device') == code ? '● ' : ''}$name',
                          onPressed: () async {
                            try {
                              final store = prefs ??
                                  await SharedPreferences.getInstance();
                              final success = code == 'device'
                                  ? await store.remove('language_override')
                                  : await store.setString(
                                      'language_override', code);
                              if (!success) throw Exception('save failed');
                              if (!mounted || !dialogContext.mounted) return;
                              setState(() => languageOverride =
                                  code == 'device' ? null : code);
                              widget.onLanguageChanged?.call(languageOverride);
                              Navigator.pop(dialogContext);
                            } catch (_) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(SnackBar(
                                        content: Text(
                                            t('기록을 저장하지 못했어요. 다시 시도해 주세요.'))));
                              }
                            }
                          }),
                      const SizedBox(height: 7),
                    ],
                    const SizedBox(height: 6),
                    GuildButton(
                        label: t('돌아가기'),
                        onPressed: () => Navigator.pop(dialogContext)),
                  ]))),
            ));
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
                      child: Text(support ? t('길드 지원하기') : t('의뢰 제안하기'),
                          style: const TextStyle(
                              color: ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800))),
                  IconButton(
                      tooltip: t('닫기'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: brown)),
                ]),
                const SizedBox(height: 8),
                Text(
                    support
                        ? t('이 작은 모험들이 내일도 이어질 수 있도록, 원한다면 길드에 보급품을 보내주세요.')
                        : t('다른 모험가들과 나누고 싶은 작은 경험이 있나요? 당신의 의뢰가 언젠가 오늘의 퀘스트가 될지도 모릅니다.'),
                    style: const TextStyle(color: ink, height: 1.7)),
                const SizedBox(height: 18),
                if (support) ...[
                  for (final name in [t('작은 보급품'), t('든든한 보급품'), t('특별 보급품')])
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
                  Text(t('후원 기능은 준비 중이에요. 모든 퀘스트는 언제나 무료입니다.'),
                      style:
                          TextStyle(color: brown, fontSize: 12, height: 1.6)),
                ] else ...[
                  Text(t('의뢰 접수는 준비 중이에요. 후원 여부는 의뢰 채택에 영향을 주지 않습니다.'),
                      style:
                          TextStyle(color: brown, fontSize: 12, height: 1.6)),
                ],
                const SizedBox(height: 18),
                GuildButton(
                    label: t('돌아가기'), onPressed: () => Navigator.pop(context)),
              ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = today == null
        ? null
        : today!['legacyTitle'] is String &&
                today!['legacyDescription'] is String
            ? (
                today!['legacyTitle'] as String,
                today!['legacyDescription'] as String
              )
            : quests[today!['quest'] as int];
    final opened = today?['opened'] == true;
    final completed = today?['completed'] == true;
    final failed = today?['failed'] == true;
    final resolved = completed || failed;
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
            if (today?['active'] != null && today?['active'] != '')
              Positioned.fill(
                  child: IgnorePointer(
                      child: CustomPaint(
                          painter:
                              DecorationPainter(today!['active'] as String)))),
            const Positioned.fill(
                child: IgnorePointer(child: GuildLanternGlow())),
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
                  const Spacer(),
                  Tooltip(
                    message: t('보유 골드'),
                    child: DecoratedBox(
                      decoration: headerWoodDecoration,
                      child: TextButton(
                        onPressed: today == null ? null : showDecorations,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xffffefcc),
                          disabledForegroundColor: const Color(0xffc2ab86),
                          shape: const RoundedRectangleBorder(),
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CustomPaint(
                                  painter: HeaderIconPainter(coin: true))),
                          const SizedBox(width: 7),
                          Text("${today?['gold'] ?? 0} G",
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: t('길드 메뉴'),
                    color: cream,
                    iconColor: const Color(0xffffedc7),
                    shape: const RoundedRectangleBorder(),
                    onSelected: (v) {
                      if (v == 'settings') {
                        showLanguageSettings();
                      } else if (v == 'licenses') {
                        showLicensePage(
                            context: context, applicationName: 'Hvildir');
                      } else if (v == 'decorate') {
                        showDecorations();
                      } else {
                        showInfo(v == 'support');
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'settings', child: Text(t('설정'))),
                      PopupMenuItem(
                          value: 'licenses', child: Text(t('오픈소스 라이선스'))),
                      PopupMenuItem(
                          value: 'decorate', child: Text(t('길드 꾸미기'))),
                      PopupMenuItem(
                          value: 'support', child: Text(t('길드 지원하기'))),
                      PopupMenuItem(
                          value: 'suggest', child: Text(t('의뢰 제안하기'))),
                    ],
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: headerWoodDecoration,
                      padding: const EdgeInsets.all(12),
                      child: const CustomPaint(painter: HeaderIconPainter()),
                    ),
                  ),
                ])),
          ]),
          Transform.translate(
              offset: const Offset(0, -18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!tutorialPaused)
                        PixelPanel(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(t('길드주인'),
                                  style: TextStyle(
                                      color: Color(0xff926c49),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .5)),
                              const SizedBox(height: 7),
                              Text(
                                  tutorialComplete == false
                                      ? t(guildTutorial[tutorialStep])
                                      : t(greeting),
                                  style: const TextStyle(
                                      color: ink,
                                      fontFamily: 'sans-serif',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 1.6)),
                            ])),
                      const SizedBox(height: 20),
                      if (tutorialPaused)
                        const SizedBox.shrink()
                      else if (tutorialComplete == false) ...[
                        Center(
                            child: Text(
                                '${tutorialStep + 1} / ${guildTutorial.length}',
                                style: const TextStyle(
                                    color: Color(0xffc8ae8b), fontSize: 12))),
                        const SizedBox(height: 12),
                        GuildButton(
                            label: tutorialStep == guildTutorial.length - 1
                                ? t('모험 시작하기')
                                : t('다음 이야기'),
                            onPressed: busy ? null : advanceTutorial),
                      ] else if (error != null) ...[
                        Text(error!,
                            style: const TextStyle(color: Color(0xffffd3ae))),
                        TextButton(onPressed: load, child: Text(t('다시 시도'))),
                      ] else if (today == null)
                        Center(
                            child: CircularProgressIndicator(
                                color: Color(0xffe5c793)))
                      else if (!greetingFinished)
                        Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text(t('길드주인의 이야기를 듣고 있어요…'),
                                    style: TextStyle(
                                        color: Color(0xffc8ae8b),
                                        fontSize: 12))))
                      else if (!opened) ...[
                        Center(
                            child: Text(t('오늘의 의뢰가 도착했어요'),
                                style: TextStyle(
                                    color: Color(0xffdbc49d), fontSize: 13))),
                        const SizedBox(height: 8),
                        Center(
                            child: TextButton(
                          onPressed: busy ? null : () => update('opened'),
                          style: TextButton.styleFrom(
                              foregroundColor: const Color(0xfff4ddaf),
                              shape: const RoundedRectangleBorder(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 4)),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(
                                width: 174,
                                height: 142,
                                child: Image.asset(
                                    'assets/sealed_scroll_v2.png',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.none)),
                            SizedBox(height: 4),
                            Text(t('양피지 열기'),
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                          ]),
                        )),
                        const SizedBox(height: 4),
                        Center(
                            child: Text(t('봉인을 눌러 의뢰를 확인하세요'),
                                style: TextStyle(
                                    color: Color(0xffaa9275), fontSize: 12))),
                      ] else
                        PixelPanel(
                          parchment: true,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                    child: Text(t('오늘의 사이드퀘스트'),
                                        style: TextStyle(
                                            color: Color(0xff9a744f),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: .5))),
                                const SizedBox(height: 20),
                                Text(t(item!.$1),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: ink,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        height: 1.4)),
                                const SizedBox(height: 12),
                                Text(t(item.$2),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xff70533a),
                                        fontFamily: 'sans-serif',
                                        fontSize: 15,
                                        height: 1.7)),
                                const SizedBox(height: 22),
                                if (!resolved) ...[
                                  Center(
                                      child: Text(t('완료 보상 · 10 G'),
                                          style: TextStyle(
                                              color: Color(0xff92704c),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700))),
                                  const SizedBox(height: 10),
                                  GuildButton(
                                      label: t('퀘스트 완료'),
                                      onPressed: busy
                                          ? null
                                          : () => update('completed')),
                                  const SizedBox(height: 8),
                                  GuildButton(
                                      label: t('퀘스트 실패'),
                                      onPressed:
                                          busy ? null : () => update('failed')),
                                ] else
                                  GuildButton(
                                      label:
                                          completed ? t('퀘스트 완료') : t('퀘스트 실패'),
                                      onPressed: null),
                                const SizedBox(height: 12),
                                Text(
                                    completed
                                        ? t('작은 모험의 보상으로 10 G를 받았어요.')
                                        : failed
                                            ? t('괜찮아요. 내일 또 다른 모험이 기다려요.')
                                            : t(
                                                '완료 여부는 스스로 선택해 주세요. 하지 않아도 괜찮아요.'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xff957858),
                                        fontSize: 11,
                                        height: 1.5)),
                              ]),
                        ),
                      const SizedBox(height: 24),
                      Center(
                          child: Text(t('평범한 하루에도 모험은 숨어 있으니까요.'),
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

class DecorationPainter extends CustomPainter {
  final String active;
  const DecorationPainter(this.active);
  @override
  void paint(Canvas canvas, Size size) {
    void rect(double x, double y, double w, double h, Color color) =>
        canvas.drawRect(
            Rect.fromLTWH(size.width * x, size.height * y, size.width * w,
                size.height * h),
            Paint()..color = color);
    const dark = Color(0xff573c2b),
        gold = Color(0xffd4a960),
        green = Color(0xff70885a),
        red = Color(0xff9f5b47);
    if (active == 'plant') {
      rect(.79, .72, .11, .07, dark);
      rect(.80, .70, .09, .05, red);
      rect(.825, .62, .035, .08, green);
      rect(.80, .64, .035, .035, green);
      rect(.85, .62, .035, .035, green);
    } else if (active == 'banner') {
      rect(.05, .22, .13, .03, dark);
      rect(.06, .25, .11, .19, green);
      rect(.08, .29, .07, .025, gold);
      rect(.10, .275, .025, .08, gold);
    } else if (active == 'lantern') {
      rect(.79, .68, .09, .02, dark);
      rect(.81, .60, .05, .08, dark);
      rect(.82, .61, .03, .06, gold);
      rect(.81, .58, .05, .02, dark);
    }
  }

  @override
  bool shouldRepaint(covariant DecorationPainter oldDelegate) =>
      active != oldDelegate.active;
}

class GuildLanternGlow extends StatefulWidget {
  const GuildLanternGlow({super.key});
  @override
  State<GuildLanternGlow> createState() => _GuildLanternGlowState();
}

class _GuildLanternGlowState extends State<GuildLanternGlow>
    with WidgetsBindingObserver {
  Timer? timer;
  int frame = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    start();
  }

  void start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        setState(() => frame = (frame + 1) % 4);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      start();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: LanternGlowPainter(frame));
}

class LanternGlowPainter extends CustomPainter {
  final int frame;
  const LanternGlowPainter(this.frame);
  @override
  void paint(Canvas canvas, Size size) {
    final alpha = [0.10, 0.18, 0.13, 0.21][frame];
    final p = Paint()..color = const Color(0xffffd37c).withValues(alpha: alpha);
    final u = size.width / 120;
    canvas.drawRect(
        Rect.fromLTWH(size.width * .107, size.height * .317, u * 2, u * 3), p);
    canvas.drawRect(
        Rect.fromLTWH(size.width * .126, size.height * .31, u, u * 4), p);
    canvas.drawRect(
        Rect.fromLTWH(size.width * .09, size.height * .35, u, u), p);
  }

  @override
  bool shouldRepaint(covariant LanternGlowPainter oldDelegate) =>
      oldDelegate.frame != frame;
}

const headerWoodDecoration = BoxDecoration(
  image: DecorationImage(
    image: ResizeImage(AssetImage('assets/wood_button.png'),
        width: 432, height: 144),
    centerSlice: Rect.fromLTRB(12, 8, 420, 136),
    fit: BoxFit.fill,
    filterQuality: FilterQuality.none,
  ),
);

class HeaderIconPainter extends CustomPainter {
  final bool coin;
  const HeaderIconPainter({this.coin = false});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    void box(double x, double y, double w, double h, Color color) {
      paint.color = color;
      canvas.drawRect(
          Rect.fromLTWH(
              size.width * x, size.height * y, size.width * w, size.height * h),
          paint);
    }

    if (coin) {
      box(.2, .1, .6, .8, const Color(0xffa46424));
      box(.1, .2, .8, .6, const Color(0xffa46424));
      box(.2, .2, .6, .6, const Color(0xffffcb62));
      box(.3, .3, .15, .4, const Color(0xffffe2a2));
    } else {
      for (final y in [.2, .45, .7]) {
        box(.1, y, .8, .12, const Color(0xffffefcc));
      }
    }
  }

  @override
  bool shouldRepaint(covariant HeaderIconPainter oldDelegate) =>
      oldDelegate.coin != coin;
}

class PixelPanel extends StatelessWidget {
  final Widget child;
  final bool parchment;
  const PixelPanel({super.key, required this.child, this.parchment = false});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
            image: DecorationImage(
                image: ResizeImage(AssetImage('assets/dialogue_frame.png'),
                    width: 355, height: 177),
                centerSlice: Rect.fromLTRB(12, 8, 343, 169),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none)),
        child: Padding(
            padding: EdgeInsets.fromLTRB(parchment ? 28 : 22,
                parchment ? 40 : 19, parchment ? 28 : 22, parchment ? 26 : 19),
            child: child),
      );
}

class GuildButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GuildButton({super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onPressed == null ? .55 : 1,
        child: DecoratedBox(
          decoration: const BoxDecoration(
              image: DecorationImage(
                  image: ResizeImage(AssetImage('assets/wood_button.png'),
                      width: 432, height: 144),
                  centerSlice: Rect.fromLTRB(12, 8, 420, 136),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none)),
          child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xffffefd1),
                  disabledForegroundColor: const Color(0xffffefd1),
                  shape: const RoundedRectangleBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 18)),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700))),
        ),
      );
}
