import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../services/backup_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pv_config_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  bool _saving = false;
  bool _isBackingUp = false;

  late TextEditingController _companyCtrl;
  late TextEditingController _uniteCtrl;
  late TextEditingController _labNameCtrl;
  late TextEditingController _labAddressCtrl;
  late TextEditingController _labLieuCtrl;
  late TextEditingController _docRefCtrl;
  late TextEditingController _docVersionCtrl;
  late TextEditingController _docDateCtrl;
  late TextEditingController _docRefInterneCtrl;
  late TextEditingController _docVersionInterneCtrl;
  late TextEditingController _docDateInterneCtrl;
  late TextEditingController _footNote1Ctrl;
  late TextEditingController _footNote2Ctrl;
  late TextEditingController _defaultObsCtrl;
  late TextEditingController _cachet1NameCtrl;
  late TextEditingController _cachet2NameCtrl;
  late TextEditingController _cachet3NameCtrl;

  @override
  void initState() {
    super.initState();
    _companyCtrl = TextEditingController();
    _uniteCtrl = TextEditingController();
    _labNameCtrl = TextEditingController();
    _labAddressCtrl = TextEditingController();
    _labLieuCtrl = TextEditingController();
    _docRefCtrl = TextEditingController();
    _docVersionCtrl = TextEditingController();
    _docDateCtrl = TextEditingController();
    _docRefInterneCtrl = TextEditingController();
    _docVersionInterneCtrl = TextEditingController();
    _docDateInterneCtrl = TextEditingController();
    _footNote1Ctrl = TextEditingController();
    _footNote2Ctrl = TextEditingController();
    _defaultObsCtrl = TextEditingController();
    _cachet1NameCtrl = TextEditingController();
    _cachet2NameCtrl = TextEditingController();
    _cachet3NameCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final s = await SettingsService.instance.getSettings();
    setState(() {
      _settings = s;
      _companyCtrl.text = s.companyName;
      _uniteCtrl.text = s.uniteName;
      _labNameCtrl.text = s.labName;
      _labAddressCtrl.text = s.labAddress;
      _labLieuCtrl.text = s.labLieu;
      _docRefCtrl.text = s.docRef;
      _docVersionCtrl.text = s.docVersion;
      _docDateCtrl.text = s.docDate;
      _docRefInterneCtrl.text = s.docRefInterne;
      _docVersionInterneCtrl.text = s.docVersionInterne;
      _docDateInterneCtrl.text = s.docDateInterne;
      _footNote1Ctrl.text = s.footNote1;
      _footNote2Ctrl.text = s.footNote2;
      _defaultObsCtrl.text = s.defaultObservation;
      _cachet1NameCtrl.text = s.cachet1Name;
      _cachet2NameCtrl.text = s.cachet2Name;
      _cachet3NameCtrl.text = s.cachet3Name;
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _companyCtrl,
      _uniteCtrl,
      _labNameCtrl,
      _labAddressCtrl,
      _labLieuCtrl,
      _docRefCtrl,
      _docVersionCtrl,
      _docDateCtrl,
      _docRefInterneCtrl,
      _docVersionInterneCtrl,
      _docDateInterneCtrl,
      _footNote1Ctrl,
      _footNote2Ctrl,
      _defaultObsCtrl,
      _cachet1NameCtrl,
      _cachet2NameCtrl,
      _cachet3NameCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 90,
    );
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final brandingDir = Directory(p.join(appDir.path, 'branding'));
    if (!await brandingDir.exists()) {
      await brandingDir.create(recursive: true);
    }
    final ext = p.extension(picked.path);
    final newPath = p.join(
      brandingDir.path,
      'logo_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(picked.path).copy(newPath);

    setState(() {
      _settings = _settings.copyWith(logoPath: newPath);
    });
  }

  void _showLogoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.primaryNavy),
                title: const Text('Prendre une photo du logo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickLogo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppTheme.accentTeal),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickLogo(ImageSource.gallery);
                },
              ),
              if (_settings.logoPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  title: const Text('Retirer le logo',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _settings = _settings.copyWith(clearLogo: true);
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _pickCachet(int index, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 90,
    );
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final brandingDir = Directory(p.join(appDir.path, 'branding'));
    if (!await brandingDir.exists()) {
      await brandingDir.create(recursive: true);
    }
    final ext = p.extension(picked.path);
    final newPath = p.join(
      brandingDir.path,
      'cachet_${index}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(picked.path).copy(newPath);

    setState(() {
      if (index == 1) {
        _settings = _settings.copyWith(cachet1Path: newPath);
      } else if (index == 2) {
        _settings = _settings.copyWith(cachet2Path: newPath);
      } else if (index == 3) {
        _settings = _settings.copyWith(cachet3Path: newPath);
      }
    });
  }

  void _showCachetSourceSheet(int index) {
    final String? currentPath = index == 1
        ? _settings.cachet1Path
        : (index == 2 ? _settings.cachet2Path : _settings.cachet3Path);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.primaryNavy),
                title: Text('Prendre une photo du Cachet $index'),
                onTap: () {
                  Navigator.pop(context);
                  _pickCachet(index, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppTheme.accentTeal),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickCachet(index, ImageSource.gallery);
                },
              ),
              if (currentPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  title: Text('Retirer le Cachet $index',
                      style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      if (index == 1) _settings = _settings.copyWith(clearCachet1: true);
                      if (index == 2) _settings = _settings.copyWith(clearCachet2: true);
                      if (index == 3) _settings = _settings.copyWith(clearCachet3: true);
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = _settings.copyWith(
      companyName: _companyCtrl.text.trim(),
      uniteName: _uniteCtrl.text.trim(),
      labName: _labNameCtrl.text.trim(),
      labAddress: _labAddressCtrl.text.trim(),
      labLieu: _labLieuCtrl.text.trim(),
      docRef: _docRefCtrl.text.trim(),
      docVersion: _docVersionCtrl.text.trim(),
      docDate: _docDateCtrl.text.trim(),
      docRefInterne: _docRefInterneCtrl.text.trim(),
      docVersionInterne: _docVersionInterneCtrl.text.trim(),
      docDateInterne: _docDateInterneCtrl.text.trim(),
      footNote1: _footNote1Ctrl.text.trim(),
      footNote2: _footNote2Ctrl.text.trim(),
      defaultObservation: _defaultObsCtrl.text.trim(),
      cachet1Name: _cachet1NameCtrl.text.trim(),
      cachet2Name: _cachet2NameCtrl.text.trim(),
      cachet3Name: _cachet3NameCtrl.text.trim(),
    );
    await SettingsService.instance.saveSettings(updated);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Paramètres enregistrés avec succès'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isBackingUp = true);
    final res = await BackupService.instance.createBackupAndShare();
    if (mounted) {
      setState(() => _isBackingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? (res.success ? 'Sauvegarde effectuée !' : 'Échec de la sauvegarde.')),
          backgroundColor: res.success ? AppTheme.accentTeal : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Restauration des données'),
          ],
        ),
        content: const Text(
          'Importer une sauvegarde ajoutera ou mettra à jour tous les PVs, photos et paramètres contenus dans le fichier sélectionné.\n\nVoulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
            child: const Text('Sélectionner le fichier'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isBackingUp = true);
    final res = await BackupService.instance.importBackupFromFile();
    if (mounted) {
      setState(() => _isBackingUp = false);
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? (res.success ? 'Restauration réussie !' : 'Échec de la restauration.')),
          backgroundColor: res.success ? AppTheme.accentTeal : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentTeal)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          'Paramètres du Laboratoire',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saving
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentTeal),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Hero Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.tune_rounded, color: AppTheme.accentTeal, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuration Globale',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Personnalisez l\'identité, le logo, les tampons et les mentions pour l\'ensemble des rapports PDF.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // PV Customization Card (Champs à cocher / décocher)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentTeal.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.checklist_rtl_rounded, color: AppTheme.accentTeal, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Champs du Procès-Verbal (PV)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Afficher ou masquer les rubriques selon vos normes (En-tête, soudure, base...).',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => PvConfigDialog.show(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Logo Card
          _buildCardSection(
            title: 'Logo du Laboratoire',
            icon: Icons.image_outlined,
            iconColor: const Color(0xFF0284C7),
            children: [
              const Text(
                'Ce logo figurera dans l\'en-tête officiel de chaque procès-verbal exporté.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: _showLogoSourceSheet,
                  child: Container(
                    width: 200,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _settings.logoPath != null ? AppTheme.accentTeal : const Color(0xFFCBD5E1),
                        width: _settings.logoPath != null ? 2 : 1.2,
                      ),
                    ),
                    child: _settings.logoPath != null && File(_settings.logoPath!).existsSync()
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(_settings.logoPath!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 34, color: Color(0xFF94A3B8)),
                              SizedBox(height: 6),
                              Text(
                                'Importer le logo',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'PNG, JPG recommandé',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              if (_settings.logoPath != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: _showLogoSourceSheet,
                        icon: const Icon(Icons.sync_rounded, size: 15, color: AppTheme.accentTeal),
                        label: const Text('Changer', style: TextStyle(color: AppTheme.accentTeal, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _settings = _settings.copyWith(clearLogo: true);
                          });
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red),
                        label: const Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Cachets des Ingénieurs (3 Max)
          _buildCardSection(
            title: 'Tampons & Cachets des Ingénieurs (3 Max)',
            icon: Icons.verified_outlined,
            iconColor: const Color(0xFF0D9488),
            children: [
              const Text(
                'Enregistrez les cachets officiels avec les noms des signataires (ex: Ingénieur Essais, Responsable Labo).',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _buildCachetSlot(1, _settings.cachet1Path, _cachet1NameCtrl),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
              _buildCachetSlot(2, _settings.cachet2Path, _cachet2NameCtrl),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
              _buildCachetSlot(3, _settings.cachet3Path, _cachet3NameCtrl),
            ],
          ),

          const SizedBox(height: 16),

          // Identité société
          _buildCardSection(
            title: 'Identité de l\'Entreprise',
            icon: Icons.business_rounded,
            iconColor: const Color(0xFF4F46E5),
            children: [
              _field(_companyCtrl, 'Nom de l\'Entreprise / Société', hint: 'ex: EPE ANABIB SPA', icon: Icons.apartment_rounded),
              _field(_uniteCtrl, 'Unité / Division', hint: 'ex: UNITE ALTUMET', icon: Icons.store_mall_directory_outlined),
            ],
          ),

          const SizedBox(height: 16),

          // Laboratoire
          _buildCardSection(
            title: 'Laboratoire d\'Essais',
            icon: Icons.science_rounded,
            iconColor: const Color(0xFF0284C7),
            children: [
              _field(_labNameCtrl, 'Nom officiel du Laboratoire', hint: 'ex: LABORATOIRE D\'ESSAIS MECANIQUES', maxLines: 2, icon: Icons.biotech_rounded),
              _field(_labAddressCtrl, 'Adresse du Laboratoire', hint: 'ex: Zone Industrielle, BP 123, Alger', maxLines: 2, icon: Icons.place_outlined),
              _field(_labLieuCtrl, "Lieu d'exécution des essais", hint: 'ex: Laboratoire Usine', icon: Icons.pin_drop_outlined),
            ],
          ),

          const SizedBox(height: 16),

          // Référence document PDF
          _buildCardSection(
            title: 'Références Documents (Prestation)',
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFFEA580C),
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(_docRefCtrl, 'Code Réf. Document', hint: 'ex: E10-P.LAB.02', icon: Icons.tag_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _field(_docVersionCtrl, 'Version', hint: 'ex: 01', icon: Icons.numbers_rounded),
                  ),
                ],
              ),
              _field(_docDateCtrl, 'Date d\'application du document', hint: 'ex: 03/04/2024', icon: Icons.event_note_rounded),
            ],
          ),

          const SizedBox(height: 16),

          // Référence document CMD INTERNE
          _buildCardSection(
            title: 'Références Documents (Commande Interne)',
            icon: Icons.build_circle_outlined,
            iconColor: AppTheme.accentTeal,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(_docRefInterneCtrl, 'Code Réf. Interne', hint: 'ex: LAB-INT-01', icon: Icons.tag_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _field(_docVersionInterneCtrl, 'Version', hint: 'ex: 01', icon: Icons.numbers_rounded),
                  ),
                ],
              ),
              _field(_docDateInterneCtrl, 'Date du document Interne', hint: 'ex: 01/01/2024', icon: Icons.event_note_rounded),
            ],
          ),

          const SizedBox(height: 16),

          // Constat par défaut
          _buildCardSection(
            title: 'Observation & Constat par Défaut',
            icon: Icons.visibility_outlined,
            iconColor: const Color(0xFFD97706),
            children: [
              _field(
                _defaultObsCtrl,
                'Texte de constat par défaut pré-rempli dans les nouveaux PV',
                hint: 'ex: Absence de défauts macrographiques notables...',
                maxLines: 3,
                icon: Icons.edit_note_rounded,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Mentions bas de page
          _buildCardSection(
            title: 'Mentions Légales Bas de Page PDF',
            icon: Icons.notes_rounded,
            iconColor: const Color(0xFF64748B),
            children: [
              _field(_footNote1Ctrl, 'Mention de bas de page 1', hint: 'ex: Ce rapport ne concerne que les échantillons soumis aux essais.', maxLines: 2, icon: Icons.info_outline_rounded),
              _field(_footNote2Ctrl, 'Mention de bas de page 2', hint: 'ex: Reproduction interdite sans accord écrit du laboratoire.', maxLines: 2, icon: Icons.lock_outline_rounded),
            ],
          ),

          const SizedBox(height: 16),

          // Sauvegarde & Restauration
          _buildCardSection(
            title: 'Sauvegarde & Transfert des Données',
            icon: Icons.sync_rounded,
            iconColor: AppTheme.primaryNavy,
            children: [
              const Text(
                'Exportez l\'intégralité des données (clients, PVs, mesures, photos, configurations) au format JSON pour sauvegarde ou changement d\'ordinateur.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isBackingUp ? null : _exportBackup,
                      icon: _isBackingUp
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.file_upload_outlined, size: 18),
                      label: Text(_isBackingUp ? 'Exportation…' : 'Exporter (.json)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isBackingUp ? null : _importBackup,
                      icon: const Icon(Icons.file_download_outlined, size: 18, color: AppTheme.accentTeal),
                      label: const Text('Importer (.json)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Main Save Button
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Enregistrement en cours…' : 'Enregistrer toutes les modifications', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),

          const SizedBox(height: 24),

          // About & Engineering Card
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.engineering_rounded,
                    color: Color(0xFFF59E0B),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Application Macrographique',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Créé par Ingénieur Tahar AYATI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Laboratoire d\'Essais Mécaniques — Version 1.2.1',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
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
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    Color iconColor = AppTheme.primaryNavy,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCachetSlot(int index, String? path, TextEditingController nameCtrl) {
    final bool hasImage = path != null && File(path).existsSync();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showCachetSourceSheet(index),
          child: Container(
            width: 110,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? AppTheme.accentTeal : const Color(0xFFCBD5E1),
                width: hasImage ? 1.8 : 1.2,
              ),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(File(path), fit: BoxFit.contain),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined, size: 24, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 4),
                      Text(
                        'Cachet $index',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Cachet N°$index',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasImage)
                    const Text('✓ Prêt', style: TextStyle(fontSize: 11, color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom du signataire / Rôle',
                  hintText: 'Ex: Ing. AYATI Tahar',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
                  ),
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _showCachetSourceSheet(index),
                    icon: Icon(hasImage ? Icons.edit_rounded : Icons.add_circle_outline, size: 14, color: AppTheme.accentTeal),
                    label: Text(hasImage ? 'Changer' : 'Importer image', style: const TextStyle(fontSize: 11.5, color: AppTheme.accentTeal, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 14),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        if (index == 1) _settings = _settings.copyWith(clearCachet1: true);
                        if (index == 2) _settings = _settings.copyWith(clearCachet2: true);
                        if (index == 3) _settings = _settings.copyWith(clearCachet3: true);
                      }),
                      icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                      label: const Text('Retirer', style: TextStyle(fontSize: 11.5, color: Colors.red)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF94A3B8)) : null,
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      ),
    );
  }
}
