import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/pv_config.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

/// Dialogue de personnalisation hiérarchique des champs PDF
/// Organisé par onglet, par section (avec interrupteur global de section) et par champ individuel.
class PvConfigDialog extends StatefulWidget {
  final PvFieldConfig? initialConfig;
  final ValueChanged<PvFieldConfig>? onConfigSaved;
  final int initialTabIndex;
  final bool isPrestation;

  const PvConfigDialog({
    super.key,
    this.initialConfig,
    this.onConfigSaved,
    this.initialTabIndex = 0,
    this.isPrestation = false,
  });

  static Future<PvFieldConfig?> show(
    BuildContext context, {
    PvFieldConfig? initialConfig,
    ValueChanged<PvFieldConfig>? onSaved,
    int initialTabIndex = 0,
    bool isPrestation = false,
  }) {
    return showDialog<PvFieldConfig>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PvConfigDialog(
        initialConfig: initialConfig,
        onConfigSaved: onSaved,
        initialTabIndex: initialTabIndex,
        isPrestation: isPrestation,
      ),
    );
  }

  @override
  State<PvConfigDialog> createState() => _PvConfigDialogState();
}

class _PvConfigDialogState extends State<PvConfigDialog>
    with SingleTickerProviderStateMixin {
  late PvFieldConfig _config;
  bool _loading = true;
  bool _saving = false;
  late bool _isPrestation;
  late TabController _tabController;
  AppSettings? _appSettings;

  static const _tabs = [
    Tab(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined, size: 13),
          SizedBox(width: 4),
          Text('Identification'),
        ],
      ),
    ),
    Tab(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.handyman_outlined, size: 13),
          SizedBox(width: 4),
          Text('Soudage'),
        ],
      ),
    ),
    Tab(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 13),
          SizedBox(width: 4),
          Text('Échantillons'),
        ],
      ),
    ),
    Tab(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 13),
          SizedBox(width: 4),
          Text('Constat'),
        ],
      ),
    ),
    Tab(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.draw_outlined, size: 13),
          SizedBox(width: 4),
          Text('Signatures'),
        ],
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _isPrestation = widget.isPrestation;
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    SettingsService.instance.getSettings().then((s) {
      if (mounted) setState(() => _appSettings = s);
    });
    if (widget.initialConfig != null) {
      _config = widget.initialConfig!;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await SettingsService.instance.getPvConfig(isPrestation: _isPrestation);
    final s = await SettingsService.instance.getSettings();
    if (mounted) setState(() { _config = cfg; _appSettings = s; _loading = false; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await SettingsService.instance.savePvConfig(_config, isPrestation: _isPrestation);
    if (widget.onConfigSaved != null) widget.onConfigSaved!(_config);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, _config);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isPrestation
            ? '✓ Configuration Prestation enregistrée !'
            : '✓ Configuration Commande Interne enregistrée !'),
        backgroundColor: AppTheme.accentTeal,
      ));
    }
  }

  Future<void> _switchMode(bool newIsPrestation) async {
    if (_isPrestation == newIsPrestation || _saving) return;
    setState(() => _saving = true);
    try {
      // Sauvegarder la configuration courante avant de basculer
      await SettingsService.instance.savePvConfig(_config, isPrestation: _isPrestation);
      // Charger la configuration du nouveau mode sélectionné
      final newCfg = await SettingsService.instance.getPvConfig(isPrestation: newIsPrestation);
      if (mounted) {
        setState(() {
          _isPrestation = newIsPrestation;
          _config = newCfg;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _modeSelectorItem(String label, bool isPrest, IconData icon) {
    final isSelected = _isPrestation == isPrest;
    return InkWell(
      onTap: () => _switchMode(isPrest),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isPrest ? AppTheme.accentTeal : AppTheme.primaryNavy)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setAll(bool value) {
    setState(() {
      _config = PvFieldConfig(
        showPvNumero: value, showDateEmission: value, showDateReception: value, showDateEssai: value,
        showLogo: value, showCompanyHeader: value, showLabInfo: value,
        showDocMeta: value, showDatesBlock: value, showNomClient: value,
        showCoordonneesClient: value, showDimensions: value, showNuance: value,
        showNWps: value, showNPqr: value, showMethodeEssai: value,
        showNbEchantillons: value, showMethodeEchantillonnage: value,
        showSpecificationEssai: value, showProjet: value,
        showDemandeur: value, showNCommandeInterne: value, showDesignationSoudure: value,
        showDateSoudage: value, showAttaqueChimique: value, showMaterielUtilise: value,
        showSoudeurCode: value,
        showSectionSoudage: value, showProcedeSoudage: value,
        showMetalApport: value, showPositionSoudage: value,
        showNJoint: value, showTraitementThermique: value,
        showTableParametres: value, showParamVitesse: value,
        showParamTension: value, showParamCourant: value,
        showParamFils: value, showParamFlux: value,
        showTableMetalBase: value, showMetalNuance: value,
        showNCoulee: value, showNBobine: value, showDiametreTube: value,
        showEpNominale: value, showEpReel: value, showEpSurPhoto: value,
        showFournisseur: value, showTableSoudure: value, showTypeLot: value,
        showGrossissement: value, showNTube: value, showSurepaisseur: value,
        showLargeur: value, showPenetration: value, showDesaxage: value,
        showInterpenetration: value, showDisclaimer: value,
        showSectionTitle: value, showObservation: value,
        showSignatures: value, showFootnotes: value, showPageNumber: value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      );
    }

    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 650;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 24,
        vertical: isMobile ? 12 : 20,
      ),
      backgroundColor: Colors.white,
      child: Container(
        width: isMobile ? double.infinity : 760,
        height: isMobile ? media.size.height * 0.82 : 640,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête ──
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.accentTeal, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Champs à imprimer sur le PDF',
                    style: TextStyle(
                      fontSize: isMobile ? 12.5 : 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
                // Sélecteur de mode interactif (Cmd Interne / Prestation)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _modeSelectorItem('Cmd Interne', false, Icons.business_center_outlined),
                      _modeSelectorItem('Prestation', true, Icons.assignment_outlined),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Actions rapides ──
            Row(
              children: [
                _quickAction('Tout cocher', AppTheme.primaryNavy, () => _setAll(true), isMobile),
                const SizedBox(width: 6),
                _quickAction('Tout décocher', Colors.redAccent, () => _setAll(false), isMobile),
                const Spacer(),
                _quickAction('Défaut', AppTheme.accentTeal,
                    () => setState(() => _config = const PvFieldConfig()), isMobile),
              ],
            ),
            const SizedBox(height: 6),

            // ── Tab bar ──
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppTheme.primaryNavy,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 10),
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3)],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(2),
                tabs: _tabs,
              ),
            ),
            const SizedBox(height: 6),

            // ── Tab content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabIdentification(isMobile),
                  _buildTabSoudageParam(isMobile),
                  _buildTabEchantillons(isMobile),
                  _buildTabConstat(isMobile),
                  _buildTabSignatures(isMobile),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Boutons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Enregistrer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1 — IDENTIFICATION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTabIdentification(bool isMobile) {
    final sec1Active = _config.showPvNumero || _config.showDateEmission || _config.showDateReception || _config.showDateEssai || _config.showLogo || _config.showCompanyHeader || _config.showLabInfo || _config.showDocMeta;
    final sec2Active = _config.showNomClient || _config.showCoordonneesClient || _config.showProjet || _config.showCustomFields;
    final sec3Active = _config.showDimensions || _config.showNuance || _config.showNWps || _config.showNPqr || _config.showMethodeEssai || _config.showMethodeEchantillonnage || _config.showSpecificationEssai;

    return _tabList([
      // 1. Identification du PV & En-tête
      _buildSectionBox(
        title: '1. Identification du PV & En-tête',
        icon: Icons.web_asset_rounded,
        isActive: sec1Active,
        onToggleSection: (val) {
          setState(() {
            _config = _config.copyWith(
              showPvNumero: val,
              showDateEmission: val,
              showDateReception: val,
              showDateEssai: val,
              showLogo: val,
              showCompanyHeader: val,
              showLabInfo: val,
              showDocMeta: val,
              showDatesBlock: val,
            );
          });
        },
        children: [
          _item('N° PV',
              'Numéro de référence du rapport (ex: 01/2026)',
              Icons.tag_rounded, _config.showPvNumero,
              (v) => setState(() => _config = _config.copyWith(showPvNumero: v))),
          _item('Date d\'Émission',
              'Date d\'édition officielle du procès-verbal',
              Icons.event_available_outlined, _config.showDateEmission,
              (v) => setState(() => _config = _config.copyWith(showDateEmission: v))),
          _item('Date de Réception',
              'Date de réception de l\'échantillon au laboratoire',
              Icons.inbox_outlined, _config.showDateReception,
              (v) => setState(() => _config = _config.copyWith(showDateReception: v))),
          _item('Date d\'Essai',
              'Date d\'exécution de l\'examen métallographique',
              Icons.biotech_outlined, _config.showDateEssai,
              (v) => setState(() => _config = _config.copyWith(showDateEssai: v))),
          _item('Logo de l\'entreprise',
              'Affiche le logo personnalisé ou officiel dans le coin supérieur gauche',
              Icons.image_outlined, _config.showLogo,
              (v) => setState(() => _config = _config.copyWith(showLogo: v))),
          _item('En-tête Entreprise & Unité',
              'Nom de la société et nom de l\'unité / laboratoire',
              Icons.business_rounded, _config.showCompanyHeader,
              (v) => setState(() => _config = _config.copyWith(showCompanyHeader: v))),
          _item('Coordonnées & Lieu du Laboratoire',
              'Nom du laboratoire, adresse complète et lieu d\'exécution des essais',
              Icons.location_on_outlined, _config.showLabInfo,
              (v) => setState(() => _config = _config.copyWith(showLabInfo: v))),
          _item('Métadonnées Document (Réf / Version / Date)',
              'Tableau officiel de référence qualité (ex: E10-P.LAB.02, Version 01)',
              Icons.description_outlined, _config.showDocMeta,
              (v) => setState(() => _config = _config.copyWith(showDocMeta: v))),
        ],
      ),

      // 2. Client / Demandeur & Projet
      _buildSectionBox(
        title: '2. Client / Demandeur & Projet',
        icon: Icons.person_outline_rounded,
        isActive: sec2Active,
        onToggleSection: (val) {
          setState(() {
            _config = _config.copyWith(
              showNomClient: val,
              showCoordonneesClient: val,
              showProjet: val,
              showCustomFields: val,
            );
          });
        },
        children: [
          _item('Nom Client / Demandeur',
              'Raison sociale ou nom de l\'entreprise cliente (ex: SONELGAZ, COSIDER...)',
              Icons.person_outline_rounded, _config.showNomClient,
              (v) => setState(() => _config = _config.copyWith(showNomClient: v))),
          _item('Coordonnées / Adresse du Client',
              'Adresse complète, site d\'intervention ou coordonnées du demandeur',
              Icons.apartment_rounded, _config.showCoordonneesClient,
              (v) => setState(() => _config = _config.copyWith(showCoordonneesClient: v))),
          _item('Projet / Bon de Commande (BC)',
              'Intitulé du projet client et référence du bon de commande ou contrat',
              Icons.folder_open_rounded, _config.showProjet,
              (v) => setState(() => _config = _config.copyWith(showProjet: v))),
          _item('Champs Personnalisés (Marché N°, etc.)',
              'Affiche les champs additionnels ajoutés manuellement dans le formulaire (ex: Marché N°, Réf. Spécifique...)',
              Icons.extension_outlined, _config.showCustomFields,
              (v) => setState(() => _config = _config.copyWith(showCustomFields: v))),
        ],
      ),

      // 3. Caractéristiques Techniques
      _buildSectionBox(
        title: '3. Caractéristiques Techniques',
        icon: Icons.tune_rounded,
        isActive: sec3Active,
        onToggleSection: (val) {
          setState(() {
            _config = _config.copyWith(
              showDimensions: val,
              showNuance: val,
              showNWps: val,
              showNPqr: val,
              showMethodeEssai: val,
              showMethodeEchantillonnage: val,
              showSpecificationEssai: val,
            );
          });
        },
        children: [
          _item('Dimensions du Tube (Ø × Épaisseur)',
              'Diamètre extérieur et épaisseur du tube (ex: 406 × 11.10 mm)',
              Icons.straighten_rounded, _config.showDimensions,
              (v) => setState(() => _config = _config.copyWith(showDimensions: v))),
          _item('Nuance Métallurgique',
              'Grade d\'acier du métal de base (ex: X 60 / API 5L Gr. B / Acier au carbone)',
              Icons.category_outlined, _config.showNuance,
              (v) => setState(() => _config = _config.copyWith(showNuance: v))),
          _item('N° WPS (DMOS)',
              'Numéro du descriptif de mode opératoire de soudage',
              Icons.verified_outlined, _config.showNWps,
              (v) => setState(() => _config = _config.copyWith(showNWps: v))),
          _item('N° PQR (QMOS)',
              'Numéro du procès-verbal de qualification de mode opératoire',
              Icons.verified_user_outlined, _config.showNPqr,
              (v) => setState(() => _config = _config.copyWith(showNPqr: v))),
          _item('Méthode d\'Essai',
              'Norme de préparation et d\'attaque macrographique (ex: ISO 17639 / ASTM)',
              Icons.science_outlined, _config.showMethodeEssai,
              (v) => setState(() => _config = _config.copyWith(showMethodeEssai: v))),
          _item('Méthode d\'Échantillonnage',
              'Norme de prélèvement des éprouvettes (ex: ISO 15614-1 / API 5L)',
              Icons.biotech_outlined, _config.showMethodeEchantillonnage,
              (v) => setState(() => _config = _config.copyWith(showMethodeEchantillonnage: v))),
          _item('Spécification d\'Essai',
              'Spécifications et critères d\'acceptation normatifs client',
              Icons.rule_rounded, _config.showSpecificationEssai,
              (v) => setState(() => _config = _config.copyWith(showSpecificationEssai: v))),
        ],
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2 — SOUDAGE & PARAMÈTRES
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTabSoudageParam(bool isMobile) {
    final sec1Active = _config.showSectionSoudage || _config.showProcedeSoudage || _config.showMetalApport || _config.showPositionSoudage || _config.showNJoint || _config.showTraitementThermique;
    final sec2Active = _config.showTableParametres || _config.showParamVitesse || _config.showParamTension || _config.showParamCourant || _config.showParamFils || _config.showParamFlux || _config.showNbEchantillons;

    return _tabList([
      // 1. Soudage & Assemblage
      _buildSectionBox(
        title: '1. Soudage & Assemblage',
        icon: Icons.handyman_outlined,
        isActive: sec1Active,
        onToggleSection: (val) {
          setState(() {
            _config = _config.copyWith(
              showSectionSoudage: val,
              showProcedeSoudage: val,
              showMetalApport: val,
              showPositionSoudage: val,
              showNJoint: val,
              showTraitementThermique: val,
            );
          });
        },
        children: [
          _item('Bloc Général Soudage & Assemblage',
              'Active la section générale de soudage dans le tableau des caractéristiques',
              Icons.handyman_outlined, _config.showSectionSoudage,
              (v) => setState(() => _config = _config.copyWith(showSectionSoudage: v))),
          _item('Procédé de Soudage',
              'Procédé utilisé (ex: SAWH, 141 TIG, 111 SMAW, 135 MAG, 121 SAW)',
              Icons.precision_manufacturing_outlined, _config.showProcedeSoudage,
              (v) => setState(() => _config = _config.copyWith(showProcedeSoudage: v))),
          _item('Métal d\'Apport / Lot',
              'Nuance du fil/électrode et numéro de lot (ex: E 8018 -G H4, ER70S-6)',
              Icons.grain_rounded, _config.showMetalApport,
              (v) => setState(() => _config = _config.copyWith(showMetalApport: v))),
          _item('Position de Soudage',
              'Position normalisée (ex: 5G, 6G, HL-045, PA 1G, PC 2G, PF 3G)',
              Icons.rotate_90_degrees_cw_outlined, _config.showPositionSoudage,
              (v) => setState(() => _config = _config.copyWith(showPositionSoudage: v))),
          _item('N° Joint / Repère',
              'Identification du joint de soudure (ex: Joint W-01, Repère EP-01)',
              Icons.tag_rounded, _config.showNJoint,
              (v) => setState(() => _config = _config.copyWith(showNJoint: v))),
          _item('Traitement Thermique (PWHT)',
              'État thermique après soudage (ex: Brut de soudage, PWHT 620°C (1h))',
              Icons.thermostat_outlined, _config.showTraitementThermique,
              (v) => setState(() => _config = _config.copyWith(showTraitementThermique: v))),
        ],
      ),

      // 3. Paramètres de Soudage (SAW)
      _buildSectionBox(
        title: _isPrestation ? '2. Paramètres de Soudage (SAW)' : '3. Paramètres de Soudage (SAW)',
        icon: Icons.electric_bolt_rounded,
        isActive: sec2Active,
        onToggleSection: (val) {
          setState(() {
            _config = _config.copyWith(
              showTableParametres: val,
              showParamVitesse: val,
              showParamTension: val,
              showParamCourant: val,
              showParamFils: val,
              showParamFlux: val,
              showNbEchantillons: val,
            );
          });
        },
        children: [
          _item('Tableau Paramètres de Soudage',
              'Tableau des paramètres électriques et d\'avance (affiché dans le PDF)',
              Icons.table_chart_outlined, _config.showTableParametres,
              (v) => setState(() => _config = _config.copyWith(showTableParametres: v))),
          _item('Vitesse de Soudage',
              'Vitesse d\'avance du chariot de soudage (ex: 0,9 m/min)',
              Icons.speed_rounded, _config.showParamVitesse,
              (v) => setState(() => _config = _config.copyWith(showParamVitesse: v))),
          _item('Tension d\'Arc (U INT / U EXT)',
              'Tensions en Volts pour passe intérieure et extérieure (ex: 32 V)',
              Icons.electric_bolt_rounded, _config.showParamTension,
              (v) => setState(() => _config = _config.copyWith(showParamTension: v))),
          _item('Courant de Soudage (I INT / I EXT)',
              'Intensités en Ampères pour passes INT et EXT (ex: 630 A / 780 A)',
              Icons.flash_on_rounded, _config.showParamCourant,
              (v) => setState(() => _config = _config.copyWith(showParamCourant: v))),
          _item('Ø et Nuances Fils d\'Apport',
              'Calibres et références des fils de soudage (ex: Ø 3,2mm / 4mm)',
              Icons.linear_scale_rounded, _config.showParamFils,
              (v) => setState(() => _config = _config.copyWith(showParamFils: v))),
          _item('Flux de Soudage',
              'Désignation commerciale et lot du flux minéral (ex: D1FX25376 P223)',
              Icons.grain_rounded, _config.showParamFlux,
              (v) => setState(() => _config = _config.copyWith(showParamFlux: v))),
          _item('Nombre d\'Échantillons',
              'Compteur du nombre total d\'éprouvettes examinées',
              Icons.format_list_numbered_rounded, _config.showNbEchantillons,
              (v) => setState(() => _config = _config.copyWith(showNbEchantillons: v))),
        ],
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 3 — ÉCHANTILLONS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTabEchantillons(bool isMobile) {
    final sec1Active = _config.showSectionTitle || _config.showTypeLot || _config.showGrossissement;
    final sec2Active = _config.showTableMetalBase || _config.showMetalNuance || _config.showFournisseur || _config.showNCoulee || _config.showNBobine || _config.showDiametreTube || _config.showEpNominale || _config.showEpReel || _config.showEpSurPhoto;
    final sec3Active = _config.showTableSoudure || _config.showNTube || _config.showSurepaisseur || _config.showLargeur || _config.showPenetration || _config.showDesaxage || _config.showInterpenetration;

    return _tabList([
      // 1. Titre & Grossissement Photo
      _buildSectionBox(
        title: '1. Titre & Grossissement Photo',
        icon: Icons.photo_camera_outlined,
        isActive: sec1Active,
        onToggleSection: (val) {
          setState(() {
            _config = _config.copyWith(
              showSectionTitle: val,
              showTypeLot: val,
              showGrossissement: val,
            );
          });
        },
        children: [
          _item('Bannière « EXAMEN MACROGRAPHIQUE »',
              'Bandeau gris séparateur au-dessus des photos d\'échantillons',
              Icons.title_rounded, _config.showSectionTitle,
              (v) => setState(() => _config = _config.copyWith(showSectionTitle: v))),
          _item('Type / Lot de Fabrication',
              'Mention du lot de fabrication affiché sous la photo (ex: LOT 27)',
              Icons.badge_outlined, _config.showTypeLot,
              (v) => setState(() => _config = _config.copyWith(showTypeLot: v))),
          _item('Grossissement Optique (G)',
              'Facteur d\'agrandissement de la macrographie affiché sous la photo (ex: 1,8 FOIS)',
              Icons.zoom_in_rounded, _config.showGrossissement,
              (v) => setState(() => _config = _config.copyWith(showGrossissement: v))),
        ],
      ),

      // 2. Métal de Base
      _buildSectionBox(
        title: '2. Métal de Base (par échantillon)',
        icon: Icons.layers_rounded,
        isActive: sec2Active,
        onToggleSection: (val) {
          setState(() {
            _config = _config.copyWith(
              showTableMetalBase: val,
              showMetalNuance: val,
              showFournisseur: val,
              showNCoulee: val,
              showNBobine: val,
              showDiametreTube: val,
              showEpNominale: val,
              showEpReel: val,
              showEpSurPhoto: val,
            );
          });
        },
        children: [
          _item('Tableau Métal de Base',
              'Active le tableau des caractéristiques métallurgiques du tube',
              Icons.table_chart_outlined, _config.showTableMetalBase,
              (v) => setState(() => _config = _config.copyWith(showTableMetalBase: v))),
          _item('Nuance Métal de Base',
              'Grade d\'acier propre à l\'éprouvette (ex: X 60)',
              Icons.category_outlined, _config.showMetalNuance,
              (v) => setState(() => _config = _config.copyWith(showMetalNuance: v))),
          _item('Fournisseur / Fabricant Tôle',
              'Nom de l\'aciérie productrice (ex: TOSYALI)',
              Icons.storefront_outlined, _config.showFournisseur,
              (v) => setState(() => _config = _config.copyWith(showFournisseur: v))),
          _item('N° Coulée Aciérie',
              'Numéro de coulée de l\'acier (ex: 26302120)',
              Icons.tag_rounded, _config.showNCoulee,
              (v) => setState(() => _config = _config.copyWith(showNCoulee: v))),
          _item('N° Bobine / Coil',
              'Numéro d\'identification de la bobine laminée (ex: 2630415233)',
              Icons.rotate_right_rounded, _config.showNBobine,
              (v) => setState(() => _config = _config.copyWith(showNBobine: v))),
          _item('Ø Tube (mm)',
              'Diamètre extérieur en millimètres (ex: 406)',
              Icons.crop_free_rounded, _config.showDiametreTube,
              (v) => setState(() => _config = _config.copyWith(showDiametreTube: v))),
          _item('Épaisseur Nominale (mm)',
              'Épaisseur théorique de commande (ex: 11,10)',
              Icons.straighten_rounded, _config.showEpNominale,
              (v) => setState(() => _config = _config.copyWith(showEpNominale: v))),
          _item('Épaisseur Réelle (mm)',
              'Épaisseur physique mesurée sur la pièce (ex: 11)',
              Icons.height_rounded, _config.showEpReel,
              (v) => setState(() => _config = _config.copyWith(showEpReel: v))),
          _item('Épaisseur sur Photo (mm)',
              'Mesure optique sur tirage pour le calcul de grossissement',
              Icons.photo_size_select_actual_outlined, _config.showEpSurPhoto,
              (v) => setState(() => _config = _config.copyWith(showEpSurPhoto: v))),
        ],
      ),

      // 3. Soudure & Mesures Tube
      _buildSectionBox(
        title: '3. Soudure & Mesures Tube (par échantillon)',
        icon: Icons.architecture_rounded,
        isActive: sec3Active,
        onToggleSection: (val) {
          setState(() {
            _config = _config.copyWith(
              showTableSoudure: val,
              showNTube: val,
              showSurepaisseur: val,
              showLargeur: val,
              showPenetration: val,
              showDesaxage: val,
              showInterpenetration: val,
            );
          });
        },
        children: [
          _item('Tableau Soudure & Cotes',
              'Active le tableau des dimensions géométriques des cordons',
              Icons.table_chart_outlined, _config.showTableSoudure,
              (v) => setState(() => _config = _config.copyWith(showTableSoudure: v))),
          _item('N° Tube Traçabilité',
              'Numéro de série individuel du tube (ex: 1345 G)',
              Icons.fingerprint_rounded, _config.showNTube,
              (v) => setState(() => _config = _config.copyWith(showNTube: v))),
          _item('Surépaisseur de Cordon (EXT & INT)',
              'Hauteur des dômes de soudure extérieur et intérieur (mm)',
              Icons.vertical_align_top_rounded, _config.showSurepaisseur,
              (v) => setState(() => _config = _config.copyWith(showSurepaisseur: v))),
          _item('Largeur des Cordons (EXT & INT)',
              'Largeur transversale des cordons à la surface du tube (mm)',
              Icons.swap_horiz_rounded, _config.showLargeur,
              (v) => setState(() => _config = _config.copyWith(showLargeur: v))),
          _item('Pénétration de Fusion (EXT & INT %)',
              'Profondeur de pénétration en pourcentage de l\'épaisseur',
              Icons.arrow_downward_rounded, _config.showPenetration,
              (v) => setState(() => _config = _config.copyWith(showPenetration: v))),
          _item('Désaxage / Misalignment (mm)',
              'Décalage d\'axe transversal entre passes selon API 5L Fig. 4',
              Icons.compare_arrows_rounded, _config.showDesaxage,
              (v) => setState(() => _config = _config.copyWith(showDesaxage: v))),
          _item('Interpénétration / Recouvrement (mm)',
              'Zone de chevauchement centrale des deux cordons de soudure',
              Icons.merge_type_rounded, _config.showInterpenetration,
              (v) => setState(() => _config = _config.copyWith(showInterpenetration: v))),
        ],
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 4 — CONSTAT
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTabConstat(bool isMobile) {
    final sec1Active = _config.showObservation || _config.showDisclaimer || _config.showFootnotes || _config.showPageNumber;

    return _tabList([
      _buildSectionBox(
        title: '1. Constat & Conclusion',
        icon: Icons.visibility_outlined,
        isActive: sec1Active,
        onToggleSection: (val) {
          setState(() {
            _config = _config.copyWith(
              showObservation: val,
              showDisclaimer: val,
              showFootnotes: val,
              showPageNumber: val,
            );
          });
        },
        children: [
          _item('Observations & Constat de Conformité',
              'Phrase de conclusion métallographique ("L\'examen a relevé une fusion complète...")',
              Icons.comment_outlined, _config.showObservation,
              (v) => setState(() => _config = _config.copyWith(showObservation: v))),
          _item('Mention Légale (Disclaimer)',
              'Avertissement sur la reproduction du rapport et validité des échantillons',
              Icons.info_outline_rounded, _config.showDisclaimer,
              (v) => setState(() => _config = _config.copyWith(showDisclaimer: v))),
          _item('Notes de Bas de Page (Footnotes)',
              'Mentions des personnes autorisant le rapport pour production / qualification',
              Icons.format_list_bulleted_rounded, _config.showFootnotes,
              (v) => setState(() => _config = _config.copyWith(showFootnotes: v))),
          _item('Numérotation de Page (Page X sur Y)',
              'Affiche la pagination dans le coin inférieur droit',
              Icons.numbers_rounded, _config.showPageNumber,
              (v) => setState(() => _config = _config.copyWith(showPageNumber: v))),
        ],
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 5 — SIGNATURES
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTabSignatures(bool isMobile) {
    final s1Name = _appSettings?.cachet1Name.isNotEmpty == true ? _appSettings!.cachet1Name : 'Cachet 1';
    final s2Name = _appSettings?.cachet2Name.isNotEmpty == true ? _appSettings!.cachet2Name : 'Cachet 2';
    final s3Name = _appSettings?.cachet3Name.isNotEmpty == true ? _appSettings!.cachet3Name : 'Cachet 3';

    final bool hasC1 = _appSettings?.cachet1Path != null && _appSettings!.cachet1Path!.isNotEmpty;
    final bool hasC2 = _appSettings?.cachet2Path != null && _appSettings!.cachet2Path!.isNotEmpty;
    final bool hasC3 = _appSettings?.cachet3Path != null && _appSettings!.cachet3Path!.isNotEmpty;

    return _tabList([
      _buildSectionBox(
        title: '1. Tableau des Signatures',
        icon: Icons.draw_rounded,
        isActive: _config.showSignatures,
        onToggleSection: (val) => setState(() => _config = _config.copyWith(showSignatures: val)),
        children: [
          _item('Tableau des Signatures',
              'Colonnes des signataires (Laboratoire, Client, Tierce Partie, etc.)',
              Icons.draw_rounded, _config.showSignatures,
              (v) => setState(() => _config = _config.copyWith(showSignatures: v))),
        ],
      ),
      const SizedBox(height: 12),
      _buildSectionBox(
        title: '2. Cachet / Tampon du Laboratoire',
        icon: Icons.verified_outlined,
        isActive: _config.showSignatures,
        onToggleSection: (_) {},
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Sélectionnez quel cachet apposer dans la zone signature du laboratoire, ou laissez vide pour un tampon manuel :',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ),
          _cachetRadioItem(
            value: 0,
            title: 'Aucun cachet (Case signature vide)',
            subtitle: 'Pour signature ou tamponnage manuel après impression',
            icon: Icons.block_flipped,
            isConfigured: true,
          ),
          _cachetRadioItem(
            value: 1,
            title: 'Cachet N°1 — $s1Name',
            subtitle: hasC1 ? '✓ Image prête' : 'Non configuré (Définir dans Paramètres)',
            icon: Icons.verified_rounded,
            isConfigured: hasC1,
          ),
          _cachetRadioItem(
            value: 2,
            title: 'Cachet N°2 — $s2Name',
            subtitle: hasC2 ? '✓ Image prête' : 'Non configuré (Définir dans Paramètres)',
            icon: Icons.verified_rounded,
            isConfigured: hasC2,
          ),
          _cachetRadioItem(
            value: 3,
            title: 'Cachet N°3 — $s3Name',
            subtitle: hasC3 ? '✓ Image prête' : 'Non configuré (Définir dans Paramètres)',
            icon: Icons.verified_rounded,
            isConfigured: hasC3,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.accentTeal),
                SizedBox(width: 6),
                Text('Structure des signatures',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy)),
              ],
            ),
            SizedBox(height: 8),
            Text('• Tableau de signatures dynamique à 4 colonnes modifiables :',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
            SizedBox(height: 4),
            Text('  1. Laboratoire (ex: Laboratoire EM / EEM)',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            SizedBox(height: 3),
            Text('  2. Client / Demandeur',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            SizedBox(height: 3),
            Text('  3. Représentant / Entreprise (ex: Cosider)',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            SizedBox(height: 3),
            Text('  4. Tierce Partie / Autorités de Contrôle',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            SizedBox(height: 4),
            Text('• Les titres et noms des signataires sont 100% personnalisables dans le formulaire.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    ]);
  }

  Widget _cachetRadioItem({
    required int value,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isConfigured,
  }) {
    final bool isSelected = _config.selectedCachet == value;
    return InkWell(
      onTap: () {
        setState(() {
          _config = _config.copyWith(selectedCachet: value);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentTeal.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accentTeal : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppTheme.accentTeal : AppTheme.textMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: isSelected ? AppTheme.accentTeal : AppTheme.primaryNavy),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isConfigured ? (isSelected ? AppTheme.accentTeal : AppTheme.textMuted) : Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS & WIDGETS
  // ═══════════════════════════════════════════════════════════════
  Widget _tabList(List<Widget> children) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      children: children,
    );
  }

  Widget _buildSectionBox({
    required String title,
    required IconData icon,
    required bool isActive,
    required ValueChanged<bool> onToggleSection,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppTheme.accentTeal.withValues(alpha: 0.35) : AppTheme.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header with Master Section Switch
          InkWell(
            onTap: () => onToggleSection(!isActive),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.accentTeal.withValues(alpha: 0.08)
                    : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: isActive ? AppTheme.accentTeal : AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isActive ? AppTheme.primaryNavy : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    isActive ? 'Actif' : 'Masqué',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppTheme.accentTeal : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.65,
                    child: Switch.adaptive(
                      value: isActive,
                      onChanged: onToggleSection,
                      activeColor: AppTheme.accentTeal,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          // Sub items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(String label, Color color, VoidCallback onTap, bool isMobile) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            )),
      ),
    );
  }

  Widget _item(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: value ? AppTheme.accentTeal : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: value ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Transform.scale(
              scale: 0.62,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.accentTeal,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
