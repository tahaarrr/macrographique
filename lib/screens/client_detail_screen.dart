import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/client.dart';
import '../models/rapport.dart';
import '../theme/app_theme.dart';
import 'rapport_detail_screen.dart';
import 'rapport_form_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientName;
  final String? clientAddress;

  const ClientDetailScreen({
    super.key,
    required this.clientName,
    this.clientAddress,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late Future<List<Rapport>> _rapportsFuture;
  String _query = '';
  String _selectedProjectFilter = 'ALL'; // 'ALL' or specific project name
  bool _sortAscending = true;

  // Mode sélection multiple
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
      _rapportsFuture =
          DatabaseHelper.instance.getRapportsForClient(widget.clientName);
    });
  }

  Future<void> _showChangeClientTypeDialog(bool currentIsInterne, int count) async {
    final newType = currentIsInterne ? 'prestation' : 'commande_interne';
    final newLabel = currentIsInterne ? 'Prestation' : 'Commande Interne';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: AppTheme.accentTeal),
            SizedBox(width: 8),
            Text('Modifier le type du client'),
          ],
        ),
        content: Text(
          'Voulez-vous modifier le type de ce dossier client et passer ses $count PV(s) en « $newLabel » ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
            child: Text('Passer en $newLabel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.updateClientType(widget.clientName, newType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Dossier client passé en $newLabel ($count PVs mis à jour)'),
            backgroundColor: AppTheme.accentTeal,
          ),
        );
      }
      _loadData();
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
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

  Future<void> _showMoveDialog(List<int> ids, List<Rapport> allRapports) async {
    final clients = await DatabaseHelper.instance.getAllClients();
    if (!mounted) return;

    // Collect distinct project names for this client
    final projects = allRapports
        .map((r) => r.projet.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    int targetType = 0; // 0 = Move to another Client, 1 = Move to another Project
    String? selectedTargetClient = clients.firstWhere(
      (c) => c.nomClient.toLowerCase() != widget.clientName.toLowerCase(),
      orElse: () => clients.isNotEmpty ? clients.first : ClientModel(nomClient: '', coordonneesClient: '', nbRapports: 0, totalEchantillons: 0),
    ).nomClient;
    final newClientCtrl = TextEditingController();

    String? selectedTargetProject = projects.isNotEmpty ? projects.first : null;
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
                  
                  // Switch Move Destination Type
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
                    // Move to Client Option
                    const Text(
                      'Choisir un dossier client de destination :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (clients.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedTargetClient!.isNotEmpty ? selectedTargetClient : null,
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
                    // Move to Project Option
                    const Text(
                      'Choisir un projet / sous-dossier de destination :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (projects.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedTargetProject,
                        decoration: const InputDecoration(
                          labelText: 'Projet existant',
                          prefixIcon: Icon(Icons.folder_outlined),
                          isDense: true,
                        ),
                        items: projects
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) => setModalState(() => selectedTargetProject = val),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newProjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ou saisir un NOUVEAU projet',
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
                              final destProject = newProjectCtrl.text.trim().isNotEmpty
                                  ? newProjectCtrl.text.trim()
                                  : selectedTargetProject;
                              if (destProject == null || destProject.isEmpty) return;

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
                            _loadData();
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
      _loadData();
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
          'Êtes-vous sûr de vouloir supprimer définitivement le rapport d\'essai N° ${r.pvNumero} pour « ${r.nomClient} » ainsi que toutes ses photos et mesures ?',
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
      final remaining = await DatabaseHelper.instance.getRapportsForClient(widget.clientName);
      if (remaining.isEmpty && mounted) {
        Navigator.pop(context, true);
      } else {
        _loadData();
      }
    }
  }

  Future<void> _deleteEntireClientFolder() async {
    final rapports = await _rapportsFuture;
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Supprimer tout le dossier « ${widget.clientName} » ?',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Attention : Cette action est irréversible !\n\nLe dossier client sera entièrement effacé ainsi que la TOTALITÉ de ses ${rapports.length} rapport(s) PV, photos et mesures macrographiques associées.',
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
            child: const Text('Supprimer définitivement le dossier'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteClient(widget.clientName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Dossier client « ${widget.clientName} » et ses ${rapports.length} PV(s) supprimés.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedIds.length} sélectionné(s)'
              : 'Dossier Client : ${widget.clientName}',
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded),
            tooltip: _isSelectionMode ? 'Fermer la sélection' : 'Mode Sélection',
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) _selectedIds.clear();
              });
            },
          ),
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.add_task_rounded),
              tooltip: 'Nouveau PV pour ce client',
              onPressed: () async {
                final rapports = await _rapportsFuture;
                if (!context.mounted) return;
                final bool isInterne = rapports.isNotEmpty
                    ? (rapports.first.typeRapport == 'commande_interne' ||
                        widget.clientName.toLowerCase().contains('sonelgaz') ||
                        widget.clientName.toLowerCase().contains('sonalgaz') ||
                        widget.clientName.toLowerCase().contains('transport gaz'))
                    : (widget.clientName.toLowerCase().contains('sonelgaz') ||
                        widget.clientName.toLowerCase().contains('sonalgaz') ||
                        widget.clientName.toLowerCase().contains('transport gaz'));

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RapportFormScreen(
                      initialClientName: widget.clientName,
                      initialClientAddress: widget.clientAddress,
                      initialTypeRapport: isInterne ? 'commande_interne' : 'prestation',
                    ),
                  ),
                );
                if (mounted) _loadData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              tooltip: 'Supprimer tout le dossier client',
              onPressed: _deleteEntireClientFolder,
            ),
          ],
        ],
      ),
      body: FutureBuilder<List<Rapport>>(
        future: _rapportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final allRapports = snapshot.data ?? [];
          final bool isInterne = allRapports.isNotEmpty
              ? (allRapports.first.typeRapport == 'commande_interne' ||
                  widget.clientName.toLowerCase().contains('sonelgaz') ||
                  widget.clientName.toLowerCase().contains('sonalgaz') ||
                  widget.clientName.toLowerCase().contains('transport gaz'))
              : (widget.clientName.toLowerCase().contains('sonelgaz') ||
                  widget.clientName.toLowerCase().contains('sonalgaz') ||
                  widget.clientName.toLowerCase().contains('transport gaz'));

          // Collect distinct projects for sub-folder chips (ignore empty or '/')
          final projectsSet = <String>{};
          for (final r in allRapports) {
            final p = r.projet.trim();
            if (p.isNotEmpty && p != '/') {
              projectsSet.add(p);
            }
          }
          final projectsList = projectsSet.toList()..sort();

          // Apply project sub-folder filter
          List<Rapport> filteredByProject = allRapports;
          if (_selectedProjectFilter != 'ALL') {
            filteredByProject = allRapports
                .where((r) => r.projet.trim().toLowerCase() == _selectedProjectFilter.toLowerCase())
                .toList();
          }

          // Apply search query filter across ALL data fields & Natural Sort (1, 2, 3...)
          final rawRapports = _query.isEmpty
              ? filteredByProject
              : filteredByProject.where((r) {
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

                  // Recherche dans les échantillons (Tube, Lot, Coulée, Bobine, Fournisseur...)
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

          final rapports = List<Rapport>.from(rawRapports)
            ..sort((a, b) => _sortAscending
                ? DatabaseHelper.comparePvNumbers(a.pvNumero, b.pvNumero)
                : DatabaseHelper.comparePvNumbers(b.pvNumero, a.pvNumero));

          return Column(
            children: [
              // ── Hero Header with Gradient ──
              Container(
                width: double.infinity,
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
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar folder icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Center(
                              child: Icon(Icons.folder_shared_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.clientName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                if (widget.clientAddress != null && widget.clientAddress!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.clientAddress!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 10,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Type badge (cliquable)
                          InkWell(
                            onTap: () => _showChangeClientTypeDialog(isInterne, allRapports.length),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isInterne
                                    ? AppTheme.accentTeal.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isInterne ? AppTheme.accentTeal : Colors.white38,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isInterne ? Icons.build_circle_outlined : Icons.business_outlined,
                                    size: 11,
                                    color: isInterne ? AppTheme.accentTeal : Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isInterne ? 'Cmd Interne' : 'Prestation',
                                    style: TextStyle(
                                      color: isInterne ? AppTheme.accentTeal : Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Stats chips
                      Row(
                        children: [
                          _buildStatChip(Icons.description_outlined, '${allRapports.length} PV(s)'),
                          const SizedBox(width: 6),
                          _buildStatChip(Icons.folder_copy_outlined, '${projectsList.length} Projet(s)'),
                          const SizedBox(width: 6),
                          _buildStatChip(
                            Icons.science_outlined,
                            '${allRapports.fold<int>(0, (s, r) => s + r.echantillons.length)} Éch.',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Project Chips ──
                        if (projectsList.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentTeal,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Sous-dossiers Projets',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 36,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                _projectChip('Tous (${allRapports.length})', 'ALL', Icons.folder_outlined, null),
                                const SizedBox(width: 6),
                                ...projectsList.map((p) {
                                  final count = allRapports.where((r) => r.projet.trim().toLowerCase() == p.toLowerCase()).length;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _projectChip('$p ($count)', p, Icons.folder_open_rounded, null),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        // ── Search bar ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Rechercher par N° PV, Tube, Lot, Nuance, Date...',
                                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
                                      ),
                                    ),
                                    onChanged: (v) => setState(() => _query = v.toLowerCase()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: IconButton(
                                  tooltip: _sortAscending ? 'Ordre croissant (1→9)' : 'Ordre décroissant (9→1)',
                                  icon: Icon(
                                    _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                    color: AppTheme.primaryNavy,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _sortAscending = !_sortAscending),
                                ),
                              ),
                            ],
                          ),
                        ),

              // Selection mode actions bar
              if (_isSelectionMode)
                Container(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _showMoveDialog(_selectedIds.toList(), allRapports),
                        icon: const Icon(Icons.drive_file_move_outlined, size: 14),
                        label: const Text('Déplacer', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _deleteSelected(_selectedIds.toList()),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('Supprimer', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),

              // PVs List
              Expanded(
                child: rapports.isEmpty
                    ? Center(
                        child: Text(
                          _query.isNotEmpty
                              ? 'Aucun PV ne correspond à "$_query"'
                              : 'Aucun PV dans ce sous-dossier.',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: rapports.length,
                          itemBuilder: (context, index) {
                            final r = rapports[index];
                            final isSelected = _selectedIds.contains(r.id);
                            final tubes = r.echantillons
                                .map((e) => e.nTube.trim())
                                .where((t) => t.isNotEmpty)
                                .toSet()
                                .toList();
                            final tubesText = tubes.isNotEmpty ? tubes.join(', ') : '/';

                            final types = r.echantillons
                                .map((e) => e.typeLot.trim())
                                .where((t) => t.isNotEmpty)
                                .toSet()
                                .toList();
                            final typeText = types.isNotEmpty ? types.join(', ') : '/';

                            final dateEssaiText = r.dateEssai.trim().isNotEmpty ? r.dateEssai.trim() : '/';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isSelected ? 2 : 1,
                              shadowColor: Colors.black.withValues(alpha: 0.05),
                              color: isSelected
                                  ? AppTheme.accentTeal.withValues(alpha: 0.06)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isSelected
                                    ? const BorderSide(color: AppTheme.accentTeal, width: 1.5)
                                    : const BorderSide(color: Color(0xFFE8EDF5)),
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
                                    _loadData();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                                  child: Row(
                                    children: [
                                      // Left colored accent bar
                                      Container(
                                        width: 3.5,
                                        height: 56,
                                        margin: const EdgeInsets.only(left: 10, right: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.accentTeal
                                              : (r.typeRapport == 'commande_interne'
                                                  ? AppTheme.accentTeal
                                                  : AppTheme.primaryNavy),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      if (_isSelectionMode) ...[
                                        Checkbox(
                                          value: isSelected,
                                          activeColor: AppTheme.accentTeal,
                                          onChanged: (_) => _toggleSelection(r.id!),
                                        ),
                                        const SizedBox(width: 2),
                                      ],
                                      // PV number badge
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: (r.typeRapport == 'commande_interne'
                                                  ? AppTheme.accentTeal
                                                  : AppTheme.primaryNavy)
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          r.pvNumero.split('/').first.trim().padLeft(2, '0').length > 2
                                              ? r.pvNumero.split('/').first.trim().substring(0, 2)
                                              : r.pvNumero.split('/').first.trim().padLeft(2, '0'),
                                          style: TextStyle(
                                            color: r.typeRapport == 'commande_interne'
                                                ? AppTheme.accentTeal
                                                : AppTheme.primaryNavy,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'PV N° ${r.pvNumero}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                ),
                                                Text(
                                                  r.dateEmission.isNotEmpty ? r.dateEmission : r.dateEssai,
                                                  style: const TextStyle(
                                                    fontSize: 9.5,
                                                    color: Color(0xFF94A3B8),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'N° Tube: $tubesText',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1E293B),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Type: $typeText',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF475569),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2.5),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Date Essai: $dateEssaiText',
                                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                ),
                                                if (r.projet.trim().isNotEmpty && r.projet.trim() != '/') ...[
                                                  const SizedBox(width: 6),
                                                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      r.projet,
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        color: AppTheme.primaryNavy,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      if (!_isSelectionMode) ...[
                                        IconButton(
                                          icon: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.accentTeal, size: 19),
                                          tooltip: 'Cloner / Dupliquer pour le PV suivant',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RapportFormScreen(copyFromRapport: r),
                                              ),
                                            );
                                            _loadData();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 19),
                                          tooltip: 'Supprimer ce rapport PV',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          onPressed: () => _deleteSingleRapport(r),
                                        ),
                                      ],
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
      ),
    ),
  ],
);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RapportFormScreen(
                initialClientName: widget.clientName,
                initialClientAddress: widget.clientAddress,
              ),
            ),
          );
          _loadData();
        },
        backgroundColor: AppTheme.accentTeal,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau PV', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectChip(String label, String value, IconData icon, Color? color) {
    final isSelected = _selectedProjectFilter == value ||
        (_selectedProjectFilter.toLowerCase() == value.toLowerCase());
    return GestureDetector(
      onTap: () => setState(() => _selectedProjectFilter = isSelected && value != 'ALL' ? 'ALL' : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentTeal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accentTeal : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.accentTeal.withValues(alpha: 0.25), blurRadius: 6)]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? Colors.white : AppTheme.accentTeal),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
