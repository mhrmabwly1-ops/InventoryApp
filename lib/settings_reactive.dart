import 'package:flutter/widgets.dart';
import 'settings_store.dart';

mixin SettingsReactive<T extends StatefulWidget> on State<T> {
  void _handleSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void startSettingsListener() {
    try {
      SettingsStore().addListener(_handleSettingsChanged);
    } catch (e) {}
  }

  void stopSettingsListener() {
    try {
      SettingsStore().removeListener(_handleSettingsChanged);
    } catch (e) {}
  }
}
