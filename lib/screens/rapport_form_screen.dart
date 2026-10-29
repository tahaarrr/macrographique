import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/client.dart';
import '../models/echantillon.dart';
import '../models/pv_config.dart';
import '../models/rapport.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pv_config_dialog.dart';
import 'photo_measure_screen.dart';

class RapportFormScreen extends StatefulWidget {
  final Rapport? rapport; // null = création, non-null = édition
  final String? initialClientName;
  final String? initialClientAddress;
  final String? initialTypeRapport;
  final Rapport? copyFromRapport;

  const RapportFormScreen({
    super.key,
    this.rapport,
    this.copyFromRapport,
    this.initialClientName,
    this.initialClientAddress,
    this.initialTypeRapport,
  });

  @override
  State<RapportFormScreen> createState() => _RapportFormScreenState();
}

class _RapportFormScreenState extends State<RapportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  late TextEditingController _pvNumeroCtrl;
  late TextEditingController _dateReceptionCtrl;
  late TextEditingController _dateEmissionCtrl;
  late TextEditingController _dateEssaiCtrl;
  late TextEditingController _nomClientCtrl;
  late TextEditingController _coordonneesClientCtrl;
  late TextEditingController _dimensionsCtrl;
  late TextEditingController _nuanceCtrl;
  late TextEditingController _nWpsCtrl;
  late TextEditingController _nPqrCtrl;
  late TextEditingController _methodeEssaiCtrl;
  late TextEditingController _methodeEchantillonnageCtrl;
  late TextEditingController _specificationEssaiCtrl;
  late TextEditingController _projetCtrl;
  late TextEditingController _observationCtrl;
  late TextEditingController _dateSignatureCtrl;
  late TextEditingController _laboratoireCtrl;
  late TextEditingController _sigCol1ValueCtrl; // Nom signataire laboratoire
  // Dynamic signature table columns
  late TextEditingController _sigCol2HeaderCtrl;
  late TextEditingController _sigCol2ValueCtrl;
  late TextEditingController _sigCol3HeaderCtrl;
  late TextEditingController _sigCol3ValueCtrl;
  late TextEditingController _sigCol4HeaderCtrl;
  late TextEditingController _sigCol4ValueCtrl;

  late String _typeRapport;

  late TextEditingController _demandeurCtrl;
  late TextEditingController _nCommandeInterneCtrl;
  late TextEditingController _designationSoudureCtrl;
  late TextEditingController _dateSoudageCtrl;
  late TextEditingController _procedeSoudageCtrl;
  late TextEditingController _metalApportCtrl;
  late TextEditingController _positionSoudageCtrl;
  late TextEditingController _nJointCtrl;
  late TextEditingController _traitementThermiqueCtrl;
  late TextEditingController _soudeurCodeCtrl;
  late TextEditingController _attaqueChimiqueCtrl;
  late TextEditingController _materielUtiliseCtrl;

  // Signatures CMD INTERNE
  late TextEditingController _sigInterneOperateurCtrl;
  late TextEditingController _sigInterneVerificateurCtrl;
  late TextEditingController _sigInterneChefCtrl;

  List<Echantillon> _echantillons = [];
  List<TextEditingController> _obsControllers = [];
  List<Map<String, TextEditingController>> _sampleControllers = [];
  List<ClientModel> _existingClients = [];
  bool _saving = false;

  // Two-step auto-fill: client chip → project chips
  String? _selectedClientForProject;
  List<Rapport> _clientProjects = [];

  // PDF layout options
  int _photosPerRow = 2;       // 2 or 4 photos per line (prestation only)
  int _photoHeightPdf = 140;   // Photo height in PDF (px)

  // PV Field configuration (synchronized with PvConfigDialog)
  PvFieldConfig _pvConfig = const PvFieldConfig();

  // Dynamic custom fields added by user per section (sectionKey -> fieldLabel -> controller)
  final Map<String, Map<String, TextEditingController>> _customFieldControllers = {};

  // Custom renamed labels for fields (fieldKey -> customTitle)
  final Map<String, String> _customLabels = {};

  // Wizard step navigation
  int _currentStep = 0;
  static const int _totalSteps = 5;
  late final PageController _pageController;

  Map<String, TextEditingController> _createSampleControllers(Echantillon e) {
    return {
      'vitesse': TextEditingController(text: e.vitesse),
      'uInt': TextEditingController(text: e.uInt),
      'uExt': TextEditingController(text: e.uExt),
      'iInt': TextEditingController(text: e.iInt),
      'iExt': TextEditingController(text: e.iExt),
      'filInt1': TextEditingController(text: e.filInt1),
      'filInt2': TextEditingController(text: e.filInt2),
      'flux': TextEditingController(text: e.flux),
      'typeLot': TextEditingController(text: e.typeLot),
      'grossissement': TextEditingController(text: e.grossissement),
      'metalNuance': TextEditingController(text: e.metalNuance),
      'nCoulee': TextEditingController(text: e.nCoulee),
      'nBobine': TextEditingController(text: e.nBobine),
      'diametreTube': TextEditingController(text: e.diametreTube),
      'epNominale': TextEditingController(text: e.epNominale),
      'epReel': TextEditingController(text: e.epReel),
      'fournisseur': TextEditingController(text: e.fournisseur),
      'nTube': TextEditingController(text: e.nTube),
      'surepExt': TextEditingController(text: e.surepExt),
      'surepInt': TextEditingController(text: e.surepInt),
      'largeurExt': TextEditingController(text: e.largeurExt),
      'largeurInt': TextEditingController(text: e.largeurInt),
      'penetrationExt': TextEditingController(text: e.penetrationExt),
      'penetrationInt': TextEditingController(text: e.penetrationInt),
      'desaxage': TextEditingController(text: e.desaxage),
      'interpenetration': TextEditingController(text: e.interpenetration),
    };
  }

  bool get _isEditing => widget.rapport != null;

  static const List<String> _observationPresets = [
    "L'examen macrographique a relevé une fusion complète et une bonne interpénétration des passes de soudure.",
    "L'examen macrographique met en évidence un cordon de soudure régulier, sans porosité ni fissure décelable.",
    "L'examen macrographique ne présente aucun défaut majeur, assemblage conforme à la spécification.",
    "Assemblage soudé présentant une bonne mouillabilité et une pénétration satisfaisante sur l'ensemble de la coupe.",
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    final r = widget.rapport ?? widget.copyFromRapport;
    final isClone = widget.copyFromRapport != null;
    final today = _dateFormat.format(DateTime.now());

    _pvNumeroCtrl = TextEditingController(text: widget.rapport?.pvNumero ?? '');
    _dateReceptionCtrl =
        TextEditingController(text: r?.dateReception ?? today);
    _dateEmissionCtrl = TextEditingController(text: r?.dateEmission ?? today);
    _dateEssaiCtrl = TextEditingController(text: r?.dateEssai ?? today);
    _nomClientCtrl = TextEditingController(
      text: r?.nomClient ?? widget.initialClientName ?? '',
    );
    _coordonneesClientCtrl = TextEditingController(
      text: r?.coordonneesClient ?? widget.initialClientAddress ?? '',
    );
    _dimensionsCtrl = TextEditingController(text: r?.dimensions ?? '10');
    _nuanceCtrl = TextEditingController(text: r?.nuance ?? 'Acier au carbone');
    _nWpsCtrl = TextEditingController(text: r?.nWps ?? '');
    _nPqrCtrl = TextEditingController(text: r?.nPqr ?? 'A QUALIFIER');
    _methodeEssaiCtrl = TextEditingController(text: r?.methodeEssai ?? '/');
    _methodeEchantillonnageCtrl = TextEditingController(
      text: r?.methodeEchantillonnage ?? 'ISO15614-1',
    );
    _specificationEssaiCtrl =
        TextEditingController(text: r?.specificationEssai ?? '/');
    _projetCtrl = TextEditingController(text: r?.projet ?? '/');
    _observationCtrl = TextEditingController(text: r?.observation ?? '');
    _dateSignatureCtrl =
        TextEditingController(text: r?.dateSignature ?? today);
    _laboratoireCtrl =
        TextEditingController(text: r?.laboratoire ?? 'EM');
    _sigCol1ValueCtrl = TextEditingController(
      text: r?.sigCol1Value ?? '',
    );
    _sigCol2HeaderCtrl = TextEditingController(
      text: r?.sigCol2Header ?? '',
    );
    _sigCol2ValueCtrl = TextEditingController(
      text: r?.sigCol2Value ?? '',
    );
    _sigCol3HeaderCtrl = TextEditingController(
      text: r?.sigCol3Header ?? '',
    );
    _sigCol3ValueCtrl = TextEditingController(
      text: r?.sigCol3Value ?? '',
    );
    _sigCol4HeaderCtrl = TextEditingController(
      text: r?.sigCol4Header ?? '',
    );
    _sigCol4ValueCtrl = TextEditingController(
      text: r?.sigCol4Value ?? '',
    );

    final initialClientLower = (widget.rapport?.nomClient ?? widget.initialClientName ?? '').toLowerCase();
    final isSonelgaz = initialClientLower.contains('sonelgaz') ||
        initialClientLower.contains('sonalgaz') ||
        initialClientLower.contains('transport gaz');

    _typeRapport = r?.typeRapport ?? (widget.initialTypeRapport ?? (isSonelgaz ? 'commande_interne' : 'prestation'));
    _photosPerRow = r?.photosPerRow ?? 2;
    _photoHeightPdf = r?.photoHeightPdf ?? 140;

    _demandeurCtrl = TextEditingController(text: r?.demandeur ?? '');
    _nCommandeInterneCtrl = TextEditingController(text: r?.nCommandeInterne ?? '');
    _designationSoudureCtrl = TextEditingController(text: r?.designationSoudure ?? '');
    _dateSoudageCtrl = TextEditingController(text: r?.dateSoudage ?? today);
    _procedeSoudageCtrl = TextEditingController(text: r?.procedeSoudage ?? '');
    _metalApportCtrl = TextEditingController(text: r?.metalApport ?? '');
    _positionSoudageCtrl = TextEditingController(text: r?.positionSoudage ?? '');
    _nJointCtrl = TextEditingController(text: r?.nJoint ?? '');
    _traitementThermiqueCtrl = TextEditingController(text: r?.traitementThermique ?? '');
    _soudeurCodeCtrl = TextEditingController(text: r?.soudeurCode ?? '');
    _attaqueChimiqueCtrl = TextEditingController(text: r?.attaqueChimique ?? '');
    _materielUtiliseCtrl = TextEditingController(text: r?.materielUtilise ?? '');

    _sigInterneOperateurCtrl = TextEditingController(text: r?.sigInterneOperateur ?? '');
    _sigInterneVerificateurCtrl = TextEditingController(text: r?.sigInterneVerificateur ?? '');
    _sigInterneChefCtrl = TextEditingController(text: r?.sigInterneChef ?? '');

    // Load dynamic custom fields and custom labels from JSON
    try {
      final rawCustom = r?.customFieldsJson;
      if (rawCustom != null && rawCustom.isNotEmpty && rawCustom != '{}') {
        final decoded = jsonDecode(rawCustom);
        if (decoded is Map) {
          decoded.forEach((secKey, fields) {
            if (secKey == '_labels' && fields is Map) {
              fields.forEach((k, v) {
                if (v != null && v.toString().isNotEmpty) {
                  _customLabels[k.toString()] = v.toString();
                }
              });
            } else if (fields is Map) {
              _customFieldControllers[secKey.toString()] = {};
              fields.forEach((k, v) {
                _customFieldControllers[secKey.toString()]![k.toString()] =
                    TextEditingController(text: v?.toString() ?? '');
              });
            }
          });
        }
      }
    } catch (_) {}

    if (r != null && r.echantillons.isNotEmpty) {
      _echantillons = r.echantillons
          .map((e) => e.copyWith(id: isClone ? null : e.id, rapportId: isClone ? null : e.rapportId, photoPath: isClone ? null : e.photoPath))
          .toList();
    } else {
      _echantillons = [
        Echantillon(numero: 1),
        Echantillon(numero: 2),
      ];
    }

    _obsControllers = _echantillons
        .map((e) => TextEditingController(text: e.observation))
        .toList();

    _sampleControllers = _echantillons
        .map((e) => _createSampleControllers(e))
        .toList();

    if (!_isEditing) {
      _nomClientCtrl.addListener(() {
        final text = _nomClientCtrl.text.toLowerCase().trim();
        if (text.contains('sonelgaz') || text.contains('sonalgaz') || text.contains('transport gaz')) {
          if (_typeRapport != 'commande_interne') {
            setState(() => _typeRapport = 'commande_interne');
            _loadPvConfig();
          }
        }
        _initNextPvNumero();
      });
      _projetCtrl.addListener(() {
        _initNextPvNumero();
      });
      _initNextPvNumero();
      _initDefaultsFromSettings();
    }
    _loadExistingClients();
    _loadPvConfig();
  }

  Future<void> _loadPvConfig() async {
    final isPrestation = _typeRapport != 'commande_interne';
    final config = await SettingsService.instance.getPvConfig(
      isPrestation: isPrestation,
    );
    if (mounted) setState(() => _pvConfig = config);
  }

  Future<void> _loadExistingClients() async {
    final clients = await DatabaseHelper.instance.getAllClients();
    final uniqueMap = <String, ClientModel>{};
    for (final c in clients) {
      final name = c.nomClient.trim();
      if (name.isNotEmpty && !uniqueMap.containsKey(name)) {
        uniqueMap[name] = c;
      }
    }
    if (mounted) setState(() => _existingClients = uniqueMap.values.toList());
  }

  Future<void> _initNextPvNumero() async {
    final basePv = widget.copyFromRapport?.pvNumero;
    final client = _nomClientCtrl.text.trim().isNotEmpty
        ? _nomClientCtrl.text.trim()
        : (widget.copyFromRapport?.nomClient ?? widget.initialClientName);
    final proj = _projetCtrl.text.trim().isNotEmpty
        ? _projetCtrl.text.trim()
        : widget.copyFromRapport?.projet;

    final next = await DatabaseHelper.instance.getNextPvNumero(
      basePvNumero: basePv,
      nomClient: client,
      projet: proj,
    );
    if (mounted) setState(() => _pvNumeroCtrl.text = next);
  }

  Future<void> _initDefaultsFromSettings() async {
    final settings = await SettingsService.instance.getSettings();
    if (mounted && _observationCtrl.text.isEmpty) {
      setState(() {
        _observationCtrl.text = settings.defaultObservation;
      });
    }
  }

  /// Step 1 — Appui sur chip client : remplit uniquement nom + adresse
  /// et propose les projets existants pour ce client.
  Future<void> _autoFillClientInfo(String clientName) async {
    final found = _existingClients.firstWhere(
      (c) => c.nomClient == clientName,
      orElse: () => _existingClients.first,
    );

    // Charger tous les rapports de ce client pour proposer les projets
    final rapports = await DatabaseHelper.instance.getRapportsForClient(clientName);
    if (!mounted) return;

    final isInterne = found.isCommandeInterne ||
        clientName.toLowerCase().contains('sonelgaz') ||
        clientName.toLowerCase().contains('sonalgaz') ||
        clientName.toLowerCase().contains('transport gaz');

    setState(() {
      _nomClientCtrl.text = found.nomClient;
      _coordonneesClientCtrl.text = found.coordonneesClient;
      if (!_isEditing && widget.rapport == null) {
        _typeRapport = isInterne ? 'commande_interne' : 'prestation';
      }
      _selectedClientForProject = clientName;
      _clientProjects = rapports;
    });

    _loadPvConfig();

    if (!_isEditing) {
      _initNextPvNumero();
    }
  }

  /// Step 2 — Appui sur chip projet : remplit caractéristiques techniques du rapport choisi.
  void _autoFillFromRapport(Rapport r) {
    setState(() {
      _typeRapport = r.typeRapport;
      _projetCtrl.text = r.projet;
      _dimensionsCtrl.text = r.dimensions;
      _nuanceCtrl.text = r.nuance;
      _nWpsCtrl.text = r.nWps;
      _nPqrCtrl.text = r.nPqr;
      _methodeEssaiCtrl.text = r.methodeEssai;
      _methodeEchantillonnageCtrl.text = r.methodeEchantillonnage;
      _specificationEssaiCtrl.text = r.specificationEssai;
      _observationCtrl.text = r.observation;
      _laboratoireCtrl.text = r.laboratoire;
      _sigCol1ValueCtrl.text = r.sigCol1Value;
      _sigCol2HeaderCtrl.text = r.sigCol2Header;
      _sigCol2ValueCtrl.text = r.sigCol2Value;
      _sigCol3HeaderCtrl.text = r.sigCol3Header;
      _sigCol3ValueCtrl.text = r.sigCol3Value;
      _sigCol4HeaderCtrl.text = r.sigCol4Header;
      _sigCol4ValueCtrl.text = r.sigCol4Value;
      _clientProjects = []; // Ferme la liste des projets
      _selectedClientForProject = null;
    });

    if (!_isEditing) {
      _initNextPvNumero();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Projet « ${r.projet.isNotEmpty ? r.projet : 'PV ${r.pvNumero}'} » copié'),
          backgroundColor: AppTheme.accentTeal,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Builds project chips for selected client (Step 2 of auto-fill)
  List<Widget> _buildProjectChips() {
    final seen = <String>{};
    final unique = _clientProjects.where((r) {
      final key = '${r.projet.trim()}|${r.dimensions.trim()}|${r.nuance.trim()}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();

    return [
      const SizedBox(height: 8),
      const Text(
        'Choisir un projet / caractéristiques :',
        style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: unique.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final r = unique[i];
            final label = r.projet.isNotEmpty ? r.projet : 'PV ${r.pvNumero}';
            final subtitle = r.dimensions.isNotEmpty ? ' · ${r.dimensions}' : '';
            return ActionChip(
              avatar: const Icon(Icons.folder_open_outlined, size: 14, color: AppTheme.accentTeal),
              label: Text(
                '$label$subtitle',
                style: const TextStyle(fontSize: 11),
              ),
              onPressed: () => _autoFillFromRapport(r),
              backgroundColor: AppTheme.bgLight,
              side: const BorderSide(color: AppTheme.accentTeal),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          },
        ),
      ),
    ];
  }

  @override
  void dispose() {
    for (final c in [
      _pvNumeroCtrl,
      _dateReceptionCtrl,
      _dateEmissionCtrl,
      _dateEssaiCtrl,
      _nomClientCtrl,
      _coordonneesClientCtrl,
      _dimensionsCtrl,
      _nuanceCtrl,
      _nWpsCtrl,
      _nPqrCtrl,
      _methodeEssaiCtrl,
      _methodeEchantillonnageCtrl,
      _specificationEssaiCtrl,
      _projetCtrl,
      _observationCtrl,
      _dateSignatureCtrl,
      _laboratoireCtrl,
      _sigCol1ValueCtrl,
      _sigCol2HeaderCtrl,
      _sigCol2ValueCtrl,
      _sigCol3HeaderCtrl,
      _sigCol3ValueCtrl,
      _sigCol4HeaderCtrl,
      _sigCol4ValueCtrl,
      _demandeurCtrl,
      _nCommandeInterneCtrl,
      _designationSoudureCtrl,
      _dateSoudageCtrl,
      _procedeSoudageCtrl,
      _metalApportCtrl,
      _positionSoudageCtrl,
      _nJointCtrl,
      _traitementThermiqueCtrl,
      _soudeurCodeCtrl,
      _attaqueChimiqueCtrl,
      _materielUtiliseCtrl,
      _sigInterneOperateurCtrl,
      _sigInterneVerificateurCtrl,
      _sigInterneChefCtrl,
      ..._obsControllers,
    ]) {
      c.dispose();
    }
    for (final secMap in _customFieldControllers.values) {
      for (final ctrl in secMap.values) {
        ctrl.dispose();
      }
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initial;
    try {
      initial = _dateFormat.parse(controller.text);
    } catch (_) {
      initial = DateTime.now();
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = _dateFormat.format(picked);
    }
  }

  void _addEchantillon() {
    setState(() {
      final nextNum = _echantillons.isEmpty
          ? 1
          : (_echantillons
                  .map((e) => e.numero)
                  .reduce((a, b) => a > b ? a : b) +
              1);
      final newEch = Echantillon(numero: nextNum);
      _echantillons.add(newEch);
      _obsControllers.add(TextEditingController());
      _sampleControllers.add(_createSampleControllers(newEch));
    });
  }

  void _removeEchantillon(int index) {
    setState(() {
      _echantillons.removeAt(index);
      _obsControllers[index].dispose();
      _obsControllers.removeAt(index);

      final map = _sampleControllers.removeAt(index);
      for (final c in map.values) {
        c.dispose();
      }

      for (int i = 0; i < _echantillons.length; i++) {
        _echantillons[i] = _echantillons[i].copyWith(numero: i + 1);
      }
    });
  }

  Future<void> _pickPhoto(int index, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      // Import à la taille réelle d'origine sans réduction ni compression
    );
    if (picked == null) return;

    if (!mounted) return;
    final croppedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoCropEditorDialog(
          imageFile: File(picked.path),
        ),
      ),
    );

    if (croppedPath != null) {
      setState(() {
        _echantillons[index] = _echantillons[index].copyWith(
          photoPath: croppedPath,
          rawPhotoPath: croppedPath,
          measureData: '',
        );
      });
    } else {
      // Si l'utilisateur n'a pas recadré, enregistrer la photo brute
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final ext = p.extension(picked.path);
      final newPath = p.join(
        photosDir.path,
        'ech_${DateTime.now().millisecondsSinceEpoch}_$index$ext',
      );
      await File(picked.path).copy(newPath);

      setState(() {
        _echantillons[index] = _echantillons[index].copyWith(
          photoPath: newPath,
          rawPhotoPath: newPath,
          measureData: '',
        );
      });
    }
  }

  void _showPhotoSourceSheet(int index) {
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
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryNavy),
                title: const Text('Prendre une photo avec l\'appareil'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(index, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.accentTeal),
                title: const Text('Choisir depuis la galerie photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(index, ImageSource.gallery);
                },
              ),
              if (_echantillons[index].photoPath != null) ...[
                ListTile(
                  leading: const Icon(Icons.crop_rotate_rounded, color: AppTheme.primaryNavy),
                  title: const Text('Ajuster & Recadrer la photo actuelle'),
                  onTap: () async {
                    Navigator.pop(context);
                    final e = _echantillons[index];
                    // Use the clean rawPhotoPath if the current photoPath is annotated
                    final bool isAnnotated = e.photoPath != null && e.photoPath!.contains('photo_annotated_');
                    final String inputPath;
                    if (isAnnotated && e.rawPhotoPath?.isNotEmpty == true && File(e.rawPhotoPath!).existsSync()) {
                      inputPath = e.rawPhotoPath!;
                    } else {
                      inputPath = e.photoPath!;
                    }
                    final croppedPath = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _PhotoCropEditorDialog(
                          imageFile: File(inputPath),
                        ),
                      ),
                    );
                    if (croppedPath != null) {
                      setState(() {
                        _echantillons[index] = _echantillons[index].copyWith(
                          photoPath: croppedPath,
                          rawPhotoPath: croppedPath,
                          measureData: '',  // Reset stale measure data since image bounds changed
                        );
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Retirer cette photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _echantillons[index] = _echantillons[index].copyWith(clearPhoto: true);
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _selectPresetObservation(int? echantillonIndex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                echantillonIndex != null
                    ? 'Observation pour ${_echantillons[echantillonIndex].label}'
                    : 'Observation globale du PV',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._observationPresets.map((preset) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(preset, style: const TextStyle(fontSize: 13)),
                      onTap: () {
                        setState(() {
                          if (echantillonIndex != null) {
                            _obsControllers[echantillonIndex].text = preset;
                          } else {
                            _observationCtrl.text = preset;
                          }
                        });
                        Navigator.pop(context);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now().toIso8601String();

      // Collect observations and dynamic parameters for each sample
      final updatedEchantillons = <Echantillon>[];
      for (int i = 0; i < _echantillons.length; i++) {
        final obsText = _obsControllers[i].text.trim();
        final map = _sampleControllers[i];
        updatedEchantillons.add(
          _echantillons[i].copyWith(
            observation: obsText,
            vitesse: map['vitesse']?.text.trim(),
            uInt: map['uInt']?.text.trim(),
            uExt: map['uExt']?.text.trim(),
            iInt: map['iInt']?.text.trim(),
            iExt: map['iExt']?.text.trim(),
            filInt1: map['filInt1']?.text.trim(),
            filInt2: map['filInt2']?.text.trim(),
            flux: map['flux']?.text.trim(),
            typeLot: map['typeLot']?.text.trim(),
            grossissement: map['grossissement']?.text.trim(),
            metalNuance: map['metalNuance']?.text.trim(),
            nCoulee: map['nCoulee']?.text.trim(),
            nBobine: map['nBobine']?.text.trim(),
            diametreTube: map['diametreTube']?.text.trim(),
            epNominale: map['epNominale']?.text.trim(),
            epReel: map['epReel']?.text.trim(),
            fournisseur: map['fournisseur']?.text.trim(),
            nTube: map['nTube']?.text.trim(),
            surepExt: map['surepExt']?.text.trim(),
            surepInt: map['surepInt']?.text.trim(),
            largeurExt: map['largeurExt']?.text.trim(),
            largeurInt: map['largeurInt']?.text.trim(),
            penetrationExt: map['penetrationExt']?.text.trim(),
            penetrationInt: map['penetrationInt']?.text.trim(),
            desaxage: map['desaxage']?.text.trim(),
            interpenetration: map['interpenetration']?.text.trim(),
          ),
        );
      }

      final rapport = Rapport(
        id: widget.rapport?.id,
        pvNumero: _pvNumeroCtrl.text.trim(),
        dateReception: _dateReceptionCtrl.text.trim(),
        dateEmission: _dateEmissionCtrl.text.trim(),
        dateEssai: _dateEssaiCtrl.text.trim(),
        typeRapport: _typeRapport,
        nomClient: _nomClientCtrl.text.trim(),
        coordonneesClient: _coordonneesClientCtrl.text.trim(),
        dimensions: _dimensionsCtrl.text.trim(),
        nuance: _nuanceCtrl.text.trim(),
        nWps: _nWpsCtrl.text.trim(),
        nPqr: _nPqrCtrl.text.trim(),
        methodeEssai: _methodeEssaiCtrl.text.trim(),
        nbEchantillons: updatedEchantillons.length,
        methodeEchantillonnage: _methodeEchantillonnageCtrl.text.trim(),
        specificationEssai: _specificationEssaiCtrl.text.trim(),
        projet: _projetCtrl.text.trim(),
        observation: _observationCtrl.text.trim(),
        dateSignature: _dateSignatureCtrl.text.trim(),
        laboratoire: _laboratoireCtrl.text.trim(),
        sigCol1Value: _sigCol1ValueCtrl.text.trim(),
        sigCol2Header: _sigCol2HeaderCtrl.text.trim(),
        sigCol2Value: _sigCol2ValueCtrl.text.trim(),
        sigCol3Header: _sigCol3HeaderCtrl.text.trim(),
        sigCol3Value: _sigCol3ValueCtrl.text.trim(),
        sigCol4Header: _sigCol4HeaderCtrl.text.trim(),
        sigCol4Value: _sigCol4ValueCtrl.text.trim(),
        // CMD INTERNE fields
        demandeur: _demandeurCtrl.text.trim(),
        nCommandeInterne: _nCommandeInterneCtrl.text.trim(),
        designationSoudure: _designationSoudureCtrl.text.trim(),
        dateSoudage: _dateSoudageCtrl.text.trim(),
        procedeSoudage: _procedeSoudageCtrl.text.trim(),
        metalApport: _metalApportCtrl.text.trim(),
        positionSoudage: _positionSoudageCtrl.text.trim(),
        nJoint: _nJointCtrl.text.trim(),
        traitementThermique: _traitementThermiqueCtrl.text.trim(),
        soudeurCode: _soudeurCodeCtrl.text.trim(),
        paramPenetration: '',
        paramRemplissage: '',
        paramFinition: '',
        attaqueChimique: _attaqueChimiqueCtrl.text.trim(),
        materielUtilise: _materielUtiliseCtrl.text.trim(),
        sigInterneOperateur: _sigInterneOperateurCtrl.text.trim(),
        sigInterneVerificateur: _sigInterneVerificateurCtrl.text.trim(),
        sigInterneChef: _sigInterneChefCtrl.text.trim(),
        photosPerRow: _photosPerRow,
        photoHeightPdf: _photoHeightPdf,
        customFieldsJson: _serializeCustomFields(),
        createdAt: widget.rapport?.createdAt ?? now,
        echantillons: updatedEchantillons,
      );

      if (_isEditing) {
        await DatabaseHelper.instance.updateRapport(rapport);
      } else {
        await DatabaseHelper.instance.insertRapport(rapport);
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> stepLabels = [
      'Identification',
      'Soudage & Param.',
      'Échantillons',
      'Constat',
      'Signatures',
    ];
    final List<IconData> stepIcons = [
      Icons.assignment_outlined,
      Icons.handyman_outlined,
      Icons.photo_library_outlined,
      Icons.visibility_outlined,
      Icons.draw_outlined,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le PV N° ${_pvNumeroCtrl.text}' : 'Nouveau Rapport d\'Essai'),
        elevation: 0,
        backgroundColor: AppTheme.primaryNavyDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Personnaliser les champs du PV',
            onPressed: () async {
              final newConfig = await PvConfigDialog.show(
                context,
                initialConfig: _pvConfig,
                initialTabIndex: _currentStep,
                isPrestation: _typeRapport != 'commande_interne',
              );
              if (newConfig != null && mounted) {
                setState(() => _pvConfig = newConfig);
              } else {
                await _loadPvConfig();
              }
            },
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.check_rounded, size: 26),
                tooltip: 'Enregistrer le PV',
                onPressed: _save,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // ── Modern Stepper Header ──
            Container(
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
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        // Type de rapport selector
                        Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    setState(() => _typeRapport = 'prestation');
                                    await _loadPvConfig();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _typeRapport == 'prestation' ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: _typeRapport == 'prestation'
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.business_center_outlined,
                                          size: 14,
                                          color: _typeRapport == 'prestation' ? AppTheme.primaryNavy : Colors.white70,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Prestation',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: _typeRapport == 'prestation' ? AppTheme.primaryNavy : Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    setState(() => _typeRapport = 'commande_interne');
                                    await _loadPvConfig();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _typeRapport == 'commande_interne' ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: _typeRapport == 'commande_interne'
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.build_circle_outlined,
                                          size: 14,
                                          color: _typeRapport == 'commande_interne' ? AppTheme.accentTeal : Colors.white70,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Commande Interne',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: _typeRapport == 'commande_interne' ? AppTheme.accentTeal : Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Step dots + labels
                        Row(
                          children: List.generate(_totalSteps, (i) {
                            final isCompleted = i < _currentStep;
                            final isActive = i == _currentStep;
                            return Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _currentStep = i);
                                        _pageController.animateToPage(
                                          i,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      child: Column(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 250),
                                            width: isActive ? 38 : 30,
                                            height: isActive ? 38 : 30,
                                            decoration: BoxDecoration(
                                              color: isCompleted
                                                  ? AppTheme.accentTeal
                                                  : (isActive ? Colors.white : Colors.white.withValues(alpha: 0.15)),
                                              shape: BoxShape.circle,
                                              border: isActive
                                                  ? Border.all(color: AppTheme.accentTeal, width: 2.5)
                                                  : Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                              boxShadow: isActive
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.white.withValues(alpha: 0.3),
                                                        blurRadius: 8,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Center(
                                              child: isCompleted
                                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                                  : Icon(
                                                      stepIcons[i],
                                                      color: isActive ? AppTheme.primaryNavy : Colors.white70,
                                                      size: isActive ? 18 : 14,
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            stepLabels[i],
                                            style: TextStyle(
                                              fontSize: 10.0,
                                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                              color: isActive ? Colors.white : Colors.white60,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (i < _totalSteps - 1)
                                    Expanded(
                                      child: Container(
                                        height: 2,
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: isCompleted ? AppTheme.accentTeal : Colors.white24,
                                          borderRadius: BorderRadius.circular(1),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Centered Responsive Page Content ──
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // ─── ÉTAPE 1 : Identification + Client + Caractéristiques ───
                      _buildStep1(),
                      // ─── ÉTAPE 2 : Soudage & Assemblage + Paramètres ───
                      _buildStepSoudageParam(),
                      // ─── ÉTAPE 3 : Échantillons & Options Photo ───
                      _buildStep2(),
                      // ─── ÉTAPE 4 : Constat Macrographique ───
                      _buildStep3(),
                      // ─── ÉTAPE 5 : Signatures ───
                      _buildStep4(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // ── Modern Floating Bottom Navigation Bar ──
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (_currentStep > 0)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _currentStep--);
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Précédent', style: TextStyle(fontSize: 12)),
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              // Step Indicator Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Text(
                  'Étape ${_currentStep + 1} / $_totalSteps',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
              const Spacer(),
              if (_currentStep < _totalSteps - 1)
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _currentStep++);
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Suivant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                )
              else
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    _saving ? 'Enregistrement…' : 'Enregistrer le PV',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ─── ÉTAPE 1 : Identification du PV + Client / Demandeur + Caractéristiques Techniques ───
  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Identification & Dates du PV
        _buildCardSection(
          title: '1. Identification du PV & Dates',
          icon: Icons.assignment_outlined,
          onAddChamp: () => _showAddCustomFieldDialog(
            'identification',
            'Identification du PV',
            ['N° Rapport / Affaire', 'Lieu d\'Essai', 'Température', 'Conditions Ambiantes', 'Réf. Norme'],
          ),
          children: [
            _textField(_pvNumeroCtrl, 'PV N° (ex: 01/2026)', required: true),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _dateField('Date Réception', _dateReceptionCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _dateField('Date d\'essai', _dateEssaiCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _dateField('Date Émission', _dateEmissionCtrl)),
              ],
            ),
            _buildCustomFieldsForSection('identification'),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Client / Demandeur & Projet
        _buildCardSection(
          title: '2. Client / Demandeur & Projet',
          icon: Icons.business_outlined,
          onAddChamp: () => _showAddCustomFieldDialog(
            'client',
            'Client / Demandeur & Projet',
            ['Site / Chantier', 'Contact / Demandeur', 'N° Bon de Commande', 'N° Contrat / Réf.', 'Sous-Traitant'],
          ),
          children: [
            if (_existingClients.isNotEmpty && !_isEditing && widget.initialClientName == null) ...[
              const Text('Auto-remplissage depuis un dossier existant :',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingClients.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final c = _existingClients[i];
                    final isSelected = _selectedClientForProject == c.nomClient;
                    return ActionChip(
                      avatar: Icon(
                        c.isCommandeInterne ? Icons.build_circle_outlined : Icons.business_center_outlined,
                        size: 14,
                        color: isSelected ? Colors.white : (c.isCommandeInterne ? AppTheme.accentTeal : AppTheme.primaryNavy),
                      ),
                      label: Text(c.nomClient, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                      onPressed: () => _autoFillClientInfo(c.nomClient),
                      backgroundColor: isSelected ? AppTheme.primaryNavy : AppTheme.bgLight,
                      side: BorderSide(color: isSelected ? AppTheme.primaryNavy : AppTheme.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  },
                ),
              ),
              if (_clientProjects.isNotEmpty) ..._buildProjectChips(),
              const SizedBox(height: 12),
            ],
            _textField(_nomClientCtrl, 'Nom Client / Demandeur (ex: SONELGAZ)', required: true),
            const SizedBox(height: 6),
            if (_pvConfig.showCoordonneesClient)
              _textField(_coordonneesClientCtrl, 'Coordonnées / Adresse du client'),
            const SizedBox(height: 6),
            if (_pvConfig.showProjet)
              _textField(_projetCtrl, 'Marché N° / Projet (ex: 21 / SONELGAZ TG / DPGS)'),
            _buildCustomFieldsForSection('client'),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Caractéristiques Techniques
        _buildCardSection(
          title: '3. Caractéristiques Techniques',
          icon: Icons.tune_rounded,
          onAddChamp: () => _showAddCustomFieldDialog(
            'caracteristiques',
            'Caractéristiques Techniques',
            ['Type Chanfrein', 'Température d\'Essai', 'Attaque Chimique', 'Norme Référence', 'Épaisseur Revêtement'],
          ),
          children: [
            if (_pvConfig.showDimensions || _pvConfig.showNuance)
              Row(
                children: [
                  if (_pvConfig.showDimensions)
                    Expanded(child: _textField(_dimensionsCtrl, 'Dimensions (mm) (ex: 711.2x9.5)')),
                  if (_pvConfig.showDimensions && _pvConfig.showNuance)
                    const SizedBox(width: 10),
                  if (_pvConfig.showNuance)
                    Expanded(child: _textField(_nuanceCtrl, 'Nuance (ex: API 5L X60M)')),
                ],
              ),
            const SizedBox(height: 6),
            if (_pvConfig.showNWps || _pvConfig.showNPqr)
              Row(
                children: [
                  if (_pvConfig.showNWps)
                    Expanded(child: _textField(_nWpsCtrl, 'N° WPS (ex: 38)')),
                  if (_pvConfig.showNWps && _pvConfig.showNPqr)
                    const SizedBox(width: 10),
                  if (_pvConfig.showNPqr)
                    Expanded(child: _textField(_nPqrCtrl, 'N° PQR (ex: 41)')),
                ],
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (_pvConfig.showMethodeEssai)
                  Expanded(child: _textField(_methodeEssaiCtrl, 'Méthode d\'essai (ex: API 5L / ISO 17639)')),
                if (_pvConfig.showMethodeEssai && _pvConfig.showMethodeEchantillonnage)
                  const SizedBox(width: 10),
                if (_pvConfig.showMethodeEchantillonnage)
                  Expanded(child: _textField(_methodeEchantillonnageCtrl, 'Méthode d\'échantillonnage (ex: ISO 15614-1)')),
              ],
            ),
            const SizedBox(height: 6),
            if (_pvConfig.showSpecificationEssai)
              _textField(_specificationEssaiCtrl, 'Spécification d\'essai (ex: /)'),
            _buildCustomFieldsForSection('caracteristiques'),
            if (!_pvConfig.showDimensions && !_pvConfig.showNuance &&
                !_pvConfig.showNWps && !_pvConfig.showNPqr &&
                !_pvConfig.showMethodeEssai && !_pvConfig.showMethodeEchantillonnage &&
                !_pvConfig.showSpecificationEssai &&
                (_customFieldControllers['caracteristiques']?.isEmpty ?? true))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Tous les champs de cette section sont masqués dans la configuration du PV.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  /// ─── ÉTAPE 2 : Soudage & Assemblage + Paramètres de Soudage (Onglet Dédié) ───
  Widget _buildStepSoudageParam() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Soudage & Assemblage
        _buildSoudageAssemblageSection(),
        const SizedBox(height: 16),

        // ⚡ Paramètres électriques — saisie unique avec propagation vers tous les échantillons
        _buildCardSection(
          title: '⚡ Paramètres Soudage (Vitesse, Flux, U, I, Fils)',
          icon: Icons.electric_bolt_outlined,
          children: [
            const Text(
              'Saisissez les paramètres communs puis appliquez-les à tous les échantillons :',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            if (_pvConfig.showParamVitesse || _pvConfig.showParamFlux)
              Row(
                children: [
                  if (_pvConfig.showParamVitesse)
                    Expanded(
                      child: TextFormField(
                        controller: _sampleControllers.isNotEmpty ? _sampleControllers[0]['vitesse'] : null,
                        decoration: const InputDecoration(labelText: 'Vitesse (m/min)', isDense: true),
                      ),
                    ),
                  if (_pvConfig.showParamVitesse && _pvConfig.showParamFlux)
                    const SizedBox(width: 8),
                  if (_pvConfig.showParamFlux)
                    Expanded(
                      child: TextFormField(
                        controller: _sampleControllers.isNotEmpty ? _sampleControllers[0]['flux'] : null,
                        decoration: const InputDecoration(labelText: 'Flux', isDense: true),
                      ),
                    ),
                ],
              ),
            if (_pvConfig.showParamTension) ...[const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sampleControllers.isNotEmpty ? _sampleControllers[0]['uInt'] : null,
                      decoration: const InputDecoration(labelText: 'U INT (V)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _sampleControllers.isNotEmpty ? _sampleControllers[0]['uExt'] : null,
                      decoration: const InputDecoration(labelText: 'U EXT (V)', isDense: true),
                    ),
                  ),
                ],
              ),
            ],
            if (_pvConfig.showParamCourant) ...[const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sampleControllers.isNotEmpty ? _sampleControllers[0]['iInt'] : null,
                      decoration: const InputDecoration(labelText: 'I INT (A)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _sampleControllers.isNotEmpty ? _sampleControllers[0]['iExt'] : null,
                      decoration: const InputDecoration(labelText: 'I EXT (A)', isDense: true),
                    ),
                  ),
                ],
              ),
            ],
            if (_pvConfig.showParamFils) ...[const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sampleControllers.isNotEmpty ? _sampleControllers[0]['filInt1'] : null,
                      decoration: const InputDecoration(labelText: 'Ø Fil INT 1', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _sampleControllers.isNotEmpty ? _sampleControllers[0]['filInt2'] : null,
                      decoration: const InputDecoration(labelText: 'Ø Fil INT 2', isDense: true),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                if (_sampleControllers.isEmpty) return;
                final first = _sampleControllers[0];
                setState(() {
                  for (int i = 1; i < _sampleControllers.length; i++) {
                    final t = _sampleControllers[i];
                    t['vitesse']?.text = first['vitesse']?.text ?? '';
                    t['flux']?.text = first['flux']?.text ?? '';
                    t['uInt']?.text = first['uInt']?.text ?? '';
                    t['uExt']?.text = first['uExt']?.text ?? '';
                    t['iInt']?.text = first['iInt']?.text ?? '';
                    t['iExt']?.text = first['iExt']?.text ?? '';
                    t['filInt1']?.text = first['filInt1']?.text ?? '';
                    t['filInt2']?.text = first['filInt2']?.text ?? '';
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paramètres appliqués à tous les échantillons !'),
                    duration: Duration(seconds: 2),
                    backgroundColor: AppTheme.accentTeal,
                  ),
                );
              },
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Appliquer à tous les échantillons'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accentTeal),
            ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }



  Widget _buildSoudageAssemblageSection() {
    if (!_pvConfig.showSectionSoudage) return const SizedBox.shrink();

    return _buildCardSection(
      title: '4. Soudage & Assemblage',
      icon: Icons.handyman_outlined,
      onAddChamp: () => _showAddCustomFieldDialog(
        'soudage',
        'Soudage & Assemblage',
        ['Gaz de Protection', 'Débit Gaz (l/min)', 'Préchauffage (°C)', 'Température Entre Passes', 'Polarité', 'Type Chanfrein'],
      ),
      children: [
        const Text(
          'Procédé, métaux d\'apport, position et PWHT',
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 10),
        if (_pvConfig.showProcedeSoudage || _pvConfig.showMetalApport)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_pvConfig.showProcedeSoudage)
                Expanded(
                  child: _textField(_procedeSoudageCtrl, 'Procédé de Soudage (ex: SAWH)'),
                ),
              if (_pvConfig.showProcedeSoudage && _pvConfig.showMetalApport)
                const SizedBox(width: 12),
              if (_pvConfig.showMetalApport)
                Expanded(
                  child: _textField(_metalApportCtrl, 'Fil de soudage / Lot'),
                ),
            ],
          ),
        if (_pvConfig.showPositionSoudage || _pvConfig.showNJoint)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_pvConfig.showPositionSoudage)
                Expanded(
                  child: _textField(_positionSoudageCtrl, 'Position de Soudage'),
                ),
              if (_pvConfig.showPositionSoudage && _pvConfig.showNJoint)
                const SizedBox(width: 12),
              if (_pvConfig.showNJoint)
                Expanded(
                  child: _textField(_nJointCtrl, 'N° Joint / Repère'),
                ),
            ],
          ),
        if (_pvConfig.showTraitementThermique)
          _textField(_traitementThermiqueCtrl, 'Traitement Thermique (PWHT)'),
        
        _buildCustomFieldsForSection('soudage'),
      ],
    );
  }

  /// ─── ÉTAPE 2 : Échantillons & Photos Macrographiques (avec Options d'affichage) ───
  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Options photo PDF liées directement aux échantillons
        _buildCardSection(
          title: 'Options Affichage Photos (PDF)',
          icon: Icons.photo_size_select_large_rounded,
          children: [
            Row(
              children: [
                const Icon(Icons.height_rounded, size: 18, color: AppTheme.primaryNavy),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Taille de la photo dans le PDF',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$_photoHeightPdf px',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                ),
              ],
            ),
            Slider(
              value: _photoHeightPdf.toDouble(),
              min: 60,
              max: 300,
              divisions: 24,
              activeColor: AppTheme.primaryNavy,
              label: '$_photoHeightPdf px',
              onChanged: (val) => setState(() => _photoHeightPdf = val.round()),
            ),
            if (_typeRapport == 'prestation') ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.grid_view_rounded, size: 18, color: AppTheme.primaryNavy),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Photos par ligne (PDF Prestation)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _photosPerRow = 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _photosPerRow == 2 ? AppTheme.primaryNavy : AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: _photosPerRow == 2 ? AppTheme.primaryNavy : AppTheme.borderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.view_column_outlined, size: 16,
                                color: _photosPerRow == 2 ? Colors.white : AppTheme.primaryNavy),
                            const SizedBox(width: 6),
                            Text('2 par ligne',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: _photosPerRow == 2 ? Colors.white : AppTheme.primaryNavy)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _photosPerRow = 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _photosPerRow == 4 ? AppTheme.primaryNavy : AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: _photosPerRow == 4 ? AppTheme.primaryNavy : AppTheme.borderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_view_rounded, size: 16,
                                color: _photosPerRow == 4 ? Colors.white : AppTheme.primaryNavy),
                            const SizedBox(width: 6),
                            Text('4 par ligne',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: _photosPerRow == 4 ? Colors.white : AppTheme.primaryNavy)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // Liste des Échantillons
        _buildEchantillonsSection(),
        const SizedBox(height: 80),
      ],
    );
  }

  /// ─── ÉTAPE 3 : Constat Macrographique Global ───
  Widget _buildStep3() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_pvConfig.showObservation)
          _buildCardSection(
            title: 'Constat Macrographique Global',
            icon: Icons.visibility_outlined,
            onAddChamp: () => _openSectionConfig(5),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Observation / Conclusion du PV :',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  TextButton.icon(
                    onPressed: () => _selectPresetObservation(null),
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('Presets', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              _textField(_observationCtrl, 'Observation globale', maxLines: 5),
            ],
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'La section Constat est masquée dans la configuration du PV.',
                style: TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  /// ─── ÉTAPE 4 : Signatures (Étape dédiée) ───
  Widget _buildStep4() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_pvConfig.showSignatures)
          _buildCardSection(
            title: 'Signatures (4 Colonnes Dynamiques)',
            icon: Icons.draw_outlined,
            onAddChamp: () => _showAddCustomFieldDialog(
              'signatures',
              'Signatures & Validation',
              ['Visa Qualité', 'N° Agrément', 'Visa Client / Tierce Partie', 'Date de Validation'],
            ),
            children: [
              _dateField('Date de signature', _dateSignatureCtrl),
              _textField(_laboratoireCtrl, 'Laboratoire (ex: EM / EEM)'),
              _textField(_sigCol1ValueCtrl, 'Signataire Laboratoire (ex: SALMOUN RACHID)'),
              const Divider(height: 20),
              const Text('Colonnes de Signatures Modifiables',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                  color: AppTheme.bgLight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Colonne 2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy)),
                    const SizedBox(height: 6),
                    _textField(_sigCol2HeaderCtrl, 'Titre Colonne 2 (ex: TIERCE PARTIE ou Nom Client)'),
                    _textField(_sigCol2ValueCtrl, 'Nom Signataire Colonne 2 (ex: AYATI TAHAR)'),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                  color: AppTheme.bgLight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Colonne 3', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy)),
                    const SizedBox(height: 6),
                    _textField(_sigCol3HeaderCtrl, 'Titre Colonne 3 (ex: Représentant Cosider / /)'),
                    _textField(_sigCol3ValueCtrl, 'Nom Signataire Colonne 3 (ex: /)'),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                  color: AppTheme.bgLight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Colonne 4', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy)),
                    const SizedBox(height: 6),
                    _textField(_sigCol4HeaderCtrl, 'Titre Colonne 4 (ex: Tierce Partie / Autorités)'),
                    _textField(_sigCol4ValueCtrl, 'Nom Signataire Colonne 4 (ex: /)'),
                  ],
                ),
              ),
              _buildCustomFieldsForSection('signatures'),
            ],
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'La section Signatures est masquée dans la configuration du PV.',
                style: TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEchantillonsSection() {
    return _buildCardSection(
      title: 'Échantillons & Photo Macrographique (${_echantillons.length})',
      icon: Icons.photo_library_outlined,
      children: [
        ..._echantillons.asMap().entries.map((entry) {
          final index = entry.key;
          final e = entry.value;
          final hasPhoto = e.photoPath != null && File(e.photoPath!).existsSync();

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showPhotoSourceSheet(index),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasPhoto ? AppTheme.accentTeal : AppTheme.borderSubtle,
                            width: hasPhoto ? 2 : 1,
                          ),
                        ),
                        child: hasPhoto
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(e.photoPath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: AppTheme.primaryNavy,
                                    size: 24,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Photo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
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
                          Text(
                            e.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasPhoto ? 'Photo chargée' : 'Appuyez pour ajouter une photo',
                            style: TextStyle(
                              fontSize: 12,
                              color: hasPhoto ? AppTheme.accentTeal : AppTheme.textMuted,
                            ),
                          ),
                          if (hasPhoto) ...[
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () => _openPhotoMeasureScreen(index),
                              icon: const Icon(Icons.square_foot_rounded, size: 14),
                              label: const Text('📐 Mesurer sur Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppTheme.primaryNavy,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Supprimer cet échantillon',
                      onPressed: _echantillons.length > 1
                          ? () => _removeEchantillon(index)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Observation ${e.label} :',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _selectPresetObservation(index),
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('Preset', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _obsControllers[index],
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Constat spécifique à cet échantillon (optionnel)',
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 8),

                // ExpansionTile pour modifier les paramètres de l'échantillon (Disponible pour tous les rapports)
                Builder(
                  builder: (context) {
                    final map = _sampleControllers[index];
                    return ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                        title: const Text(
                          'Paramètres, Métal de base & Soudure (champs modifiables)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                        subtitle: const Text(
                          'Vitesse, U/I INT/EXT, Nuance, N° Coulée, Soudure, etc.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        children: [
                          // 1. PARAMETRES — gérés dans l'onglet Soudage & Param.
                          // (supprimés ici pour éviter la duplication)
                          // 2. PHOTO HEADER & FOOTER
                          if (_pvConfig.showTypeLot || _pvConfig.showGrossissement) ...[
                            _buildSubSectionHeader('🖼️ TITRE & GROSSISSEMENT PHOTO', onAddChamp: () => _openSectionConfig(4)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (_pvConfig.showTypeLot)
                                  Expanded(child: _textField(map['typeLot']!, 'Type (ex: LOT 27)')),
                                if (_pvConfig.showTypeLot && _pvConfig.showGrossissement)
                                  const SizedBox(width: 8),
                                if (_pvConfig.showGrossissement)
                                  Expanded(child: _textField(map['grossissement']!, 'Grossissement (ex: 1,8 FOIS)')),
                              ],
                            ),
                            const Divider(height: 16),
                          ],
                          // 3. METAL DE BASE
                          if (_pvConfig.showTableMetalBase) ...[
                            _buildSubSectionHeader('⚙️ MÉTAL DE BASE', onAddChamp: () => _openSectionConfig(3)),
                            const SizedBox(height: 6),
                            if (_pvConfig.showMetalNuance || _pvConfig.showFournisseur)
                              Row(
                                children: [
                                  if (_pvConfig.showMetalNuance)
                                    Expanded(child: _textField(map['metalNuance']!, 'Nuance (ex: X 60)')),
                                  if (_pvConfig.showMetalNuance && _pvConfig.showFournisseur)
                                    const SizedBox(width: 8),
                                  if (_pvConfig.showFournisseur)
                                    Expanded(child: _textField(map['fournisseur']!, 'Fournisseur')),
                                ],
                              ),
                            if (_pvConfig.showNCoulee || _pvConfig.showNBobine)
                              Row(
                                children: [
                                  if (_pvConfig.showNCoulee)
                                    Expanded(child: _textField(map['nCoulee']!, 'N° Coulée')),
                                  if (_pvConfig.showNCoulee && _pvConfig.showNBobine)
                                    const SizedBox(width: 8),
                                  if (_pvConfig.showNBobine)
                                    Expanded(child: _textField(map['nBobine']!, 'N° Bobine')),
                                ],
                              ),
                            if (_pvConfig.showDiametreTube || _pvConfig.showEpNominale || _pvConfig.showEpReel)
                              Row(
                                children: [
                                  if (_pvConfig.showDiametreTube)
                                    Expanded(child: _textField(map['diametreTube']!, 'Ø Tube (mm)')),
                                  if (_pvConfig.showDiametreTube && _pvConfig.showEpNominale)
                                    const SizedBox(width: 8),
                                  if (_pvConfig.showEpNominale)
                                    Expanded(child: _textField(map['epNominale']!, 'Ep. Nominale (mm)')),
                                  if (_pvConfig.showEpNominale && _pvConfig.showEpReel)
                                    const SizedBox(width: 8),
                                  if (_pvConfig.showEpReel)
                                    Expanded(child: _textField(map['epReel']!, 'Ep. Réel (mm)')),
                                ],
                              ),
                            const Divider(height: 16),
                          ],
                          // 4. SOUDURE & N° TUBE
                          if (_pvConfig.showTableSoudure) ...[
                            _buildSubSectionHeader('📏 SOUDURE & MESURES TUBE', onAddChamp: () => _openSectionConfig(4)),
                            const SizedBox(height: 6),
                            if (_pvConfig.showNTube)
                              _textField(map['nTube']!, 'N° Tube (ex: 1345 G)'),
                            if (_pvConfig.showSurepaisseur)
                              Row(
                                children: [
                                  Expanded(child: _textField(map['surepExt']!, 'Surépaisseur EXT (mm)')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _textField(map['surepInt']!, 'Surépaisseur INT (mm)')),
                                ],
                              ),
                            if (_pvConfig.showLargeur)
                              Row(
                                children: [
                                  Expanded(child: _textField(map['largeurExt']!, 'Largeur EXT (mm)')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _textField(map['largeurInt']!, 'Largeur INT (mm)')),
                                ],
                              ),
                            if (_pvConfig.showPenetration)
                              Row(
                                children: [
                                  Expanded(child: _textField(map['penetrationExt']!, 'Pénétration EXT (%)')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _textField(map['penetrationInt']!, 'Pénétration INT (%)')),
                                ],
                              ),
                            if (_pvConfig.showDesaxage || _pvConfig.showInterpenetration)
                              Row(
                                children: [
                                  if (_pvConfig.showDesaxage)
                                    Expanded(child: _textField(map['desaxage']!, 'Désaxage (mm)')),
                                  if (_pvConfig.showDesaxage && _pvConfig.showInterpenetration)
                                    const SizedBox(width: 8),
                                  if (_pvConfig.showInterpenetration)
                                    Expanded(child: _textField(map['interpenetration']!, 'Interpénétration (mm)')),
                                ],
                              ),
                          ],
                          // Message si tout est masqué
                          if (!_pvConfig.showTableParametres && !_pvConfig.showTableMetalBase &&
                              !_pvConfig.showTableSoudure && !_pvConfig.showTypeLot && !_pvConfig.showGrossissement)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Tous les tableaux sont masqués dans la config du PV.',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addEchantillon,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Ajouter un échantillon'),
        ),
      ],
    );
  }

  Future<void> _openPhotoMeasureScreen(int index) async {
    final e = _echantillons[index];
    final map = _sampleControllers[index];
    if (e.photoPath == null || e.photoPath!.isEmpty || !File(e.photoPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord ajouter une photo à l\'échantillon.')),
      );
      return;
    }

    String initialEp = map['epReel']?.text.trim() ?? '';
    if (initialEp.isEmpty && _dimensionsCtrl.text.trim().isNotEmpty) {
      final dimText = _dimensionsCtrl.text.trim();
      final matches = RegExp(r'(\d+(?:[\,\.]\d+)?)').allMatches(dimText).map((m) => m.group(0)!).toList();
      if (matches.isNotEmpty) {
        final candidate = matches.last.replaceAll('.', ',');
        final doubleVal = double.tryParse(candidate.replaceAll(',', '.')) ?? 0;
        if (doubleVal > 0 && doubleVal < 100) {
          initialEp = candidate;
        }
      }
    }
    if (initialEp.isEmpty) {
      initialEp = '11';
    }

    // Use rawPhotoPath only when the current photoPath is an annotated image
    final bool isAnnotated = e.photoPath != null && e.photoPath!.contains('photo_annotated_');
    final String cleanPhoto;
    if (isAnnotated && e.rawPhotoPath?.isNotEmpty == true && File(e.rawPhotoPath!).existsSync()) {
      cleanPhoto = e.rawPhotoPath!;
    } else {
      cleanPhoto = e.photoPath!;
    }

    final result = await Navigator.push<PhotoMeasureResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoMeasureScreen(
          photoPath: cleanPhoto,
          rawPhotoPath: cleanPhoto,
          initialMeasureData: e.measureData,
          photoHeightPdf: _photoHeightPdf.toDouble(),
          initialGrossissement: map['grossissement']?.text.isNotEmpty == true ? map['grossissement']!.text : '1,8',
          initialEpReel: initialEp,
          initialSurepExt: map['surepExt']?.text.isNotEmpty == true ? map['surepExt']!.text : '1,66',
          initialSurepInt: map['surepInt']?.text.isNotEmpty == true ? map['surepInt']!.text : '1,66',
          initialLargeurExt: map['largeurExt']?.text.isNotEmpty == true ? map['largeurExt']!.text : '15',
          initialLargeurInt: map['largeurInt']?.text.isNotEmpty == true ? map['largeurInt']!.text : '12,77',
          initialPenetrationExt: map['penetrationExt']?.text.isNotEmpty == true ? map['penetrationExt']!.text : '68,18',
          initialPenetrationInt: map['penetrationInt']?.text.isNotEmpty == true ? map['penetrationInt']!.text : '55,54',
          initialDesaxage: map['desaxage']?.text.isNotEmpty == true ? map['desaxage']!.text : '0',
          initialInterpenetration: map['interpenetration']?.text.isNotEmpty == true ? map['interpenetration']!.text : '2,22',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _echantillons[index] = _echantillons[index].copyWith(
          photoPath: result.annotatedPhotoPath ?? _echantillons[index].photoPath,
          rawPhotoPath: result.rawPhotoPath ?? _echantillons[index].rawPhotoPath,
          measureData: result.measureData ?? _echantillons[index].measureData,
        );
        if (result.epReel.isNotEmpty) {
          map['epReel']?.text = result.epReel;
        }
        if (result.grossissement.isNotEmpty) {
          map['grossissement']?.text = result.grossissement;
        }
        map['surepExt']?.text = result.surepExt;
        map['surepInt']?.text = result.surepInt;
        map['largeurExt']?.text = result.largeurExt;
        map['largeurInt']?.text = result.largeurInt;
        map['penetrationExt']?.text = result.penetrationExt;
        map['penetrationInt']?.text = result.penetrationInt;
        map['desaxage']?.text = result.desaxage;
        map['interpenetration']?.text = result.interpenetration;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Mesures reportées avec succès sur l\'échantillon !'),
            backgroundColor: AppTheme.accentTeal,
          ),
        );
      }
    }
  }



  Future<void> _openSectionConfig(int tabIndex) async {
    final newConfig = await PvConfigDialog.show(
      context,
      initialConfig: _pvConfig,
      initialTabIndex: tabIndex,
      isPrestation: _typeRapport != 'commande_interne',
    );
    if (newConfig != null && mounted) {
      setState(() => _pvConfig = newConfig);
    } else {
      await _loadPvConfig();
    }
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    VoidCallback? onAddChamp,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryNavy, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
                if (onAddChamp != null)
                  InkWell(
                    onTap: onAddChamp,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 14, color: AppTheme.accentTeal),
                          SizedBox(width: 3),
                          Text(
                            '+ Champ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSubSectionHeader(String title, {VoidCallback? onAddChamp}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
        ),
        if (onAddChamp != null)
          InkWell(
            onTap: onAddChamp,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 12, color: AppTheme.accentTeal),
                  SizedBox(width: 2),
                  Text(
                    '+ Champ',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String defaultLabel, {
    String? fieldKey,
    bool required = false,
    int maxLines = 1,
    VoidCallback? onDelete,
    bool canEditLabel = true,
  }) {
    final key = fieldKey ?? defaultLabel;
    final currentLabel = _customLabels[key] ?? defaultLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Libellé au-dessus (toujours visible, avec mini crayon discret)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  currentLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canEditLabel)
                GestureDetector(
                  onTap: () => _editFieldLabel(key, currentLabel),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Icon(Icons.edit_outlined, size: 11, color: Colors.grey.shade400),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          // ── Champ de saisie
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2340),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 1.2),
              ),
              suffixIconConstraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
              suffixIcon: GestureDetector(
                onTap: onDelete ?? () => setState(() => controller.clear()),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    onDelete != null ? Icons.delete_outline_rounded : Icons.close_rounded,
                    size: 13,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _editFieldLabel(String key, String currentLabel) async {
    final controller = TextEditingController(text: currentLabel);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined, color: AppTheme.primaryNavy, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Modifier le libellé du champ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Libellé actuel : "$currentLabel"',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nouveau libellé du champ',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) Navigator.pop(ctx, val.trim());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          if (_customLabels.containsKey(key))
            TextButton(
              onPressed: () {
                setState(() {
                  _customLabels.remove(key);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Rétablir', style: TextStyle(color: Colors.orange)),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newLabel != null && newLabel.isNotEmpty) {
      setState(() {
        _customLabels[key] = newLabel;
      });
    }
  }

  Widget _dateField(String label, TextEditingController controller) {
    final currentLabel = _customLabels[label] ?? label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  currentLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _editFieldLabel(label, currentLabel),
                child: Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(Icons.edit_outlined, size: 11, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2340),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
              ),
              suffixIconConstraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
              suffixIcon: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primaryNavy),
              ),
            ),
            onTap: () => _pickDate(controller),
          ),
        ],
      ),
    );
  }

  String _serializeCustomFields() {
    final customMap = <String, dynamic>{};
    if (_customLabels.isNotEmpty) {
      customMap['_labels'] = Map<String, String>.from(_customLabels);
    }
    _customFieldControllers.forEach((secKey, fields) {
      final fieldMap = <String, String>{};
      fields.forEach((name, ctrl) {
        if (ctrl.text.trim().isNotEmpty) {
          fieldMap[name] = ctrl.text.trim();
        } else {
          fieldMap[name] = '';
        }
      });
      if (fieldMap.isNotEmpty) {
        customMap[secKey] = fieldMap;
      }
    });
    return jsonEncode(customMap);
  }

  Future<void> _showAddCustomFieldDialog(
    String sectionKey,
    String sectionTitle,
    List<String> suggestions,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_box_outlined, color: AppTheme.primaryNavy, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Ajouter un champ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entrez le libellé du nouveau champ (ex: N° Bobine, Réf. Spécifique...) :',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Nom du champ',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) Navigator.pop(ctx, val.trim());
                      },
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Suggestions rapides :',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: suggestions.map((s) {
                          return ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 11, color: AppTheme.primaryNavy)),
                            backgroundColor: AppTheme.bgLight,
                            side: const BorderSide(color: AppTheme.borderSubtle),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () {
                              controller.text = s;
                              setDialogState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final val = controller.text.trim();
                    if (val.isNotEmpty) {
                      Navigator.pop(ctx, val);
                    }
                  },
                  child: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _customFieldControllers.putIfAbsent(sectionKey, () => {});
        if (!_customFieldControllers[sectionKey]!.containsKey(result)) {
          _customFieldControllers[sectionKey]![result] = TextEditingController();
        }
      });
    }
  }

  Widget _buildCustomFieldsForSection(String sectionKey) {
    final fields = _customFieldControllers[sectionKey];
    if (fields == null || fields.isEmpty) return const SizedBox.shrink();

    return Column(
      children: fields.entries.map((entry) {
        final fieldName = entry.key;
        final ctrl = entry.value;

        return _textField(
          ctrl,
          fieldName,
          fieldKey: '${sectionKey}_$fieldName',
          canEditLabel: true,
          onDelete: () {
            setState(() {
              ctrl.dispose();
              _customFieldControllers[sectionKey]?.remove(fieldName);
            });
          },
        );
      }).toList(),
    );
  }
}

