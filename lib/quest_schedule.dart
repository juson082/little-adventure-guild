const questCooldown = Duration(hours: 24);

/// An unopened scroll never expires. Older opened records are migrated by
/// the caller, since their exact opening time was not previously recorded.
bool questHasExpired(Map<String, dynamic>? saved, DateTime now) {
  if (saved == null || saved['opened'] != true) return false;
  final timestamp = saved['opened_at_ms'];
  if (timestamp is! int) return false;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
      .add(questCooldown);
  return !now.toUtc().isBefore(expiresAt);
}

Duration? timeUntilQuestExpiry(Map<String, dynamic>? saved, DateTime now) {
  if (saved == null || saved['opened'] != true) return null;
  final timestamp = saved['opened_at_ms'];
  if (timestamp is! int) return null;
  return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
      .add(questCooldown)
      .difference(now.toUtc());
}
