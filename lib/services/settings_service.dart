import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/pv_config.dart';

class SettingsService {
  SettingsService._internal();
  static final SettingsService instance = SettingsService._internal();

  static const _prefix = 'settings_';

  // ── Clés séparées Commande Interne vs Prestation ──
  static const _pvPrefixInterne = 'pv_config_interne_';
  static const _pvPrefixPrestation = 'pv_config_prestation_';

  // Ancienne clé (conservée pour compatibilité / migration silencieuse)
  static const _pvPrefixLegacy = 'pv_config_';

  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String?>{};
    const defaultSettings = AppSettings();
    for (final key in defaultSettings.toMap().keys) {
      map[key] = prefs.getString('$_prefix$key');
    }
    return AppSettings.fromMap(map);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final map = settings.toMap();
    for (final entry in map.entries) {
      await prefs.setString('$_prefix${entry.key}', entry.value);
    }
  }

  // ── Commande Interne ──────────────────────────────────────────────
  Future<PvFieldConfig> getPvConfigInterne() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String?>{};
    const defaultConfig = PvFieldConfig();
    for (final key in defaultConfig.toMap().keys) {
      // Priorité : clé interne → fallback ancienne clé commune
      map[key] = prefs.getString('$_pvPrefixInterne$key')
          ?? prefs.getString('$_pvPrefixLegacy$key');
    }
    return PvFieldConfig.fromMap(map);
  }

  Future<void> savePvConfigInterne(PvFieldConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final map = config.toMap();
    for (final entry in map.entries) {
      await prefs.setString('$_pvPrefixInterne${entry.key}', entry.value);
    }
  }

  // ── Prestation ───────────────────────────────────────────────────
  Future<PvFieldConfig> getPvConfigPrestation() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String?>{};
    const defaultConfig = PvFieldConfig();
    for (final key in defaultConfig.toMap().keys) {
      // Priorité : clé prestation → fallback ancienne clé commune
      map[key] = prefs.getString('$_pvPrefixPrestation$key')
          ?? prefs.getString('$_pvPrefixLegacy$key');
    }
    return PvFieldConfig.fromMap(map);
  }

  Future<void> savePvConfigPrestation(PvFieldConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final map = config.toMap();
    for (final entry in map.entries) {
      await prefs.setString('$_pvPrefixPrestation${entry.key}', entry.value);
    }
  }

  // ── Méthode générique (garde la compatibilité des appels existants) ──
  Future<PvFieldConfig> getPvConfig({bool isPrestation = false}) =>
      isPrestation ? getPvConfigPrestation() : getPvConfigInterne();

  Future<void> savePvConfig(PvFieldConfig config, {bool isPrestation = false}) =>
      isPrestation ? savePvConfigPrestation(config) : savePvConfigInterne(config);
}

