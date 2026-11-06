import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_adventure_guild/environment_service.dart';
import 'package:little_adventure_guild/guild_content.dart';
import 'package:little_adventure_guild/hard_quests.dart';
import 'package:little_adventure_guild/quest_environment.dart';

void main() {
  const clear =
      WeatherObservation(code: 0, cloudCover: 5, windKmh: 2, recentRain: false);
  const rain = WeatherObservation(
      code: 61, cloudCover: 100, windKmh: 12, recentRain: true);
  const afterRain =
      WeatherObservation(code: 3, cloudCover: 85, windKmh: 1, recentRain: true);

  test('날씨 정보가 없으면 일반과 어려운 의뢰 전체가 추첨 대상이다', () {
    const environment = QuestEnvironment();
    final eligible = eligibleQuestIndices(environment);
    expect(eligible.length, quests.length + hardQuests.length);
    expect(eligible,
        List<int>.generate(quests.length + hardQuests.length, (i) => i));
    expect(questFitsEnvironment('밤하늘의 별 세기', environment), isTrue);
    expect(questFitsEnvironment('아침 하늘 바라보기', environment), isTrue);
    expect(questFitsEnvironment('빗소리 감상하기', environment), isTrue);
  });
  test('비 오는 날에는 비 의뢰와 조건 없는 의뢰가 가능하고 햇빛 의뢰는 제외한다', () {
    const environment = QuestEnvironment(weather: rain);
    expect(questFitsEnvironment('빗소리 감상하기', environment), isTrue);
    expect(questFitsEnvironment('눈 감고 햇빛 쬐기', environment), isFalse);
    expect(questFitsEnvironment('밤하늘의 별 세기', environment), isFalse);
    expect(questFitsEnvironment('비 온 뒤의 풍경 보기', environment), isFalse);
    expect(questFitsEnvironment('오래된 사진 한 장 보기', environment), isTrue);
    final eligible = eligibleQuestIndices(environment);
    expect(eligible, contains(quests.length)); // Hard quests remain available.
    expect(eligible,
        isNot(contains(quests.indexWhere((q) => q.$1 == '눈 감고 햇빛 쬐기'))));
    final random = Random(42);
    for (var i = 0; i < 500; i++) {
      expect(eligible, contains(chooseDailyQuest(environment, random)));
    }
  });
  test('시간 조건은 적용하지 않고 맑음과 비 그친 뒤를 구분한다', () {
    const sunny = QuestEnvironment(weather: clear);
    const wet = QuestEnvironment(weather: afterRain);
    expect(questFitsEnvironment('밤하늘의 별 세기', sunny), isTrue);
    expect(questFitsEnvironment('아침 하늘 바라보기', sunny), isTrue);
    expect(questFitsEnvironment('눈 감고 햇빛 쬐기', sunny), isTrue);
    expect(questFitsEnvironment('빗소리 감상하기', sunny), isFalse);
    expect(questFitsEnvironment('비 온 뒤의 풍경 보기', wet), isTrue);
    expect(questFitsEnvironment('빗소리 감상하기', wet), isFalse);
  });
  test('모든 날씨 조건은 실제 의뢰 제목과 일치한다', () {
    final titles = quests.map((q) => q.$1).toSet();
    for (final group in [
      sunsetQuests,
      clearSkyQuests,
      sunnyQuests,
      cloudQuests,
      windyQuests,
      rainQuests,
      afterRainQuests
    ]) {
      for (final title in group) {
        expect(titles, contains(title));
      }
    }
  });
  test('MET 예보의 시간과 날씨를 해석한다', () {
    final now = DateTime.utc(2026, 7, 1, 11); // 20:00 in Tokyo.
    final parsed = parseWeather({
      'properties': {
        'timeseries': [
          {
            'time': '2026-07-01T10:00:00Z',
            'data': {
              'instant': {
                'details': {'cloud_area_fraction': 85, 'wind_speed': 4}
              },
              'next_1_hours': {
                'summary': {'symbol_code': 'rain'}
              }
            }
          },
          {'time': '2026-07-01T12:00:00Z', 'data': {}}
        ]
      }
    }, now);
    expect(parsed, isNotNull);
    expect(parsed!.recentRain, isNull);
    expect(parsed.raining, isTrue);
    expect(parsed.windKmh, closeTo(14.4, 0.001));
    expect(
        questFitsEnvironment('비 온 뒤의 풍경 보기', QuestEnvironment(weather: parsed)),
        isFalse);
  });
  test('불완전한 날씨 응답은 날씨 미상으로 처리한다', () {
    expect(
        parseWeather({
          'current': {'weather_code': 0}
        }, DateTime.now()),
        isNull);
    expect(parseWeather('invalid', DateTime.now()), isNull);
  });
}
