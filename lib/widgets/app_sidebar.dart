import 'package:flutter/material.dart';

import '../controllers/sidebar_controller.dart';
import '../db/database_helper.dart';
import '../main.dart';
import '../screens/rapport_form_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import 'backup_dialog.dart';

class AppSidebar extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback? onNavigate;

  const AppSidebar({
    super.key,
    required this.isCollapsed,
    this.onNavigate,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  Future<Map<String, int>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  void _fetchStats() {
    setState(() {
      _statsFuture = DatabaseHelper.instance.getDashboardStats();
    });
  }

  void _navigateToTab(int index) {
    widget.onNavigate?.call();
    SidebarController.instance.setNavIndex(index);
    if (appNavigatorKey.currentState?.canPop() == true) {
      appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    _fetchStats();
  }

  Future<void> _openNewPv() async {
    widget.onNavigate?.call();
    await appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const RapportFormScreen()),
    );
    _fetchStats();
  }

  Future<void> _openSettings() async {
    widget.onNavigate?.call();
    await appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _fetchStats();
  }

  void _openBackup() {
    widget.onNavigate?.call();
    final ctx = appNavigatorKey.currentContext ?? context;
    BackupDialog.show(ctx, onRestored: _fetchStats);
  }

  @override
  Widget build(BuildContext context) {
    final isDrawer = widget.onNavigate != null;
    final isCollapsed = isDrawer ? false : widget.isCollapsed;
    final width = isDrawer ? double.infinity : (isCollapsed ? 70.0 : 250.0);
    final activeIndex = SidebarController.instance.currentNavIndex;

    Widget sidebarContent = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. EN-TÊTE DU SIDEBAR ──
          if (isCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  _buildLogoBox(),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                    tooltip: 'Agrandir le menu',
                    onPressed: () => SidebarController.instance.toggleCollapse(),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 10, 12),
              child: Row(
                children: [
                  _buildLogoBox(),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Macrographique',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Labo Essais Mécaniques',
                          style: TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isDrawer)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF94A3B8)),
                      tooltip: 'Fermer le menu',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.keyboard_double_arrow_left_rounded, size: 20, color: Color(0xFF94A3B8)),
                      tooltip: 'Réduire le menu',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => SidebarController.instance.toggleCollapse(),
                    ),
                ],
              ),
            ),

          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 12),

          // ── 2. CORPS SCROLLABLE (NAVIGATION & OUTILS) ──
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // BOUTON D'ACTION PRINCIPALE (+ NOUVEAU PV)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: isCollapsed
                        ? Tooltip(
                            message: 'Nouveau PV',
                            child: InkWell(
                              onTap: _openNewPv,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _openNewPv,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentTeal,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppTheme.accentTeal.withValues(alpha: 0.35),
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Nouveau PV',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // SECTION NAVIGATION
                  if (!isCollapsed)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'NAVIGATION',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),

                  _buildNavItem(
                    index: 0,
                    title: 'Tableau de Bord',
                    icon: Icons.dashboard_rounded,
                    isSelected: activeIndex == 0,
                    isCollapsed: isCollapsed,
                    onTap: () => _navigateToTab(0),
                  ),
                  _buildNavItem(
                    index: 1,
                    title: 'Dossiers Clients',
                    icon: Icons.folder_shared_rounded,
                    badgeKey: 'clients',
                    isSelected: activeIndex == 1,
                    isCollapsed: isCollapsed,
                    onTap: () => _navigateToTab(1),
                  ),
                  _buildNavItem(
                    index: 2,
                    title: 'Tous les Rapports PV',
                    icon: Icons.assignment_rounded,
                    badgeKey: 'rapports',
                    isSelected: activeIndex == 2,
                    isCollapsed: isCollapsed,
                    onTap: () => _navigateToTab(2),
                  ),

                  const SizedBox(height: 12),

                  // SECTION OUTILS
                  if (!isCollapsed)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'OUTILS & GESTION',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(color: Color(0xFF1E293B), height: 16),
                    ),

                  _buildActionItem(
                    title: 'Sauvegarde & Export',
                    icon: Icons.cloud_sync_rounded,
                    isCollapsed: isCollapsed,
                    onTap: _openBackup,
                  ),
                  _buildActionItem(
                    title: 'Paramètres Globaux',
                    icon: Icons.tune_rounded,
                    isCollapsed: isCollapsed,
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
          ),

          // ── 3. PIED DU SIDEBAR (AUTEUR / STATUT) ──
          if (isCollapsed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Tooltip(
                  message: 'Ing. AYATI Tahar — Welding Inspection',
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155), width: 0.8),
                    ),
                    child: const Center(
                      child: Text(
                        'AT',
                        style: TextStyle(
                          color: Color(0xFF2DD4BF),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF334155), width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF2DD4BF),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ing. AYATI Tahar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Macrographie Inspection',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (isDrawer) {
      return Container(
        color: const Color(0xFF0F172A),
        child: sidebarContent,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: isCollapsed ? 70.0 : 250.0,
          maxWidth: isCollapsed ? 70.0 : 250.0,
          child: SizedBox(
            width: isCollapsed ? 70.0 : 250.0,
            child: sidebarContent,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoBox() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.35),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.science_rounded, size: 19, color: Colors.white),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
    String? badgeKey,
    required bool isSelected,
    required bool isCollapsed,
    required VoidCallback onTap,
  }) {
    final itemWidget = Container(
      margin: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 10 : 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 10,
            vertical: 9,
          ),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF94A3B8),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
                if (badgeKey != null)
                  FutureBuilder<Map<String, int>>(
                    future: _statsFuture,
                    builder: (context, snap) {
                      final count = snap.data?[badgeKey];
                      if (count == null || count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentTeal.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF94A3B8),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(
        message: title,
        preferBelow: false,
        child: itemWidget,
      );
    }
    return itemWidget;
  }

  Widget _buildActionItem({
    required String title,
    required IconData icon,
    required bool isCollapsed,
    required VoidCallback onTap,
  }) {
    final itemWidget = Container(
      margin: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 10 : 8,
        vertical: 2,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 10,
            vertical: 9,
          ),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              if (!isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(
        message: title,
        preferBelow: false,
        child: itemWidget,
      );
    }
    return itemWidget;
  }
}
