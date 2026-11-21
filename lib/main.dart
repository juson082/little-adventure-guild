import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guild_content.dart';
import 'guild_audio.dart';
import 'quest_environment.dart';
import 'quest_schedule.dart';
import 'environment_service.dart';
import 'guild_decorations.dart';
import 'guild_keeper_idle.dart';
import 'natural_text.dart';
import 'hard_quests.dart';
import 'quest_feedback.dart';
import 'guild_support.dart';
import 'support_messages.dart';
import 'translations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Galmuri',
    ], await rootBundle.loadString('assets/fonts/Galmuri-LICENSE.txt'));
    yield LicenseEntryWithLineBreaks([
      'MuseScore General / FluidR3',
    ], await rootBundle.loadString('assets/licenses/MS-Basic-LICENSE.txt'));
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
      Locale('es'),
    ],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    localeResolutionCallback: (locale, supported) => supported.firstWhere(
      (v) => v.languageCode == locale?.languageCode,
      orElse: () => const Locale('en'),
    ),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brown, surface: cream),
      scaffoldBackgroundColor: const Color(0xfff6eedc),
      fontFamily: 'Galmuri',
    ),
    home: GuildHome(
      onLanguageChanged: (value) => setState(() => languageOverride = value),
    ),
  );
}

Future<T?> showGuildDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black54,
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (context, _, __) => builder(context),
  transitionBuilder: (context, animation, _, child) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(
        begin: .93,
        end: 1,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    ),
  ),
);

class GuildHome extends StatefulWidget {
  final ValueChanged<String?>? onLanguageChanged;
  const GuildHome({super.key, this.onLanguageChanged});
  @override
  State<GuildHome> createState() => _GuildHomeState();
}

