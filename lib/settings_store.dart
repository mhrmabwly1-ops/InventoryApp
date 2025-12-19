import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'database_helper.dart';

class SettingsStore extends ChangeNotifier {
  static final SettingsStore _instance = SettingsStore._internal();
  factory SettingsStore() => _instance;
  SettingsStore._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final String _cacheFile = 'settings_store_cache.json';

  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _advancedSettings = {};

  bool get initialized => _initialized;
  bool _initialized = false;

  Map<String, dynamic> get settings => Map.unmodifiable(_settings);
  Map<String, dynamic> get advancedSettings => Map.unmodifiable(_advancedSettings);

  // Load settings from database; fall back to cached file on error
  Future<void> load() async {
    try {
      final db = await _db.database;
      final sys = await _db.getSystemSettings();
      final adv = await _db.getAdvancedSettings();

      _settings = Map<String, dynamic>.from(sys);
      _advancedSettings = Map<String, dynamic>.from(adv);
      _initialized = true;
      await _saveCache();
      notifyListeners();
    } catch (e) {
      // try to load cache
      await _loadCache();
      _initialized = true;
      notifyListeners();
    }
  }

  Future<File> _cacheFileRef() async {
    try {
      final path = Directory.current.path;
      return File('\$path/\$_cacheFile');
    } catch (e) {
      return File(_cacheFile);
    }
  }

  Future<void> _saveCache() async {
    try {
      final file = await _cacheFileRef();
      final content = jsonEncode({'settings': _settings, 'advanced': _advancedSettings});
      await file.writeAsString(content);
    } catch (e) {
      // ignore cache errors
    }
  }

  Future<void> _loadCache() async {
    try {
      final file = await _cacheFileRef();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        _settings = Map<String, dynamic>.from(map['settings'] ?? {});
        _advancedSettings = Map<String, dynamic>.from(map['advanced'] ?? {});
      }
    } catch (e) {
      // ignore
    }
  }

  dynamic getSetting(String key) => _settings[key];

  dynamic getAdvanced(String key) => _advancedSettings[key];

  Future<void> setSetting(String key, dynamic value) async {
    _settings[key] = value;
    try {
      await _db.updateSystemSetting(key, value);
    } catch (e) {
      // ignore db write errors but keep in-memory
    }
    await _saveCache();
    notifyListeners();
  }

  Future<void> setAdvanced(String key, dynamic value) async {
    _advancedSettings[key] = value;
    try {
      await _db.updateAdvancedSetting(key, value);
    } catch (e) {
      // ignore
    }
    await _saveCache();
    notifyListeners();
  }

  Future<void> resetSettings() async {
    try {
      await _db.resetSystemSettings();
    } catch (e) {
      // ignore
    }
    _settings.clear();
    _advancedSettings.clear();
    await _saveCache();
    notifyListeners();
  }

  // Helper to allow external listeners
  void onSettingsChange(VoidCallback listener) => addListener(listener);
}

class SettingsProvider extends InheritedNotifier<SettingsStore> {
  const SettingsProvider({Key? key, required SettingsStore store, required Widget child}) : super(key: key, notifier: store, child: child);

  static SettingsStore of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
    if (provider == null || provider.notifier == null) throw FlutterError('SettingsProvider not found in context');
    return provider.notifier as SettingsStore;
  }
}