// ─── ÉCRAN INTERACTIF DE RECADRAGE, FOND NOIR, ÉTIQUETTES / ÉCHELLE, HISTORIQUE (UNDO/REDO) & FILTRE RADIO ───

enum _RadioFilterPreset {
  original,          // Photo originale en couleurs réelles (Par défaut)
  colorEnhanced,     // Couleurs vives & contraste net (Conserve les couleurs)
  radioMacro,        // N&B Radio Macro (Révélation ZAT & cordon)
  radioHighContrast, // N&B Contraste élevé
  radioMetallo,      // N&B Métallographie ZAT
  radioNegative,     // Négatif type film radiographique RX
  radioBinarize,     // Binarisation & haut contraste N&B
  custom,            // Réglages manuels personnalisés
}

enum _EditorTab {
  crop,        // 1. Cadrage & Rotation
  filter,      // 2. Filtres Radio & Volume
  blackBg,     // 3. Fond Noir (Remplacer tout en noir / Gomme / Pinceau)
  annotations, // 4. Étiquettes, Commentaires & Échelle
}

enum _AnnotationType {
  label,  // Étiquette / Commentaire (texte libre, taille, badge, couleur)
  scale,  // Échelle / Règle graduée mm ajustable
}

class _PhotoAnnotationItem {
  final String id;
  _AnnotationType type;
  String text;
  Offset pos; // Position normalisée (0.0 à 1.0)
  double fontSize; // 10.0 à 48.0
  bool hasBadge; // Fond sombre ou texte avec ombre
  Color color; // Couleur du texte
  double scaleWidthNorm; // Largeur relative de l'échelle (ex: 0.18)
  double strokeWidth; // Épaisseur des traits / bordures

