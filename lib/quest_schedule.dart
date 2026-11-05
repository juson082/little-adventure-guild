const questCooldown = Duration(hours: 24);

/// Unopened scrolls expire at the next local midnight. Opened scrolls last
/// 24 hours from the tap; older opened records are migrated by the caller.
bool questHasExpired(Map<String, dynamic>? saved, DateTime now) {
  if (saved == null) return false;
  if (saved['opened'] != true) {
    final assigned = saved['date'];
    if (assigned is! String) return false;
    final date = DateTime.tryParse(assigned);
    if (date == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(date.year, date.month, date.day).isBefore(today);
  }
  final timestamp = saved['opened_at_ms'];
  if (timestamp is! int) return false;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
      .add(questCooldown);
  return !now.toUtc().isBefore(expiresAt);
}

Duration? timeUntilQuestExpiry(Map<String, dynamic>? saved, DateTime now) {
  if (saved == null) return null;
  if (saved['opened'] != true) {
    if (questHasExpired(saved, now)) return Duration.zero;
    final nextMidnight = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    return nextMidnight.difference(now);
  }
  final timestamp = saved['opened_at_ms'];
  if (timestamp is! int) return null;
  return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
      .add(questCooldown)
      .difference(now.toUtc());
}