class _GuildHomeState extends State<GuildHome> with WidgetsBindingObserver {
  final GuildSupport guildSupport = GuildSupport();
  String greeting = guildGreetings.first;
  SharedPreferences? prefs;
  Map<String, dynamic>? today;
  String? error;
  bool busy = false;
  bool loading = false;
  static const weatherPreference = 'weather_location_enabled_met_no_v1';
  static const environmentService = EnvironmentService();
  bool rewarding = false;
  Offset rewardStart = Offset.zero;
  Offset rewardEnd = Offset.zero;
  final screenKey = GlobalKey();
  final goldKey = GlobalKey();
  final completeKey = GlobalKey();
  final ScrollController screenScroll = ScrollController();
  Timer? dateTimer;
  Timer? questExpiryTimer;
  Timer? greetingTimer;
  Timer? tutorialPauseTimer;
  Timer? idleTimer;
  final dialogueKey = GlobalKey<_GuildDialogueTextState>();
  bool idlePending = false;
  bool idleShown = false;
  int? idleMessageIndex;
  bool appVisible = true;
  bool tutorialPaused = false;
  bool greetingFinished = false;
  bool revealing = false;
  double musicVolume = 1;
  double effectsVolume = 1;
  bool documentClosed = false;
  bool showGreeting = false;
  bool? feedbackSuccess;
  int feedbackIndex = 0;
  bool? tutorialComplete;
  String? languageOverride;
  String get language {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final code =
        languageOverride ??
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
    guildSupport.initialize();
    WidgetsBinding.instance.addObserver(this);
    load();
    dateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (questHasExpired(today, DateTime.now()) && !busy && !rewarding) {
        load(isVisit: false);
      }
    });
  }

  @override
  void dispose() {
    guildSupport.dispose();
    questExpiryTimer?.cancel();
    screenScroll.dispose();
    greetingTimer?.cancel();
    tutorialPauseTimer?.cancel();
    idleTimer?.cancel();
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
    appVisible = state == AppLifecycleState.resumed;
    if (appVisible) guildSupport.onAppResumed();
    if (!appVisible) {
      idleTimer?.cancel();
      idlePending = false;
    } else if ((today?['completed'] == true || today?['failed'] == true) &&
        !idleShown) {
      scheduleIdleMessage();
    }
    if (state == AppLifecycleState.resumed &&
        (questHasExpired(today, DateTime.now()) ||
            (prefs != null &&
                prefs!.getString('last_visit_date') != dateKey))) {
      load();
    }
  }

  Future<void> load({bool isVisit = true}) async {
    if (loading) return;
    loading = true;
    try {
      final store = await SharedPreferences.getInstance();
      final savedMusicVolume = (store.getDouble('music_volume') ?? 1.0).clamp(
        0.0,
        1.0,
      );
      final savedEffectsVolume = (store.getDouble('effects_volume') ?? 1.0)
          .clamp(0.0, 1.0);
      GuildAudio.setMusicVolume(savedMusicVolume);
      GuildAudio.setEffectsVolume(savedEffectsVolume);
      final completedTutorial =
          tutorialComplete ?? store.getBool('tutorial_complete') ?? false;
      languageOverride = store.getString('language_override');
      if (isVisit &&
          Platform.isAndroid &&
          completedTutorial &&
          !store.containsKey(weatherPreference)) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await offerWeatherChoice(store);
        if (!mounted) return;
      }
      final raw = store.getString('today');
      Map<String, dynamic>? saved;
      String? previousQuestDate;
      if (raw != null) {
        saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        previousQuestDate = saved['date'] is String
            ? saved['date'] as String
            : null;
        if (saved['catalogVersion'] == null) {
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
            (saved['quest'] as int) >= quests.length + hardQuests.length) {
          throw const FormatException('잘못된 퀘스트 기록');
        }
      }
      // Older versions did not record the opening instant. Keep the existing
      // opened quest for a full 24 hours from migration instead of replacing it.
      if (saved != null &&
          saved['opened'] == true &&
          saved['opened_at_ms'] is! int) {
        saved['opened_at_ms'] = DateTime.now().toUtc().millisecondsSinceEpoch;
        if (!await store.setString('today', jsonEncode(saved))) {
          throw Exception('save failed');
        }
      }
      if (saved == null || questHasExpired(saved, DateTime.now())) {
        idleTimer?.cancel();
        idlePending = false;
        idleShown = false;
        idleMessageIndex = null;
        final previousUnopened = saved != null && saved['opened'] != true
            ? saved['quest'] as int?
            : null;
        WeatherObservation? weather;
        if (store.getBool(weatherPreference) == true) {
          weather = await environmentService.currentWeather().timeout(
            const Duration(seconds: 14),
            onTimeout: () => null,
          );
        }
        final index = chooseDailyQuest(
          QuestEnvironment(weather: weather),
          Random(),
          excludeIndex: previousUnopened,
        );
        saved = {
          'gold': saved?['gold'] ?? 0,
          'unlocked': saved?['unlocked'] ?? <String>[],
          'active_items': saved?['active_items'] ?? <String>[],
          'failed': false,
          'date': dateKey,
          'quest': index,
          'catalogVersion': 1,
          'opened': false,
          'completed': false,
        };
        if (!await store.setString('today', jsonEncode(saved))) {
          throw Exception('저장 실패');
        }
      }
      final previousVisit = DateTime.tryParse(
        store.getString('last_visit_date') ?? previousQuestDate ?? '',
      );
      final currentDate = DateTime.parse(dateKey);
      final absentDays = previousVisit == null
          ? 0
          : DateTime.utc(currentDate.year, currentDate.month, currentDate.day)
                .difference(
                  DateTime.utc(
                    previousVisit.year,
                    previousVisit.month,
                    previousVisit.day,
                  ),
                )
                .inDays;
      final shouldGreet =
          isVisit &&
          completedTutorial &&
          store.getString('last_greeting_date') != dateKey;
      final choices = absentDays >= 3 ? guildReturnGreetings : guildGreetings;
      final selectedGreeting = choices[Random().nextInt(choices.length)];
      if (shouldGreet &&
          !await store.setString('last_greeting_date', dateKey)) {
        throw Exception('저장 실패');
      }
      if (isVisit &&
          store.getString('last_visit_date') != dateKey &&
          !await store.setString('last_visit_date', dateKey)) {
        throw Exception('저장 실패');
      }
      if (mounted) {
        setState(() {
          prefs = store;
          musicVolume = savedMusicVolume;
          effectsVolume = savedEffectsVolume;
          today = saved;
          error = null;
          tutorialComplete = completedTutorial;
          languageOverride = store.getString('language_override');
          if (shouldGreet) greeting = selectedGreeting;
          if (isVisit) {
            feedbackSuccess = null;
            showGreeting = shouldGreet;
            greetingFinished = completedTutorial && !shouldGreet;
          }
        });
      }
      scheduleQuestExpiry();
      if (shouldGreet) {
        startGreeting();
      }
    } catch (_) {
      if (mounted) setState(() => error = t('오늘의 의뢰를 불러오지 못했어요. 다시 시도해 주세요.'));
    } finally {
      loading = false;
    }
  }

  void scheduleQuestExpiry() {
    questExpiryTimer?.cancel();
    final remaining = timeUntilQuestExpiry(today, DateTime.now());
    if (remaining == null) return;
    if (remaining <= Duration.zero) {
      questExpiryTimer = Timer(const Duration(seconds: 1), () {
        if (mounted && !busy && !rewarding) load(isVisit: false);
      });
      return;
    }
    questExpiryTimer = Timer(remaining, () {
      if (!mounted) return;
      if (!busy && !rewarding) {
        load(isVisit: false);
      } else {
        scheduleQuestExpiry();
      }
    });
  }

  void startGreeting() {
    greetingTimer?.cancel();
  }

  void scheduleIdleMessage() {
    idleTimer?.cancel();
    if (!appVisible || idleShown) return;
    idleTimer = Timer(const Duration(minutes: 1), () {
      if (!mounted ||
          !appVisible ||
          (today?['completed'] != true && today?['failed'] != true)) {
        return;
      }
      if (showGreeting) {
        idlePending = true;
      } else {
        showIdleMessage();
      }
    });
  }

  void showIdleMessage() {
    if (!mounted || idleShown) return;
    idlePending = false;
    idleShown = true;
    setState(() {
      idleMessageIndex = Random().nextInt(questIdleMessages['ko']!.length);
      feedbackSuccess = null;
      greetingFinished = false;
      showGreeting = true;
    });
  }

  void advanceDialogue() {
    if (dialogueKey.currentState?.revealAll() == true) return;
    if (tutorialComplete == false) {
      advanceTutorial();
      return;
    }
    if (!showGreeting) return;
    setState(() => showGreeting = false);
    greetingTimer?.cancel();
    greetingTimer = Timer(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(() => greetingFinished = true);
      if (idlePending) showIdleMessage();
    });
  }

  Future<void> advanceTutorial() async {
    if (busy || tutorialPaused || prefs == null) return;
    if (tutorialStep < guildTutorial.length - 1) {
      if (tutorialStep == tutorialPauseAfterStep) {
        setState(() => tutorialPaused = true);
        GuildAudio.question();
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
      if (!await prefs!.setString('last_greeting_date', dateKey)) {
        throw Exception('저장 실패');
      }
      if (!await prefs!.setBool('tutorial_complete', true)) {
        throw Exception('저장 실패');
      }
      if (mounted) {
        setState(() {
          tutorialComplete = true;
          greetingFinished = true;
          showGreeting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('안내 진행 상태를 저장하지 못했어요. 다시 시도해 주세요.'))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted &&
        Platform.isAndroid &&
        tutorialComplete == true &&
        prefs != null &&
        !prefs!.containsKey(weatherPreference)) {
      await offerWeatherChoice(prefs!);
    }
  }

  Future<void> openQuest() async {
    if (busy || revealing || today == null) return;
    if (questHasExpired(today, DateTime.now())) {
      await load();
      return;
    }
    if (today!['opened'] == true) {
      setState(() => documentClosed = false);
      return;
    }
    final openedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    setState(() {
      revealing = true;
      documentClosed = false;
    });
    GuildAudio.reveal(hard: (today!['quest'] as int) >= quests.length);
    await update('opened', openedAt: openedAt);
    if (!mounted) return;
    await Future<void>.delayed(
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(seconds: 3),
    );
    if (!mounted) return;
    setState(() => revealing = false);
  }

  Future<void> completeQuest() async {
    if (busy ||
        rewarding ||
        today == null ||
        today!['opened'] != true ||
        today!['completed'] == true ||
        today!['failed'] == true) {
      return;
    }
    if (questHasExpired(today, DateTime.now())) {
      await load();
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      await update('completed');
      if (mounted && today?['completed'] == true) {
        GuildAudio.gold();
        showQuestFeedback(true);
      }
      return;
    }
    final root = screenKey.currentContext?.findRenderObject() as RenderBox?;
    final button = completeKey.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || button == null) {
      await update('completed');
      if (mounted && today?['completed'] == true) {
        GuildAudio.gold();
        showQuestFeedback(true);
      }
      return;
    }
    final start = root.globalToLocal(
      button.localToGlobal(button.size.center(Offset.zero)),
    );
    setState(() {
      rewarding = true;
      rewardEnd = Offset.zero;
    });
    if (screenScroll.hasClients) {
      await screenScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return;
    final target = goldKey.currentContext?.findRenderObject() as RenderBox?;
    final end = target == null
        ? Offset(root.size.width - 85, 38)
        : root.globalToLocal(
            target.localToGlobal(target.size.center(Offset.zero)),
          );
    setState(() {
      rewardStart = start;
      rewardEnd = end;
    });
    GuildAudio.gold();
    await Future<void>.delayed(const Duration(milliseconds: 1450));
    if (!mounted) return;
    await update('completed');
    if (mounted) {
      setState(() => rewarding = false);
      if (today?['completed'] == true) showQuestFeedback(true);
    }
  }

  Future<void> failQuest() async {
    await update('failed');
    if (mounted && today?['failed'] == true) showQuestFeedback(false);
  }

  void showQuestFeedback(bool success) {
    final messages = success ? questSuccessMessages : questFailureMessages;
    final index = Random().nextInt(messages['ko']!.length);
    setState(() {
      feedbackSuccess = success;
      idleMessageIndex = null;
      feedbackIndex = index;
      greeting = messages['ko']![index];
      documentClosed = true;
      greetingFinished = false;
      showGreeting = true;
    });
    startGreeting();
    idleShown = false;
    scheduleIdleMessage();
  }

  Future<void> update(String key, {int? openedAt}) async {
    if (busy || today == null) return;
    final checkedAt = key == 'opened' && openedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(openedAt)
        : DateTime.now();
    if (questHasExpired(today, checkedAt)) {
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
    if (key == 'opened') {
      next['opened_at_ms'] =
          openedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    }
    if (key == 'completed') {
      final isHard = (today!['quest'] as int) >= quests.length;
      next['gold'] = (today!['gold'] as int? ?? 0) + (isHard ? 30 : 10);
    }
    try {
      if (!await prefs!.setString('today', jsonEncode(next))) {
        throw Exception('저장 실패');
      }
      if (mounted) {
        setState(() => today = next);
        if (key == 'opened') scheduleQuestExpiry();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('기록을 저장하지 못했어요. 다시 시도해 주세요.'))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> selectDecoration(GuildDecoration decoration) async {
    if (busy || today == null || prefs == null) return false;
    if (questHasExpired(today, DateTime.now())) {
      await load();
      return false;
    }
    final owned = List<String>.from(today!['unlocked'] as List? ?? []);
    final active = List<String>.from(today!['active_items'] as List? ?? []);
    var gold = today!['gold'] as int? ?? 0;
    if (!owned.contains(decoration.id)) {
      if (gold < decorationPrice) return false;
      gold -= decorationPrice;
      owned.add(decoration.id);
    }
    if (active.contains(decoration.id)) {
      active.remove(decoration.id);
    } else {
      final sameSlot = guildDecorations
          .where((item) => item.slot == decoration.slot)
          .map((item) => item.id)
          .toSet();
      active.removeWhere(sameSlot.contains);
      active.add(decoration.id);
    }
    final next = {
      ...today!,
      'gold': gold,
      'unlocked': owned,
      'active_items': active,
    };
    setState(() => busy = true);
    try {
      if (!await prefs!.setString('today', jsonEncode(next))) {
        throw Exception('save failed');
      }
      if (mounted) setState(() => today = next);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t('꾸미기 기록을 저장하지 못했어요.'))));
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showGuildMenu() {
    showGuildDialog<void>(
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
                Align(
                  alignment: Alignment.centerRight,
                  child: PixelCloseButton(
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
                for (final entry in [
                  ('settings', t('설정')),
                  ('support', t('길드 지원하기')),
                  ('suggest', t('의뢰 제안하기')),
                ]) ...[
                  GuildButton(
                    label: entry.$2,
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (entry.$1 == 'settings') {
                        showLanguageSettings();
                      } else {
                        showInfo(entry.$1 == 'support');
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        showLicenses();
                      },
                      child: Text(
                        t('오픈소스 라이선스'),
                        style: const TextStyle(fontSize: 11, color: brown),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        showPrivacyPolicy();
                      },
                      child: Text(
                        language == 'ko' ? '개인정보처리방침' : 'Privacy policy',
                        style: const TextStyle(fontSize: 11, color: brown),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showLicenses() {
    showGuildDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: PixelPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: PixelCloseButton(
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
              Flexible(
                child: FutureBuilder<List<LicenseEntry>>(
                  future: LicenseRegistry.licenses.toList(),
                  builder: (context, snapshot) => SingleChildScrollView(
                    child: SelectableText(
                      snapshot.data
                              ?.map(
                                (entry) =>
                                    '${entry.packages.join(', ')}\n${entry.paragraphs.map((p) => p.text).join('\n')}',
                              )
                              .join('\n\n') ??
                          '',
                      style: const TextStyle(
                        color: ink,
                        fontFamily: 'sans-serif',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showPrivacyPolicy() {
    showGuildDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: PixelPanel(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: PixelCloseButton(
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
                FutureBuilder<String>(
                  future: rootBundle.loadString('assets/privacy_policy.txt'),
                  builder: (context, snapshot) => SelectableText(
                    snapshot.data ?? '',
                    style: const TextStyle(
                      color: ink,
                      fontFamily: 'sans-serif',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showDecorations() {
    showGuildDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          final owned = List<String>.from(today?['unlocked'] as List? ?? []);
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('길드 꾸미기'),
                            style: TextStyle(
                              color: ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        PixelCloseButton(
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    Text(
                      '${t("보유 골드")}  $gold G',
                      style: const TextStyle(
                        color: brown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 16),
                    for (final item in guildDecorations) ...[
                      GuildButton(
                        soundEnabled: false,
                        label: owned.contains(item.id)
                            ? '${decorationName(language, item)} · ${(today?['active_items'] as List? ?? []).contains(item.id) ? t("치우기") : t("놓기")}'
                            : '${decorationName(language, item)} · $decorationPrice G',
                        onPressed:
                            busy ||
                                (!owned.contains(item.id) &&
                                    gold < decorationPrice)
                            ? null
                            : () async {
                                await selectDecoration(item);
                                if (context.mounted) refresh(() {});
                              },
                      ),
                      const SizedBox(height: 7),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> showLanguageSettings() async {
    await showGuildDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: PixelPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: PixelCloseButton(
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ),
                  Text(
                    t('음량'),
                    style: const TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (final isMusic in [true, false]) ...[
                    Text(
                      t(isMusic ? '음악' : '효과음'),
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      key: ValueKey(isMusic ? 'musicVolume' : 'effectsVolume'),
                      value: isMusic ? musicVolume : effectsVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label:
                          '${((isMusic ? musicVolume : effectsVolume) * 100).round()}%',
                      activeColor: brown,
                      onChanged: (value) {
                        refresh(() {
                          if (isMusic) {
                            musicVolume = value;
                            GuildAudio.setMusicVolume(value);
                          } else {
                            effectsVolume = value;
                            GuildAudio.setEffectsVolume(value);
                          }
                        });
                      },
                      onChangeEnd: (value) async {
                        final store =
                            prefs ?? await SharedPreferences.getInstance();
                        await store.setDouble(
                          isMusic ? 'music_volume' : 'effects_volume',
                          value,
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    t('언어'),
                    style: const TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButton<String>(
                    key: const ValueKey('languageSelector'),
                    value: languageOverride ?? 'device',
                    isExpanded: true,
                    items:
                        [
                              ('device', t('기기 설정 따르기')),
                              ('ko', '한국어'),
                              ('en', 'English'),
                              ('ja', '日本語'),
                              ('zh', '简体中文'),
                              ('hi', 'हिन्दी'),
                              ('es', 'Español'),
                            ]
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.$1,
                                child: Text(entry.$2),
                              ),
                            )
                            .toList(),
                    onChanged: (code) async {
                      if (code == null) return;
                      try {
                        final store =
                            prefs ?? await SharedPreferences.getInstance();
                        final success = code == 'device'
                            ? await store.remove('language_override')
                            : await store.setString('language_override', code);
                        if (!success) throw Exception('save failed');
                        if (!mounted || !dialogContext.mounted) return;
                        setState(
                          () =>
                              languageOverride = code == 'device' ? null : code,
                        );
                        widget.onLanguageChanged?.call(languageOverride);
                        refresh(() {});
                      } catch (_) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(t('기록을 저장하지 못했어요. 다시 시도해 주세요.')),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  if (Platform.isAndroid) ...[
                    GuildButton(
                      label: t('위치와 날씨'),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        showWeatherSettings();
                      },
                    ),
                    const SizedBox(height: 7),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget weatherExplanation() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NaturalText(
        t(
          '주변 날씨를 사용하면 그날에 어울리는 의뢰를 고를 수 있어요. 허용하면 대략적인 위치가 날씨 서비스 MET Norway에 전송됩니다. 앱은 위치를 저장하지 않습니다.',
        ),
        style: const TextStyle(
          color: ink,
          fontFamily: 'sans-serif',
          fontSize: 13,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 8),
      NaturalText(
        t('오늘 받은 의뢰는 설정을 바꿔도 바뀌지 않아요.'),
        style: const TextStyle(
          color: brown,
          fontFamily: 'sans-serif',
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        t('날씨 자료: MET Norway · CC BY 4.0 · 가공됨'),
        style: const TextStyle(
          color: brown,
          fontFamily: 'sans-serif',
          fontSize: 12,
        ),
      ),
      const SelectableText(
        'https://www.met.no/  ·  https://creativecommons.org/licenses/by/4.0/',
        style: TextStyle(color: brown, fontFamily: 'sans-serif', fontSize: 10),
      ),
    ],
  );

  Future<void> offerWeatherChoice(SharedPreferences store) async {
    if (!mounted || store.containsKey(weatherPreference)) return;
    final allow = await showGuildDialog<bool>(
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
                Text(
                  t('위치와 날씨'),
                  style: const TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                weatherExplanation(),
                const SizedBox(height: 16),
                GuildButton(
                  label: t('사용하기'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                ),
                const SizedBox(height: 8),
                GuildButton(
                  label: t('사용 안 함'),
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    final enabled =
        allow == true && await environmentService.requestLocationPermission();
    if (!await store.setBool(weatherPreference, enabled)) {
      throw Exception('save failed');
    }
    if (mounted && allow == true && !enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('위치 권한을 허용하면 날씨를 사용할 수 있어요. 기기 설정에서 권한을 확인해 주세요.')),
        ),
      );
    }
  }

  Future<void> showWeatherSettings() async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    var enabled = store.getBool(weatherPreference) ?? false;
    var changing = false;
    await showGuildDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: PixelPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: PixelCloseButton(
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ),
                  Text(
                    t('위치와 날씨'),
                    style: const TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  weatherExplanation(),
                  const SizedBox(height: 16),
                  GuildButton(
                    label: '${t('위치와 날씨')} · ${t(enabled ? '켜짐' : '꺼짐')}',
                    onPressed: changing
                        ? null
                        : () async {
                            refresh(() => changing = true);
                            try {
                              final wasEnabled = enabled;
                              final next = enabled
                                  ? false
                                  : await environmentService
                                        .requestLocationPermission();
                              if (!await store.setBool(
                                weatherPreference,
                                next,
                              )) {
                                throw Exception('save failed');
                              }
                              if (!dialogContext.mounted) return;
                              refresh(() => enabled = next);
                              if (!wasEnabled && !next) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t(
                                        '위치 권한을 허용하면 날씨를 사용할 수 있어요. 기기 설정에서 권한을 확인해 주세요.',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t('기록을 저장하지 못했어요. 다시 시도해 주세요.'),
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                refresh(() => changing = false);
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showInfo(bool support) {
    showGuildDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
          child: PixelPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        support ? t('길드 지원하기') : t('의뢰 제안하기'),
                        style: const TextStyle(
                          color: ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PixelCloseButton(onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 8),
                NaturalText(
                  support
                      ? t('이 작은 모험들이 내일도 이어질 수 있도록, 원한다면 길드에 보급품을 보내주세요.')
                      : t(
                          '다른 모험가들과 나누고 싶은 작은 경험이 있나요? 당신의 의뢰가 언젠가 오늘의 퀘스트가 될지도 모릅니다.',
                        ),
                  style: const TextStyle(color: ink, height: 1.7),
                ),
                const SizedBox(height: 18),
                if (support) ...[
                  ListenableBuilder(
                    listenable: guildSupport,
                    builder: (context, _) {
                      final words = supportMessages[language]!;
                      final items = [
                        ('작은 보급품', 'small-pixel.png', GuildSupport.ids[0]),
                        ('든든한 보급품', 'generous-pixel.png', GuildSupport.ids[1]),
                        ('특별 보급품', 'special-pixel.png', GuildSupport.ids[2]),
                      ];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (name, image, id) in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: Image.asset(
                                      'assets/support/$image',
                                      filterQuality: FilterQuality.none,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GuildButton(
                                      label:
                                          '${t(name)} · ${guildSupport.products[id]?.price ?? words['price']}',
                                      onPressed:
                                          guildSupport.busy ||
                                              guildSupport.products[id] == null
                                          ? null
                                          : () => guildSupport.purchase(id),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (guildSupport.loading)
                            Text(
                              words['loading']!,
                              style: const TextStyle(
                                color: brown,
                                fontSize: 12,
                              ),
                            ),
                          if (!guildSupport.loading &&
                              (guildSupport.message != null ||
                                  !guildSupport.available ||
                                  guildSupport.products.length < 3))
                            NaturalText(
                              words[guildSupport.message ?? 'unavailable']!,
                              style: const TextStyle(
                                color: brown,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          if (!guildSupport.loading &&
                              (!guildSupport.available ||
                                  guildSupport.products.length < 3))
                            TextButton(
                              onPressed: guildSupport.refresh,
                              child: Text(words['retry']!),
                            ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  NaturalText(
                    t('의뢰 접수는 준비 중이에요. 후원 여부는 의뢰 채택에 영향을 주지 않습니다.'),
                    style: TextStyle(color: brown, fontSize: 12, height: 1.6),
                  ),
                ],
              ],
            ),
          ),
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
            today!['legacyDescription'] as String,
          )
        : (today!['quest'] as int) < quests.length
        ? quests[today!['quest'] as int]
        : hardQuests[(today!['quest'] as int) - quests.length];
    final isHard = today != null && (today!['quest'] as int) >= quests.length;
    final opened = today?['opened'] == true;
    final completed = today?['completed'] == true;
    final failed = today?['failed'] == true;
    final resolved = completed || failed;
    return Scaffold(
      backgroundColor: const Color(0xff291c15),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !tutorialPaused && (tutorialComplete == false || showGreeting)
            ? advanceDialogue
            : null,
        child: Stack(
        key: screenKey,
        children: [
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: const GuildRoomBackground(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  controller: screenScroll,
                  padding: EdgeInsets.zero,
                  children: [
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.29,
                          child: Image.asset(
                            'assets/guild_interior_v4.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                        for (final item in guildDecorations)
                          if ((today?['active_items'] as List? ?? []).contains(
                            item.id,
                          ))
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ClipRect(
                                  clipper: GuildDecorationClipper(item.region),
                                  child: Image.asset(
                                    item.asset,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                    filterQuality: FilterQuality.none,
                                  ),
                                ),
                              ),
                            ),
                        if ((today?['active_items'] as List? ?? []).isNotEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: GuildDecorationEffects(
                                activeItems: Set<String>.from(
                                  today?['active_items'] as List? ?? [],
                                ),
                              ),
                            ),
                          ),
                        const Positioned.fill(
                          child: IgnorePointer(child: GuildLanternGlow()),
                        ),
                        if (tutorialPaused)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Align(
                                alignment: const Alignment(.25, -.48),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutBack,
                                  builder: (context, value, child) =>
                                      Transform.scale(
                                        scale: value,
                                        child: child,
                                      ),
                                  child: const Text(
                                    '?',
                                    style: TextStyle(
                                      color: Color(0xffffdf86),
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Color(0xff4a2918),
                                          offset: Offset(2, 2),
                                        ),
                                        Shadow(
                                          color: Color(0xff4a2918),
                                          offset: Offset(-2, -2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: .26),
                                  Colors.transparent,
                                  Colors.transparent,
                                ],
                                stops: const [0, .38, 1],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              transitionBuilder: (child, animation) =>
                                  AnimatedBuilder(
                                    animation: animation,
                                    child: child,
                                    builder: (context, child) {
                                      final step =
                                          (animation.value * 8).ceil() / 8;
                                      return ClipRect(
                                        child: Align(
                                          alignment: Alignment.center,
                                          heightFactor: step.clamp(0.0, 1.0),
                                          child: Opacity(
                                            opacity: animation.value > .7
                                                ? 1
                                                : 0,
                                            child: child,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              child:
                                  !tutorialPaused &&
                                      (tutorialComplete == false ||
                                          showGreeting)
                                  ? GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: advanceDialogue,
                                      child: PixelPanel(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t('길드주인'),
                                              style: TextStyle(
                                                color: Color(0xff926c49),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: .5,
                                              ),
                                            ),
                                            const SizedBox(height: 7),
                                            GuildDialogueText(
                                              key: dialogueKey,
                                              text: tutorialComplete == false
                                                  ? t(guildTutorial[tutorialStep])
                                                  : idleMessageIndex != null
                                                  ? questIdleMessages[language]![idleMessageIndex!]
                                                  : feedbackSuccess == null
                                                  ? t(greeting)
                                                  : (feedbackSuccess!
                                                        ? questSuccessMessages
                                                        : questFailureMessages)[language]![feedbackIndex],
                                              style: const TextStyle(
                                                color: ink,
                                                fontFamily: 'sans-serif',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                height: 1.6,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('closed'),
                                    ),
                            ),
                            const SizedBox(height: 20),
                            if (tutorialPaused)
                              const SizedBox.shrink()
                            else if (tutorialComplete == false)
                              const SizedBox.shrink()
                            else if (error != null) ...[
                              Text(
                                error!,
                                style: const TextStyle(
                                  color: Color(0xffffd3ae),
                                ),
                              ),
                              TextButton(
                                onPressed: load,
                                child: Text(t('다시 시도')),
                              ),
                            ] else if (today == null)
                              Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xffe5c793),
                                ),
                              )
                            else if (!greetingFinished)
                              const SizedBox.shrink()
                            else if (!resolved &&
                                (!opened || documentClosed)) ...[
                              Center(
                                child: Semantics(
                                  button: true,
                                  label: t('양피지 열기'),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 2600),
                                    curve: Curves.linear,
                                    builder: (context, value, child) => Opacity(
                                      opacity: (value / .12).clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(
                                          0,
                                          (1 - value) * 12 +
                                              sin(value * pi * 6) *
                                                  5 *
                                                  (1 - value),
                                        ),
                                        child: child,
                                      ),
                                    ),
                                    child: TextButton(
                                      key: const ValueKey('openQuest'),
                                      onPressed: busy || revealing
                                          ? null
                                          : openQuest,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.keyboard_double_arrow_down,
                                            color: Color(0xffffd681),
                                            size: 30,
                                          ),
                                          const SizedBox(
                                            width: 220,
                                            height: 150,
                                            child: SealedScrollAura(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: MediaQuery.paddingOf(context).right + 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: t('보유 골드'),
                  child: DecoratedBox(
                    decoration: headerWoodDecoration,
                    child: TextButton(
                      key: goldKey,
                      onPressed: today == null || rewarding
                          ? null
                          : () {
                              GuildAudio.wood();
                              showDecorations();
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xffffefcc),
                        disabledForegroundColor: const Color(0xffc2ab86),
                        shape: const RoundedRectangleBorder(),
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CustomPaint(
                              painter: HeaderIconPainter(coin: true),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "${today?['gold'] ?? 0} G",
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: t('길드 메뉴'),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: rewarding
                          ? null
                          : () {
                              GuildAudio.wood();
                              showGuildMenu();
                            },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: headerWoodDecoration,
                        padding: const EdgeInsets.all(12),
                        child: const CustomPaint(painter: HeaderIconPainter()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (opened &&
              !resolved &&
              !documentClosed &&
              !revealing &&
              greetingFinished &&
              item != null)
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = min(
                      520.0,
                      min(
                        constraints.maxWidth - 16,
                        (constraints.maxHeight - 16) * 2 / 3,
                      ),
                    );
                    return Center(
                      child: SizedBox(
                        width: max(0, width),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => IgnorePointer(
                            ignoring: value < .95,
                            child: Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 16),
                                child: Transform.scale(
                                  scale: .94 + .06 * value,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                          child: QuestDocument(
                            title: t(item.$1),
                            description: t(item.$2),
                            hard: isHard,
                            completed: completed,
                            failed: failed,
                            heading: t('오늘의 사이드퀘스트'),
                            reward: isHard
                                ? t('완료 보상 · 10 G').replaceAll('10', '30')
                                : t('완료 보상 · 10 G'),
                            completeLabel: t('퀘스트 완료'),
                            failLabel: t('퀘스트 실패'),
                            completeKey: completeKey,
                            onComplete: busy || rewarding || resolved
                                ? null
                                : completeQuest,
                            onFail: busy || rewarding || resolved
                                ? null
                                : failQuest,
                            onClose: rewarding
                                ? null
                                : () => setState(() => documentClosed = true),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (rewarding && rewardEnd != Offset.zero)
            Positioned.fill(
              child: IgnorePointer(
                child: RewardFlight(start: rewardStart, end: rewardEnd),
              ),
            ),
          if (revealing)
            Positioned.fill(
              child: AbsorbPointer(child: QuestReveal(hard: isHard)),
            ),
        ],
        ),
      ),
    );
  }
}

class PixelCloseButton extends StatelessWidget {
  const PixelCloseButton({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: MaterialLocalizations.of(context).closeButtonTooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: headerWoodDecoration,
          padding: const EdgeInsets.all(12),
          child: const CustomPaint(painter: PixelClosePainter()),
        ),
      ),
    ),
  );
}

class PixelClosePainter extends CustomPainter {
  const PixelClosePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xffffedc7);
    final unit = size.width / 7;
    for (var i = 1; i < 6; i++) {
      canvas.drawRect(Rect.fromLTWH(i * unit, i * unit, unit, unit), paint);
      canvas.drawRect(
        Rect.fromLTWH((6 - i) * unit, i * unit, unit, unit),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GuildDialogueText extends StatefulWidget {
  const GuildDialogueText({super.key, required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<GuildDialogueText> createState() => _GuildDialogueTextState();
}

class _GuildDialogueTextState extends State<GuildDialogueText> {
  Timer? timer;
  int visible = 0;

  @override
  void initState() {
    super.initState();
    begin();
  }

  @override
  void didUpdateWidget(covariant GuildDialogueText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) begin();
  }

  void begin() {
    timer?.cancel();
    visible = 0;
    final length = widget.text.characters.length;
    timer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) return;
      setState(() => visible = min(visible + 1, length));
      if (visible >= length) timer.cancel();
    });
  }

  bool revealAll() {
    final length = widget.text.characters.length;
    if (visible >= length) return false;
    timer?.cancel();
    setState(() => visible = length);
    return true;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NaturalText(widget.text, style: widget.style, visibleCharacters: visible);
}

class GuildRoomBackground extends StatelessWidget {
  const GuildRoomBackground({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final roomHeight = width * 1312 / 1199;
      final floorTop = width / 1.29;
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/guild_interior_v4.png',
                fit: BoxFit.fitWidth,
                filterQuality: FilterQuality.none,
              ),
            ),
            const Positioned.fill(child: GuildKeeperIdle()),
            if (constraints.maxHeight > roomHeight)
              Positioned(
                top: roomHeight,
                left: 0,
                right: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/guild_floor_extension.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            if (constraints.maxHeight > floorTop)
              Positioned(
                top: floorTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xcc291c15)],
                      stops: [0, .6],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class GuildDecorationEffects extends StatefulWidget {
  const GuildDecorationEffects({super.key, required this.activeItems});
  final Set<String> activeItems;

  @override
  State<GuildDecorationEffects> createState() => _GuildDecorationEffectsState();
}

class _GuildDecorationEffectsState extends State<GuildDecorationEffects>
    with WidgetsBindingObserver {
  Timer? timer;
  int frame = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    start();
  }

  void start() {
    timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
      return;
    }
    timer = Timer.periodic(const Duration(milliseconds: 125), (_) {
      if (mounted) setState(() => frame = (frame + 1) % 32);
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
  Widget build(BuildContext context) => CustomPaint(
    painter: GuildDecorationEffectsPainter(widget.activeItems, frame),
  );
}

class GuildDecorationEffectsPainter extends CustomPainter {
  const GuildDecorationEffectsPainter(this.activeItems, this.frame);
  final Set<String> activeItems;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 360;
    canvas.save();
    canvas.scale(scale);
    final angle = frame * 2 * pi / 32;
    final pulse = (1 + sin(angle)) / 2;
    const gold = Color(0xffffe191);
    const blue = Color(0xff9ef7ff);
    const ember = Color(0xffffa74c);

    void spark(double x, double y, double radius, Color color, double alpha) {
      final paint = Paint()..color = color.withValues(alpha: alpha.clamp(0, 1));
      final px = x.roundToDouble(), py = y.roundToDouble();
      canvas.drawRect(Rect.fromLTWH(px - radius, py, radius * 2 + 1, 2), paint);
      canvas.drawRect(Rect.fromLTWH(px, py - radius, 2, radius * 2 + 1), paint);
    }

    void twinkles(double x, double y, List<Offset> points, Color color) {
      for (var i = 0; i < points.length; i++) {
        final alpha = (35 + 125 * (.5 + .5 * sin(angle + i * 2))) / 255;
        spark(x + points[i].dx, y + points[i].dy, 2, color, alpha);
      }
    }

    if (activeItems.contains('sword')) {
      final progress = frame / 31;
      spark(
        13,
        102 + 45 * progress,
        3,
        gold,
        (50 + 145 * sin(pi * progress)) / 255,
      );
      spark(9, 94, 2, gold, (40 + 100 * pulse) / 255);
    }
    if (activeItems.contains('shield')) {
      final progress = frame / 31;
      spark(
        51 + 24 * progress,
        226 + 32 * progress,
        3,
        gold,
        (75 + 115 * sin(pi * progress)) / 255,
      );
      spark(63, 244, 2, gold, (45 + 100 * pulse) / 255);
    }
    if (activeItems.contains('sigil')) {
      for (var i = 0; i < 6; i++) {
        final theta = angle + i * 2 * pi / 6;
        spark(180 + 19 * cos(theta), 99 + 19 * sin(theta), 2, gold, 155 / 255);
      }
      spark(180, 99, 2, gold, (85 + 130 * pulse) / 255);
    }
    if (activeItems.contains('crystal')) {
      final path = Path()
        ..moveTo(255, 139)
        ..lineTo(246, 153)
        ..lineTo(247, 170)
        ..lineTo(255, 177)
        ..lineTo(264, 168)
        ..lineTo(263, 151)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(
            0xff68fffa,
          ).withValues(alpha: (10 + 40 * pulse) / 255),
      );
      for (var i = 0; i < 3; i++) {
        final theta = angle + i * 2 * pi / 3;
        spark(255 + 19 * cos(theta), 158 + 20 * sin(theta), 2, blue, 150 / 255);
      }
    }
    if (activeItems.contains('helm')) {
      for (var i = 0; i < 3; i++) {
        final progress = (frame / 32 + i / 3) % 1;
        spark(
          40 + i * 8 + 2 * sin(angle + i),
          156 - 18 * progress,
          2,
          ember,
          140 * (1 - progress) / 255,
        );
      }
      canvas.drawRect(
        const Rect.fromLTWH(44, 152, 9, 3),
        Paint()..color = ember.withValues(alpha: (25 + 65 * pulse) / 255),
      );
    }
    if (activeItems.contains('staff')) {
      for (var i = 0; i < 3; i++) {
        final theta = angle + i * 2 * pi / 3;
        spark(351 + 7 * cos(theta), 102 + 12 * sin(theta), 2, gold, 165 / 255);
      }
      spark(351, 97, 3, gold, (80 + 130 * pulse) / 255);
    }
    if (activeItems.contains('banner_dragon')) {
      twinkles(180, 84, const [
        Offset(-14, -4),
        Offset(0, 1),
        Offset(14, -4),
      ], gold);
    }
    if (activeItems.contains('spellbook')) {
      for (var i = 0; i < 3; i++) {
        final progress = (frame / 32 + i / 3) % 1;
        spark(
          41 + i * 8 + 3 * sin(angle + i),
          158 - 20 * progress,
          2,
          blue,
          145 * (1 - progress) / 255,
        );
      }
      canvas.drawRect(
        const Rect.fromLTWH(39, 162, 20, 2),
        Paint()..color = blue.withValues(alpha: (30 + 80 * pulse) / 255),
      );
    }
    if (activeItems.contains('treasure')) {
      twinkles(255, 162, const [
        Offset(-9, -9),
        Offset(8, -3),
        Offset(0, 5),
      ], gold);
    }
    if (activeItems.contains('armor')) {
      twinkles(273, 150, const [
        Offset(-9, -13),
        Offset(8, -5),
        Offset(0, 13),
      ], blue);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GuildDecorationEffectsPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      !setEquals(oldDelegate.activeItems, activeItems);
}

class GuildDecorationClipper extends CustomClipper<Rect> {
  const GuildDecorationClipper(this.region);
  final Rect region;
  @override
  Rect getClip(Size size) {
    const originalWidth = 1199.0;
    const visibleHeight = originalWidth / 1.29;
    return Rect.fromLTRB(
      region.left / originalWidth * size.width,
      region.top / visibleHeight * size.height,
      region.right / originalWidth * size.width,
      region.bottom / visibleHeight * size.height,
    );
  }

  @override
  bool shouldReclip(covariant GuildDecorationClipper oldClipper) =>
      oldClipper.region != region;
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
      Rect.fromLTWH(size.width * .107, size.height * .317, u * 2, u * 3),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .126, size.height * .31, u, u * 4),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .09, size.height * .35, u, u),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant LanternGlowPainter oldDelegate) =>
      oldDelegate.frame != frame;
}

const headerWoodDecoration = BoxDecoration(
  image: DecorationImage(
    image: ResizeImage(
      AssetImage('assets/wood_button.png'),
      width: 432,
      height: 144,
    ),
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
          size.width * x,
          size.height * y,
          size.width * w,
          size.height * h,
        ),
        paint,
      );
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

class QuestDocument extends StatelessWidget {
  const QuestDocument({
    super.key,
    required this.title,
    required this.description,
    required this.hard,
    required this.completed,
    required this.failed,
    required this.heading,
    required this.reward,
    required this.completeLabel,
    required this.failLabel,
    this.completeKey,
    this.onComplete,
    this.onFail,
    this.onClose,
  });
  final String title, description, heading, reward, completeLabel, failLabel;
  final bool hard, completed, failed;
  final VoidCallback? onComplete, onFail, onClose;
  final GlobalKey? completeKey;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 2 / 3,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth, h = constraints.maxHeight;
        Widget action(
          String label,
          VoidCallback? callback,
          bool selected, {
          Key? key,
        }) => TextButton(
          key: key,
          onPressed: callback == null
              ? null
              : () {
                  GuildAudio.wood();
                  callback();
                },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            foregroundColor: const Color(0xffffefcd),
            disabledForegroundColor: const Color(0xffffefcd),
            shape: const RoundedRectangleBorder(),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: selected
                ? const Color(0x665b390d)
                : Colors.transparent,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Color(0xff49200b), offset: Offset(1, 2)),
                  ],
                ),
              ),
            ),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                hard
                    ? 'assets/quest_paper_hard.png'
                    : 'assets/quest_paper_normal.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
            Positioned(
              right: w * .08,
              top: h * .07,
              child: PixelCloseButton(
                key: const ValueKey('closeQuest'),
                onPressed: onClose,
              ),
            ),
            Positioned(
              left: w * .15,
              right: w * .15,
              top: h * (hard ? .23 : .12),
              bottom: h * (hard ? .25 : .35),
              child: LayoutBuilder(
                builder: (context, contentConstraints) {
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: contentConstraints.maxWidth,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!hard) ...[
                              Text(
                                heading,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xff926438),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            NaturalText(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            NaturalText(
                              description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff62452b),
                                fontFamily: 'sans-serif',
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              reward,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff8b5b21),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (hard) ...[
              Positioned(
                left: w * .095,
                width: w * .375,
                top: h * .79,
                height: h * .085,
                child: action(
                  completeLabel,
                  onComplete,
                  completed,
                  key: completeKey,
                ),
              ),
              Positioned(
                left: w * .53,
                width: w * .375,
                top: h * .79,
                height: h * .085,
                child: action(failLabel, onFail, failed),
              ),
            ] else ...[
              Positioned(
                left: w * .13,
                width: w * .74,
                top: h * .67,
                height: h * .10,
                child: action(
                  completeLabel,
                  onComplete,
                  completed,
                  key: completeKey,
                ),
              ),
              Positioned(
                left: w * .13,
                width: w * .74,
                top: h * .80,
                height: h * .10,
                child: action(failLabel, onFail, failed),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class PixelPanel extends StatelessWidget {
  final Widget child;
  final bool parchment;
  final bool ornate;
  const PixelPanel({
    super.key,
    required this.child,
    this.parchment = false,
    this.ornate = false,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: parchment
        ? BoxDecoration(
            color: const Color(0xffead1a0),
            border: Border.all(
              color: ornate ? const Color(0xffd69a32) : const Color(0xff6c4029),
              width: ornate ? 8 : 6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xff28170e),
                spreadRadius: 3,
                offset: Offset(0, 4),
              ),
              BoxShadow(color: Color(0xffb2804d), spreadRadius: 1),
            ],
          )
        : const BoxDecoration(
            image: DecorationImage(
              image: ResizeImage(
                AssetImage('assets/dialogue_frame.png'),
                width: 355,
                height: 177,
              ),
              centerSlice: Rect.fromLTRB(20, 20, 335, 157),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
    child: CustomPaint(
      foregroundPainter: ornate ? const OrnateFramePainter() : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          parchment ? 28 : 24,
          parchment ? 40 : 25,
          parchment ? 28 : 24,
          parchment ? 26 : 25,
        ),
        child: child,
      ),
    ),
  );
}

class OrnateFramePainter extends CustomPainter {
  const OrnateFramePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()..color = const Color(0xffb77920);
    final light = Paint()..color = const Color(0xffffd76b);
    final green = Paint()..color = const Color(0xff57815a);
    for (final x in [0.0, size.width - 22]) {
      for (final y in [0.0, size.height - 22]) {
        canvas.drawRect(Rect.fromLTWH(x, y, 22, 22), gold);
        canvas.drawRect(Rect.fromLTWH(x + 4, y + 4, 14, 14), light);
        canvas.drawRect(Rect.fromLTWH(x + 8, y + 8, 6, 6), green);
      }
    }
    for (double y = 32; y < size.height - 24; y += 28) {
      for (final x in [1.0, size.width - 9]) {
        canvas.drawRect(Rect.fromLTWH(x, y, 8, 12), gold);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 4, 4, 4), green);
      }
    }
    final x = size.width / 2;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, 6), width: 36, height: 8),
      gold,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, 6), width: 20, height: 4),
      light,
    );
  }

  @override
  bool shouldRepaint(covariant OrnateFramePainter oldDelegate) => false;
}

class GuildButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool soundEnabled;
  const GuildButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.soundEnabled = true,
  });
  @override
  State<GuildButton> createState() => _GuildButtonState();
}

class _GuildButtonState extends State<GuildButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      if (widget.onPressed != null) setState(() => pressed = true);
    },
    onPointerUp: (_) {
      if (pressed) setState(() => pressed = false);
    },
    onPointerCancel: (_) {
      if (pressed) setState(() => pressed = false);
    },
    child: AnimatedSlide(
      duration: const Duration(milliseconds: 90),
      offset: pressed ? const Offset(0, .04) : Offset.zero,
      child: Opacity(
        opacity: widget.onPressed == null ? .55 : 1,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: ResizeImage(
                AssetImage('assets/wood_button.png'),
                width: 432,
                height: 144,
              ),
              centerSlice: Rect.fromLTRB(12, 8, 420, 136),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          child: TextButton(
            onPressed: widget.onPressed == null
                ? null
                : () {
                    if (widget.soundEnabled) GuildAudio.wood();
                    widget.onPressed!();
                  },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xffffefd1),
              disabledForegroundColor: const Color(0xffffefd1),
              shape: const RoundedRectangleBorder(),
              minimumSize: const Size(0, 72),
              padding: const EdgeInsets.symmetric(horizontal: 28),
            ),
            child: SizedBox(
              height: 32,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RewardFlight extends StatelessWidget {
  const RewardFlight({super.key, required this.start, required this.end});
  final Offset start, end;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1400),
    builder: (context, value, _) =>
        CustomPaint(painter: RewardFlightPainter(value, start, end)),
  );
}

class RewardFlightPainter extends CustomPainter {
  final double progress;
  final Offset start, end;
  RewardFlightPainter(this.progress, this.start, this.end);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 6; i++) {
      final delay = i * .035;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      final burst = sin(min(1.0, t * 2.3) * pi / 2) * (1 - t);
      final spread = Offset((i - 2.5) * 17, -35 - (i % 3) * 13) * burst;
      final travel = Curves.easeInCubic.transform(t);
      final pos = Offset.lerp(start + spread, end, travel)!;
      final scale = (1 - .65 * travel).clamp(.25, 1.0);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.scale(scale);
      canvas.drawRect(
        const Rect.fromLTWH(-7, -9, 14, 18),
        Paint()..color = const Color(0xff854417),
      );
      canvas.drawRect(
        const Rect.fromLTWH(-9, -6, 18, 12),
        Paint()..color = const Color(0xff854417),
      );
      canvas.drawRect(
        const Rect.fromLTWH(-5, -7, 10, 14),
        Paint()..color = const Color(0xffffc654),
      );
      canvas.drawRect(
        const Rect.fromLTWH(-2, -5, 3, 9),
        Paint()..color = const Color(0xffffe6a0),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant RewardFlightPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}

class SealedScrollAura extends StatefulWidget {
  const SealedScrollAura({super.key});
  @override
  State<SealedScrollAura> createState() => _SealedScrollAuraState();
}

class _SealedScrollAuraState extends State<SealedScrollAura>
    with WidgetsBindingObserver {
  Timer? timer;
  int frame = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateTimer();
  }

  void updateTimer() {
    timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
      return;
    }
    timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => frame = (frame + 1) % 16);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateTimer();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: SealedScrollAuraPainter(frame / 16),
    child: Image.asset(
      'assets/sealed_scroll_v2.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    ),
  );
}

class SealedScrollAuraPainter extends CustomPainter {
  const SealedScrollAuraPainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = .5 + .5 * sin(phase * 2 * pi);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * (.42 + .06 * pulse);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Color(0xffffd77d).withValues(alpha: .12 + .07 * pulse),
          Color(0xffffc65e).withValues(alpha: .07 + .04 * pulse),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);
    for (var i = 0; i < 7; i++) {
      final angle = i * 2 * pi / 7 + phase * 2 * pi;
      final position =
          center +
          Offset(cos(angle) * size.width * .43, sin(angle) * size.height * .37);
      final alpha = .28 + .38 * (.5 + .5 * sin(phase * 2 * pi + i));
      final paint = Paint()..color = Color(0xffffdf98).withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromCenter(center: position, width: 3, height: 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SealedScrollAuraPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class QuestReveal extends StatelessWidget {
  final bool hard;
  const QuestReveal({super.key, this.hard = false});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(seconds: 3),
    builder: (context, value, _) => Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: QuestRevealPainter(value, hard)),
        ),
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, .04),
            child: Opacity(
              opacity: ((1 - value) / .18).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1 + .08 * sin(pi * value),
                child: SizedBox(
                  width: min(260, MediaQuery.sizeOf(context).width * .65),
                  child: Image.asset(
                    'assets/sealed_scroll_v2.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class QuestRevealPainter extends CustomPainter {
  final double progress;
  final bool hard;
  QuestRevealPainter(this.progress, this.hard);
  @override
  void paint(Canvas canvas, Size size) {
    final fade = sin(pi * progress).clamp(0.0, 1.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: .55 * fade),
    );
    final center = Offset(size.width / 2, size.height * .52);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xffffe9a3).withValues(alpha: .8 * fade),
          const Color(0xffe7a63b).withValues(alpha: .35 * fade),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .7));
    canvas.drawCircle(center, size.width * .7, glow);
    if (hard) {
      final rayPaint = Paint()
        ..color = const Color(0xffffe8a0).withValues(alpha: .65 * fade)
        ..strokeWidth = 4;
      for (var i = 0; i < 12; i++) {
        final a = i * pi / 6 + progress * .25;
        final direction = Offset(cos(a), sin(a));
        canvas.drawLine(
          center + direction * size.width * .23,
          center + direction * size.width * .8,
          rayPaint,
        );
      }
      final ring = Paint()
        ..color = const Color(0xffffe2a0).withValues(alpha: .8 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, size.width * (.15 + .5 * progress), ring);
      final flash =
          ((progress - .65) / .17).clamp(0.0, 1.0) *
          ((1 - progress) / .12).clamp(0.0, 1.0);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: flash),
      );
    }
    final star = Paint()..color = Color(0xffffe5a2).withValues(alpha: fade);
    for (var i = 0; i < 16; i++) {
      final angle = i * 2 * pi / 16 + progress * .4;
      final radius = size.width * (.20 + .12 * ((i * 7) % 5) / 5);
      final pos = center + Offset(cos(angle), sin(angle)) * radius;
      final edge = 3.0 + (i % 3) * 2;
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: edge, height: edge),
        star,
      );
    }
  }

  @override
  bool shouldRepaint(covariant QuestRevealPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.hard != hard;
}
