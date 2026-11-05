import 'package:flutter_test/flutter_test.dart';
import 'package:little_adventure_guild/quest_schedule.dart';

void main() {
  test('양피지를 누른 순간부터 정확히 24시간 뒤 만료된다', () {
    final start = DateTime.utc(2026, 11, 5, 14, 30);
    final saved = <String, dynamic>{
      'opened': true,
      'opened_at_ms': start.millisecondsSinceEpoch
    };
    expect(
        questHasExpired(saved,
            start.add(const Duration(hours: 23, minutes: 59, seconds: 59))),
        isFalse);
    expect(
        questHasExpired(saved, start.add(const Duration(hours: 24))), isTrue);
    expect(
        questHasExpired(saved, start.add(const Duration(hours: 25))), isTrue);
    expect(timeUntilQuestExpiry(saved, start.add(const Duration(hours: 23))),
        const Duration(hours: 1));
  });
  test('열지 않은 양피지는 기기 날짜가 바뀌면 만료된다', () {
    final saved = <String, dynamic>{'opened': false, 'date': '2026-11-05'};
    expect(questHasExpired(saved, DateTime(2026, 11, 5, 23, 59, 59)), isFalse);
    expect(timeUntilQuestExpiry(saved, DateTime(2026, 11, 5, 23, 59, 59)),
        const Duration(seconds: 1));
    expect(questHasExpired(saved, DateTime(2026, 11, 6)), isTrue);
    expect(timeUntilQuestExpiry(saved, DateTime(2026, 11, 6)), Duration.zero);
  });
  test('이전 버전의 시각 없는 기록은 자동으로 만료하지 않는다', () {
    final saved = <String, dynamic>{'opened': true, 'date': '2025-01-01'};
    expect(questHasExpired(saved, DateTime.utc(2026, 11, 5)), isFalse);
    expect(timeUntilQuestExpiry(saved, DateTime.utc(2026, 11, 5)), isNull);
  });
  test('날짜와 서머타임이 달라져도 실제 경과 시간으로 계산한다', () {
    final start = DateTime.parse('2026-11-01T01:30:00-04:00');
    final saved = <String, dynamic>{
      'opened': true,
      'opened_at_ms': start.millisecondsSinceEpoch
    };
    expect(questHasExpired(saved, DateTime.parse('2026-11-02T00:29:59-05:00')),
        isFalse);
    expect(questHasExpired(saved, DateTime.parse('2026-11-02T00:30:00-05:00')),
        isTrue);
  });
}
