import 'dart:math';
import 'guild_content.dart';
import 'hard_quests.dart';

/// Weather is optional. Missing context falls back to the entire catalogue.
class WeatherObservation {
  const WeatherObservation(
      {required this.code,
      required this.cloudCover,
      required this.windKmh,
      required this.recentRain});
  final int code;
  final double cloudCover;
  final double windKmh;
  final bool? recentRain;

  bool get raining => const {
        51,
        53,
        55,
        56,
        57,
        61,
        63,
        65,
        66,
        67,
        80,
        81,
        82,
        95,
        96,
        99
      }.contains(code);
  bool get sunny => const {0, 1, 2}.contains(code) && cloudCover <= 65;
  bool get visibleClouds => cloudCover >= 20 && cloudCover < 95 && !raining;
  bool get windy => windKmh >= 5;
}

class QuestEnvironment {
  const QuestEnvironment({this.weather});
  final WeatherObservation? weather;
}

const sunsetQuests = <String>{'노을 바라보기'};
const clearSkyQuests = <String>{'밤하늘의 별 세기'};
const sunnyQuests = <String>{
  '눈 감고 햇빛 쬐기',
  '햇빛이 닿는 나무 보기',
  '나무 그늘에서 쉬기',
  '나뭇잎 그림자 구경하기',
  '창문 그림자 찾아보기'
};
const cloudQuests = <String>{
  '구름에서 동물 찾기',
  '구름의 움직임 보기',
  '구름에 이름 붙이기',
  '구름 사이의 빈 하늘 보기'
};
const windyQuests = <String>{
  '바람에 흔들리는 나뭇잎 보기',
  '오늘의 바람 방향 짐작하기',
  '바람에 움직이는 풀 보기'
};
const rainQuests = <String>{
  '빗소리 감상하기',
  '유리창의 빗방울 따라가기',
  '비 오는 날 어울리는 노래 고르기',
  '빗방울 소리와 바람 소리 구분하기'
};
const afterRainQuests = <String>{
  '비 온 뒤의 풍경 보기',
  '비에 젖은 잎 바라보기',
  '비 온 뒤 우산 말리기'
};

bool questFitsEnvironment(String title, QuestEnvironment e) {
  final w = e.weather;
  if (w == null) return true;
  if (sunsetQuests.contains(title)) return !w.raining;
  if (clearSkyQuests.contains(title)) return w.sunny;
  if (sunnyQuests.contains(title)) return w.sunny;
  if (cloudQuests.contains(title)) return w.visibleClouds;
  if (windyQuests.contains(title)) return w.windy;
  if (rainQuests.contains(title)) return w.raining;
  if (afterRainQuests.contains(title)) {
    return !w.raining && (w.recentRain ?? true);
  }
  return true;
}

/// Returns catalogue indices, keeping normal and hard quests equally weighted.
List<int> eligibleQuestIndices(QuestEnvironment environment) => [
      for (var i = 0; i < quests.length; i++)
        if (questFitsEnvironment(quests[i].$1, environment)) i,
      for (var i = 0; i < hardQuests.length; i++) quests.length + i,
    ];

int chooseDailyQuest(QuestEnvironment environment, Random random,
    {int? excludeIndex}) {
  final eligible = eligibleQuestIndices(environment);
  // A scroll that was never opened must visibly change on the next day.
  if (excludeIndex != null && eligible.length > 1) {
    eligible.remove(excludeIndex);
  }
  return eligible[random.nextInt(eligible.length)];
}
