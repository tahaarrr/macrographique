import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/app_settings.dart';
import '../models/echantillon.dart';
import '../models/pv_config.dart';
import '../models/rapport.dart';
import '../services/pdf_service.dart';
import '../services/pdf_service_modern.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pv_config_dialog.dart';
import 'rapport_form_screen.dart';

class RapportDetailScreen extends StatefulWidget {
  final int rapportId;

  const RapportDetailScreen({super.key, required this.rapportId});

  @override
  State<RapportDetailScreen> createState() => _RapportDetailScreenState();
}

class _RapportDetailScreenState extends State<RapportDetailScreen> {
  Rapport? _rapport;
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await DatabaseHelper.instance.getRapportById(widget.rapportId);
    setState(() {
      _rapport = r;
      _loading = false;
    });
  }

  Future<void> _deleteRapport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce rapport ?'),
        content: const Text(
          'Cette action est irréversible. Le rapport PV et tous ses échantillons seront effacés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && _rapport?.id != null) {
      await DatabaseHelper.instance.deleteRapport(_rapport!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _previewPdf({int initialVersion = 2}) async {
    if (_rapport == null) return;
    setState(() => _generating = true);
    try {
      final settings = await SettingsService.instance.getSettings();
      final pvConfig = await SettingsService.instance.getPvConfig(
        isPrestation: !_rapport!.isCommandeInterne,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PdfPreviewPage(
            rapport: _rapport!,
            settings: settings,
            pvConfig: pvConfig,
            initialTemplateVersion: initialVersion,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur aperçu PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _sharePdf({int version = 2}) async {
    if (_rapport == null) return;
    setState(() => _generating = true);
    try {
      final settings = await SettingsService.instance.getSettings();
      final pvConfig = await SettingsService.instance.getPvConfig(
        isPrestation: !_rapport!.isCommandeInterne,
      );
      final bytes = version == 2
          ? await PdfServiceModern.generateRapportBytes(_rapport!, settings: settings, pvConfig: pvConfig)
          : await PdfService.generateRapportBytes(_rapport!, settings: settings, pvConfig: pvConfig);
      final filename = '${_rapport!.defaultPdfFileName}.pdf';
      final tempDir = await getTemporaryDirectory();
      final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${tempDir.path}/$safeName');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, name: safeName, mimeType: 'application/pdf')],
          text: 'Rapport d\'essai PV N° ${_rapport!.pvNumero} (Modèle ${version == 2 ? "Moderne V2" : "Officiel V1"})',
          subject: 'PV N° ${_rapport!.pvNumero} - ${_rapport!.nomClient}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur partage PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_rapport == null) {
      return const Scaffold(
        body: Center(child: Text('Rapport introuvable')),
      );
    }

    final r = _rapport!;

    return Scaffold(
      appBar: AppBar(
        title: Text('PV N° ${r.pvNumero}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.control_point_duplicate_rounded),
            tooltip: 'Cloner / Dupliquer (Créer le PV suivant)',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RapportFormScreen(copyFromRapport: r),
                ),
              );
              _load();
            },
          ),
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Personnaliser les champs du PV',
              onPressed: () async {
                final isPrestation = _rapport != null && !_rapport!.isCommandeInterne;
                final curConfig = await SettingsService.instance.getPvConfig(isPrestation: isPrestation);
                if (!context.mounted) return;
                await PvConfigDialog.show(
                  context,
                  initialConfig: curConfig,
                  isPrestation: isPrestation,
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Modifier ce rapport',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RapportFormScreen(rapport: r)),
              );
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Supprimer ce rapport',
            onPressed: _deleteRapport,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // 1. Hero Header Banner
              _buildHeroHeader(r, isDesktop),

              // 2. Main Content Cards
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 20 : 12,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── SECTION 1 : IDENTIFICATION DU PV ──
                      _buildIdentificationCard(r, isDesktop),

                      const SizedBox(height: 14),

                      // ── SECTION 2 : SOUDAGE & ASSEMBLAGE (Si Commande Interne) ──
                      if (r.isCommandeInterne) ...[
                        _buildCommandeInterneCard(r, isDesktop),
                        const SizedBox(height: 14),
                      ],

                      // ── SECTION 3 : ÉCHANTILLONS & MACROGRAPHIES ──
                      _buildSamplesSection(r, isDesktop),

                      const SizedBox(height: 14),

                      // ── SECTION 4 : CONSTAT MACROGRAPHIQUE ──
                      _buildObservationCard(r),

                      const SizedBox(height: 14),

                      // ── SECTION 5 : SIGNATURES & VALIDATION ──
                      _buildSignaturesCard(r),

                      // ── CHAMPS PERSONNALISÉS SUPPLÉMENTAIRES (Si existants) ──
                      _buildCustomFieldsCard(r),

                      const SizedBox(height: 70),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // HERO HEADER BANNER
  // ══════════════════════════════════════════════════════════════════
  Widget _buildHeroHeader(Rapport r, bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 16,
              16,
              isDesktop ? 24 : 16,
              22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client Avatar / Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                        Icons.business_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Client & Address Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.nomClient.isNotEmpty ? r.nomClient : 'Client non renseigné',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 18 : 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (r.coordonneesClient.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    r.coordonneesClient,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // PV Number and Type Badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'PV N° ${r.pvNumero.isNotEmpty ? r.pvNumero : "---"}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            r.isCommandeInterne ? 'Commande Interne' : 'Prestation',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Chips Bar
                Builder(
                  builder: (context) {
                    final tubes = r.echantillons
                        .map((e) => e.nTube.trim())
                        .where((t) => t.isNotEmpty)
                        .toSet()
                        .toList();
                    final tubesText = tubes.isNotEmpty ? tubes.join(', ') : '---';
                    final tubeLabel = tubesText.toUpperCase().startsWith('TUBE') ? tubesText : 'Tube: $tubesText';

                    final types = r.echantillons
                        .map((e) => e.typeLot.trim())
                        .where((t) => t.isNotEmpty)
                        .toSet()
                        .toList();
                    final typeVal = types.isNotEmpty
                        ? types.join(', ')
                        : (r.isCommandeInterne ? 'Commande Interne' : (r.typeRapport.isNotEmpty ? r.typeRapport : '---'));
                    final typeLabel = typeVal.toUpperCase().startsWith('TYPE') ? typeVal : 'Type: $typeVal';

                    final pvVal = r.pvNumero.trim().isNotEmpty ? r.pvNumero.trim() : '---';
                    final pvLabel = pvVal.toUpperCase().startsWith('PV') ? pvVal : 'PV N° $pvVal';

                    final dimLabel = r.dimensions.toLowerCase().contains('mm')
                        ? r.dimensions
                        : '${r.dimensions} mm';

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _headerChip(Icons.tag_rounded, pvLabel, const Color(0xFF38BDF8)),
                        _headerChip(Icons.adjust_rounded, tubeLabel, const Color(0xFFFB923C)),
                        _headerChip(Icons.category_rounded, typeLabel, const Color(0xFF818CF8)),
                        if (r.dimensions.isNotEmpty)
                          _headerChip(Icons.straighten_rounded, dimLabel, const Color(0xFF34D399)),
                        if (r.nuance.isNotEmpty)
                          _headerChip(Icons.tune_rounded, r.nuance, const Color(0xFFA78BFA)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // CARD 1: IDENTIFICATION & CARACTÉRISTIQUES (STRUCTURE ÉPURÉE & LISIBLE)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildIdentificationCard(Rapport r, bool isDesktop) {
    final customClient = _getCustomFieldsForSection(r, 'client');
    final customCarac = _getCustomFieldsForSection(r, 'caracteristiques');
    final customIdent = _getCustomFieldsForSection(r, 'ident');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.assignment_outlined,
            iconColor: AppTheme.primaryNavy,
            title: 'Identification & Caractéristiques',
            subtitle: 'Informations administratives et métallurgiques du PV',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // Client & Demandeur (Full width pour éviter la troncature)
          _infoTile(
            label: 'Client / Demandeur',
            value: r.nomClient,
            icon: Icons.business_rounded,
            iconColor: AppTheme.primaryNavy,
            fullWidth: true,
          ),
          if (r.coordonneesClient.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoTile(
              label: 'Adresse & Coordonnées',
              value: r.coordonneesClient,
              icon: Icons.location_on_outlined,
              fullWidth: true,
            ),
          ],
          const SizedBox(height: 8),

          // Dates Row (3 dates bien aérées)
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  label: 'Réception',
                  value: r.dateReception,
                  icon: Icons.move_to_inbox_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoTile(
                  label: 'Date Essai',
                  value: r.dateEssai,
                  icon: Icons.science_rounded,
                  iconColor: AppTheme.accentTeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoTile(
                  label: 'Émission',
                  value: r.dateEmission,
                  icon: Icons.send_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nuance & Dimensions (Important: badges lisibles)
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  label: 'Nuance Acier',
                  value: r.nuance,
                  icon: Icons.diamond_outlined,
                  iconColor: AppTheme.accentTeal,
                  badge: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoTile(
                  label: 'Dimensions',
                  value: r.dimensions.isNotEmpty ? '${r.dimensions} mm' : '---',
                  icon: Icons.straighten_rounded,
                  iconColor: AppTheme.primaryNavy,
                  badge: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // WPS & PQR
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  label: 'N° WPS',
                  value: r.nWps,
                  icon: Icons.description_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoTile(
                  label: 'N° PQR',
                  value: r.nPqr,
                  icon: Icons.task_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Projet & Méthode
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  label: 'Projet / Marché',
                  value: r.projet,
                  icon: Icons.folder_open_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoTile(
                  label: 'Méthode d\'Essai',
                  value: r.methodeEssai,
                  icon: Icons.biotech_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Spécification d'essai & Méthode d'échantillonnage
          if (r.specificationEssai.isNotEmpty || r.methodeEchantillonnage.isNotEmpty)
            Row(
              children: [
                if (r.specificationEssai.isNotEmpty)
                  Expanded(
                    child: _infoTile(
                      label: 'Spécification d\'Essai',
                      value: r.specificationEssai,
                      icon: Icons.gavel_rounded,
                    ),
                  ),
                if (r.specificationEssai.isNotEmpty && r.methodeEchantillonnage.isNotEmpty)
                  const SizedBox(width: 8),
                if (r.methodeEchantillonnage.isNotEmpty)
                  Expanded(
                    child: _infoTile(
                      label: 'Échantillonnage',
                      value: r.methodeEchantillonnage,
                      icon: Icons.rule_rounded,
                    ),
                  ),
              ],
            ),

          // Champs personnalisés attachés
          if (customClient.isNotEmpty || customCarac.isNotEmpty || customIdent.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            ...[...customClient, ...customCarac, ...customIdent].map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _infoTile(
                  label: entry.key,
                  value: entry.value,
                  icon: Icons.extension_outlined,
                  fullWidth: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // CARD 2: SOUDAGE & ASSEMBLAGE (COMMANDE INTERNE)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildCommandeInterneCard(Rapport r, bool isDesktop) {
    final customSoudage = _getCustomFieldsForSection(r, 'soudage');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.handyman_outlined,
            iconColor: const Color(0xFFD97706),
            title: 'Soudage & Assemblage',
            subtitle: 'Paramètres du procédé et du joint soudé',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  label: 'Procédé Soudage',
                  value: r.procedeSoudage,
                  icon: Icons.settings_suggest_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoTile(
                  label: 'Position Soudage',
                  value: r.positionSoudage,
                  icon: Icons.explore_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  label: 'Métal d\'Apport / Lot',
                  value: r.metalApport,
                  icon: Icons.cable_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoTile(
                  label: 'N° Joint',
                  value: r.nJoint,
                  icon: Icons.linear_scale_rounded,
                ),
              ),
            ],
          ),
          if (r.traitementThermique.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoTile(
              label: 'Traitement Thermique (PWHT)',
              value: r.traitementThermique,
              icon: Icons.local_fire_department_rounded,
              fullWidth: true,
            ),
          ],
          if (customSoudage.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            ...customSoudage.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _infoTile(
                  label: entry.key,
                  value: entry.value,
                  icon: Icons.extension_outlined,
                  fullWidth: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // CARD 4: CONSTAT MACROGRAPHIQUE
  // ══════════════════════════════════════════════════════════════════
  Widget _buildObservationCard(Rapport r) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.visibility_outlined,
            iconColor: const Color(0xFF4F46E5),
            title: 'Constat Macrographique & Conclusion',
            subtitle: 'Résultat officiel de l\'examen métallurgique',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, color: AppTheme.accentTeal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.observation.isNotEmpty ? r.observation : 'Aucun constat spécifique renseigné.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // CARD 5: SIGNATURES & VALIDATION
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSignaturesCard(Rapport r) {
    final col1Header = r.laboratoire.isNotEmpty ? r.laboratoire : 'Laboratoire';
    final col1Val = r.sigCol1Value.isNotEmpty ? r.sigCol1Value : '/';

    final col2Header = r.sigCol2Header.isNotEmpty ? r.sigCol2Header : 'Client';
    final col2Val = r.sigCol2Value.isNotEmpty ? r.sigCol2Value : '/';

    final col3Header = r.sigCol3Header.isNotEmpty ? r.sigCol3Header : 'Représentant';
    final col3Val = r.sigCol3Value.isNotEmpty ? r.sigCol3Value : '/';

    final col4Header = r.sigCol4Header.isNotEmpty ? r.sigCol4Header : 'Tierce Partie';
    final col4Val = r.sigCol4Value.isNotEmpty ? r.sigCol4Value : '/';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCardHeader(
                  icon: Icons.draw_rounded,
                  iconColor: AppTheme.primaryNavy,
                  title: 'Signatures & Validation',
                  subtitle: 'Signataires officiels du rapport',
                ),
              ),
              if (r.dateSignature.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_available_rounded, size: 13, color: AppTheme.accentTeal),
                      const SizedBox(width: 4),
                      Text(
                        r.dateSignature,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              final signers = [
                {'role': col1Header, 'name': col1Val, 'icon': Icons.verified_user_rounded, 'color': AppTheme.primaryNavy},
                {'role': col2Header, 'name': col2Val, 'icon': Icons.person_outline_rounded, 'color': AppTheme.accentTeal},
                {'role': col3Header, 'name': col3Val, 'icon': Icons.badge_outlined, 'color': const Color(0xFF6366F1)},
                {'role': col4Header, 'name': col4Val, 'icon': Icons.shield_outlined, 'color': const Color(0xFFD97706)},
              ];

              if (isWide) {
                return Row(
                  children: signers.map((s) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _buildSignerTile(
                        role: s['role'] as String,
                        name: s['name'] as String,
                        icon: s['icon'] as IconData,
                        color: s['color'] as Color,
                      ),
                    ),
                  )).toList(),
                );
              } else {
                return Column(
                  children: signers.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildSignerTile(
                      role: s['role'] as String,
                      name: s['name'] as String,
                      icon: s['icon'] as IconData,
                      color: s['color'] as Color,
                      horizontal: true,
                    ),
                  )).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignerTile({
    required String role,
    required String name,
    required IconData icon,
    required Color color,
    bool horizontal = false,
  }) {
    final bool hasName = name.isNotEmpty && name != '/';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: horizontal
          ? Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role,
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        hasName ? name : '--- (Non assigné)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasName ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasName ? name : '---',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasName ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // CARD 6: CHAMPS PERSONNALISÉS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildCustomFieldsCard(Rapport r) {
    if (r.customFieldsJson.isEmpty || r.customFieldsJson == '{}') {
      return const SizedBox.shrink();
    }
    try {
      final decoded = jsonDecode(r.customFieldsJson);
      if (decoded is! Map) return const SizedBox.shrink();

      final knownSections = {'client', 'caracteristiques', 'ident', 'commande_interne', 'soudage', 'constat', 'signatures', '_labels'};
      final labels = <String, String>{};
      if (decoded['_labels'] is Map) {
        (decoded['_labels'] as Map).forEach((k, v) {
          if (v != null) labels[k.toString()] = v.toString();
        });
      }

      final leftoverEntries = <MapEntry<String, String>>[];
      decoded.forEach((secKey, fields) {
        if (knownSections.contains(secKey) || fields is! Map) return;
        fields.forEach((k, v) {
          final valStr = v?.toString() ?? '';
          if (valStr.trim().isNotEmpty) {
            final label = labels['${secKey}_$k'] ?? labels[k.toString()] ?? k.toString();
            leftoverEntries.add(MapEntry(label, valStr));
          }
        });
      });

      if (leftoverEntries.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(top: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.extension_outlined,
              iconColor: const Color(0xFF6366F1),
              title: 'Autres Informations & Rubriques',
              subtitle: 'Champs additionnels personnalisés',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            ...leftoverEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _infoTile(
                  label: entry.key,
                  value: entry.value,
                  icon: Icons.extension_rounded,
                  fullWidth: true,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }


  Widget _buildSamplesSection(Rapport r, bool isDesktop) {
    if (r.echantillons.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.bgLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.science_outlined, color: AppTheme.textMuted, size: 36),
            ),
            const SizedBox(height: 10),
            const Text(
              'Aucun échantillon enregistré',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ajoutez des photos de macrographie et effectuez vos mesures directement.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RapportFormScreen(rapport: r)),
                );
                _load();
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
              label: const Text('Ajouter des photos & mesures', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.photo_library_outlined,
            iconColor: AppTheme.accentTeal,
            title: 'Échantillons & Analyses Macrographiques (${r.echantillons.length})',
            subtitle: 'Photos, mesures des cordons et métallographie',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          ...r.echantillons.map((e) => _buildSampleCard(e, r)),
        ],
      ),
    );
  }

  Widget _buildSampleCard(Echantillon e, Rapport r) {
    final hasPhoto = e.photoPath != null && File(e.photoPath!).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_rounded, color: AppTheme.accentTeal, size: 16),
                const SizedBox(width: 6),
                Text(
                  e.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                if (r.isCommandeInterne) ...[
                  if (e.typeLot.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e.typeLot,
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (e.grossissement.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e.grossissement,
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ],
            ),
          ),

          // Photo Macro Preview
          GestureDetector(
            onTap: hasPhoto
                ? () {
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(16),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            InteractiveViewer(
                              maxScale: 6.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(e.photoPath!)),
                              ),
                            ),
                            IconButton.filled(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded),
                              style: IconButton.styleFrom(backgroundColor: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                : null,
            child: Container(
              height: 200,
              width: double.infinity,
              color: const Color(0xFF0B0F19),
              child: hasPhoto
                  ? Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Center(
                          child: Image.file(
                            File(e.photoPath!),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen_rounded, color: Colors.white, size: 13),
                              SizedBox(width: 3),
                              Text('Agrandir', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported_outlined, color: Colors.white38, size: 32),
                          SizedBox(height: 4),
                          Text('Pas de photo macrographique', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
            ),
          ),

          // Observation spécifique
          if (e.observation.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFF1F5F9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 14, color: AppTheme.primaryNavy),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Observation : ${e.observation}',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textDark),
                    ),
                  ),
                ],
              ),
            ),

          // Détails Commande Interne
          if (r.isCommandeInterne)
            Builder(
              builder: (context) {
                final gVal = double.tryParse(e.grossissement.replaceAll(' FOIS', '').replaceAll('x', '').replaceAll(',', '.').trim()) ?? 1.8;
                final epReelVal = double.tryParse(e.epReel.replaceAll(',', '.').trim()) ?? 11.0;
                final epPhotoVal = (gVal * epReelVal).toStringAsFixed(2).replaceAll('.', ',');

                return Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Métal de base
                      _buildSubSectionTitle('Métal de Base', Icons.layers_rounded, AppTheme.primaryNavy),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _metricBadge('Nuance', e.metalNuance.isNotEmpty ? e.metalNuance : '---'),
                          _metricBadge('Coulée N°', e.nCoulee.isNotEmpty ? e.nCoulee : '---'),
                          _metricBadge('Bobine N°', e.nBobine.isNotEmpty ? e.nBobine : '---'),
                          _metricBadge('Ø Tube', e.diametreTube.isNotEmpty ? '${e.diametreTube} mm' : '---'),
                          _metricBadge('Ep. Nom./Réel', '${e.epNominale.isNotEmpty ? e.epNominale : "---"} / ${e.epReel.isNotEmpty ? e.epReel : "---"} mm'),
                          _metricBadge('Ep. sur photo', '$epPhotoVal mm', highlight: true),
                          _metricBadge('Fournisseur', e.fournisseur.isNotEmpty ? e.fournisseur : '---'),
                        ],
                      ),

                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFE2E8F0))),

                      // Soudure
                      _buildSubSectionTitle('Mesures Soudure', Icons.precision_manufacturing_rounded, AppTheme.accentTeal),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _metricBadge('N° Tube', e.nTube.isNotEmpty ? e.nTube : '---'),
                          _metricBadge('Surépaisseur (Ext/Int)', '${e.surepExt.isNotEmpty ? e.surepExt : "---"} / ${e.surepInt.isNotEmpty ? e.surepInt : "---"} mm'),
                          _metricBadge('Largeur (Ext/Int)', '${e.largeurExt.isNotEmpty ? e.largeurExt : "---"} / ${e.largeurInt.isNotEmpty ? e.largeurInt : "---"} mm'),
                          _metricBadge('Pénétration (Ext/Int)', '${e.penetrationExt.isNotEmpty ? e.penetrationExt : "---"}% / ${e.penetrationInt.isNotEmpty ? e.penetrationInt : "---"}%'),
                          _metricBadge('Désaxage', e.desaxage.isNotEmpty ? '${e.desaxage} mm' : '0 mm'),
                          _metricBadge('Interpénétration', e.interpenetration.isNotEmpty ? '${e.interpenetration} mm' : '---', highlight: true),
                        ],
                      ),

                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFE2E8F0))),

                      // Paramètres
                      _buildSubSectionTitle('Paramètres de Soudage', Icons.bolt_rounded, const Color(0xFFD97706)),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metricBadge('Vitesse', e.vitesse.isNotEmpty ? '${e.vitesse} m/min' : '---'),
                          _metricBadge('U (Int/Ext)', '${e.uInt.isNotEmpty ? e.uInt : "---"} / ${e.uExt.isNotEmpty ? e.uExt : "---"}'),
                          _metricBadge('I (Int/Ext)', '${e.iInt.isNotEmpty ? e.iInt : "---"} / ${e.iExt.isNotEmpty ? e.iExt : "---"}'),
                          _metricBadge('Fil 1', e.filInt1.isNotEmpty ? e.filInt1 : '---'),
                          _metricBadge('Fil 2', e.filInt2.isNotEmpty ? e.filInt2 : '---'),
                          _metricBadge('Flux', e.flux.isNotEmpty ? e.flux : '---'),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // HELPER WIDGETS & UI COMPONENTS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildCardHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.primaryNavy,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _infoTile({
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
    bool fullWidth = false,
    bool badge = false,
  }) {
    final displayVal = value.trim().isNotEmpty ? value.trim() : '---';
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: iconColor ?? const Color(0xFF64748B)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          if (badge && displayVal != '---')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: (iconColor ?? AppTheme.primaryNavy).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                displayVal,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: iconColor ?? AppTheme.primaryNavy,
                ),
              ),
            )
          else
            Text(
              displayVal,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                color: displayVal == '---' ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
              ),
              maxLines: fullWidth ? 3 : 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _metricBadge(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.accentTeal.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? AppTheme.accentTeal.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10.5)),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: highlight ? AppTheme.accentTeal : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, String>> _getCustomFieldsForSection(Rapport r, String targetSecKey) {
    if (r.customFieldsJson.isEmpty || r.customFieldsJson == '{}') return [];
    try {
      final decoded = jsonDecode(r.customFieldsJson);
      if (decoded is! Map) return [];

      final labels = <String, String>{};
      if (decoded['_labels'] is Map) {
        (decoded['_labels'] as Map).forEach((k, v) {
          if (v != null) labels[k.toString()] = v.toString();
        });
      }

      final fields = decoded[targetSecKey];
      if (fields is! Map) return [];

      final list = <MapEntry<String, String>>[];
      fields.forEach((k, v) {
        final valStr = v?.toString() ?? '';
        if (valStr.trim().isNotEmpty) {
          final label = labels['${targetSecKey}_$k'] ?? labels[k.toString()] ?? k.toString();
          list.add(MapEntry(label, valStr));
        }
      });
      return list;
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // FLOATING BOTTOM ACTION BAR
  // ══════════════════════════════════════════════════════════════════
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Config button
              IconButton(
                onPressed: () => PvConfigDialog.show(
                  context,
                  isPrestation: _rapport != null && !_rapport!.isCommandeInterne,
                ),
                icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Personnaliser les champs',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 6),
              // Edit button
              OutlinedButton.icon(
                onPressed: () async {
                  if (_rapport == null) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RapportFormScreen(rapport: _rapport!)),
                  );
                  _load();
                },
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              const SizedBox(width: 6),
              // Preview PDF button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generating ? null : _previewPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                  label: const Text('Aperçu PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: AppTheme.primaryNavy, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Generate & Share button
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generating ? null : _sharePdf,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                  icon: _generating
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share_rounded, size: 15),
                  label: Text(
                    _generating ? '…' : 'Partager',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PDF Preview Page avec Sélecteur Dynamique V1 / V2 ──────────────────────────

class _PdfPreviewPage extends StatefulWidget {
  final Rapport rapport;
  final AppSettings settings;
  final PvFieldConfig pvConfig;
  final int initialTemplateVersion;

  const _PdfPreviewPage({
    required this.rapport,
    required this.settings,
    required this.pvConfig,
    this.initialTemplateVersion = 2,
  });

  @override
  State<_PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<_PdfPreviewPage> {
  late int _selectedVersion;
  Uint8List? _cachedBytes;
  double _zoomWidth = 700;

  static const double _zoomMin = 350;
  static const double _zoomMax = 1400;
  static const double _zoomStep = 100;

  late PvFieldConfig _pvConfig;

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.initialTemplateVersion;
    _pvConfig = widget.pvConfig;
  }

  Future<Uint8List> _generatePdfBytes() async {
    if (_selectedVersion == 2) {
      _cachedBytes = await PdfServiceModern.generateRapportBytes(
        widget.rapport,
        settings: widget.settings,
        pvConfig: _pvConfig,
      );
    } else {
      _cachedBytes = await PdfService.generateRapportBytes(
        widget.rapport,
        settings: widget.settings,
        pvConfig: _pvConfig,
      );
    }
    return _cachedBytes!;
  }

  String get _safeTitle {
    return widget.rapport.defaultPdfFileName;
  }

  Future<void> _share(BuildContext context) async {
    try {
      final bytes = _cachedBytes ?? await _generatePdfBytes();
      final tempDir = await getTemporaryDirectory();
      final safeName = '$_safeTitle.pdf';
      final file = File('${tempDir.path}/$safeName');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, name: safeName, mimeType: 'application/pdf')],
          text: 'PV N° ${widget.rapport.pvNumero} (${_selectedVersion == 2 ? "Modèle V2 Moderne" : "Modèle V1 Officiel"})',
          subject: 'PV N° ${widget.rapport.pvNumero}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de partage : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final bytes = _cachedBytes ?? await _generatePdfBytes();
      final safeName = '$_safeTitle.pdf';
      final selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choisir le dossier de téléchargement',
      );
      if (selectedDir == null) return;

      final file = File('$selectedDir/$safeName');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('PDF enregistré : ${file.path}')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de téléchargement : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(
          isMobile ? 'V$_selectedVersion · ${widget.rapport.pvNumero}' : 'PV N° ${widget.rapport.pvNumero}',
          style: TextStyle(fontSize: isMobile ? 14 : 16),
        ),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        actions: [
          // Modèle Switcher Toggle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (_selectedVersion != 1) {
                      setState(() {
                        _selectedVersion = 1;
                        _cachedBytes = null;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _selectedVersion == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isMobile ? 'V1' : '📄 V1 (Officiel)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: _selectedVersion == 1 ? AppTheme.primaryNavy : Colors.white,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (_selectedVersion != 2) {
                      setState(() {
                        _selectedVersion = 2;
                        _cachedBytes = null;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _selectedVersion == 2 ? AppTheme.accentTeal : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isMobile ? '✨ V2' : '✨ V2 (Moderne)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: _selectedVersion == 2 ? Colors.white : Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            // ── Zoom controls on Desktop ──
            IconButton(
              icon: const Icon(Icons.zoom_out_rounded),
              tooltip: 'Zoom −',
              onPressed: _zoomWidth > _zoomMin
                  ? () => setState(() => _zoomWidth -= _zoomStep)
                  : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Text(
                '${((_zoomWidth / 700) * 100).round()}%',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded),
              tooltip: 'Zoom +',
              onPressed: _zoomWidth < _zoomMax
                  ? () => setState(() => _zoomWidth += _zoomStep)
                  : null,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'Personnaliser les champs',
            onPressed: () async {
              final newConfig = await PvConfigDialog.show(
                context,
                initialConfig: _pvConfig,
                isPrestation: !widget.rapport.isCommandeInterne,
              );
              if (newConfig != null && mounted) {
                setState(() {
                  _pvConfig = newConfig;
                  _cachedBytes = null;
                });
              }
            },
          ),
          if (!isMobile) ...[
            const VerticalDivider(color: Colors.white24, width: 8),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Télécharger PDF',
              onPressed: () => _downloadPdf(context),
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Partager',
              onPressed: () => _share(context),
            ),
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'Imprimer',
              onPressed: () async {
                final bytes = _cachedBytes ?? await _generatePdfBytes();
                await Printing.layoutPdf(
                  onLayout: (_) async => bytes,
                  name: _safeTitle,
                );
              },
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Options',
              onSelected: (val) async {
                if (val == 'download') {
                  _downloadPdf(context);
                } else if (val == 'share') {
                  _share(context);
                } else if (val == 'print') {
                  final bytes = _cachedBytes ?? await _generatePdfBytes();
                  await Printing.layoutPdf(
                    onLayout: (_) async => bytes,
                    name: _safeTitle,
                  );
                } else if (val == 'zoom_in') {
                  if (_zoomWidth < _zoomMax) setState(() => _zoomWidth += _zoomStep);
                } else if (val == 'zoom_out') {
                  if (_zoomWidth > _zoomMin) setState(() => _zoomWidth -= _zoomStep);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'download',
                  child: Row(children: [Icon(Icons.download_rounded, size: 18, color: AppTheme.primaryNavy), SizedBox(width: 8), Text('Télécharger PDF')]),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(children: [Icon(Icons.share_rounded, size: 18, color: AppTheme.accentTeal), SizedBox(width: 8), Text('Partager')]),
                ),
                const PopupMenuItem(
                  value: 'print',
                  child: Row(children: [Icon(Icons.print_rounded, size: 18, color: Color(0xFF64748B)), SizedBox(width: 8), Text('Imprimer')]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'zoom_in',
                  child: Row(children: [Icon(Icons.zoom_in_rounded, size: 18), SizedBox(width: 8), Text('Zoom +')]),
                ),
                const PopupMenuItem(
                  value: 'zoom_out',
                  child: Row(children: [Icon(Icons.zoom_out_rounded, size: 18), SizedBox(width: 8), Text('Zoom −')]),
                ),
              ],
            ),
          ],
        ],
      ),
      body: PdfPreview(
        key: ValueKey('${_selectedVersion}_${_pvConfig.toMap().values.join()}'),
        build: (_) async => _cachedBytes ?? await _generatePdfBytes(),
        allowPrinting: true,
        allowSharing: true,
        onShared: (ctx) => _share(ctx),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: _zoomWidth,
        pdfFileName: '$_safeTitle.pdf',
        loadingWidget: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Génération du Modèle ${_selectedVersion == 2 ? "V2 (Moderne)" : "V1 (Officiel)"}…',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
