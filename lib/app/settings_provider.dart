import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-facing app settings (theme + accent). Persistence is wired in the
/// data-layer step; for now it lives in memory.
class Settings {
  final ThemeMode themeMode;
  final Color accent;
  const Settings({this.themeMode = ThemeMode.system, this.accent = const Color(0xFF0066FF)});

  Settings copyWith({ThemeMode? themeMode, Color? accent}) =>
      Settings(themeMode: themeMode ?? this.themeMode, accent: accent ?? this.accent);
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => const Settings();

  void setDark(bool on) => state = state.copyWith(themeMode: on ? ThemeMode.dark : ThemeMode.light);
}

// Brand uses a single Primary Blue — no user-selectable accent.
final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