  _PhotoAnnotationItem({
    required this.id,
    required this.type,
    required this.text,
    required this.pos,
    this.fontSize = 22.0,
    this.hasBadge = false,
    this.color = Colors.white,
    this.scaleWidthNorm = 0.20,
    this.strokeWidth = 2.0,
  });

  _PhotoAnnotationItem clone() {
    return _PhotoAnnotationItem(
      id: id,
      type: type,
      text: text,
      pos: pos,
      fontSize: fontSize,
      hasBadge: hasBadge,
      color: color,
      scaleWidthNorm: scaleWidthNorm,
      strokeWidth: strokeWidth,
    );
  }
}

class _BlackMaskStroke {
  final List<Offset> points;
  final double strokeWidth;
  _BlackMaskStroke(this.points, this.strokeWidth);
}

class _EditorSnapshot {
  final int turns;
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
  final _RadioFilterPreset filterPreset;
  final double customContrast;
  final double customBrightness;
  final double customBlackVolume;
  final double customSaturation;
  final bool customKeepColor;
  final bool customInvert;
  final double maskTop;
  final double maskBottom;
  final double maskLeft;
  final double maskRight;
  final List<_BlackMaskStroke> blackStrokes;
  final List<_PhotoAnnotationItem> annotations;
  final String? selectedAnnotationId;

