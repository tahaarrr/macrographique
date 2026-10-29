import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôleur singleton pour la barre latérale (Sidebar)
/// Gère l'état réduit/déployé persistant et la navigation active.
class SidebarController extends ChangeNotifier {
  static final SidebarController instance = SidebarController._internal();
  SidebarController._internal() {
    _loadState();
  }

  static const _prefKeyCollapsed = 'sidebar_collapsed_state';

  bool _isCollapsed = false;
  bool get isCollapsed => _isCollapsed;

  int _currentNavIndex = 0; // 0: Dashboard, 1: Clients, 2: Rapports, 3: Settings
  int get currentNavIndex => _currentNavIndex;

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isCollapsed = prefs.getBool(_prefKeyCollapsed) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleCollapse() async {
    _isCollapsed = !_isCollapsed;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyCollapsed, _isCollapsed);
    } catch (_) {}
  }

  void setNavIndex(int index) {
    if (_currentNavIndex != index) {
      _currentNavIndex = index;
      notifyListeners();
    }
  }
}
