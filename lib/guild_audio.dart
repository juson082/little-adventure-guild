import 'dart:async';
import 'package:flutter/services.dart';

/// Audio is implemented by the Android host and is optional on other hosts.
abstract final class GuildAudio {
  static const _channel = MethodChannel('hvildir/sound_effects');

  static void wood() => unawaited(_play('wood'));
  static void gold() => unawaited(_play('gold'));
  static void reveal({required bool hard}) =>
      unawaited(_play(hard ? 'reveal_hard' : 'reveal_normal'));
  static void setEffectsVolume(double volume) => unawaited(_setVolume(volume));
  static void setMusicVolume(double volume) =>
      unawaited(_setMusicVolume(volume));

  static Future<void> _setMusicVolume(double volume) async {
    try {
      await _channel.invokeMethod<void>('musicVolume', volume.clamp(0.0, 1.0));
    } on MissingPluginException {
      // Audio is optional on unsupported platforms.
    } on PlatformException {
      // The preference remains saved even if audio is unavailable.
    }
  }

  static Future<void> _setVolume(double volume) async {
    try {
      await _channel.invokeMethod<void>('volume', volume.clamp(0.0, 1.0));
    } on MissingPluginException {
      // Audio is optional on unsupported platforms.
    } on PlatformException {
      // The preference remains saved even if audio is unavailable.
    }
  }

  static Future<void> _play(String sound) async {
    try {
      await _channel.invokeMethod<void>('play', sound);
    } on MissingPluginException {
      // Other platforms do not yet provide a sound-effects implementation.
    } on PlatformException {
      // Audio is optional and must never block interaction.
    }
  }
}