  _EditorSnapshot({
    required this.turns,
    required this.cropLeft,
    required this.cropTop,
    required this.cropRight,
    required this.cropBottom,
    required this.filterPreset,
    required this.customContrast,
    required this.customBrightness,
    required this.customBlackVolume,
    required this.customSaturation,
    required this.customKeepColor,
    required this.customInvert,
    required this.maskTop,
    required this.maskBottom,
    required this.maskLeft,
    required this.maskRight,
    required this.blackStrokes,
    required this.annotations,
    required this.selectedAnnotationId,
  });
}

class _PhotoCropEditorDialog extends StatefulWidget {
  final File imageFile;

  const _PhotoCropEditorDialog({required this.imageFile});

  @override
  State<_PhotoCropEditorDialog> createState() => _PhotoCropEditorDialogState();
}

class _PhotoCropEditorDialogState extends State<_PhotoCropEditorDialog> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  int _turns = 0; // 0, 1, 2, 3 quarter turns (0°, 90°, 180°, 270°)
  bool _processing = false;
  ui.Image? _rawUiImage;

  // Ordre du workflow : On commence par 1. Cadrage
  _EditorTab _currentTab = _EditorTab.crop;

  // 1. Cadrage normalisé (0.0 à 1.0)
  double _cropLeft = 0.0;
  double _cropTop = 0.0;
  double _cropRight = 1.0;
  double _cropBottom = 1.0;

  // 2. Filtre Photo & Curseurs (Par défaut : Couleurs originales de la prise de vue !)
  _RadioFilterPreset _filterPreset = _RadioFilterPreset.original;
  double _customContrast = 1.00;
  double _customBrightness = 0.0;
  double _customBlackVolume = 0.0;
  double _customSaturation = 1.00;
  bool _customKeepColor = true; // Conserver les couleurs d'origine
  bool _customInvert = false;

  // 3. Fond Noir (Background Noir & Gomme)
  double _maskTop = 0.0;
  double _maskBottom = 1.0;
  double _maskLeft = 0.0;
  double _maskRight = 1.0;
  List<_BlackMaskStroke> _blackStrokes = [];
  _BlackMaskStroke? _currentStroke;
  double _brushWidth = 24.0;
  bool _isEraser = false; // Bascule Pinceau vs Gomme

  // 4. Étiquettes, Commentaires & Échelle multiples (aucune par défaut, ajout manuel si souhaité)
  List<_PhotoAnnotationItem> _annotations = [];
  String? _selectedAnnotationId;
  final TextEditingController _annotationTextCtrl = TextEditingController();

  // Historique d'annulation (Undo / Redo étape par étape)
  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _loadRawImageDimensions();
  }

  void _loadRawImageDimensions() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _rawUiImage = frame.image;
        });
      }
    } catch (_) {}
  }

  _EditorSnapshot _takeSnapshot() {
    return _EditorSnapshot(
      turns: _turns,
      cropLeft: _cropLeft,
      cropTop: _cropTop,
      cropRight: _cropRight,
      cropBottom: _cropBottom,
      filterPreset: _filterPreset,
      customContrast: _customContrast,
      customBrightness: _customBrightness,
      customBlackVolume: _customBlackVolume,
      customSaturation: _customSaturation,
      customKeepColor: _customKeepColor,
      customInvert: _customInvert,
      maskTop: _maskTop,
      maskBottom: _maskBottom,
      maskLeft: _maskLeft,
      maskRight: _maskRight,
      blackStrokes: _blackStrokes.map((s) => _BlackMaskStroke(List.of(s.points), s.strokeWidth)).toList(),
      annotations: _annotations.map((a) => a.clone()).toList(),
      selectedAnnotationId: _selectedAnnotationId,
    );
  }

  void _recordState() {
    _redoStack.clear();
    _undoStack.add(_takeSnapshot());
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final current = _takeSnapshot();
    _redoStack.add(current);
    final prev = _undoStack.removeLast();
    _applySnapshot(prev);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final current = _takeSnapshot();
    _undoStack.add(current);
    final next = _redoStack.removeLast();
    _applySnapshot(next);
  }

  void _applySnapshot(_EditorSnapshot s) {
    setState(() {
      _turns = s.turns;
      _cropLeft = s.cropLeft;
      _cropTop = s.cropTop;
      _cropRight = s.cropRight;
      _cropBottom = s.cropBottom;
      _filterPreset = s.filterPreset;
      _customContrast = s.customContrast;
      _customBrightness = s.customBrightness;
      _customBlackVolume = s.customBlackVolume;
      _customSaturation = s.customSaturation;
      _customKeepColor = s.customKeepColor;
      _customInvert = s.customInvert;
      _maskTop = s.maskTop;
      _maskBottom = s.maskBottom;
      _maskLeft = s.maskLeft;
      _maskRight = s.maskRight;
      _blackStrokes = s.blackStrokes.map((st) => _BlackMaskStroke(List.of(st.points), st.strokeWidth)).toList();
      _annotations = s.annotations.map((a) => a.clone()).toList();
      _selectedAnnotationId = s.selectedAnnotationId;
      final selected = _currentSelectedAnnotation;
      if (selected != null && _annotationTextCtrl.text != selected.text) {
        _annotationTextCtrl.text = selected.text;
      }
    });
  }

  _PhotoAnnotationItem? get _currentSelectedAnnotation {
    if (_selectedAnnotationId == null) return null;
    try {
      return _annotations.firstWhere((a) => a.id == _selectedAnnotationId);
    } catch (_) {
      return _annotations.isNotEmpty ? _annotations.first : null;
    }
  }

  List<double>? get _currentColorMatrix {
    switch (_filterPreset) {
      case _RadioFilterPreset.original:
        return null; // Conserve la photo originale avec 100% de ses vraies couleurs !
      case _RadioFilterPreset.colorEnhanced:
        return _buildColorEnhancedMatrix(contrast: 1.25, brightness: 6.0, saturation: 1.30);
      case _RadioFilterPreset.radioMacro:
        return _buildColorMatrix(contrast: 1.45, brightness: 5.0, blackVolume: 0.0, invert: false);
      case _RadioFilterPreset.radioHighContrast:
        return _buildColorMatrix(contrast: 1.90, brightness: 10.0, blackVolume: 15.0, invert: false);
      case _RadioFilterPreset.radioMetallo:
        return _buildColorMatrix(contrast: 2.30, brightness: -4.0, blackVolume: 25.0, invert: false);
      case _RadioFilterPreset.radioNegative:
        return _buildColorMatrix(contrast: 1.35, brightness: 0.0, blackVolume: 0.0, invert: true);
      case _RadioFilterPreset.radioBinarize:
        return _buildColorMatrix(contrast: 3.20, brightness: -15.0, blackVolume: 40.0, invert: false);
      case _RadioFilterPreset.custom:
        if (_customKeepColor) {
          return _buildColorEnhancedMatrix(
            contrast: _customContrast,
            brightness: _customBrightness,
            saturation: _customSaturation,
          );
        } else {
          return _buildColorMatrix(
            contrast: _customContrast,
            brightness: _customBrightness,
            blackVolume: _customBlackVolume,
            invert: _customInvert,
          );
        }
    }
  }

  static List<double> _buildColorEnhancedMatrix({
    required double contrast,
    required double brightness,
    required double saturation,
  }) {
    final c = contrast;
    final b = brightness;
    final s = saturation;

    const rw = 0.299;
    const gw = 0.587;
    const bw = 0.114;

    final invS = 1.0 - s;
    final rR = (invS * rw + s) * c;
    final rG = (invS * gw) * c;
    final rB = (invS * bw) * c;

    final gR = (invS * rw) * c;
    final gG = (invS * gw + s) * c;
    final gB = (invS * bw) * c;

    final bR = (invS * rw) * c;
    final bG = (invS * gw) * c;
    final bB = (invS * bw + s) * c;

    final offset = 128.0 * (1.0 - c) + b;

    return <double>[
      rR, rG, rB, 0, offset,
      gR, gG, gB, 0, offset,
      bR, bG, bB, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> _buildColorMatrix({
    required double contrast,
    required double brightness,
    required double blackVolume,
    required bool invert,
  }) {
    const rw = 0.299;
    const gw = 0.587;
    const bw = 0.114;

    final c = contrast;
    final sign = invert ? -1.0 : 1.0;
    final r = sign * rw * c;
    final g = sign * gw * c;
    final b = sign * bw * c;

    final offset = invert
        ? 128.0 * (1.0 + c) + brightness + blackVolume
        : 128.0 * (1.0 - c) + brightness - blackVolume;

    return <double>[
      r, g, b, 0, offset,
      r, g, b, 0, offset,
      r, g, b, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  void _rotate() {
    _recordState();
    setState(() {
      _turns = (_turns + 1) % 4;
    });
  }

  void _resetAll() {
    _recordState();
    setState(() {
      _turns = 0;
      _cropLeft = 0.0;
      _cropTop = 0.0;
      _cropRight = 1.0;
      _cropBottom = 1.0;
      _filterPreset = _RadioFilterPreset.original;
      _customContrast = 1.00;
      _customBrightness = 0.0;
      _customBlackVolume = 0.0;
      _customSaturation = 1.00;
      _customKeepColor = true;
      _customInvert = false;
      _maskTop = 0.0;
      _maskBottom = 1.0;
      _maskLeft = 0.0;
      _maskRight = 1.0;
      _blackStrokes.clear();
      _isEraser = false;
      _annotations = [];
      _selectedAnnotationId = null;
      _annotationTextCtrl.clear();
      _currentTab = _EditorTab.crop;
    });
  }

  Future<void> _cropAndSave() async {
    setState(() => _processing = true);
    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image fullImage = await boundary.toImage(pixelRatio: 3.0);

      // Découpage selon le cadre normalisé
      final cropW = (fullImage.width * (_cropRight - _cropLeft)).clamp(1.0, fullImage.width.toDouble());
      final cropH = (fullImage.height * (_cropBottom - _cropTop)).clamp(1.0, fullImage.height.toDouble());
      final cropX = (fullImage.width * _cropLeft).clamp(0.0, fullImage.width - cropW);
      final cropY = (fullImage.height * _cropTop).clamp(0.0, fullImage.height - cropH);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, cropW, cropH));
      canvas.drawImageRect(
        fullImage,
        Rect.fromLTWH(cropX, cropY, cropW, cropH),
        Rect.fromLTWH(0, 0, cropW, cropH),
        Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(cropW.toInt(), cropH.toInt());

      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final croppedPath = p.join(
        photosDir.path,
        'crop_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await File(croppedPath).writeAsBytes(bytes);

      if (mounted) {
        Navigator.pop(context, croppedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur traitement photo: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _eraseStrokeAt(Offset norm, double w, double h) {
    final threshold = (_brushWidth / (w < h ? w : h)) * 1.5;
    setState(() {
      _blackStrokes.removeWhere((stroke) {
        return stroke.points.any((pt) => (pt - norm).distance <= threshold);
      });
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _annotationTextCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double imageAspect = 4 / 3;
    if (_rawUiImage != null && _rawUiImage!.width > 0 && _rawUiImage!.height > 0) {
      if (_turns % 2 == 1) {
        imageAspect = _rawUiImage!.height / _rawUiImage!.width;
      } else {
        imageAspect = _rawUiImage!.width / _rawUiImage!.height;
      }
    }

    final matrix = _currentColorMatrix;

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Édition Photo & Rendu Radio',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Bouton Annuler (Undo)
          IconButton(
            icon: Icon(
              Icons.undo_rounded,
              color: _undoStack.isNotEmpty ? const Color(0xFF00E5FF) : Colors.white24,
            ),
            tooltip: 'Annuler étape (Undo)',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          // Bouton Rétablir (Redo)
          IconButton(
            icon: Icon(
              Icons.redo_rounded,
              color: _redoStack.isNotEmpty ? const Color(0xFF00E5FF) : Colors.white24,
            ),
            tooltip: 'Rétablir étape (Redo)',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          // Bouton Rotation
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded),
            tooltip: 'Pivoter 90°',
            onPressed: _rotate,
          ),
          // Réinitialiser tout
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Tout réinitialiser',
            onPressed: _resetAll,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Zone centrale d'aperçu de l'image ──
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: AspectRatio(
                    aspectRatio: imageAspect,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;

                        final rectPx = Rect.fromLTRB(
                          _cropLeft * w,
                          _cropTop * h,
                          _cropRight * w,
                          _cropBottom * h,
                        );

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 1. RepaintBoundary capturé (Image + Filtre + Masques + Annotations + Mire)
                            Positioned.fill(
                              child: RepaintBoundary(
                                key: _cropKey,
                                child: RotatedBox(
                                  quarterTurns: _turns,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: matrix != null
                                            ? ColorFiltered(
                                                colorFilter: ColorFilter.matrix(matrix),
                                                child: Image.file(
                                                  widget.imageFile,
                                                  fit: BoxFit.fill,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                ),
                                              )
                                            : Image.file(
                                                widget.imageFile,
                                                fit: BoxFit.fill,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                      ),
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _PhotoAnnotationPainter(
                                            strokes: [
                                              ..._blackStrokes,
                                              if (_currentStroke != null) _currentStroke!,
                                            ],
                                            maskTop: _maskTop,
                                            maskBottom: _maskBottom,
                                            maskLeft: _maskLeft,
                                            maskRight: _maskRight,
                                            annotations: _annotations,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 2. Traçage Pinceau / Gomme Fond Noir tactile
                            if (_currentTab == _EditorTab.blackBg)
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (details) {
                                    _recordState();
                                    final pos = details.localPosition;
                                    final norm = Offset((pos.dx / w).clamp(0.0, 1.0), (pos.dy / h).clamp(0.0, 1.0));
                                    if (_isEraser) {
                                      _eraseStrokeAt(norm, w, h);
                                    } else {
                                      setState(() {
                                        _currentStroke = _BlackMaskStroke([norm], _brushWidth);
                                      });
                                    }
                                  },
                                  onPanUpdate: (details) {
                                    final pos = details.localPosition;
                                    final norm = Offset((pos.dx / w).clamp(0.0, 1.0), (pos.dy / h).clamp(0.0, 1.0));
                                    if (_isEraser) {
                                      _eraseStrokeAt(norm, w, h);
                                    } else {
                                      setState(() {
                                        _currentStroke?.points.add(norm);
                                      });
                                    }
                                  },
                                  onPanEnd: (_) {
                                    if (!_isEraser && _currentStroke != null && _currentStroke!.points.isNotEmpty) {
                                      setState(() {
                                        _blackStrokes.add(_currentStroke!);
                                        _currentStroke = null;
                                      });
                                    }
                                  },
                                ),
                              ),

                            // 3. Poignées pour déplacer les étiquettes et l'échelle (Onglet 4 actif)
                            if (_currentTab == _EditorTab.annotations)
                              for (final item in _annotations)
                                Positioned(
                                  left: (item.pos.dx * w) - 8,
                                  top: (item.pos.dy * h) - 8,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _selectedAnnotationId = item.id;
                                        _annotationTextCtrl.text = item.text;
                                      });
                                    },
                                    onPanStart: (_) {
                                      _recordState();
                                      setState(() {
                                        _selectedAnnotationId = item.id;
                                        _annotationTextCtrl.text = item.text;
                                      });
                                    },
                                    onPanUpdate: (details) {
                                      setState(() {
                                        item.pos = Offset(
                                          (item.pos.dx + details.delta.dx / w).clamp(_cropLeft + 0.01, (_cropRight - 0.06).clamp(_cropLeft + 0.01, 0.95)),
                                          (item.pos.dy + details.delta.dy / h).clamp(_cropTop + 0.01, (_cropBottom - 0.06).clamp(_cropTop + 0.01, 0.95)),
                                        );
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _selectedAnnotationId == item.id ? const Color(0xFF00E5FF) : Colors.white30,
                                          width: _selectedAnnotationId == item.id ? 2.0 : 1.0,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        color: _selectedAnnotationId == item.id
                                            ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
                                            : Colors.black.withValues(alpha: 0.2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            item.type == _AnnotationType.scale ? Icons.straighten_rounded : Icons.open_with_rounded,
                                            size: 13,
                                            color: _selectedAnnotationId == item.id ? const Color(0xFF00E5FF) : Colors.white70,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.text.isNotEmpty ? item.text : '(vide)',
                                            style: TextStyle(
                                              color: _selectedAnnotationId == item.id ? Colors.white : Colors.white70,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_selectedAnnotationId == item.id) ...[
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () {
                                                _recordState();
                                                setState(() {
                                                  _annotations.removeWhere((a) => a.id == item.id);
                                                  _selectedAnnotationId = _annotations.isNotEmpty ? _annotations.first.id : null;
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                            // 4. Cadrage persistant sur tous les onglets :
                            // - Onglet Cadrage : masque semi-transparent + grille tiers + 4 poignées
                            // - Autres onglets : masque noir opaque 100% hors-cadre + bordure cyan du cadrage actif
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _CropOverlayPainter(
                                    rectPx,
                                    isCropTab: _currentTab == _EditorTab.crop,
                                  ),
                                ),
                              ),
                            ),
                            if (_currentTab == _EditorTab.crop) ...[
                              _buildHandle(rectPx.left - 18, rectPx.top - 18, (dx, dy) {
                                setState(() {
                                  _cropLeft = (_cropLeft + dx / w).clamp(0.0, _cropRight - 0.10);
                                  _cropTop = (_cropTop + dy / h).clamp(0.0, _cropBottom - 0.10);
                                });
                              }),
                              _buildHandle(rectPx.right - 18, rectPx.top - 18, (dx, dy) {
                                setState(() {
                                  _cropRight = (_cropRight + dx / w).clamp(_cropLeft + 0.10, 1.0);
                                  _cropTop = (_cropTop + dy / h).clamp(0.0, _cropBottom - 0.10);
                                });
                              }),
                              _buildHandle(rectPx.left - 18, rectPx.bottom - 18, (dx, dy) {
                                setState(() {
                                  _cropLeft = (_cropLeft + dx / w).clamp(0.0, _cropRight - 0.10);
                                  _cropBottom = (_cropBottom + dy / h).clamp(_cropTop + 0.10, 1.0);
                                });
                              }),
                              _buildHandle(rectPx.right - 18, rectPx.bottom - 18, (dx, dy) {
                                setState(() {
                                  _cropRight = (_cropRight + dx / w).clamp(_cropLeft + 0.10, 1.0);
                                  _cropBottom = (_cropBottom + dy / h).clamp(_cropTop + 0.10, 1.0);
                                });
                              }),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ── Navigation spacieuse par étapes / onglets (Workflow ordonné) ──
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0B132B),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  _navTab(_EditorTab.crop, Icons.crop_rounded, '1. Cadrage'),
                  const SizedBox(width: 4),
                  _navTab(_EditorTab.filter, Icons.tune_rounded, '2. Filtres Photo'),
                  const SizedBox(width: 4),
                  _navTab(_EditorTab.blackBg, Icons.brush_rounded, '3. Fond Noir'),
                  const SizedBox(width: 4),
                  _navTab(_EditorTab.annotations, Icons.label_important_rounded, '4. Étiquettes / Échelle'),
                ],
              ),
            ),

            // ── Panneau de réglages dédié & aéré ──
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: const Color(0xFF0F172A),
              constraints: const BoxConstraints(minHeight: 125),
              child: _buildSelectedTabContent(),
            ),

            // ── Boutons d'action principaux (Annuler / Valider) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              color: const Color(0xFF0B132B),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                      ),
                      onPressed: _processing ? null : _cropAndSave,
                      icon: _processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        _processing ? 'Traitement…' : 'Valider la Photo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  Widget _navTab(_EditorTab tab, IconData icon, String title) {
    final isSelected = _currentTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentTab = tab;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? const Color(0xFF00E5FF) : Colors.white70),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_currentTab) {
      case _EditorTab.crop:
        return _buildCropPanel();
      case _EditorTab.filter:
        return _buildFilterPanel();
      case _EditorTab.blackBg:
        return _buildBlackBgPanel();
      case _EditorTab.annotations:
        return _buildAnnotationsPanel();
    }
  }

  // ── 1. Panneau Cadrage & Plein Cadre ──
  Widget _buildCropPanel() {
    final isFullCrop = _cropLeft == 0.0 && _cropTop == 0.0 && _cropRight == 1.0 && _cropBottom == 1.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.crop_free_rounded, color: Color(0xFF00E5FF), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ajustez les 4 coins pour découper la zone de soudure',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isFullCrop ? Colors.white38 : const Color(0xFF00E5FF),
                side: BorderSide(color: isFullCrop ? Colors.white24 : const Color(0xFF00E5FF)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                _recordState();
                setState(() {
                  _cropLeft = 0.0;
                  _cropTop = 0.0;
                  _cropRight = 1.0;
                  _cropBottom = 1.0;
                });
              },
              icon: const Icon(Icons.fullscreen_rounded, size: 16),
              label: const Text('Plein cadre', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _rotate,
              icon: const Icon(Icons.rotate_right_rounded, size: 18),
              label: Text('Pivoter (${_turns * 90}°)', style: const TextStyle(fontSize: 11.5)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => setState(() => _currentTab = _EditorTab.filter),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Étape 2 : Filtres Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2. Panneau Filtres Photo (Couleur réelle & Radio) ──
  Widget _buildFilterPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterCard(
                preset: _RadioFilterPreset.original,
                icon: Icons.palette_outlined,
                title: 'Original',
                subtitle: 'Couleur réelle',
              ),
              const SizedBox(width: 8),
              _filterCard(
                preset: _RadioFilterPreset.colorEnhanced,
                icon: Icons.color_lens_rounded,
                title: 'Couleur +',
                subtitle: 'Vives & Net',
              ),
              const SizedBox(width: 8),
              _filterCard(
                preset: _RadioFilterPreset.radioMacro,
                icon: Icons.filter_b_and_w_rounded,
                title: 'Radio Macro',
                subtitle: 'N&B Recommandé',
              ),
              const SizedBox(width: 8),
              _filterCard(
                preset: _RadioFilterPreset.radioHighContrast,
                icon: Icons.contrast_rounded,
                title: 'Contraste +',
                subtitle: 'N&B Sombre',
              ),
              const SizedBox(width: 8),
              _filterCard(
                preset: _RadioFilterPreset.radioMetallo,
                icon: Icons.biotech_rounded,
                title: 'Métallo ZAT',
                subtitle: 'N&B Structure',
              ),
              const SizedBox(width: 8),
              _filterCard(
                preset: _RadioFilterPreset.radioNegative,
                icon: Icons.invert_colors_rounded,
                title: 'Négatif RX',
                subtitle: 'Film radio',
              ),
              const SizedBox(width: 8),
              _filterCard(
                preset: _RadioFilterPreset.radioBinarize,
                icon: Icons.dark_mode_rounded,
                title: 'Binarisation',
                subtitle: 'Seuil N&B',
              ),
              const SizedBox(width: 8),
              _filterCard(
                preset: _RadioFilterPreset.custom,
                icon: Icons.tune_rounded,
                title: 'Curseurs',
                subtitle: 'Ajustements',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildCustomSliders(),
      ],
    );
  }

  Widget _filterCard({
    required _RadioFilterPreset preset,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _filterPreset == preset;
    return InkWell(
      onTap: () {
        _recordState();
        setState(() {
          _filterPreset = preset;
          if (preset == _RadioFilterPreset.original) {
            _customContrast = 1.00;
            _customBrightness = 0.0;
            _customBlackVolume = 0.0;
            _customSaturation = 1.00;
            _customKeepColor = true;
            _customInvert = false;
          } else if (preset == _RadioFilterPreset.colorEnhanced) {
            _customContrast = 1.25;
            _customBrightness = 6.0;
            _customBlackVolume = 0.0;
            _customSaturation = 1.30;
            _customKeepColor = true;
            _customInvert = false;
          } else if (preset == _RadioFilterPreset.radioMacro) {
            _customContrast = 1.45;
            _customBrightness = 5.0;
            _customBlackVolume = 0.0;
            _customSaturation = 0.0;
            _customKeepColor = false;
            _customInvert = false;
          } else if (preset == _RadioFilterPreset.radioHighContrast) {
            _customContrast = 1.90;
            _customBrightness = 10.0;
            _customBlackVolume = 15.0;
            _customSaturation = 0.0;
            _customKeepColor = false;
            _customInvert = false;
          } else if (preset == _RadioFilterPreset.radioMetallo) {
            _customContrast = 2.30;
            _customBrightness = -4.0;
            _customBlackVolume = 25.0;
            _customSaturation = 0.0;
            _customKeepColor = false;
            _customInvert = false;
          } else if (preset == _RadioFilterPreset.radioNegative) {
            _customContrast = 1.35;
            _customBrightness = 0.0;
            _customBlackVolume = 0.0;
            _customSaturation = 0.0;
            _customKeepColor = false;
            _customInvert = true;
          } else if (preset == _RadioFilterPreset.radioBinarize) {
            _customContrast = 3.20;
            _customBrightness = -15.0;
            _customBlackVolume = 40.0;
            _customSaturation = 0.0;
            _customKeepColor = false;
            _customInvert = false;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 102,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF14B8A6) : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF00E5FF)),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 8.5,
                color: isSelected ? Colors.white.withValues(alpha: 0.85) : Colors.white38,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSliders() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Bascule Mode Couleur vs N&B Radio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  _recordState();
                  setState(() {
                    _customKeepColor = true;
                    _filterPreset = _RadioFilterPreset.custom;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _customKeepColor ? const Color(0xFF0D9488) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.palette_rounded, size: 14, color: _customKeepColor ? Colors.white : Colors.white70),
                      const SizedBox(width: 4),
                      Text('🎨 Couleurs d\'origine', style: TextStyle(color: _customKeepColor ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  _recordState();
                  setState(() {
                    _customKeepColor = false;
                    _filterPreset = _RadioFilterPreset.custom;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: !_customKeepColor ? const Color(0xFF0D9488) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_b_and_w_rounded, size: 14, color: !_customKeepColor ? Colors.white : Colors.white70),
                      const SizedBox(width: 4),
                      Text('📻 N&B Radio RX', style: TextStyle(color: !_customKeepColor ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white60,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  _recordState();
                  setState(() {
                    _customContrast = 1.00;
                    _customBrightness = 0.0;
                    _customBlackVolume = 0.0;
                    _customSaturation = 1.00;
                    _customKeepColor = true;
                    _customInvert = false;
                    _filterPreset = _RadioFilterPreset.original;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 13),
                label: const Text('Réinitialiser', style: TextStyle(fontSize: 10.5)),
              ),
            ],
          ),

          const Divider(color: Colors.white12, height: 10),

          // Slider Contraste
          Row(
            children: [
              const Icon(Icons.contrast_rounded, size: 15, color: Color(0xFF00E5FF)),
              const SizedBox(width: 6),
              SizedBox(
                width: 110,
                child: Text(
                  'Contraste : ${_customContrast.toStringAsFixed(2)}x',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Slider(
                  value: _customContrast,
                  min: 0.5,
                  max: 3.5,
                  activeColor: const Color(0xFF00E5FF),
                  inactiveColor: Colors.white24,
                  onChangeStart: (_) => _recordState(),
                  onChanged: (val) {
                    setState(() {
                      _customContrast = val;
                      _filterPreset = _RadioFilterPreset.custom;
                    });
                  },
                ),
              ),
            ],
          ),
          // Slider Luminosité
          Row(
            children: [
              const Icon(Icons.brightness_6_rounded, size: 15, color: Color(0xFF00E5FF)),
              const SizedBox(width: 6),
              SizedBox(
                width: 110,
                child: Text(
                  'Luminosité : ${_customBrightness > 0 ? '+' : ''}${_customBrightness.toInt()}',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Slider(
                  value: _customBrightness,
                  min: -80,
                  max: 80,
                  activeColor: const Color(0xFF00E5FF),
                  inactiveColor: Colors.white24,
                  onChangeStart: (_) => _recordState(),
                  onChanged: (val) {
                    setState(() {
                      _customBrightness = val;
                      _filterPreset = _RadioFilterPreset.custom;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_customKeepColor) ...[
            // Slider Saturation Couleur
            Row(
              children: [
                const Icon(Icons.color_lens_rounded, size: 15, color: Color(0xFF00E5FF)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 110,
                  child: Text(
                    'Couleurs : ${_customSaturation.toStringAsFixed(2)}x',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _customSaturation,
                    min: 0.0,
                    max: 2.5,
                    activeColor: const Color(0xFF00E5FF),
                    inactiveColor: Colors.white24,
                    onChangeStart: (_) => _recordState(),
                    onChanged: (val) {
                      setState(() {
                        _customSaturation = val;
                        _filterPreset = _RadioFilterPreset.custom;
                      });
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            // Slider Volume & Profondeur des Noirs
            Row(
              children: [
                const Icon(Icons.exposure_rounded, size: 15, color: Color(0xFF00E5FF)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 110,
                  child: Text(
                    'Volume Noirs : ${_customBlackVolume > 0 ? '+' : ''}${_customBlackVolume.toInt()}',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _customBlackVolume,
                    min: -60,
                    max: 80,
                    activeColor: const Color(0xFF00E5FF),
                    inactiveColor: Colors.white24,
                    onChangeStart: (_) => _recordState(),
                    onChanged: (val) {
                      setState(() {
                        _customBlackVolume = val;
                        _filterPreset = _RadioFilterPreset.custom;
                      });
                    },
                  ),
                ),
              ],
            ),
            // Bascule Négatif RX
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    _recordState();
                    setState(() {
                      _customInvert = !_customInvert;
                      _filterPreset = _RadioFilterPreset.custom;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _customInvert ? const Color(0xFF0D9488) : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.invert_colors_rounded, size: 14, color: _customInvert ? Colors.white : Colors.white70),
                        const SizedBox(width: 4),
                        Text('Négatif RX : ${_customInvert ? "OUI" : "NON"}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. Panneau Fond Noir (Remplacement total, Gomme, Pinceau & Masques) ──
  Widget _buildBlackBgPanel() {
    final hasBlackApplied = _maskTop > 0 || _maskBottom < 1.0 || _maskLeft > 0 || _maskRight < 1.0 || _blackStrokes.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Boutons rapides : Remplacer tout en noir / Supprimer tout le noir
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFF00E5FF),
                  side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _recordState();
                  setState(() {
                    // Masque tout le fond périphérique en noir pur
                    _maskTop = 0.22;
                    _maskBottom = 0.78;
                    _maskLeft = 0.05;
                    _maskRight = 0.95;
                  });
                },
                icon: const Icon(Icons.format_color_fill_rounded, size: 16),
                label: const Text('⬛ Remplir tout en Noir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: hasBlackApplied ? Colors.amberAccent : Colors.white38,
                  side: BorderSide(color: hasBlackApplied ? Colors.amberAccent.withValues(alpha: 0.6) : Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: hasBlackApplied
                    ? () {
                        _recordState();
                        setState(() {
                          _maskTop = 0.0;
                          _maskBottom = 1.0;
                          _maskLeft = 0.0;
                          _maskRight = 1.0;
                          _blackStrokes.clear();
                        });
                      }
                    : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('🗑️ Supprimer Fond Noir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Sélecteur Mode Pinceau Noir vs Gomme + Taille
        Row(
          children: [
            // Mode Pinceau
            InkWell(
              onTap: () => setState(() => _isEraser = false),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: !_isEraser ? const Color(0xFF0D9488) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: !_isEraser ? const Color(0xFF14B8A6) : Colors.white24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.brush_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Pinceau Noir', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Mode Gomme
            InkWell(
              onTap: () => setState(() => _isEraser = true),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isEraser ? Colors.amber.shade800 : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isEraser ? Colors.amberAccent : Colors.white24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_fix_high_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Gomme', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Taille
            const Text('Taille :', style: TextStyle(color: Colors.white70, fontSize: 11)),
            Expanded(
              child: Slider(
                value: _brushWidth,
                min: 8.0,
                max: 60.0,
                activeColor: _isEraser ? Colors.amberAccent : const Color(0xFF00E5FF),
                inactiveColor: Colors.white24,
                onChanged: (val) => setState(() => _brushWidth = val),
              ),
            ),
            Text('${_brushWidth.toInt()}px', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),

        // Curseurs fins de masquage Haut & Bas
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Text('Masque Haut :', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                  Expanded(
                    child: Slider(
                      value: _maskTop,
                      min: 0.0,
                      max: 0.45,
                      activeColor: Colors.white70,
                      inactiveColor: Colors.white24,
                      onChangeStart: (_) => _recordState(),
                      onChanged: (val) => setState(() => _maskTop = val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  const Text('Masque Bas :', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                  Expanded(
                    child: Slider(
                      value: _maskBottom,
                      min: 0.55,
                      max: 1.0,
                      activeColor: Colors.white70,
                      inactiveColor: Colors.white24,
                      onChangeStart: (_) => _recordState(),
                      onChanged: (val) => setState(() => _maskBottom = val),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 4. Panneau Étiquettes, Commentaires & Échelle ──
  Widget _buildAnnotationsPanel() {
    final selected = _currentSelectedAnnotation;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barre supérieure : Ajout d'étiquette, d'échelle et liste des éléments actifs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Bouton Ajouter Étiquette / Commentaire
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _recordState();
                  final newId = DateTime.now().millisecondsSinceEpoch.toString();
                  final existingTexts = _annotations.map((a) => a.text).toSet();
                  String nextLabel = '(a)';
                  for (final candidate in ['(a)', '(b)', '(c)', '(d)', '(e)', '(f)']) {
                    if (!existingTexts.contains(candidate)) {
                      nextLabel = candidate;
                      break;
                    }
                  }
                  setState(() {
                    _annotations.add(
                      _PhotoAnnotationItem(
                        id: newId,
                        type: _AnnotationType.label,
                        text: nextLabel,
                        pos: Offset(
                          (_cropLeft + 0.04).clamp(0.02, 0.85),
                          (_cropTop + 0.04).clamp(0.02, 0.85),
                        ),
                        fontSize: 22.0,
                        hasBadge: false,
                        color: Colors.white,
                      ),
                    );
                    _selectedAnnotationId = newId;
                    _annotationTextCtrl.text = nextLabel;
                  });
                },
                icon: const Icon(Icons.add_comment_rounded, size: 15),
                label: const Text('+ Étiquette', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              // Bouton Ajouter Échelle / Règle mm
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFF00E5FF),
                  side: const BorderSide(color: Color(0xFF00E5FF)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _recordState();
                  final newId = DateTime.now().millisecondsSinceEpoch.toString();
                  setState(() {
                    _annotations.add(
                      _PhotoAnnotationItem(
                        id: newId,
                        type: _AnnotationType.scale,
                        text: '10 mm',
                        pos: Offset(
                          (_cropRight - 0.24).clamp(_cropLeft + 0.02, 0.75),
                          (_cropBottom - 0.10).clamp(_cropTop + 0.02, 0.88),
                        ),
                        fontSize: 14.0,
                        scaleWidthNorm: 0.22,
                        color: Colors.white,
                      ),
                    );
                    _selectedAnnotationId = newId;
                    _annotationTextCtrl.text = '10 mm';
                  });
                },
                icon: const Icon(Icons.straighten_rounded, size: 15),
                label: const Text('+ Échelle mm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              // Liste des éléments sur la photo
              if (_annotations.isNotEmpty) ...[
                const Text('Sur photo :', style: TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(width: 6),
                ..._annotations.map((item) {
                  final isSel = item.id == _selectedAnnotationId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAnnotationId = item.id;
                          _annotationTextCtrl.text = item.text;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? Colors.white : Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.type == _AnnotationType.scale ? Icons.straighten_rounded : Icons.label_rounded,
                              size: 13,
                              color: isSel ? Colors.black : Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.text.isNotEmpty ? item.text : '(vide)',
                              style: TextStyle(
                                color: isSel ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Détails et réglages de l'annotation active
        if (selected != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Champ de texte et boutons rapides
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _annotationTextCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: selected.type == _AnnotationType.scale ? 'Ex: 10 mm, 5 mm…' : 'Texte ou commentaire…',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                            ),
                          ),
                          onChanged: (val) {
                            _recordState();
                            setState(() => selected.text = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bouton Supprimer
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.amberAccent, size: 20),
                      tooltip: 'Supprimer cet élément',
                      onPressed: () {
                        _recordState();
                        setState(() {
                          _annotations.removeWhere((a) => a.id == selected.id);
                          _selectedAnnotationId = _annotations.isNotEmpty ? _annotations.first.id : null;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // 2. Suggestions / Raccourcis rapides
                if (selected.type == _AnnotationType.label) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        '(a)', '(b)', '(c)', '(d)', '(1)', '(2)',
                        'Zone Fondue (ZF)', 'ZAT', 'Métal Base (MB)', 'Racine', 'Passe finale', 'Défaut', 'Fissure', 'Porosité'
                      ].map((tag) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              _recordState();
                              setState(() {
                                selected.text = tag;
                                _annotationTextCtrl.text = tag;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected.text == tag ? const Color(0xFF00E5FF) : Colors.white10,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: selected.text == tag ? Colors.black : Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['1 mm', '2 mm', '5 mm', '10 mm', '20 mm', '50 mm'].map((s) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              _recordState();
                              setState(() {
                                selected.text = s;
                                _annotationTextCtrl.text = s;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected.text == s ? const Color(0xFF00E5FF) : Colors.white10,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  color: selected.text == s ? Colors.black : Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                // 3. Choix de couleur de repère / étiquette
                Row(
                  children: [
                    const Text('Couleur :', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Colors.white,
                            const Color(0xFFFFEA00), // Jaune vif
                            const Color(0xFF00E5FF), // Cyan
                            const Color(0xFF00FF66), // Vert néon
                            const Color(0xFFFF9100), // Orange
                            const Color(0xFFFF007F), // Rose flash
                            const Color(0xFFE040FB), // Magenta
                            Colors.black,
                          ].map((c) {
                            final isSel = selected.color == c;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () {
                                  _recordState();
                                  setState(() => selected.color = c);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF00E5FF) : Colors.white60,
                                      width: isSel ? 2.5 : 1.0,
                                    ),
                                    boxShadow: isSel ? [const BoxShadow(color: Color(0xFF00E5FF), blurRadius: 4)] : null,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // 4. Épaisseur de trait et Taille du texte
                Row(
                  children: [
                    const Text('Trait :', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 16, color: Colors.white),
                      onPressed: () {
                        _recordState();
                        setState(() => selected.strokeWidth = (selected.strokeWidth - 0.5).clamp(0.8, 6.0));
                      },
                    ),
                    Text('${selected.strokeWidth.toStringAsFixed(1)}px', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
                      onPressed: () {
                        _recordState();
                        setState(() => selected.strokeWidth = (selected.strokeWidth + 0.5).clamp(0.8, 6.0));
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Taille :', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Expanded(
                      child: Slider(
                        value: selected.fontSize,
                        min: 12.0,
                        max: 42.0,
                        activeColor: const Color(0xFF00E5FF),
                        inactiveColor: Colors.white24,
                        onChangeStart: (_) => _recordState(),
                        onChanged: (val) => setState(() => selected.fontSize = val),
                      ),
                    ),
                    Text('${selected.fontSize.toInt()}pt', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    if (selected.type == _AnnotationType.label) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          _recordState();
                          setState(() => selected.hasBadge = !selected.hasBadge);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected.hasBadge ? const Color(0xFF0D9488) : Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: selected.hasBadge ? const Color(0xFF14B8A6) : Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(selected.hasBadge ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 13, color: Colors.white),
                              const SizedBox(width: 3),
                              const Text('Badge', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              '💡 Touchez une étiquette sur la photo ou cliquez sur "+ Étiquette" pour en ajouter une.',
              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHandle(double x, double y, void Function(double dx, double dy) onPan) {
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _recordState(),
        onPanUpdate: (details) => onPan(details.delta.dx, details.delta.dy),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 4, spreadRadius: 1),
            ],
          ),
          child: const Icon(Icons.touch_app_rounded, size: 18, color: Colors.black),
        ),
      ),
    );
  }
}

class _PhotoAnnotationPainter extends CustomPainter {
  final List<_BlackMaskStroke> strokes;
  final double maskTop;
  final double maskBottom;
  final double maskLeft;
  final double maskRight;
  final List<_PhotoAnnotationItem> annotations;

  _PhotoAnnotationPainter({
    required this.strokes,
    required this.maskTop,
    required this.maskBottom,
    required this.maskLeft,
    required this.maskRight,
    required this.annotations,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final blackPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;

    // 1. Masques périphériques Haut / Bas / Gauche / Droite
    if (maskTop > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, maskTop * h), blackPaint);
    }
    if (maskBottom < 1.0) {
      canvas.drawRect(Rect.fromLTWH(0, maskBottom * h, w, (1.0 - maskBottom) * h), blackPaint);
    }
    if (maskLeft > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, maskLeft * w, h), blackPaint);
    }
    if (maskRight < 1.0) {
      canvas.drawRect(Rect.fromLTWH(maskRight * w, 0, (1.0 - maskRight) * w, h), blackPaint);
    }

    // 2. Traits de pinceau Fond Noir
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final strokePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (stroke.points.length == 1) {
        final pt = Offset(stroke.points[0].dx * w, stroke.points[0].dy * h);
        canvas.drawCircle(pt, stroke.strokeWidth / 2, blackPaint);
      } else {
        final path = Path();
        path.moveTo(stroke.points[0].dx * w, stroke.points[0].dy * h);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx * w, stroke.points[i].dy * h);
        }
        canvas.drawPath(path, strokePaint);
      }
    }

    // 3. Annotations multiples (Étiquettes, Commentaires & Échelles)
    for (final item in annotations) {
      if (item.text.isEmpty) continue;

      if (item.type == _AnnotationType.label) {
        final textSpan = TextSpan(
          text: item.text,
          style: TextStyle(
            color: item.color,
            fontSize: item.fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
            shadows: item.hasBadge
                ? null
                : const [
                    Shadow(color: Colors.black, blurRadius: 6, offset: Offset(2, 2)),
                    Shadow(color: Colors.black, blurRadius: 6, offset: Offset(-1, -1)),
                  ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();

        final posX = (item.pos.dx * w).clamp(0.0, w - textPainter.width);
        final posY = (item.pos.dy * h).clamp(0.0, h - textPainter.height);

        if (item.hasBadge) {
          const padH = 6.0;
          const padV = 3.0;
          final bgRect = Rect.fromLTWH(
            posX - padH,
            posY - padV,
            textPainter.width + padH * 2,
            textPainter.height + padV * 2,
          );
          final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.85);
          final borderPaint = Paint()
            ..color = item.color.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = item.strokeWidth.clamp(0.8, 6.0);
          canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), bgPaint);
          canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), borderPaint);
        }

        textPainter.paint(canvas, Offset(posX, posY));
      } else if (item.type == _AnnotationType.scale) {
        // Règle / Mire graduée
        final scaleWidth = (w * item.scaleWidthNorm).clamp(45.0, 160.0);
        final scaleHeight = (scaleWidth * 0.25).clamp(16.0, 32.0);
        final posX = (item.pos.dx * w).clamp(0.0, w - scaleWidth);
        final posY = (item.pos.dy * h).clamp(0.0, h - scaleHeight - 20);

        final bgRect = Rect.fromLTWH(posX, posY, scaleWidth, scaleHeight);
        final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
        canvas.drawRect(bgRect, bgPaint);

        final borderPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = item.strokeWidth.clamp(0.8, 6.0);
        canvas.drawRect(bgRect, borderPaint);

        final tickPaint = Paint()
          ..color = Colors.black
          ..strokeWidth = item.strokeWidth.clamp(0.8, 5.0);
        const int numDivisions = 5;
        final step = scaleWidth / numDivisions;
        for (int i = 0; i <= numDivisions; i++) {
          final x = posX + i * step;
          final isMajor = (i == 0 || i == numDivisions || i == numDivisions ~/ 2);
          final tickH = isMajor ? scaleHeight * 0.70 : scaleHeight * 0.40;
          canvas.drawLine(Offset(x, posY), Offset(x, posY + tickH), tickPaint);
        }

        // Texte sous la mire
        final textSpan = TextSpan(
          text: item.text,
          style: TextStyle(
            color: item.color == Colors.black ? Colors.black : item.color,
            fontSize: item.fontSize,
            fontWeight: FontWeight.bold,
            shadows: item.color == Colors.black
                ? const [Shadow(color: Colors.white, blurRadius: 4)]
                : const [
                    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1.5, 1.5)),
                  ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();
        final textPosX = posX + (scaleWidth - textPainter.width) / 2;
        textPainter.paint(canvas, Offset(textPosX, posY + scaleHeight + 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PhotoAnnotationPainter old) => true;
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  final bool isCropTab;

  _CropOverlayPainter(this.cropRect, {this.isCropTab = true});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    // En onglet Cadrage : masque semi-transparent noir à 60% pour visualiser la découpe
    // Dans les autres onglets : masque NOIR OPAQUE 100% pour que la zone hors-cadre reste masquée
    final maskPaint = Paint()
      ..color = isCropTab ? Colors.black.withValues(alpha: 0.60) : Colors.black;

    final path = Path()
      ..addRect(fullRect)
      ..addRect(cropRect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, maskPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCropTab ? 2.0 : 1.5;
    canvas.drawRect(cropRect, borderPaint);

    if (isCropTab) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final wThird = cropRect.width / 3;
      final hThird = cropRect.height / 3;

      canvas.drawLine(Offset(cropRect.left + wThird, cropRect.top), Offset(cropRect.left + wThird, cropRect.bottom), gridPaint);
      canvas.drawLine(Offset(cropRect.left + 2 * wThird, cropRect.top), Offset(cropRect.left + 2 * wThird, cropRect.bottom), gridPaint);
      canvas.drawLine(Offset(cropRect.left, cropRect.top + hThird), Offset(cropRect.right, cropRect.top + hThird), gridPaint);
      canvas.drawLine(Offset(cropRect.left, cropRect.top + 2 * hThird), Offset(cropRect.right, cropRect.top + 2 * hThird), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.isCropTab != isCropTab;
  }
}
