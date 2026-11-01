import 'package:flutter/material.dart';

import '../controllers/sidebar_controller.dart';
import '../db/database_helper.dart';
import '../models/client.dart';
import '../models/rapport.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import 'client_detail_screen.dart';
import 'rapport_detail_screen.dart';
import 'rapport_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<ClientModel>> _clientsFuture;
  late Future<List<Rapport>> _rapportsFuture;
  late Future<Map<String, int>> _statsFuture;
  String _query = '';
  int _selectedNavIndex = 0; // 0: Tableau de bord, 1: Clients, 2: Rapports

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedNavIndex = SidebarController.instance.currentNavIndex;
    SidebarController.instance.addListener(_onSidebarChanged);
    _reload();
  }

  @override
  void dispose() {
    SidebarController.instance.removeListener(_onSidebarChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onSidebarChanged() {
    final newIndex = SidebarController.instance.currentNavIndex;
    if (_selectedNavIndex != newIndex) {
      setState(() {
        _selectedNavIndex = newIndex;
        if (newIndex == 1) {
          _tabController.animateTo(0);
        } else if (newIndex == 2) {
          _tabController.animateTo(1);
        }
      });
    }
  }

  void _reload() {
    setState(() {
      _clientsFuture = DatabaseHelper.instance.getAllClients();
      _rapportsFuture = DatabaseHelper.instance.getAllRapports();
      _statsFuture = DatabaseHelper.instance.getDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width >= 750;

    final workspaceContent = Column(
      children: [
        _buildWorkspaceTopBar(isDesktop: isDesktop),
        Expanded(
          child: _selectedNavIndex == 0
              ? _buildDashboardView(isDesktop)
              : (_selectedNavIndex == 1
                  ? _buildClientsView(isDesktop)
                  : _buildRapportsView(isDesktop)),
        ),
      ],
    );

    // Desktop: AppShell already provides the sidebar, so no Row needed here
    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: workspaceContent,
      );
    }

    // Responsive Mobile/Tablet view with Drawer
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: AppSidebar(
          isCollapsed: false,
          onNavigate: () => Navigator.pop(context),
        ),
      ),
      body: workspaceContent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentTeal,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau PV', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RapportFormScreen()),
          );
          _reload();
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // EN-TETE DE LA ZONE DE TRAVAIL
  // ══════════════════════════════════════════════════════════════════
  Widget _buildWorkspaceTopBar({required bool isDesktop}) {
    final title = _selectedNavIndex == 0
        ? 'Tableau de Bord'
        : (_selectedNavIndex == 1 ? 'Dossiers Clients' : 'Tous les Rapports PV');
    final subtitle = _selectedNavIndex == 0
        ? 'Vue d\'ensemble des examens et éprouvettes'
        : (_selectedNavIndex == 1
            ? 'Gestion et historique des clients du laboratoire'
            : 'Traçabilité et consultation des procès-verbaux');

    if (isDesktop) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E3A8A),
              Color(0xFF0F172A),
            ],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x330F172A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Champ de recherche desktop adaptatif
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300, minWidth: 80),
                child: SizedBox(
                  height: 38,
                  child: _buildSearchTextField(isDark: true),
                ),
              ),
            ),
            const SizedBox(width: 8),

            IconButton(
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
              onPressed: _reload,
            ),
            const SizedBox(width: 6),

            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RapportFormScreen()),
                );
                _reload();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Nouveau PV',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Version Mobile / Tablette responsive (< 750px) style dark gradient
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualiser',
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: _reload,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: _buildSearchTextField(isDark: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTextField({bool isDark = true}) {
    return TextField(
      style: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: 'Rechercher Client, PV, Tube, Date…',
        hintStyle: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF94A3B8),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 16,
          color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF94A3B8),
        ),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
                ),
                onPressed: () => setState(() => _query = ''),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
        ),
      ),
      onChanged: (v) => setState(() => _query = v.toLowerCase()),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 3. VUE TABLEAU DE BORD (AVEC KPIS & ONGLETS)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDashboardView(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cartes statistiques KPI
        FutureBuilder<Map<String, int>>(
          future: _statsFuture,
          builder: (context, snapshot) {
            final stats = snapshot.data ?? {'clients': 0, 'rapports': 0, 'echantillons': 0};
            return Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 14,
                isDesktop ? 16 : 10,
                isDesktop ? 24 : 14,
                isDesktop ? 8 : 6,
              ),
              child: _buildKpiSection(stats, isDesktop),
            );
          },
        ),

        // Sélecteur d'onglets
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 14,
            isDesktop ? 6 : 4,
            isDesktop ? 24 : 14,
            isDesktop ? 10 : 8,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.circular(7),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(3),
              tabs: const [
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_shared_outlined, size: 15),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Dossiers Clients',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 15),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Tous les Rapports PV',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Contenu des onglets
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildClientsTab(),
              _buildRapportsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiSection(Map<String, int> stats, bool isDesktop) {
    final cards = [
      _buildModernKpiCard(
        title: 'Clients / Sociétés',
        value: stats['clients']!.toString(),
        subtitle: 'Dossiers industriels',
        icon: Icons.business_center_rounded,
        color: AppTheme.accentTeal,
        onTap: () => setState(() => _selectedNavIndex = 1),
      ),
      _buildModernKpiCard(
        title: 'Procès-Verbaux (PV)',
        value: stats['rapports']!.toString(),
        subtitle: 'Rapports macrographiques',
        icon: Icons.assignment_rounded,
        color: const Color(0xFF2563EB),
        onTap: () => setState(() => _selectedNavIndex = 2),
      ),
      _buildModernKpiCard(
        title: 'Échantillons Testés',
        value: stats['echantillons']!.toString(),
        subtitle: 'Coupes transversales',
        icon: Icons.science_rounded,
        color: const Color(0xFFD97706),
        onTap: () => setState(() => _selectedNavIndex = 2),
      ),
    ];

    if (!isDesktop) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            SizedBox(width: 225, child: cards[0]),
            const SizedBox(width: 10),
            SizedBox(width: 225, child: cards[1]),
            const SizedBox(width: 10),
            SizedBox(width: 225, child: cards[2]),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 14),
        Expanded(child: cards[1]),
        const SizedBox(width: 14),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _buildModernKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300, size: 16),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 4. VUES DIRECTES CLIENTS & RAPPORTS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildClientsView(bool isDesktop) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 10, isDesktop ? 24 : 16, 0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedNavIndex = 0),
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                label: const Text('Retour au Tableau de Bord'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              FutureBuilder<List<ClientModel>>(
                future: _clientsFuture,
                builder: (context, snap) {
                  final count = snap.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count Dossier${count > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppTheme.accentTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(child: _buildClientsTab()),
      ],
    );
  }

  Widget _buildRapportsView(bool isDesktop) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 10, isDesktop ? 24 : 16, 0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedNavIndex = 0),
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                label: const Text('Retour au Tableau de Bord'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              FutureBuilder<List<Rapport>>(
                future: _rapportsFuture,
                builder: (context, snap) {
                  final count = snap.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count Procès-Verbal${count > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(child: _buildRapportsTab()),
      ],
    );
  }

  Widget _buildClientsTab() {
    return FutureBuilder<List<ClientModel>>(
      future: _clientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final allClients = snapshot.data ?? [];
        final clients = _query.isEmpty
            ? allClients
            : allClients.where((c) {
                return c.nomClient.toLowerCase().contains(_query) ||
                    c.coordonneesClient.toLowerCase().contains(_query);
              }).toList();

        if (clients.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.folder_off_outlined, size: 42, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _query.isNotEmpty
                        ? 'Aucun dossier client trouvé pour "$_query".'
                        : 'Aucun client enregistré.\nAppuyez sur + pour créer le premier PV.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                itemCount: clients.length + 1, // +1 for section header
                itemBuilder: (context, index) {
                  // Section header
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_shared_outlined, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            '${clients.length} dossier${clients.length > 1 ? 's' : ''} client${clients.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.sort_rounded, size: 15, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    );
                  }
                  final client = clients[index - 1];
                  final bool isInterne = client.isCommandeInterne;
                  // Build initials avatar
                  final initials = client.nomClient.trim().isNotEmpty
                      ? client.nomClient.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
                      : '?';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1.5,
                    shadowColor: Colors.black.withValues(alpha: 0.04),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientDetailScreen(
                              clientName: client.nomClient,
                              clientAddress: client.coordonneesClient,
                            ),
                          ),
                        );
                        _reload();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            // Initials avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isInterne
                                      ? [const Color(0xFF0D9488), const Color(0xFF0F766E)]
                                      : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isInterne ? const Color(0xFF0D9488) : const Color(0xFF1E3A8A)).withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          client.nomClient,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: isInterne
                                              ? AppTheme.accentTeal.withValues(alpha: 0.1)
                                              : AppTheme.primaryNavy.withValues(alpha: 0.07),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isInterne
                                                ? AppTheme.accentTeal.withValues(alpha: 0.4)
                                                : AppTheme.primaryNavy.withValues(alpha: 0.25),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          isInterne ? 'Commande Interne' : 'Prestation',
                                          style: TextStyle(
                                            color: isInterne ? AppTheme.accentTeal : AppTheme.primaryNavy,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (client.coordonneesClient.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            client.coordonneesClient,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _buildMiniChip('${client.nbRapports} PV', Icons.description_outlined, AppTheme.accentTeal),
                                      _buildMiniChip('${client.totalEchantillons} échantillon${client.totalEchantillons > 1 ? 's' : ''}', Icons.science_outlined, const Color(0xFF475569)),
                                      if (client.latestPvNumero != null && client.latestPvNumero!.isNotEmpty)
                                        _buildMiniChip('Dernier: N° ${client.latestPvNumero}', Icons.history_rounded, const Color(0xFF3B82F6)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 19),
                              tooltip: 'Supprimer ce dossier client',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => _deleteClient(client),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll(List<Rapport> rapports) {
    setState(() {
      if (_selectedIds.length == rapports.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(rapports.map((r) => r.id!));
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _showMoveDialog(List<int> ids) async {
    final clients = await DatabaseHelper.instance.getAllClients();
    if (!mounted) return;

    int targetType = 0; // 0 = Move to Client, 1 = Move to Project
    String? selectedTargetClient = clients.isNotEmpty ? clients.first.nomClient : null;
    final newClientCtrl = TextEditingController();
    final newProjectCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.drive_file_move_outlined, color: AppTheme.primaryNavy),
                      const SizedBox(width: 10),
                      Text(
                        'Déplacer ${ids.length} PV(s)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Dossier Client', style: TextStyle(fontSize: 11)),
                        icon: Icon(Icons.folder_shared_outlined, size: 14),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Sous-dossier Projet', style: TextStyle(fontSize: 11)),
                        icon: Icon(Icons.account_tree_outlined, size: 14),
                      ),
                    ],
                    selected: {targetType},
                    onSelectionChanged: (val) {
                      setModalState(() => targetType = val.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (targetType == 0) ...[
                    const Text(
                      'Choisir un dossier client de destination :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (clients.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedTargetClient,
                        decoration: const InputDecoration(
                          labelText: 'Client existant',
                          prefixIcon: Icon(Icons.business_outlined),
                          isDense: true,
                        ),
                        items: clients
                            .map((c) => DropdownMenuItem(
                                  value: c.nomClient,
                                  child: Text(c.nomClient, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) => setModalState(() => selectedTargetClient = val),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newClientCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ou saisir un NOUVEAU client',
                        hintText: 'ex: SONATRACH',
                        prefixIcon: Icon(Icons.add_business_outlined),
                        isDense: true,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Saisir le nom du projet de destination :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newProjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom du projet / sous-dossier',
                        hintText: 'ex: PIPELINE 28 INCH',
                        prefixIcon: Icon(Icons.create_new_folder_outlined),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Confirmer'),
                          onPressed: () async {
                            if (targetType == 0) {
                              final destClient = newClientCtrl.text.trim().isNotEmpty
                                  ? newClientCtrl.text.trim()
                                  : selectedTargetClient;
                              if (destClient == null || destClient.isEmpty) return;

                              await DatabaseHelper.instance.moveRapportsToClient(ids, destClient);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ ${ids.length} PV(s) déplacé(s) vers « $destClient »'),
                                    backgroundColor: AppTheme.accentTeal,
                                  ),
                                );
                              }
                            } else {
                              final destProject = newProjectCtrl.text.trim();
                              if (destProject.isEmpty) return;

                              await DatabaseHelper.instance.moveRapportsToProject(ids, destProject);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ ${ids.length} PV(s) classé(s) dans le projet « $destProject »'),
                                    backgroundColor: AppTheme.accentTeal,
                                  ),
                                );
                              }
                            }
                            _reload();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteClient(ClientModel client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Supprimer le dossier « ${client.nomClient} » ?',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'Attention : Cette action supprimera définitivement le dossier client et la totalité de ses ${client.nbRapports} PV(s) ainsi que les photos et mesures associées.\n\nVoulez-vous continuer ?',
          style: const TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer tout le dossier'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteClient(client.nomClient);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Dossier « ${client.nomClient} » et ses PVs supprimés.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      _reload();
    }
  }

  Future<void> _deleteSingleRapport(Rapport r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text('Supprimer le PV N° ${r.pvNumero} ?', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer définitivement le rapport PV N° ${r.pvNumero} pour « ${r.nomClient} » ?',
          style: const TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && r.id != null) {
      await DatabaseHelper.instance.deleteRapport(r.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ PV N° ${r.pvNumero} supprimé.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      _reload();
    }
  }

  Future<void> _deleteSelected(List<int> ids) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer les PVs sélectionnés ?'),
        content: Text('Êtes-vous sûr de vouloir supprimer définitivement ces ${ids.length} rapport(s) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final id in ids) {
        await DatabaseHelper.instance.deleteRapport(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🗑️ ${ids.length} PV(s) supprimé(s)')),
        );
      }
      _reload();
    }
  }

  // TAB 2 : TOUS LES RAPPORTS
  Widget _buildRapportsTab() {
    return FutureBuilder<List<Rapport>>(
      future: _rapportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final all = snapshot.data ?? [];
        final rapports = _query.isEmpty
            ? all
            : all.where((r) {
                final q = _query.trim().toLowerCase();
                if (r.pvNumero.toLowerCase().contains(q)) return true;
                if (r.nomClient.toLowerCase().contains(q)) return true;
                if (r.coordonneesClient.toLowerCase().contains(q)) return true;
                if (r.projet.toLowerCase().contains(q)) return true;
                if (r.dateEmission.toLowerCase().contains(q)) return true;
                if (r.dateReception.toLowerCase().contains(q)) return true;
                if (r.dateEssai.toLowerCase().contains(q)) return true;
                if (r.nuance.toLowerCase().contains(q)) return true;
                if (r.dimensions.toLowerCase().contains(q)) return true;
                if (r.nWps.toLowerCase().contains(q)) return true;
                if (r.nPqr.toLowerCase().contains(q)) return true;
                if (r.procedeSoudage.toLowerCase().contains(q)) return true;
                if (r.metalApport.toLowerCase().contains(q)) return true;
                if (r.positionSoudage.toLowerCase().contains(q)) return true;
                if (r.nJoint.toLowerCase().contains(q)) return true;
                if (r.traitementThermique.toLowerCase().contains(q)) return true;
                if (r.methodeEssai.toLowerCase().contains(q)) return true;
                if (r.methodeEchantillonnage.toLowerCase().contains(q)) return true;
                if (r.specificationEssai.toLowerCase().contains(q)) return true;
                if (r.observation.toLowerCase().contains(q)) return true;
                if (r.demandeur.toLowerCase().contains(q)) return true;
                if (r.nCommandeInterne.toLowerCase().contains(q)) return true;
                if (r.designationSoudure.toLowerCase().contains(q)) return true;
                if (r.dateSoudage.toLowerCase().contains(q)) return true;
                if (r.attaqueChimique.toLowerCase().contains(q)) return true;
                if (r.materielUtilise.toLowerCase().contains(q)) return true;
                if (r.soudeurCode.toLowerCase().contains(q)) return true;

                // Recherche dans les échantillons
                for (final e in r.echantillons) {
                  if (e.nTube.toLowerCase().contains(q)) return true;
                  if (e.typeLot.toLowerCase().contains(q)) return true;
                  if (e.metalNuance.toLowerCase().contains(q)) return true;
                  if (e.nCoulee.toLowerCase().contains(q)) return true;
                  if (e.nBobine.toLowerCase().contains(q)) return true;
                  if (e.fournisseur.toLowerCase().contains(q)) return true;
                  if (e.diametreTube.toLowerCase().contains(q)) return true;
                  if (e.epNominale.toLowerCase().contains(q)) return true;
                  if (e.epReel.toLowerCase().contains(q)) return true;
                  if (e.grossissement.toLowerCase().contains(q)) return true;
                  if (e.flux.toLowerCase().contains(q)) return true;
                  if (e.vitesse.toLowerCase().contains(q)) return true;
                  if (e.observation.toLowerCase().contains(q)) return true;
                }
                return false;
              }).toList();

        if (rapports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.find_in_page_outlined,
                    size: 64,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _query.isNotEmpty
                        ? 'Aucun rapport pour "$_query"'
                        : 'Aucun rapport enregistré.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              children: [
                // Top Selection Bar
                Container(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _selectAll(rapports),
                          icon: Icon(
                            _selectedIds.length == rapports.length
                                ? Icons.deselect_rounded
                                : Icons.select_all_rounded,
                            size: 16,
                          ),
                          label: Text(
                            _selectedIds.length == rapports.length ? 'Désélectionner' : 'Tout sélec.',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (_isSelectionMode) ...[
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            ),
                            onPressed: _selectedIds.isEmpty ? null : () => _showMoveDialog(_selectedIds.toList()),
                            icon: const Icon(Icons.drive_file_move_outlined, size: 14),
                            label: Text('Déplacer (${_selectedIds.length})', style: const TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            ),
                            onPressed: _selectedIds.isEmpty ? null : () => _deleteSelected(_selectedIds.toList()),
                            icon: const Icon(Icons.delete_outline, size: 14),
                            label: const Text('Supprimer', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Rapports ListView
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      itemCount: rapports.length,
                      itemBuilder: (context, index) {
                        final r = rapports[index];
                        final isSelected = _selectedIds.contains(r.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1.5,
                          shadowColor: Colors.black.withValues(alpha: 0.04),
                          color: isSelected ? AppTheme.accentTeal.withValues(alpha: 0.06) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected
                                ? const BorderSide(color: AppTheme.accentTeal, width: 1.5)
                                : const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onLongPress: () => _toggleSelection(r.id!),
                            onTap: () async {
                              if (_isSelectionMode) {
                                _toggleSelection(r.id!);
                              } else {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RapportDetailScreen(rapportId: r.id!),
                                  ),
                                );
                                _reload();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              child: Row(
                                children: [
                                  // Left accent bar
                                  Container(
                                    width: 3.5,
                                    height: 52,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: r.isCommandeInterne ? AppTheme.accentTeal : AppTheme.primaryNavy,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  if (_isSelectionMode) ...[
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: AppTheme.accentTeal,
                                      onChanged: (_) => _toggleSelection(r.id!),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  // PV badge
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (r.isCommandeInterne ? AppTheme.accentTeal : AppTheme.primaryNavy)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      r.pvNumero.split('/').first.trim().padLeft(2, '0').length > 2
                                          ? r.pvNumero.split('/').first.trim().substring(0, 2)
                                          : r.pvNumero.split('/').first.trim().padLeft(2, '0'),
                                      style: TextStyle(
                                        color: r.isCommandeInterne ? AppTheme.accentTeal : AppTheme.primaryNavy,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final tubes = r.echantillons.map((e) => e.nTube.trim()).where((t) => t.isNotEmpty).toSet().toList();
                                        final tubesText = tubes.isNotEmpty ? tubes.join(', ') : '';
                                        final types = r.echantillons.map((e) => e.typeLot.trim()).where((t) => t.isNotEmpty).toSet().toList();
                                        final typeText = types.isNotEmpty ? types.join(', ') : '';
                                        final nuanceText = r.nuance.trim().isNotEmpty
                                            ? r.nuance.trim()
                                            : (r.echantillons.isNotEmpty && r.echantillons.first.metalNuance.trim().isNotEmpty
                                                ? r.echantillons.first.metalNuance.trim()
                                                : '');
                                        final dimText = r.dimensions.trim().isNotEmpty ? r.dimensions.trim() : '';
                                        final dateEssaiText = r.dateEssai.trim().isNotEmpty ? r.dateEssai.trim() : '/';

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: RichText(
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text: r.nomClient,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                            color: Color(0xFF0F172A),
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: ' — PV N° ${r.pvNumero}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 12.5,
                                                            color: Color(0xFF475569),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: r.isCommandeInterne
                                                        ? AppTheme.accentTeal.withValues(alpha: 0.12)
                                                        : AppTheme.primaryNavy.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(5),
                                                    border: Border.all(
                                                      color: r.isCommandeInterne ? AppTheme.accentTeal : AppTheme.primaryNavy,
                                                      width: 0.7,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    r.isCommandeInterne ? 'CMD' : 'PRESTATION',
                                                    style: TextStyle(
                                                      color: r.isCommandeInterne ? AppTheme.accentTeal : AppTheme.primaryNavy,
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Wrap(
                                              spacing: 5,
                                              runSpacing: 4,
                                              children: [
                                                if (tubesText.isNotEmpty)
                                                  _buildMiniChip('Tube: $tubesText', Icons.adjust_rounded, const Color(0xFF334155)),
                                                if (nuanceText.isNotEmpty)
                                                  _buildMiniChip('Nuance: $nuanceText', Icons.layers_outlined, const Color(0xFF0284C7)),
                                                if (dimText.isNotEmpty)
                                                  _buildMiniChip('Dim: $dimText', Icons.straighten_rounded, const Color(0xFF059669)),
                                                if (typeText.isNotEmpty)
                                                  _buildMiniChip('Lot: $typeText', Icons.tag_rounded, const Color(0xFF64748B)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today_outlined, size: 10.5, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Essai: $dateEssaiText',
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                ),
                                                if (r.projet.trim().isNotEmpty && r.projet.trim() != '/') ...[
                                                  const SizedBox(width: 8),
                                                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      r.projet.trim(),
                                                      style: const TextStyle(fontSize: 10, color: AppTheme.primaryNavy, fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!_isSelectionMode) ...[
                                    IconButton(
                                      icon: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.accentTeal, size: 18),
                                      tooltip: 'Cloner / Dupliquer pour le PV suivant',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(5),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => RapportFormScreen(copyFromRapport: r)),
                                        );
                                        _reload();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      tooltip: 'Supprimer ce PV',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(5),
                                      onPressed: () => _deleteSingleRapport(r),
                                    ),
                                  ],
                                  const SizedBox(width: 2),
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
