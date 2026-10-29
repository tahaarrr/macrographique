import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PhotoMeasureResult {
  final String epReel;
  final String grossissement;
  final String surepExt;
  final String surepInt;
  final String largeurExt;
  final String largeurInt;
  final String penetrationExt;
  final String penetrationInt;
  final String desaxage;
  final String interpenetration;
  final String? annotatedPhotoPath;
  final String? rawPhotoPath;
  final String? measureData;

  PhotoMeasureResult({
    required this.epReel,
    required this.grossissement,
    required this.surepExt,
    required this.surepInt,
    required this.largeurExt,
    required this.largeurInt,
    required this.penetrationExt,
    required this.penetrationInt,
    required this.desaxage,
    required this.interpenetration,
    this.annotatedPhotoPath,
    this.rawPhotoPath,
    this.measureData,
  });
}

class PhotoMeasureScreen extends StatefulWidget {
  final String photoPath;
  final String? rawPhotoPath;
  final String? initialMeasureData;
  final double photoHeightPdf; // hauteur slider PDF (ex: 150 px)
  final String initialGrossissement;
  final String initialEpReel;
  final String initialSurepExt;
  final String initialSurepInt;
  final String initialLargeurExt;
  final String initialLargeurInt;
  final String initialPenetrationExt;
  final String initialPenetrationInt;
  final String initialDesaxage;
  final String initialInterpenetration;

  const PhotoMeasureScreen({
    super.key,
    required this.photoPath,
    this.rawPhotoPath,
    this.initialMeasureData,
    this.photoHeightPdf = 150,
    this.initialGrossissement = '1,8',
    this.initialEpReel = '11',
    this.initialSurepExt = '1,66',
    this.initialSurepInt = '1,66',
    this.initialLargeurExt = '15',
    this.initialLargeurInt = '12,77',
    this.initialPenetrationExt = '68,18',
    this.initialPenetrationInt = '55,54',
    this.initialDesaxage = '0',
    this.initialInterpenetration = '2,22',
  });

  @override
  State<PhotoMeasureScreen> createState() => _PhotoMeasureScreenState();
}

class _PhotoMeasureScreenState extends State<PhotoMeasureScreen> {
  late TextEditingController _grossissementCtrl;
  late TextEditingController _epReelCtrl;
  late TextEditingController _epMesureePhotoCtrl;

  late TextEditingController _surepExtCtrl;
  late TextEditingController _surepIntCtrl;
  late TextEditingController _largeurExtCtrl;
  late TextEditingController _largeurIntCtrl;
  late TextEditingController _pExtMmCtrl;
  late TextEditingController _pIntMmCtrl;
  late TextEditingController _pExtPctCtrl;
  late TextEditingController _pIntPctCtrl;
  late TextEditingController _desaxageCtrl;
  late TextEditingController _interpCtrl;

  // Active handle filter mode ('all', 'ext', 'int', 'epaisseur', 'desaxage')
  String _activeMode = 'ext';

  // Measurement handles on the image (relative coordinates 0.0 - 1.0)
  Offset _epTop = const Offset(0.5, 0.3);
  Offset _epBottom = const Offset(0.5, 0.7);

  Offset _extTop = const Offset(0.5, 0.22);
  Offset _extLeft = const Offset(0.35, 0.3);
  Offset _extRight = const Offset(0.65, 0.3);
  Offset _extDeep = const Offset(0.5, 0.55);

  Offset _intBottom = const Offset(0.5, 0.78);
  Offset _intLeft = const Offset(0.38, 0.7);
  Offset _intRight = const Offset(0.62, 0.7);
  Offset _intDeep = const Offset(0.5, 0.45);

  // Poignées de flanc ajustables (Bézier Cubique : 2 points de contrôle par quadrant)
  // Cordon EXT Pénétration (gauche + droite)
  Offset? _extFlankLeft1, _extFlankLeft2;
  Offset? _extFlankRight1, _extFlankRight2;
  // Cordon EXT Chapeau / Surépaisseur (gauche + droite)
  Offset? _extCapFlankLeft1, _extCapFlankLeft2;
  Offset? _extCapFlankRight1, _extCapFlankRight2;

  // Cordon INT Pénétration (gauche + droite)
  Offset? _intFlankLeft1, _intFlankLeft2;
  Offset? _intFlankRight1, _intFlankRight2;
  // Cordon INT Chapeau / Surépaisseur (gauche + droite)
  Offset? _intCapFlankLeft1, _intCapFlankLeft2;
  Offset? _intCapFlankRight1, _intCapFlankRight2;

  // Option de masquage des repères pour schéma épuré / propre
  bool _showHandles = true;

  // Verrouillage des repères pour éviter les déplacements accidentels
  bool _isLocked = false;

  // Épaisseur de trait des repères (réglable de 0.8px à 6.0px)
  double _repereThickness = 2.4;

  // Thème de couleur des repères : 'auto' (adaptatif selon le filtre), 'fluo', 'bw_highvis', 'rx_neon', 'monochrome_white', 'monochrome_yellow'
  String _repereTheme = 'auto';

  // Rendu / Filtre Radio en direct pendant la mesure (par défaut 'none' pour préserver les vraies couleurs)
  String _displayFilter = 'none'; // none, radio_macro, contrast, negative

  List<double>? get _measureFilterMatrix {
    switch (_displayFilter) {
      case 'radio_macro':
        return _buildColorMatrix(contrast: 1.45, brightness: 5.0, invert: false);
      case 'contrast':
        return _buildColorMatrix(contrast: 1.90, brightness: 10.0, invert: false);
      case 'negative':
        return _buildColorMatrix(contrast: 1.35, brightness: 0.0, invert: true);
      case 'none':
      default:
        return null;
    }
  }

  static List<double> _buildColorMatrix({
    required double contrast,
    required double brightness,
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
        ? 128.0 * (1.0 + c) + brightness
        : 128.0 * (1.0 - c) + brightness;

    return <double>[
      r, g, b, 0, offset,
      r, g, b, 0, offset,
      r, g, b, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  void _resetAllHandles() {
    setState(() {
      _epTop = const Offset(0.5, 0.3);
      _epBottom = const Offset(0.5, 0.7);

      _extTop = const Offset(0.5, 0.22);
      _extLeft = const Offset(0.35, 0.3);
      _extRight = const Offset(0.65, 0.3);
      _extDeep = const Offset(0.5, 0.55);

      _intBottom = const Offset(0.5, 0.78);
      _intLeft = const Offset(0.38, 0.7);
      _intRight = const Offset(0.62, 0.7);
      _intDeep = const Offset(0.5, 0.45);

      _extFlankLeft1 = null; _extFlankLeft2 = null;
      _extFlankRight1 = null; _extFlankRight2 = null;
      _extCapFlankLeft1 = null; _extCapFlankLeft2 = null;
      _extCapFlankRight1 = null; _extCapFlankRight2 = null;

      _intFlankLeft1 = null; _intFlankLeft2 = null;
      _intFlankRight1 = null; _intFlankRight2 = null;
      _intCapFlankLeft1 = null; _intCapFlankLeft2 = null;
      _intCapFlankRight1 = null; _intCapFlankRight2 = null;

      _manualInterLeft = null;
      _manualInterRight = null;
      _hGuides.clear();
      _vGuides.clear();

      if (_lastCanvasSize != null) {
        _recalculateFromHandles(_lastCanvasSize!);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Tous les repères et guides ont été réinitialisés aux valeurs par défaut.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _resetFlanksOnly() {
    setState(() {
      _extFlankLeft1 = null; _extFlankLeft2 = null;
      _extFlankRight1 = null; _extFlankRight2 = null;
      _extCapFlankLeft1 = null; _extCapFlankLeft2 = null;
      _extCapFlankRight1 = null; _extCapFlankRight2 = null;

      _intFlankLeft1 = null; _intFlankLeft2 = null;
      _intFlankRight1 = null; _intFlankRight2 = null;
      _intCapFlankLeft1 = null; _intCapFlankLeft2 = null;
      _intCapFlankRight1 = null; _intCapFlankRight2 = null;

      if (_lastCanvasSize != null) {
        _recalculateFromHandles(_lastCanvasSize!);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('〰️ Courbes et flancs réinitialisés aux formes lisses.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAllGuides() {
    setState(() {
      _hGuides.clear();
      _vGuides.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧹 Tous les guides repères ont été supprimés.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _resetAutoIntersections() {
    setState(() {
      _manualInterLeft = null;
      _manualInterRight = null;
      if (_lastCanvasSize != null) {
        _recalculateFromHandles(_lastCanvasSize!);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎯 Points d\'intersection M1/M2 recalculés automatiquement.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Getters EXT Pénétration Gauche (extLeft -> extDeep)
  Offset get _effectiveExtFlankLeft1 => _extFlankLeft1 ?? Offset(
    _extLeft.dx * 0.67 + _extDeep.dx * 0.33,
    _extLeft.dy * 0.67 + _extDeep.dy * 0.33,
  );
  Offset get _effectiveExtFlankLeft2 => _extFlankLeft2 ?? Offset(
    _extLeft.dx * 0.33 + _extDeep.dx * 0.67,
    _extLeft.dy * 0.33 + _extDeep.dy * 0.67,
  );

  // Getters EXT Pénétration Droite (extDeep -> extRight)
  Offset get _effectiveExtFlankRight1 => _extFlankRight1 ?? Offset(
    _extDeep.dx * 0.67 + _extRight.dx * 0.33,
    _extDeep.dy * 0.67 + _extRight.dy * 0.33,
  );
  Offset get _effectiveExtFlankRight2 => _extFlankRight2 ?? Offset(
    _extDeep.dx * 0.33 + _extRight.dx * 0.67,
    _extDeep.dy * 0.33 + _extRight.dy * 0.67,
  );

  // Getters EXT Chapeau Droit (extRight -> extTop)
  Offset get _effectiveExtCapFlankRight1 => _extCapFlankRight1 ?? Offset(
    _extRight.dx * 0.67 + _extTop.dx * 0.33,
    _extRight.dy * 0.67 + _extTop.dy * 0.33,
  );
  Offset get _effectiveExtCapFlankRight2 => _extCapFlankRight2 ?? Offset(
    _extRight.dx * 0.33 + _extTop.dx * 0.67,
    _extRight.dy * 0.33 + _extTop.dy * 0.67,
  );

  // Getters EXT Chapeau Gauche (extTop -> extLeft)
  Offset get _effectiveExtCapFlankLeft1 => _extCapFlankLeft1 ?? Offset(
    _extTop.dx * 0.67 + _extLeft.dx * 0.33,
    _extTop.dy * 0.67 + _extLeft.dy * 0.33,
  );
  Offset get _effectiveExtCapFlankLeft2 => _extCapFlankLeft2 ?? Offset(
    _extTop.dx * 0.33 + _extLeft.dx * 0.67,
    _extTop.dy * 0.33 + _extLeft.dy * 0.67,
  );

  // Getters INT Pénétration Gauche (intLeft -> intDeep)
  Offset get _effectiveIntFlankLeft1 => _intFlankLeft1 ?? Offset(
    _intLeft.dx * 0.67 + _intDeep.dx * 0.33,
    _intLeft.dy * 0.67 + _intDeep.dy * 0.33,
  );
  Offset get _effectiveIntFlankLeft2 => _intFlankLeft2 ?? Offset(
    _intLeft.dx * 0.33 + _intDeep.dx * 0.67,
    _intLeft.dy * 0.33 + _intDeep.dy * 0.67,
  );

  // Getters INT Pénétration Droite (intDeep -> intRight)
  Offset get _effectiveIntFlankRight1 => _intFlankRight1 ?? Offset(
    _intDeep.dx * 0.67 + _intRight.dx * 0.33,
    _intDeep.dy * 0.67 + _intRight.dy * 0.33,
  );
  Offset get _effectiveIntFlankRight2 => _intFlankRight2 ?? Offset(
    _intDeep.dx * 0.33 + _intRight.dx * 0.67,
    _intDeep.dy * 0.33 + _intRight.dy * 0.67,
  );

  // Getters INT Chapeau Droit (intRight -> intBottom)
  Offset get _effectiveIntCapFlankRight1 => _intCapFlankRight1 ?? Offset(
    _intRight.dx * 0.67 + _intBottom.dx * 0.33,
    _intRight.dy * 0.67 + _intBottom.dy * 0.33,
  );
  Offset get _effectiveIntCapFlankRight2 => _intCapFlankRight2 ?? Offset(
    _intRight.dx * 0.33 + _intBottom.dx * 0.67,
    _intRight.dy * 0.33 + _intBottom.dy * 0.67,
  );

  // Getters INT Chapeau Gauche (intBottom -> intLeft)
  Offset get _effectiveIntCapFlankLeft1 => _intCapFlankLeft1 ?? Offset(
    _intBottom.dx * 0.67 + _intLeft.dx * 0.33,
    _intBottom.dy * 0.67 + _intLeft.dy * 0.33,
  );
  Offset get _effectiveIntCapFlankLeft2 => _intCapFlankLeft2 ?? Offset(
    _intBottom.dx * 0.33 + _intLeft.dx * 0.67,
    _intBottom.dy * 0.33 + _intLeft.dy * 0.67,
  );

  // Poignées manuelles pour les 2 intersections des lignes de fusion (au milieu)
  Offset? _manualInterLeft;
  Offset? _manualInterRight;

  Offset get _effectiveInterLeft {
    if (_manualInterLeft != null) return _manualInterLeft!;
    final auto = _computeFusionIntersectionsNorm(
      extLeft: _extLeft,
      extFlankLeft1: _effectiveExtFlankLeft1,
      extFlankLeft2: _effectiveExtFlankLeft2,
      extRight: _extRight,
      extFlankRight1: _effectiveExtFlankRight1,
      extFlankRight2: _effectiveExtFlankRight2,
      extDeep: _extDeep,
      intLeft: _intLeft,
      intFlankLeft1: _effectiveIntFlankLeft1,
      intFlankLeft2: _effectiveIntFlankLeft2,
      intRight: _intRight,
      intFlankRight1: _effectiveIntFlankRight1,
      intFlankRight2: _effectiveIntFlankRight2,
      intDeep: _intDeep,
    );
    return auto[0];
  }

  Offset get _effectiveInterRight {
    if (_manualInterRight != null) return _manualInterRight!;
    final auto = _computeFusionIntersectionsNorm(
      extLeft: _extLeft,
      extFlankLeft1: _effectiveExtFlankLeft1,
      extFlankLeft2: _effectiveExtFlankLeft2,
      extRight: _extRight,
      extFlankRight1: _effectiveExtFlankRight1,
      extFlankRight2: _effectiveExtFlankRight2,
      extDeep: _extDeep,
      intLeft: _intLeft,
      intFlankLeft1: _effectiveIntFlankLeft1,
      intFlankLeft2: _effectiveIntFlankLeft2,
      intRight: _intRight,
      intFlankRight1: _effectiveIntFlankRight1,
      intFlankRight2: _effectiveIntFlankRight2,
      intDeep: _intDeep,
    );
    return auto[1];
  }

  String? _activeHandle;
  Offset? _dragPosition;
  Size? _lastCanvasSize;
  bool _isUpdatingFromScript = false;
  ui.Image? _loadedUiImage;

  // ── Guides repère (style Inkscape) ────────────────────────────────────────
  static const double _rulerSize = 18.0;          // largeur/hauteur bandes règle
  static const double _guideSnapPx = 10.0;        // distance de détection d'un guide
  final List<double> _hGuides = [];  // positions normalisées Y dans imageRect (0.0-1.0)
  final List<double> _vGuides = [];  // positions normalisées X dans imageRect (0.0-1.0)
  String? _guideDragId;        // 'h:0', 'v:1', 'new_h', 'new_v'
  int _guideDragIndex = -1;

  // Option pour dessiner les repères sur l'image sauvegardée du PV
  bool _exportAnnotatedPhoto = true;

  static List<double>? _offsetToList(Offset? o) => o == null ? null : [o.dx, o.dy];
  static Offset? _listToOffset(dynamic list) {
    if (list is List && list.length >= 2) {
      final x = (list[0] as num).toDouble();
      final y = (list[1] as num).toDouble();
      return Offset(x, y);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _grossissementCtrl = TextEditingController(text: widget.initialGrossissement.replaceAll(' FOIS', '').trim());
    _epReelCtrl = TextEditingController(text: widget.initialEpReel);
    _epMesureePhotoCtrl = TextEditingController(text: widget.initialEpReel);

    _surepExtCtrl = TextEditingController(text: widget.initialSurepExt);
    _surepIntCtrl = TextEditingController(text: widget.initialSurepInt);
    _largeurExtCtrl = TextEditingController(text: widget.initialLargeurExt);
    _largeurIntCtrl = TextEditingController(text: widget.initialLargeurInt);
    _pExtPctCtrl = TextEditingController(text: widget.initialPenetrationExt);
    _pIntPctCtrl = TextEditingController(text: widget.initialPenetrationInt);
    _desaxageCtrl = TextEditingController(text: widget.initialDesaxage);
    _interpCtrl = TextEditingController(text: widget.initialInterpenetration);

    final ep = double.tryParse(widget.initialEpReel.replaceAll(',', '.')) ?? 11.0;
    final pExtP = double.tryParse(widget.initialPenetrationExt.replaceAll(',', '.')) ?? 68.18;
    final pIntP = double.tryParse(widget.initialPenetrationInt.replaceAll(',', '.')) ?? 55.54;

    _pExtMmCtrl = TextEditingController(text: ((pExtP / 100.0) * ep).toStringAsFixed(2).replaceAll('.', ','));
    _pIntMmCtrl = TextEditingController(text: ((pIntP / 100.0) * ep).toStringAsFixed(2).replaceAll('.', ','));

    _grossissementCtrl.addListener(_onGrossissementChanged);
    _epReelCtrl.addListener(_onEpReelChanged);
    _epMesureePhotoCtrl.addListener(_onEpMesureePhotoChanged);
    _pExtMmCtrl.addListener(_onPExtMmChanged);
    _pIntMmCtrl.addListener(_onPIntMmChanged);
    _pExtPctCtrl.addListener(_onPExtPctChanged);
    _pIntPctCtrl.addListener(_onPIntPctChanged);

    // ── Restauration de l'état précédent des repères & poignées ──
    if (widget.initialMeasureData != null && widget.initialMeasureData!.isNotEmpty) {
      try {
        final data = jsonDecode(widget.initialMeasureData!);
        if (data is Map) {
          if (data['epTop'] != null) _epTop = _listToOffset(data['epTop']) ?? _epTop;
          if (data['epBottom'] != null) _epBottom = _listToOffset(data['epBottom']) ?? _epBottom;
          if (data['extTop'] != null) _extTop = _listToOffset(data['extTop']) ?? _extTop;
          if (data['extLeft'] != null) _extLeft = _listToOffset(data['extLeft']) ?? _extLeft;
          if (data['extRight'] != null) _extRight = _listToOffset(data['extRight']) ?? _extRight;
          if (data['extDeep'] != null) _extDeep = _listToOffset(data['extDeep']) ?? _extDeep;

          if (data['intBottom'] != null) _intBottom = _listToOffset(data['intBottom']) ?? _intBottom;
          if (data['intLeft'] != null) _intLeft = _listToOffset(data['intLeft']) ?? _intLeft;
          if (data['intRight'] != null) _intRight = _listToOffset(data['intRight']) ?? _intRight;
          if (data['intDeep'] != null) _intDeep = _listToOffset(data['intDeep']) ?? _intDeep;

          if (data['extFlankLeft1'] != null) _extFlankLeft1 = _listToOffset(data['extFlankLeft1']);
          if (data['extFlankLeft2'] != null) _extFlankLeft2 = _listToOffset(data['extFlankLeft2']);
          if (data['extFlankRight1'] != null) _extFlankRight1 = _listToOffset(data['extFlankRight1']);
          if (data['extFlankRight2'] != null) _extFlankRight2 = _listToOffset(data['extFlankRight2']);
          if (data['extCapFlankLeft1'] != null) _extCapFlankLeft1 = _listToOffset(data['extCapFlankLeft1']);
          if (data['extCapFlankLeft2'] != null) _extCapFlankLeft2 = _listToOffset(data['extCapFlankLeft2']);
          if (data['extCapFlankRight1'] != null) _extCapFlankRight1 = _listToOffset(data['extCapFlankRight1']);
          if (data['extCapFlankRight2'] != null) _extCapFlankRight2 = _listToOffset(data['extCapFlankRight2']);

          if (data['intFlankLeft1'] != null) _intFlankLeft1 = _listToOffset(data['intFlankLeft1']);
          if (data['intFlankLeft2'] != null) _intFlankLeft2 = _listToOffset(data['intFlankLeft2']);
          if (data['intFlankRight1'] != null) _intFlankRight1 = _listToOffset(data['intFlankRight1']);
          if (data['intFlankRight2'] != null) _intFlankRight2 = _listToOffset(data['intFlankRight2']);
          if (data['intCapFlankLeft1'] != null) _intCapFlankLeft1 = _listToOffset(data['intCapFlankLeft1']);
          if (data['intCapFlankLeft2'] != null) _intCapFlankLeft2 = _listToOffset(data['intCapFlankLeft2']);
          if (data['intCapFlankRight1'] != null) _intCapFlankRight1 = _listToOffset(data['intCapFlankRight1']);
          if (data['intCapFlankRight2'] != null) _intCapFlankRight2 = _listToOffset(data['intCapFlankRight2']);

          if (data['manualInterLeft'] != null) _manualInterLeft = _listToOffset(data['manualInterLeft']);
          if (data['manualInterRight'] != null) _manualInterRight = _listToOffset(data['manualInterRight']);

          if (data['hGuides'] is List) {
            _hGuides.clear();
            for (final g in data['hGuides']) {
              if (g is num) _hGuides.add(g.toDouble());
            }
          }
          if (data['vGuides'] is List) {
            _vGuides.clear();
            for (final g in data['vGuides']) {
              if (g is num) _vGuides.add(g.toDouble());
            }
          }

          if (data['exportAnnotatedPhoto'] != null) {
            _exportAnnotatedPhoto = data['exportAnnotatedPhoto'] == true;
          }
          if (data['activeMode'] is String) {
            _activeMode = data['activeMode'];
          }
          if (data['showHandles'] != null) {
            _showHandles = data['showHandles'] == true;
          }
          if (data['repereThickness'] is num) {
            _repereThickness = (data['repereThickness'] as num).toDouble().clamp(0.8, 6.0);
          }
          if (data['repereTheme'] is String) {
            _repereTheme = data['repereTheme'];
          }
          if (data['displayFilter'] is String) {
            _displayFilter = data['displayFilter'];
          }
        }
      } catch (e) {
        debugPrint('Erreur chargement initialMeasureData: $e');
      }
    }

    final file = File(widget.photoPath);
    if (file.existsSync()) {
      _loadImageDimensions(file);
    }
  }

  void _loadImageDimensions(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _loadedUiImage = frame.image;
          if (_lastCanvasSize != null) {
            _recalculateFromHandles(_lastCanvasSize!);
          }
        });
      }
    } catch (_) {}
  }

  Rect getFittedImageRect(Size containerSize) {
    if (_loadedUiImage == null) {
      return Rect.fromLTWH(0, 0, containerSize.width, containerSize.height);
    }
    final imageAspect = _loadedUiImage!.width / _loadedUiImage!.height;
    final containerAspect = containerSize.width / containerSize.height;

    double drawWidth, drawHeight, drawLeft, drawTop;

    if (containerAspect > imageAspect) {
      drawHeight = containerSize.height;
      drawWidth = drawHeight * imageAspect;
      drawTop = 0;
      drawLeft = (containerSize.width - drawWidth) / 2;
    } else {
      drawWidth = containerSize.width;
      drawHeight = drawWidth / imageAspect;
      drawLeft = 0;
      drawTop = (containerSize.height - drawHeight) / 2;
    }
    return Rect.fromLTWH(drawLeft, drawTop, drawWidth, drawHeight);
  }

  /// Calcule la hauteur exacte (en mm) de l'image telle qu'elle sera imprimée sur le PDF A4.
  /// Prend en compte la largeur de colonne du PDF, la hauteur du conteneur (slider) et le ratio W/H.
  double _getPdfImageHeightMm() {
    final imageAspect = (_loadedUiImage != null && _loadedUiImage!.height > 0)
        ? _loadedUiImage!.width / _loadedUiImage!.height
        : 1.0;
    const double pdfPhotoBoxWidthPt = 262.04;
    final double pdfPhotoBoxHeightPt = ((widget.photoHeightPdf * 0.51).clamp(36.0, 153.0) - 6.0).clamp(30.0, 150.0);
    final double boxAspect = pdfPhotoBoxWidthPt / pdfPhotoBoxHeightPt;
    final double pdfImageHeightPt = (imageAspect > boxAspect)
        ? (pdfPhotoBoxWidthPt / imageAspect)
        : pdfPhotoBoxHeightPt;
    return pdfImageHeightPt * (25.4 / 72.0);
  }

  /// Boîte de dialogue pour réglage fin de l'épaisseur des traits de repère
  void _showThicknessDialog() {
    double temp = _repereThickness;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.line_weight_rounded, color: Color(0xFF00E5FF)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Épaisseur des traits de repère',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${temp.toStringAsFixed(1)} px',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Slider(
                value: temp,
                min: 0.8,
                max: 6.0,
                divisions: 26,
                activeColor: const Color(0xFF00E5FF),
                inactiveColor: Colors.white24,
                onChanged: (v) {
                  setDialogState(() => temp = v);
                  setState(() => _repereThickness = v);
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [1.0, 1.8, 2.4, 3.2, 4.5].map((val) {
                  final isSel = (temp - val).abs() < 0.15;
                  return ActionChip(
                    backgroundColor: isSel ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                    label: Text(
                      '${val.toStringAsFixed(1)} px',
                      style: TextStyle(
                        color: isSel ? Colors.black : Colors.white,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onPressed: () {
                      setDialogState(() => temp = val);
                      setState(() => _repereThickness = val);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _grossissementCtrl.dispose();
    _epReelCtrl.dispose();
    _epMesureePhotoCtrl.dispose();
    _surepExtCtrl.dispose();
    _surepIntCtrl.dispose();
    _largeurExtCtrl.dispose();
    _largeurIntCtrl.dispose();
    _pExtMmCtrl.dispose();
    _pIntMmCtrl.dispose();
    _pExtPctCtrl.dispose();
    _pIntPctCtrl.dispose();
    _desaxageCtrl.dispose();
    _interpCtrl.dispose();
    super.dispose();
  }

  void _onGrossissementChanged() {
    if (_isUpdatingFromScript) return;
    if (_lastCanvasSize != null) {
      _recalculateFromHandles(_lastCanvasSize!, triggerSource: 'grossissement');
    }
    setState(() {});
  }

  void _onEpReelChanged() {
    if (_isUpdatingFromScript) return;
    _recalculateAll();
    if (_lastCanvasSize != null) {
      _recalculateFromHandles(_lastCanvasSize!, triggerSource: 'epReel');
    }
    setState(() {});
  }

  void _onEpMesureePhotoChanged() {
    if (_isUpdatingFromScript) return;
    if (_lastCanvasSize != null) {
      _recalculateFromHandles(_lastCanvasSize!, triggerSource: 'epMesureePhoto');
    }
    setState(() {});
  }

  void _onPExtMmChanged() {
    if (_isUpdatingFromScript) return;
    final ep = double.tryParse(_epReelCtrl.text.replaceAll(',', '.')) ?? 11.0;
    final pExtMm = double.tryParse(_pExtMmCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final pIntMm = double.tryParse(_pIntMmCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (ep > 0) {
      _isUpdatingFromScript = true;
      _pExtPctCtrl.text = ((pExtMm / ep) * 100.0).toStringAsFixed(2).replaceAll('.', ',');
      final interp = (pExtMm + pIntMm) - ep;
      _interpCtrl.text = (interp > 0 ? interp : 0.0).toStringAsFixed(2).replaceAll('.', ',');
      _isUpdatingFromScript = false;
    }
  }

  void _onPIntMmChanged() {
    if (_isUpdatingFromScript) return;
    final ep = double.tryParse(_epReelCtrl.text.replaceAll(',', '.')) ?? 11.0;
    final pExtMm = double.tryParse(_pExtMmCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final pIntMm = double.tryParse(_pIntMmCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (ep > 0) {
      _isUpdatingFromScript = true;
      _pIntPctCtrl.text = ((pIntMm / ep) * 100.0).toStringAsFixed(2).replaceAll('.', ',');
      final interp = (pExtMm + pIntMm) - ep;
      _interpCtrl.text = (interp > 0 ? interp : 0.0).toStringAsFixed(2).replaceAll('.', ',');
      _isUpdatingFromScript = false;
    }
  }

  void _onPExtPctChanged() {
    if (_isUpdatingFromScript) return;
    final ep = double.tryParse(_epReelCtrl.text.replaceAll(',', '.')) ?? 11.0;
    final pExtPct = double.tryParse(_pExtPctCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final pIntMm = double.tryParse(_pIntMmCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (ep > 0) {
      _isUpdatingFromScript = true;
      final pExtMm = (pExtPct / 100.0) * ep;
      _pExtMmCtrl.text = pExtMm.toStringAsFixed(2).replaceAll('.', ',');
      final interp = (pExtMm + pIntMm) - ep;
      _interpCtrl.text = (interp > 0 ? interp : 0.0).toStringAsFixed(2).replaceAll('.', ',');
      _isUpdatingFromScript = false;
    }
  }

  void _onPIntPctChanged() {
    if (_isUpdatingFromScript) return;
    final ep = double.tryParse(_epReelCtrl.text.replaceAll(',', '.')) ?? 11.0;
    final pIntPct = double.tryParse(_pIntPctCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final pExtMm = double.tryParse(_pExtMmCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (ep > 0) {
      _isUpdatingFromScript = true;
      final pIntMm = (pIntPct / 100.0) * ep;
      _pIntMmCtrl.text = pIntMm.toStringAsFixed(2).replaceAll('.', ',');
      final interp = (pExtMm + pIntMm) - ep;
      _interpCtrl.text = (interp > 0 ? interp : 0.0).toStringAsFixed(2).replaceAll('.', ',');
      _isUpdatingFromScript = false;
    }
  }

  void _recalculateAll() {
    if (_isUpdatingFromScript) return;
    final ep = double.tryParse(_epReelCtrl.text.replaceAll(',', '.')) ?? 11.0;
    final pExtMm = double.tryParse(_pExtMmCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final pIntMm = double.tryParse(_pIntMmCtrl.text.replaceAll(',', '.')) ?? 0.0;

    if (ep > 0) {
      final extPct = (pExtMm / ep) * 100.0;
      final intPct = (pIntMm / ep) * 100.0;
      final interpMm = (pExtMm + pIntMm) - ep;

      _isUpdatingFromScript = true;
      _pExtPctCtrl.text = extPct.toStringAsFixed(2).replaceAll('.', ',');
      _pIntPctCtrl.text = intPct.toStringAsFixed(2).replaceAll('.', ',');
      _interpCtrl.text = (interpMm > 0 ? interpMm : 0.0).toStringAsFixed(2).replaceAll('.', ',');
      _isUpdatingFromScript = false;
    }
  }

  void _recalculateFromHandles(Size size, {String? triggerSource}) {
    _lastCanvasSize = size;

    // Calcul du rectangle réel de l'image sur l'écran (BoxFit.contain)
    final imageRect = getFittedImageRect(size);
    final imgH = imageRect.height > 0 ? imageRect.height : size.height;
    final imgW = imageRect.width > 0 ? imageRect.width : size.width;
    final imageAspect = (imgW > 0 && imgH > 0) ? imgW / imgH : 1.0;

    // Épaisseur normalisée (0.0 - 1.0) entre les deux poignées jaunes sur l'image
    double epNormH = (_epBottom.dy - _epTop.dy).abs();
    if (epNormH < 0.001) epNormH = 0.001;

    // Hauteur physique de l'image sur le papier A4 imprimé (en mm)
    final double pdfImageHeightMm = _getPdfImageHeightMm();

    final epReelMm = double.tryParse(_epReelCtrl.text.replaceAll(',', '.')) ?? 11.0;

    if (epNormH > 0.005 && epReelMm > 0) {
      if (triggerSource == 'epMesureePhoto') {
        // L'utilisateur saisit directement l'épaisseur tôle mesurée avec sa règle sur le papier (ex: 13.5 mm)
        final epPhotoVal = double.tryParse(_epMesureePhotoCtrl.text.replaceAll(',', '.')) ?? epReelMm;
        final calcG = epPhotoVal / epReelMm;

        _isUpdatingFromScript = true;
        _grossissementCtrl.text = calcG.toStringAsFixed(2).replaceAll('.', ',');
        _isUpdatingFromScript = false;
      } else if (triggerSource == 'grossissement') {
        // L'utilisateur saisit directement le grossissement (G)
        final gCurrent = double.tryParse(_grossissementCtrl.text.replaceAll(' FOIS', '').replaceAll('x', '').replaceAll(',', '.').trim()) ?? 1.0;
        final epPhotoVal = gCurrent * epReelMm;

        _isUpdatingFromScript = true;
        _epMesureePhotoCtrl.text = epPhotoVal.toStringAsFixed(2).replaceAll('.', ',');
        _isUpdatingFromScript = false;
      } else {
        // Déplacement des poignées sur l'image OU modification de Épaisseur Réelle
        // 1. Épaisseur sur le papier imprimé (mm) = fraction de hauteur × hauteur de l'image dans le PDF
        final calcEpPhoto = epNormH * pdfImageHeightMm;
        // 2. Grossissement G = Épaisseur sur photo imprimée / Épaisseur réelle de la tôle
        final calcG = calcEpPhoto / epReelMm;

        _isUpdatingFromScript = true;
        _epMesureePhotoCtrl.text = calcEpPhoto.toStringAsFixed(2).replaceAll('.', ',');
        _grossissementCtrl.text = calcG.toStringAsFixed(2).replaceAll('.', ',');
        _isUpdatingFromScript = false;
      }

      // ── ÉCHELLE RÉELLE D'ÉTALONNAGE DE LA SOUDURE selon API 5L ──────────────
      // Principe : l'étalon est l'épaisseur réelle de la tôle (epReelMm)
      // 1 unité Y normalisée = (epReelMm / epNormH) mm réels
      final scaleRealMmPerNormY = epReelMm / epNormH;
      // Distances horizontales X (pixels carrés → isotrope) :
      final scaleRealMmPerNormX = scaleRealMmPerNormY * imageAspect;

      _isUpdatingFromScript = true;

      // ── API 5L § 9.11 / Figure 4 ─────────────────────────────────────────
      // 1. Surépaisseur (Height of weld bead - API 5L Fig.4 repères 1 et 2)
      //    = distance verticale entre la surface de la tôle et le sommet du cordon
      final sExtMm = (_epTop.dy - _extTop.dy).abs() * scaleRealMmPerNormY;
      final sIntMm = (_intBottom.dy - _epBottom.dy).abs() * scaleRealMmPerNormY;
      _surepExtCtrl.text = sExtMm.toStringAsFixed(2).replaceAll('.', ',');
      _surepIntCtrl.text = sIntMm.toStringAsFixed(2).replaceAll('.', ',');

      // ── API 5L § 9.11 / Figure 4 ─────────────────────────────────────────
      // 2. Largeur du cordon (Width of weld bead)
      final lExtMm = (_extRight.dx - _extLeft.dx).abs() * scaleRealMmPerNormX;
      final lIntMm = (_intRight.dx - _intLeft.dx).abs() * scaleRealMmPerNormX;
      _largeurExtCtrl.text = lExtMm.toStringAsFixed(2).replaceAll('.', ',');
      _largeurIntCtrl.text = lIntMm.toStringAsFixed(2).replaceAll('.', ',');

      // ── API 5L § 9.11 / Figure 4 ─────────────────────────────────────────
      // 3. Pénétration (Depth of fusion)
      //    EXT : profondeur de fusion du cordon EXT dans la tôle (depuis surface EXT _epTop)
      //    INT : profondeur de fusion du cordon INT dans la tôle (depuis surface INT _epBottom)
      final pExtMm = (_extDeep.dy - _epTop.dy).abs() * scaleRealMmPerNormY;
      final pIntMm = (_epBottom.dy - _intDeep.dy).abs() * scaleRealMmPerNormY;
      _pExtMmCtrl.text = pExtMm.toStringAsFixed(2).replaceAll('.', ',');
      _pIntMmCtrl.text = pIntMm.toStringAsFixed(2).replaceAll('.', ',');

      // Pénétration en % de l'épaisseur réelle de la tôle (API 5L)
      final pExtPct = (pExtMm / epReelMm) * 100.0;
      final pIntPct = (pIntMm / epReelMm) * 100.0;
      _pExtPctCtrl.text = pExtPct.toStringAsFixed(2).replaceAll('.', ',');
      _pIntPctCtrl.text = pIntPct.toStringAsFixed(2).replaceAll('.', ',');

      // ── 4. Interpénétration (Overlap / Recouvrement des deux cordons dans l'épaisseur) ─
      //    Interpénétration = (Profondeur EXT + Profondeur INT) - Épaisseur Réelle
      final interpValMm = (pExtMm + pIntMm) - epReelMm;
      final interpMm = interpValMm > 0 ? interpValMm : 0.0;
      _interpCtrl.text = interpMm.toStringAsFixed(2).replaceAll('.', ',');

      // ── API 5L § 9.10.2 / Figure 4 c) — DÉSAXAGE (Misalignment) ─────────
      // M1, M2 : milieux de deux lignes parallèles à la surface passant par
      //          les INTERSECTIONS des lignes de fusion EXT et INT
      final pInt1 = _effectiveInterLeft;
      final pInt2 = _effectiveInterRight;

      // L'intersection supérieure correspond à la pénétration EXT dans INT
      // L'intersection inférieure correspond à la pénétration INT dans EXT
      final yExtTarget = pInt1.dy < pInt2.dy ? pInt1.dy : pInt2.dy;
      final yIntTarget = pInt1.dy > pInt2.dy ? pInt1.dy : pInt2.dy;

      // M1 : milieu exact de la ligne traversant le cordon EXT (de fusion à fusion) à yExtTarget
      final (xExtL, xExtR) = _evalBeadEndpointsAtY(
        yTarget: yExtTarget,
        toeLeft: _extLeft,
        flankLeft1: _effectiveExtFlankLeft1,
        flankLeft2: _effectiveExtFlankLeft2,
        deep: _extDeep,
        flankRight1: _effectiveExtFlankRight1,
        flankRight2: _effectiveExtFlankRight2,
        toeRight: _extRight,
      );
      final xM1Norm = (xExtL + xExtR) / 2.0;

      // M2 : milieu exact de la ligne traversant le cordon INT (de fusion à fusion) à yIntTarget
      final (xIntL, xIntR) = _evalBeadEndpointsAtY(
        yTarget: yIntTarget,
        toeLeft: _intLeft,
        flankLeft1: _effectiveIntFlankLeft1,
        flankLeft2: _effectiveIntFlankLeft2,
        deep: _intDeep,
        flankRight1: _effectiveIntFlankRight1,
        flankRight2: _effectiveIntFlankRight2,
        toeRight: _intRight,
      );
      final xM2Norm = (xIntL + xIntR) / 2.0;

      final desaxageMm = (xM1Norm - xM2Norm).abs() * scaleRealMmPerNormX;
      _desaxageCtrl.text = desaxageMm.toStringAsFixed(2).replaceAll('.', ',');

      _isUpdatingFromScript = false;
    }
  }

  /// Calcule les 2 intersections des lignes de fusion EXT et INT (Bézier cubique avec 2 points de contrôle par flanc)
  static List<Offset> _computeFusionIntersectionsNorm({
    required Offset extLeft,
    required Offset extFlankLeft1,
    required Offset extFlankLeft2,
    required Offset extRight,
    required Offset extFlankRight1,
    required Offset extFlankRight2,
    required Offset extDeep,
    required Offset intLeft,
    required Offset intFlankLeft1,
    required Offset intFlankLeft2,
    required Offset intRight,
    required Offset intFlankRight1,
    required Offset intFlankRight2,
    required Offset intDeep,
  }) {
    Offset evalCubic(Offset p0, Offset p1, Offset p2, Offset p3, double u) {
      final iu = 1.0 - u;
      return Offset(
        iu * iu * iu * p0.dx + 3 * iu * iu * u * p1.dx + 3 * iu * u * u * p2.dx + u * u * u * p3.dx,
        iu * iu * iu * p0.dy + 3 * iu * iu * u * p1.dy + 3 * iu * u * u * p2.dy + u * u * u * p3.dy,
      );
    }

    Offset evalExt(double t) {
      if (t <= 0.5) {
        return evalCubic(extLeft, extFlankLeft1, extFlankLeft2, extDeep, t * 2.0);
      } else {
        return evalCubic(extDeep, extFlankRight1, extFlankRight2, extRight, (t - 0.5) * 2.0);
      }
    }

    Offset evalInt(double t) {
      if (t <= 0.5) {
        return evalCubic(intLeft, intFlankLeft1, intFlankLeft2, intDeep, t * 2.0);
      } else {
        return evalCubic(intDeep, intFlankRight1, intFlankRight2, intRight, (t - 0.5) * 2.0);
      }
    }

    Offset? leftInt;
    double minLeftDist = double.infinity;
    for (int i = 0; i <= 100; i++) {
      final t = (i / 100.0) * 0.5;
      final pE = evalExt(t);
      for (int j = 0; j <= 100; j++) {
        final u = (j / 100.0) * 0.5;
        final pI = evalInt(u);
        final d = (pE.dx - pI.dx) * (pE.dx - pI.dx) + (pE.dy - pI.dy) * (pE.dy - pI.dy);
        if (d < minLeftDist) {
          minLeftDist = d;
          leftInt = Offset((pE.dx + pI.dx) / 2, (pE.dy + pI.dy) / 2);
        }
      }
    }

    Offset? rightInt;
    double minRightDist = double.infinity;
    for (int i = 0; i <= 100; i++) {
      final t = 0.5 + (i / 100.0) * 0.5;
      final pE = evalExt(t);
      for (int j = 0; j <= 100; j++) {
        final u = 0.5 + (j / 100.0) * 0.5;
        final pI = evalInt(u);
        final d = (pE.dx - pI.dx) * (pE.dx - pI.dx) + (pE.dy - pI.dy) * (pE.dy - pI.dy);
        if (d < minRightDist) {
          minRightDist = d;
          rightInt = Offset((pE.dx + pI.dx) / 2, (pE.dy + pI.dy) / 2);
        }
      }
    }

    final fallbackY = (extDeep.dy + intDeep.dy) / 2.0;
    final fallbackLeft = Offset((extLeft.dx + intLeft.dx) / 2.0, fallbackY);
    final fallbackRight = Offset((extRight.dx + intRight.dx) / 2.0, fallbackY);

    return [leftInt ?? fallbackLeft, rightInt ?? fallbackRight];
  }

  /// Calcule les coordonnées X gauche et droite exactes d'un cordon à la hauteur Y demandée
  static (double, double) _evalBeadEndpointsAtY({
    required double yTarget,
    required Offset toeLeft,
    required Offset flankLeft1,
    required Offset flankLeft2,
    required Offset deep,
    required Offset flankRight1,
    required Offset flankRight2,
    required Offset toeRight,
  }) {
    Offset evalBranch(Offset p0, Offset p1, Offset p2, Offset p3, double u) {
      final iu = 1.0 - u;
      return Offset(
        iu * iu * iu * p0.dx + 3 * iu * iu * u * p1.dx + 3 * iu * u * u * p2.dx + u * u * u * p3.dx,
        iu * iu * iu * p0.dy + 3 * iu * iu * u * p1.dy + 3 * iu * u * u * p2.dy + u * u * u * p3.dy,
      );
    }

    double bestXLeft = toeLeft.dx;
    double minLeftDist = double.infinity;
    for (int i = 0; i <= 100; i++) {
      final u = i / 100.0;
      final pt = evalBranch(toeLeft, flankLeft1, flankLeft2, deep, u);
      final dist = (pt.dy - yTarget).abs();
      if (dist < minLeftDist) {
        minLeftDist = dist;
        bestXLeft = pt.dx;
      }
    }

    double bestXRight = toeRight.dx;
    double minRightDist = double.infinity;
    for (int i = 0; i <= 100; i++) {
      final u = i / 100.0;
      final pt = evalBranch(deep, flankRight1, flankRight2, toeRight, u);
      final dist = (pt.dy - yTarget).abs();
      if (dist < minRightDist) {
        minRightDist = dist;
        bestXRight = pt.dx;
      }
    }

    return (bestXLeft < bestXRight ? bestXLeft : bestXRight, bestXLeft > bestXRight ? bestXLeft : bestXRight);
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.photoPath);
    final photoExists = file.existsSync();

    final isMobile = MediaQuery.of(context).size.width < 650;

    final canvasWidget = Container(
      color: Colors.black87,
      child: Column(
        children: [
          // Modern Top Toolbar for Mode Selection + Lock & Reset actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                // ── Menu déroulant Mode de mesure ──
                Expanded(
                  child: PopupMenuButton<String>(
                    tooltip: 'Sélectionner le mode de mesure',
                    constraints: const BoxConstraints(minWidth: 260, maxWidth: 340),
                    onSelected: (val) => setState(() => _activeMode = val),
                    offset: const Offset(0, 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _activeModeColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _activeModeColor, width: 1.4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_activeModeIcon, size: 15, color: _activeModeColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _activeModeLabel,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _activeModeColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down_rounded, size: 18, color: _activeModeColor),
                        ],
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      _buildModeMenuItem('ext', 'Cordon EXT', const Color(0xFF00E5FF), Icons.radio_button_checked),
                      _buildModeMenuItem('int', 'Cordon INT', const Color(0xFFFF9100), Icons.radio_button_checked),
                      _buildModeMenuItem('epaisseur', 'Épaisseur Tôle', const Color(0xFFD97706), Icons.straighten_rounded),
                      _buildModeMenuItem('desaxage', 'Désaxage / Interp.', const Color(0xFFE040FB), Icons.compare_arrows_rounded),
                      _buildModeMenuItem('all', 'Tout afficher', Colors.white, Icons.visibility_rounded),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // ── Bouton Verrouiller / Déverrouiller ──
                _toolbarIconBtn(
                  icon: _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: _isLocked ? Colors.amberAccent : Colors.white54,
                  tooltip: _isLocked ? 'Déverrouiller les repères' : 'Verrouiller les repères',
                  isActive: _isLocked,
                  activeColor: Colors.amber,
                  onTap: () {
                    setState(() => _isLocked = !_isLocked);
                    ScaffoldMessenger.of(context).removeCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isLocked
                            ? '🔒 Repères fixés / verrouillés.'
                            : '🔓 Repères déverrouillés.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                // ── Bouton Schéma Propre / Édition ──
                _toolbarIconBtn(
                  icon: !_showHandles ? Icons.visibility_off_rounded : Icons.edit_rounded,
                  color: !_showHandles ? const Color(0xFF14B8A6) : Colors.white54,
                  tooltip: !_showHandles ? 'Schéma Propre (actif)' : 'Mode Édition',
                  isActive: !_showHandles,
                  activeColor: const Color(0xFF0D9488),
                  onTap: () {
                    setState(() => _showHandles = !_showHandles);
                    ScaffoldMessenger.of(context).removeCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(!_showHandles
                            ? '✨ Schéma propre activé.'
                            : '✏️ Mode édition activé.'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                // ── Menu Rendu & Filtre Radio ──
                PopupMenuButton<String>(
                  tooltip: 'Filtre d\'affichage',
                  constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
                  onSelected: (val) => setState(() => _displayFilter = val),
                  padding: EdgeInsets.zero,
                  child: _toolbarIconContainer(
                    icon: _displayFilter != 'none' ? Icons.filter_b_and_w_rounded : Icons.image_outlined,
                    color: _displayFilter != 'none' ? const Color(0xFF00E5FF) : Colors.white54,
                    isActive: _displayFilter != 'none',
                    activeColor: const Color(0xFF00E5FF),
                  ),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'none',
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined, color: Colors.white70, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('📷 Couleur originale')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'radio_macro',
                      child: Row(
                        children: [
                          Icon(Icons.filter_b_and_w_rounded, color: Color(0xFF00E5FF), size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('📻 Radio Macro')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'contrast',
                      child: Row(
                        children: [
                          Icon(Icons.contrast_rounded, color: Colors.amberAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('⚡ Contraste élevé')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'negative',
                      child: Row(
                        children: [
                          Icon(Icons.invert_colors_rounded, color: Colors.purpleAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('🎞️ Négatif RX')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // ── Menu Thème couleurs repères ──
                PopupMenuButton<String>(
                  tooltip: 'Couleurs des repères',
                  constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
                  onSelected: (val) => setState(() => _repereTheme = val),
                  padding: EdgeInsets.zero,
                  child: _toolbarIconContainer(
                    icon: Icons.palette_rounded,
                    color: _repereTheme != 'auto' ? const Color(0xFFE040FB) : Colors.white54,
                    isActive: _repereTheme != 'auto',
                    activeColor: const Color(0xFFE040FB),
                  ),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'auto',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('🎨 Auto')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'fluo',
                      child: Row(
                        children: [
                          Icon(Icons.brush_rounded, color: Colors.amberAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('⚡ Fluo Standard')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'bw_highvis',
                      child: Row(
                        children: [
                          Icon(Icons.wb_sunny_rounded, color: Color(0xFFFFD600), size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('🟡 Haute Visibilité N&B')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rx_neon',
                      child: Row(
                        children: [
                          Icon(Icons.flashlight_on_rounded, color: Color(0xFF00FF66), size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('🟢 Négatif RX Néon')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'monochrome_white',
                      child: Row(
                        children: [
                          Icon(Icons.square_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('⚪ Monochrome Blanc')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'monochrome_yellow',
                      child: Row(
                        children: [
                          Icon(Icons.square_rounded, color: Color(0xFFFFEA00), size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('🟡 Monochrome Jaune')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // ── Épaisseur de trait ──
                _toolbarIconBtn(
                  icon: Icons.line_weight_rounded,
                  color: const Color(0xFF00E5FF),
                  tooltip: 'Épaisseur trait: ${_repereThickness.toStringAsFixed(1)}px',
                  isActive: false,
                  activeColor: const Color(0xFF00E5FF),
                  onTap: _showThicknessDialog,
                ),
                const SizedBox(width: 4),
                // ── Menu Réinitialiser ──
                PopupMenuButton<String>(
                  tooltip: 'Réinitialiser',
                  constraints: const BoxConstraints(minWidth: 260, maxWidth: 340),
                  onSelected: (val) {
                    switch (val) {
                      case 'reset_all': _resetAllHandles(); break;
                      case 'reset_flanks': _resetFlanksOnly(); break;
                      case 'reset_inter': _resetAutoIntersections(); break;
                      case 'clear_guides': _clearAllGuides(); break;
                    }
                  },
                  padding: EdgeInsets.zero,
                  child: _toolbarIconContainer(
                    icon: Icons.refresh_rounded,
                    color: Colors.redAccent,
                    isActive: false,
                    activeColor: Colors.redAccent,
                  ),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'reset_all',
                      child: Row(
                        children: [
                          Icon(Icons.restore_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('Tout réinitialiser')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reset_flanks',
                      child: Row(
                        children: [
                          Icon(Icons.gesture_rounded, color: Colors.amberAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('Réinitialiser courbes & flancs')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reset_inter',
                      child: Row(
                        children: [
                          Icon(Icons.auto_fix_high_rounded, color: Colors.purpleAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('Recalculer auto M1 / M2')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_guides',
                      child: Row(
                        children: [
                          Icon(Icons.layers_clear_rounded, color: Colors.cyanAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('Supprimer tous les guides')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: photoExists
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      if (_lastCanvasSize != size) {
                        _lastCanvasSize = size;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _recalculateFromHandles(size);
                        });
                      }
                      return GestureDetector(
                        onDoubleTapDown: (details) {
                          // Double-tap → supprimer le guide le plus proche
                          final pos = details.localPosition;
                          final imageRect = getFittedImageRect(size);
                          _tryDeleteGuide(pos, imageRect);
                        },
                        onPanStart: (details) {
                          final pos = details.localPosition;
                          final imageRect = getFittedImageRect(size);
                          // ── Zone de règle gauche → nouveau guide vertical
                          if (pos.dx < _rulerSize && pos.dy > _rulerSize) {
                            if (_isLocked) return;
                            setState(() {
                              _dragPosition = pos;
                              _vGuides.add(0.5);
                              _guideDragId = 'new_v';
                              _guideDragIndex = _vGuides.length - 1;
                            });
                            return;
                          }
                          // ── Zone de règle haute → nouveau guide horizontal
                          if (pos.dy < _rulerSize && pos.dx > _rulerSize) {
                            if (_isLocked) return;
                            setState(() {
                              _dragPosition = pos;
                              _hGuides.add(0.5);
                              _guideDragId = 'new_h';
                              _guideDragIndex = _hGuides.length - 1;
                            });
                            return;
                          }
                          // ── Guide existant le plus proche ?
                          final guideHit = _findNearestGuide(pos, imageRect);
                          if (guideHit != null) {
                            if (_isLocked) return;
                            setState(() {
                              _dragPosition = pos;
                              _guideDragId = guideHit.$1;
                              _guideDragIndex = guideHit.$2;
                              _activeHandle = null;
                            });
                            return;
                          }
                          // ── Poignées de mesure
                          if (_isLocked) {
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🔒 Repères fixés / verrouillés. Cliquez sur le bouton cadenas pour déverrouiller et ajuster.'),
                                duration: Duration(milliseconds: 1500),
                              ),
                            );
                            _guideDragId = null;
                            _activeHandle = null;
                            _dragPosition = null;
                            return;
                          }
                          final handle = _findNearestHandle(pos, size, imageRect);
                          setState(() {
                            _guideDragId = null;
                            _activeHandle = handle;
                            _dragPosition = handle != null ? pos : null;
                          });
                        },
                        onPanUpdate: (details) {
                          final pos = details.localPosition;
                          final imageRect = getFittedImageRect(size);
                          // ── Déplacement guide
                          if (_guideDragId != null) {
                            setState(() {
                              _dragPosition = pos;
                              if (_guideDragId!.startsWith('h') || _guideDragId == 'new_h') {
                                final normY = ((pos.dy - imageRect.top) / imageRect.height).clamp(0.01, 0.99);
                                if (_guideDragIndex >= 0 && _guideDragIndex < _hGuides.length) {
                                  _hGuides[_guideDragIndex] = normY;
                                }
                                if (_guideDragId == 'new_h') _guideDragId = 'h:$_guideDragIndex';
                              } else {
                                final normX = ((pos.dx - imageRect.left) / imageRect.width).clamp(0.01, 0.99);
                                if (_guideDragIndex >= 0 && _guideDragIndex < _vGuides.length) {
                                  _vGuides[_guideDragIndex] = normX;
                                }
                                if (_guideDragId == 'new_v') _guideDragId = 'v:$_guideDragIndex';
                              }
                            });
                            return;
                          }
                          // ── Déplacement poignée
                          if (_activeHandle == null) return;
                          final normX = ((pos.dx - imageRect.left) / imageRect.width).clamp(0.02, 0.98);
                          final normY = ((pos.dy - imageRect.top) / imageRect.height).clamp(0.02, 0.98);
                          final norm = Offset(normX, normY);
                          setState(() {
                            _dragPosition = pos;
                            switch (_activeHandle) {
                              case 'epTop': _epTop = norm; break;
                              case 'epBottom': _epBottom = norm; break;
                              case 'extTop': _extTop = norm; break;
                              case 'extLeft': _extLeft = norm; break;
                              case 'extRight': _extRight = norm; break;
                              case 'extDeep': _extDeep = norm; break;
                              case 'intBottom': _intBottom = norm; break;
                              case 'intLeft': _intLeft = norm; break;
                              case 'intRight': _intRight = norm; break;
                              case 'intDeep': _intDeep = norm; break;
                              case 'extFlankLeft1': _extFlankLeft1 = norm; break;
                              case 'extFlankLeft2': _extFlankLeft2 = norm; break;
                              case 'extFlankRight1': _extFlankRight1 = norm; break;
                              case 'extFlankRight2': _extFlankRight2 = norm; break;
                              case 'extCapFlankRight1': _extCapFlankRight1 = norm; break;
                              case 'extCapFlankRight2': _extCapFlankRight2 = norm; break;
                              case 'extCapFlankLeft1': _extCapFlankLeft1 = norm; break;
                              case 'extCapFlankLeft2': _extCapFlankLeft2 = norm; break;
                              case 'intFlankLeft1': _intFlankLeft1 = norm; break;
                              case 'intFlankLeft2': _intFlankLeft2 = norm; break;
                              case 'intFlankRight1': _intFlankRight1 = norm; break;
                              case 'intFlankRight2': _intFlankRight2 = norm; break;
                              case 'intCapFlankRight1': _intCapFlankRight1 = norm; break;
                              case 'intCapFlankRight2': _intCapFlankRight2 = norm; break;
                              case 'intCapFlankLeft1': _intCapFlankLeft1 = norm; break;
                              case 'intCapFlankLeft2': _intCapFlankLeft2 = norm; break;
                              case 'interLeft': _manualInterLeft = norm; break;
                              case 'interRight': _manualInterRight = norm; break;
                            }
                            _recalculateFromHandles(size);
                          });
                        },
                        onPanEnd: (details) {
                          setState(() {
                            _guideDragId = null;
                            _guideDragIndex = -1;
                            _activeHandle = null;
                            _dragPosition = null;
                          });
                          _recalculateFromHandles(size);
                        },
                        onPanCancel: () {
                          setState(() {
                            _guideDragId = null;
                            _guideDragIndex = -1;
                            _activeHandle = null;
                            _dragPosition = null;
                          });
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: _measureFilterMatrix != null
                                    ? ColorFiltered(
                                        colorFilter: ColorFilter.matrix(_measureFilterMatrix!),
                                        child: Image.file(
                                          file,
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : Image.file(
                                        file,
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ),
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _WeldOverlayPainter(
                                    epTop: _epTop,
                                    epBottom: _epBottom,
                                    extTop: _extTop,
                                    extLeft: _extLeft,
                                    extRight: _extRight,
                                    extDeep: _extDeep,
                                    extFlankLeft1: _effectiveExtFlankLeft1,
                                    extFlankLeft2: _effectiveExtFlankLeft2,
                                    extFlankRight1: _effectiveExtFlankRight1,
                                    extFlankRight2: _effectiveExtFlankRight2,
                                    extCapFlankRight1: _effectiveExtCapFlankRight1,
                                    extCapFlankRight2: _effectiveExtCapFlankRight2,
                                    extCapFlankLeft1: _effectiveExtCapFlankLeft1,
                                    extCapFlankLeft2: _effectiveExtCapFlankLeft2,
                                    intBottom: _intBottom,
                                    intLeft: _intLeft,
                                    intRight: _intRight,
                                    intDeep: _intDeep,
                                    intFlankLeft1: _effectiveIntFlankLeft1,
                                    intFlankLeft2: _effectiveIntFlankLeft2,
                                    intFlankRight1: _effectiveIntFlankRight1,
                                    intFlankRight2: _effectiveIntFlankRight2,
                                    intCapFlankRight1: _effectiveIntCapFlankRight1,
                                    intCapFlankRight2: _effectiveIntCapFlankRight2,
                                    intCapFlankLeft1: _effectiveIntCapFlankLeft1,
                                    intCapFlankLeft2: _effectiveIntCapFlankLeft2,
                                    interLeft: _effectiveInterLeft,
                                    interRight: _effectiveInterRight,
                                    activeMode: _activeMode,
                                    showHandles: _showHandles,
                                    epReel: double.tryParse(_epReelCtrl.text.replaceAll(',', '.')) ?? 11.0,
                                    imageRect: getFittedImageRect(size),
                                    strokeThickness: _repereThickness,
                                    repereTheme: _repereTheme,
                                    displayFilter: _displayFilter,
                                  ),
                              ),
                            ),
                          ),
                            // ── Guides repère (visibles en mode repères) ──
                            if (_showHandles)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _GuidesPainter(
                                    hGuides: _hGuides,
                                    vGuides: _vGuides,
                                    imageRect: getFittedImageRect(size),
                                    pdfPhotoHeightMm: _getPdfImageHeightMm(),
                                    draggingId: _guideDragId,
                                    draggingIndex: _guideDragIndex,
                                  ),
                                ),
                              ),
                            // ── Bandes de règle (gauche + haut) ──────────
                            // Bande gauche
                            Positioned(
                              left: 0,
                              top: _rulerSize,
                              bottom: 0,
                              width: _rulerSize,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xD91A1A2E),
                                  border: Border(
                                    right: BorderSide(color: Color(0xFF00E5FF), width: 1),
                                  ),
                                ),
                              ),
                            ),
                            // Bande haute
                            Positioned(
                              left: _rulerSize,
                              top: 0,
                              right: 0,
                              height: _rulerSize,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xD91A1A2E),
                                  border: Border(
                                    bottom: BorderSide(color: Color(0xFF00E5FF), width: 1),
                                  ),
                                ),
                              ),
                            ),
                            // Coin supérieur gauche
                            Positioned(
                              left: 0,
                              top: 0,
                              width: _rulerSize,
                              height: _rulerSize,
                              child: Container(
                                color: const Color(0xFF0D0D1A),
                                child: const Icon(Icons.straighten_rounded, size: 12, color: Color(0xFF00E5FF)),
                              ),
                            ),
                            // ── Loupe de précision dynamique (Zoom x2.5 au-dessus du doigt) ──
                            if (_dragPosition != null && (_activeHandle != null || _guideDragId != null))
                              _buildPrecisionMagnifier(size, _dragPosition!),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text('Aucune photo disponible.', style: TextStyle(color: Colors.white70)),
                  ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Outil de Mesure & Traçage Macro'),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              !_showHandles ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: !_showHandles ? Colors.tealAccent : Colors.white,
            ),
            tooltip: !_showHandles ? 'Afficher les repères (Mode édition)' : 'Masquer les repères (Schéma propre)',
            onPressed: () {
              setState(() => _showHandles = !_showHandles);
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(!_showHandles
                      ? '✨ Schéma propre activé (points et poignées masqués).'
                      : '✏️ Mode édition activé (points de contrôle visibles).'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: _isLocked ? Colors.amberAccent : Colors.white,
            ),
            tooltip: _isLocked ? 'Déverrouiller les repères' : 'Fixer / Verrouiller les repères',
            onPressed: () {
              setState(() => _isLocked = !_isLocked);
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isLocked
                      ? '🔒 Repères fixés / verrouillés (déplacement bloqué).'
                      : '🔓 Repères déverrouillés (déplacement libre).'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Vérification détaillée des calculs (mm avant / après impression)',
            onPressed: _showCalculationVerificationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Guide & Formules de Calcul',
            onPressed: _showHelpGuideDialog,
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Valider les mesures',
            onPressed: _saveAndReturn,
          ),
        ],
      ),
      body: isMobile
          ? Column(
              children: [
                Expanded(flex: 5, child: canvasWidget),
                Expanded(flex: 4, child: _buildSidebarContent()),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: canvasWidget),
                Expanded(flex: 2, child: _buildSidebarContent()),
              ],
            ),
    );
  }

  void _showCalculationVerificationDialog() {
    final epReelMm = double.tryParse(_epReelCtrl.text.replaceAll(',', '.')) ?? 11.0;
    final epNormH = (_epBottom.dy - _epTop.dy).abs().clamp(0.0001, 1.0);
    final imageAspect = (_loadedUiImage != null && _loadedUiImage!.height > 0)
        ? _loadedUiImage!.width / _loadedUiImage!.height
        : 1.0;
    final scaleRealMmPerNormY = epReelMm / epNormH;
    final scaleRealMmPerNormX = scaleRealMmPerNormY * imageAspect;

    final pdfImageHeightMm = _getPdfImageHeightMm();
    final epPhotoPapierMm = epNormH * pdfImageHeightMm;
    final grossissement = (epReelMm > 0) ? (epPhotoPapierMm / epReelMm) : 1.0;

    final sExtMm = (_epTop.dy - _extTop.dy).abs() * scaleRealMmPerNormY;
    final sIntMm = (_intBottom.dy - _epBottom.dy).abs() * scaleRealMmPerNormY;
    final lExtMm = (_extRight.dx - _extLeft.dx).abs() * scaleRealMmPerNormX;
    final lIntMm = (_intRight.dx - _intLeft.dx).abs() * scaleRealMmPerNormX;
    final pExtMm = (_extDeep.dy - _epTop.dy).abs() * scaleRealMmPerNormY;
    final pIntMm = (_epBottom.dy - _intDeep.dy).abs() * scaleRealMmPerNormY;

    final (xExtL, xExtR) = _evalBeadEndpointsAtY(
      yTarget: _effectiveInterLeft.dy < _effectiveInterRight.dy ? _effectiveInterLeft.dy : _effectiveInterRight.dy,
      toeLeft: _extLeft,
      flankLeft1: _effectiveExtFlankLeft1,
      flankLeft2: _effectiveExtFlankLeft2,
      deep: _extDeep,
      flankRight1: _effectiveExtFlankRight1,
      flankRight2: _effectiveExtFlankRight2,
      toeRight: _extRight,
    );
    final (xIntL, xIntR) = _evalBeadEndpointsAtY(
      yTarget: _effectiveInterLeft.dy > _effectiveInterRight.dy ? _effectiveInterLeft.dy : _effectiveInterRight.dy,
      toeLeft: _intLeft,
      flankLeft1: _effectiveIntFlankLeft1,
      flankLeft2: _effectiveIntFlankLeft2,
      deep: _intDeep,
      flankRight1: _effectiveIntFlankRight1,
      flankRight2: _effectiveIntFlankRight2,
      toeRight: _intRight,
    );
    final xM1Norm = (xExtL + xExtR) / 2.0;
    final xM2Norm = (xIntL + xIntR) / 2.0;
    final desaxageMm = (xM1Norm - xM2Norm).abs() * scaleRealMmPerNormX;
    final interpMm = ((pExtMm + pIntMm) - epReelMm).clamp(0.0, 999.0);

    Widget buildRow(String label, double valReelMm, {String? extra}) {
      final valPapierMm = valReelMm * grossissement;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '${valReelMm.toStringAsFixed(2)} mm ${extra ?? ""}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '${valPapierMm.toStringAsFixed(2)} mm',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text('Vérification & Justesse des Calculs (mm)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Synthèse de l'étalonnage
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1️⃣ Étalonnage Physique (Sur Photo / Écran) :',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(height: 6),
                        Text('• Épaisseur Réelle Métal de Base (E_réel) = ${epReelMm.toStringAsFixed(2)} mm',
                            style: const TextStyle(fontSize: 12)),
                        Text('• Hauteur normalisée image (H_norm) = ${(epNormH * 100).toStringAsFixed(2)} % de la photo',
                            style: const TextStyle(fontSize: 12)),
                        Text('• Échelle Verticale Sy = ${scaleRealMmPerNormY.toStringAsFixed(3)} mm / unité',
                            style: const TextStyle(fontSize: 12)),
                        Text('• Échelle Horizontale Sx (isotrope) = ${scaleRealMmPerNormX.toStringAsFixed(3)} mm / unité',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Synthèse sur feuille imprimée
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade400),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2️⃣ Étalonnage Après Impression (Sur Papier A4) :',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                        ),
                        const SizedBox(height: 6),
                        Text('• Hauteur photo imprimée sur feuille A4 = ${pdfImageHeightMm.toStringAsFixed(1)} mm',
                            style: const TextStyle(fontSize: 12)),
                        Text('• Épaisseur tôle mesurable à la règle sur papier = ${epPhotoPapierMm.toStringAsFixed(2)} mm',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('• Grossissement Optique = ${grossissement.toStringAsFixed(2)}× (G = Épaisseur papier / Épaisseur réelle)',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        const Text(
                          '👉 Règle de contrôle : Mesure à la règle (mm sur papier) ÷ Grossissement = Cote Réelle (mm sur tube).',
                          style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Tableau comparatif
                  const Text(
                    '📊 Tableau de Comparaison des Cotes :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 4, child: Text('Cote', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 3, child: Text('Réel (Pièce)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy))),
                        Expanded(flex: 3, child: Text('Sur Papier A4', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  buildRow('Épaisseur Tôle', epReelMm),
                  buildRow('Surépaisseur EXT', sExtMm),
                  buildRow('Surépaisseur INT', sIntMm),
                  buildRow('Largeur Cordon EXT', lExtMm),
                  buildRow('Largeur Cordon INT', lIntMm),
                  buildRow('Pénétration EXT', pExtMm, extra: '(${(pExtMm / epReelMm * 100).toStringAsFixed(1)}%)'),
                  buildRow('Pénétration INT', pIntMm, extra: '(${(pIntMm / epReelMm * 100).toStringAsFixed(1)}%)'),
                  buildRow('Interpénétration', interpMm),
                  buildRow('Désaxage (Misalignment)', desaxageMm),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Calculs Validés'),
            ),
          ],
        );
      },
    );
  }

  void _showHelpGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.primaryNavy),
              SizedBox(width: 8),
              Text('Guide de Mesure & Calculs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Toutes les valeurs affichées sont DÉJÀ en millimètres (mm) RÉELS de la pièce physique. Aucune multiplication par le grossissement à effectuer !',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentTeal, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.flash_on_rounded, color: AppTheme.accentTeal, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recalcul Automatique Dynamique : Modifier l\'Épaisseur Tôle ou le Grossissement (ex: 0.5, 1.5, 2.0) recalcule instantanément toutes les mesures en mm réels !',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '📐 Principe d\'Étalonnage & Grossissement :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 4),
                const Text(
                  '1. Ajustez les lignes de référence jaunes sur la surface haut et bas de la tôle.\n'
                  '2. L\'application calcule l\'échelle exacte en mm/pixel d\'après l\'épaisseur réelle renseignée (ex: 11 mm).\n'
                  '3. Modifier le Grossissement réajuste l\'échelle optique (mm/pixel) et met à jour instantanément toutes les mesures.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  '📏 Surépaisseur (mm) :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Distance perpendiculaire entre la surface de référence de la tôle et le sommet le plus haut du dôme du cordon.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  '📏 Largeur (mm) :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Distance euclidienne réelle 2D entre le pied de soudure gauche et le pied droit.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  '🟣 Désaxage (mm) :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Décalage horizontal mesuré entre le centre vertical du cordon EXT et le centre vertical du cordon INT :',
                  style: TextStyle(fontSize: 12),
                ),
                const Text(
                  '• Désaxage = |Axe EXT - Axe INT| (en mm réels)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
                const SizedBox(height: 12),
                const Text(
                  '🔄 Interpénétration (mm) :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Recouvrement entre les deux cordons de soudure calculé par la formule :',
                  style: TextStyle(fontSize: 12),
                ),
                const Text(
                  '• Interpénétration = Profondeur EXT + Profondeur INT - Épaisseur Tôle',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
              child: const Text('J\'ai compris'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebarContent() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section 1 : Étalonnage ──
            _buildSideSection(
              title: 'Étalonnage & Grossissement',
              icon: Icons.tune_rounded,
              color: const Color(0xFFD97706),
              onTap: () => setState(() => _activeMode = 'epaisseur'),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _sideField(
                        controller: _epReelCtrl,
                        label: 'Épaisseur Réelle (mm)',
                        hint: 'Au pied à coulisse',
                        onTap: () => setState(() => _activeMode = 'epaisseur'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _sideField(
                        controller: _grossissementCtrl,
                        label: 'Grossissement (G)',
                        hint: 'Auto-calculé',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _sideField(
                  controller: _epMesureePhotoCtrl,
                  label: 'Épaisseur sur Photo (mm)',
                  hint: 'Mesurée par règle jaune',
                  prefixIcon: Icons.straighten_rounded,
                  prefixColor: const Color(0xFFD97706),
                  onTap: () => setState(() => _activeMode = 'epaisseur'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Section 2 : Cordon EXT ──
            _buildSideSection(
              title: 'Cordon Extérieur',
              icon: Icons.radio_button_checked,
              color: const Color(0xFF00E5FF),
              onTap: () => setState(() => _activeMode = 'ext'),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _sideField(
                        controller: _surepExtCtrl,
                        label: 'Surépaisseur EXT (mm)',
                        onTap: () => setState(() => _activeMode = 'ext'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _sideField(
                        controller: _largeurExtCtrl,
                        label: 'Largeur EXT (mm)',
                        onTap: () => setState(() => _activeMode = 'ext'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _sideField(
                        controller: _pExtMmCtrl,
                        label: 'Profondeur EXT (mm)',
                        onTap: () => setState(() => _activeMode = 'ext'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _sideField(
                        controller: _pExtPctCtrl,
                        label: 'Pénétration EXT (%)',
                        onTap: () => setState(() => _activeMode = 'ext'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Section 3 : Cordon INT ──
            _buildSideSection(
              title: 'Cordon Intérieur',
              icon: Icons.radio_button_checked,
              color: const Color(0xFFFF9100),
              onTap: () => setState(() => _activeMode = 'int'),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _sideField(
                        controller: _surepIntCtrl,
                        label: 'Surépaisseur INT (mm)',
                        onTap: () => setState(() => _activeMode = 'int'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _sideField(
                        controller: _largeurIntCtrl,
                        label: 'Largeur INT (mm)',
                        onTap: () => setState(() => _activeMode = 'int'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _sideField(
                        controller: _pIntMmCtrl,
                        label: 'Profondeur INT (mm)',
                        onTap: () => setState(() => _activeMode = 'int'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _sideField(
                        controller: _pIntPctCtrl,
                        label: 'Pénétration INT (%)',
                        onTap: () => setState(() => _activeMode = 'int'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Section 4 : Recouvrement & Désaxage ──
            _buildSideSection(
              title: 'Recouvrement & Désaxage',
              icon: Icons.compare_arrows_rounded,
              color: const Color(0xFFE040FB),
              onTap: () => setState(() => _activeMode = 'desaxage'),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _sideField(
                        controller: _desaxageCtrl,
                        label: 'Désaxage (mm)',
                        onTap: () => setState(() => _activeMode = 'desaxage'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _sideField(
                        controller: _interpCtrl,
                        label: 'Interpénétration (mm)',
                        onTap: () => setState(() => _activeMode = 'desaxage'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Switch : Dessiner lignes ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
                ],
              ),
              child: SwitchListTile(
                value: _exportAnnotatedPhoto,
                onChanged: (val) => setState(() => _exportAnnotatedPhoto = val),
                title: const Text(
                  'Dessiner les lignes sur la photo (PV)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                ),
                subtitle: const Text(
                  'Imprime les repères et règles sur l\'image du rapport PDF.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
                activeColor: AppTheme.accentTeal,
                dense: true,
              ),
            ),
            const SizedBox(height: 14),

            // ── Bouton Valider ──
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveAndReturn,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Transférer les mesures sur le PV'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
                border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.25))),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: color == Colors.white ? const Color(0xFF1E293B) : color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Fields
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _sideField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    Color? prefixColor,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onTap: onTap,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperStyle: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
        labelStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        prefixIcon: prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 6, right: 4),
                child: Icon(prefixIcon, size: 14, color: prefixColor ?? AppTheme.accentTeal),
              )
            : null,
        prefixIconConstraints: const BoxConstraints(maxWidth: 26, maxHeight: 26),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
        ),
      ),
    );
  }




  // ── Helpers pour le menu déroulant de mode ──

  Color get _activeModeColor {
    switch (_activeMode) {
      case 'ext': return const Color(0xFF00E5FF);
      case 'int': return const Color(0xFFFF9100);
      case 'epaisseur': return const Color(0xFFD97706);
      case 'desaxage': return const Color(0xFFE040FB);
      case 'all': return Colors.white;
      default: return Colors.white70;
    }
  }

  String get _activeModeLabel {
    switch (_activeMode) {
      case 'ext': return 'Cordon EXT';
      case 'int': return 'Cordon INT';
      case 'epaisseur': return 'Épaisseur Tôle';
      case 'desaxage': return 'Désaxage / Interp.';
      case 'all': return 'Tout afficher';
      default: return 'Mode';
    }
  }

  IconData get _activeModeIcon {
    switch (_activeMode) {
      case 'ext': return Icons.radio_button_checked;
      case 'int': return Icons.radio_button_checked;
      case 'epaisseur': return Icons.straighten_rounded;
      case 'desaxage': return Icons.compare_arrows_rounded;
      case 'all': return Icons.visibility_rounded;
      default: return Icons.visibility_rounded;
    }
  }

  PopupMenuItem<String> _buildModeMenuItem(String mode, String label, Color color, IconData icon) {
    final isSelected = _activeMode == mode;
    return PopupMenuItem<String>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : null,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, color: color, size: 18),
        ],
      ),
    );
  }

  Widget _toolbarIconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: _toolbarIconContainer(
          icon: icon,
          color: color,
          isActive: isActive,
          activeColor: activeColor,
        ),
      ),
    );
  }

  Widget _toolbarIconContainer({
    required IconData icon,
    required Color color,
    required bool isActive,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? activeColor : Colors.white24,
          width: 1.2,
        ),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }


  /// Retourne ('h:i' | 'v:i', index) si un guide est proche, sinon null.
  (String, int)? _findNearestGuide(Offset pos, Rect imageRect) {
    for (int i = 0; i < _hGuides.length; i++) {
      final gy = imageRect.top + _hGuides[i] * imageRect.height;
      if ((pos.dy - gy).abs() < _guideSnapPx) return ('h:$i', i);
    }
    for (int i = 0; i < _vGuides.length; i++) {
      final gx = imageRect.left + _vGuides[i] * imageRect.width;
      if ((pos.dx - gx).abs() < _guideSnapPx) return ('v:$i', i);
    }
    return null;
  }

  void _tryDeleteGuide(Offset pos, Rect imageRect) {
    for (int i = 0; i < _hGuides.length; i++) {
      final gy = imageRect.top + _hGuides[i] * imageRect.height;
      if ((pos.dy - gy).abs() < _guideSnapPx) {
        setState(() => _hGuides.removeAt(i));
        return;
      }
    }
    for (int i = 0; i < _vGuides.length; i++) {
      final gx = imageRect.left + _vGuides[i] * imageRect.width;
      if ((pos.dx - gx).abs() < _guideSnapPx) {
        setState(() => _vGuides.removeAt(i));
        return;
      }
    }
  }

  String? _findNearestHandle(Offset pos, Size size, Rect imageRect) {
    if (!_showHandles) return null;
    final Map<String, Offset> handles = {};

    if (_activeMode == 'all' || _activeMode == 'epaisseur') {
      handles['epTop'] = Offset(imageRect.left + _epTop.dx * imageRect.width, imageRect.top + _epTop.dy * imageRect.height);
      handles['epBottom'] = Offset(imageRect.left + _epBottom.dx * imageRect.width, imageRect.top + _epBottom.dy * imageRect.height);
    }
    if (_activeMode == 'all' || _activeMode == 'ext') {
      handles['extTop'] = Offset(imageRect.left + _extTop.dx * imageRect.width, imageRect.top + _extTop.dy * imageRect.height);
      handles['extLeft'] = Offset(imageRect.left + _extLeft.dx * imageRect.width, imageRect.top + _extLeft.dy * imageRect.height);
      handles['extRight'] = Offset(imageRect.left + _extRight.dx * imageRect.width, imageRect.top + _extRight.dy * imageRect.height);
      handles['extDeep'] = Offset(imageRect.left + _extDeep.dx * imageRect.width, imageRect.top + _extDeep.dy * imageRect.height);
      handles['extFlankLeft1'] = Offset(imageRect.left + _effectiveExtFlankLeft1.dx * imageRect.width, imageRect.top + _effectiveExtFlankLeft1.dy * imageRect.height);
      handles['extFlankLeft2'] = Offset(imageRect.left + _effectiveExtFlankLeft2.dx * imageRect.width, imageRect.top + _effectiveExtFlankLeft2.dy * imageRect.height);
      handles['extFlankRight1'] = Offset(imageRect.left + _effectiveExtFlankRight1.dx * imageRect.width, imageRect.top + _effectiveExtFlankRight1.dy * imageRect.height);
      handles['extFlankRight2'] = Offset(imageRect.left + _effectiveExtFlankRight2.dx * imageRect.width, imageRect.top + _effectiveExtFlankRight2.dy * imageRect.height);
      handles['extCapFlankRight1'] = Offset(imageRect.left + _effectiveExtCapFlankRight1.dx * imageRect.width, imageRect.top + _effectiveExtCapFlankRight1.dy * imageRect.height);
      handles['extCapFlankRight2'] = Offset(imageRect.left + _effectiveExtCapFlankRight2.dx * imageRect.width, imageRect.top + _effectiveExtCapFlankRight2.dy * imageRect.height);
      handles['extCapFlankLeft1'] = Offset(imageRect.left + _effectiveExtCapFlankLeft1.dx * imageRect.width, imageRect.top + _effectiveExtCapFlankLeft1.dy * imageRect.height);
      handles['extCapFlankLeft2'] = Offset(imageRect.left + _effectiveExtCapFlankLeft2.dx * imageRect.width, imageRect.top + _effectiveExtCapFlankLeft2.dy * imageRect.height);
    }
    if (_activeMode == 'all' || _activeMode == 'int') {
      handles['intBottom'] = Offset(imageRect.left + _intBottom.dx * imageRect.width, imageRect.top + _intBottom.dy * imageRect.height);
      handles['intLeft'] = Offset(imageRect.left + _intLeft.dx * imageRect.width, imageRect.top + _intLeft.dy * imageRect.height);
      handles['intRight'] = Offset(imageRect.left + _intRight.dx * imageRect.width, imageRect.top + _intRight.dy * imageRect.height);
      handles['intDeep'] = Offset(imageRect.left + _intDeep.dx * imageRect.width, imageRect.top + _intDeep.dy * imageRect.height);
      handles['intFlankLeft1'] = Offset(imageRect.left + _effectiveIntFlankLeft1.dx * imageRect.width, imageRect.top + _effectiveIntFlankLeft1.dy * imageRect.height);
      handles['intFlankLeft2'] = Offset(imageRect.left + _effectiveIntFlankLeft2.dx * imageRect.width, imageRect.top + _effectiveIntFlankLeft2.dy * imageRect.height);
      handles['intFlankRight1'] = Offset(imageRect.left + _effectiveIntFlankRight1.dx * imageRect.width, imageRect.top + _effectiveIntFlankRight1.dy * imageRect.height);
      handles['intFlankRight2'] = Offset(imageRect.left + _effectiveIntFlankRight2.dx * imageRect.width, imageRect.top + _effectiveIntFlankRight2.dy * imageRect.height);
      handles['intCapFlankRight1'] = Offset(imageRect.left + _effectiveIntCapFlankRight1.dx * imageRect.width, imageRect.top + _effectiveIntCapFlankRight1.dy * imageRect.height);
      handles['intCapFlankRight2'] = Offset(imageRect.left + _effectiveIntCapFlankRight2.dx * imageRect.width, imageRect.top + _effectiveIntCapFlankRight2.dy * imageRect.height);
      handles['intCapFlankLeft1'] = Offset(imageRect.left + _effectiveIntCapFlankLeft1.dx * imageRect.width, imageRect.top + _effectiveIntCapFlankLeft1.dy * imageRect.height);
      handles['intCapFlankLeft2'] = Offset(imageRect.left + _effectiveIntCapFlankLeft2.dx * imageRect.width, imageRect.top + _effectiveIntCapFlankLeft2.dy * imageRect.height);
    }
    if (_activeMode == 'all' || _activeMode == 'desaxage') {
      handles['interLeft'] = Offset(imageRect.left + _effectiveInterLeft.dx * imageRect.width, imageRect.top + _effectiveInterLeft.dy * imageRect.height);
      handles['interRight'] = Offset(imageRect.left + _effectiveInterRight.dx * imageRect.width, imageRect.top + _effectiveInterRight.dy * imageRect.height);
    }

    String? closestKey;
    double minDistance = 35.0;

    handles.forEach((key, handlePos) {
      final dist = (pos - handlePos).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closestKey = key;
      }
    });

    return closestKey;
  }

  /// Description textuelle du repère actuellement déplacé
  String _getHandleDescription(String key) {
    switch (key) {
      case 'epTop': return 'Épaisseur Tôle (Haut)';
      case 'epBottom': return 'Épaisseur Tôle (Bas)';
      case 'extTop': return 'Sommet Cordon EXT';
      case 'extLeft': return 'Pied Gauche EXT';
      case 'extRight': return 'Pied Droit EXT';
      case 'extDeep': return 'Racine / Pénétration EXT';
      case 'extFlankLeft1': case 'extFlankLeft2': return 'Flanc Pénétration G. (EXT)';
      case 'extFlankRight1': case 'extFlankRight2': return 'Flanc Pénétration D. (EXT)';
      case 'extCapFlankLeft1': case 'extCapFlankLeft2': return 'Flanc Chapeau G. (EXT)';
      case 'extCapFlankRight1': case 'extCapFlankRight2': return 'Flanc Chapeau D. (EXT)';
      case 'intBottom': return 'Sommet Cordon INT';
      case 'intLeft': return 'Pied Gauche INT';
      case 'intRight': return 'Pied Droit INT';
      case 'intDeep': return 'Racine / Pénétration INT';
      case 'intFlankLeft1': case 'intFlankLeft2': return 'Flanc Pénétration G. (INT)';
      case 'intFlankRight1': case 'intFlankRight2': return 'Flanc Pénétration D. (INT)';
      case 'intCapFlankLeft1': case 'intCapFlankLeft2': return 'Flanc Chapeau G. (INT)';
      case 'intCapFlankRight1': case 'intCapFlankRight2': return 'Flanc Chapeau D. (INT)';
      case 'interLeft': return 'Interpénétration Gauche';
      case 'interRight': return 'Interpénétration Droite';
      default: return 'Repère de mesure';
    }
  }

  /// Construit la fenêtre de zoom fixe haute précision (HUD)
  Widget _buildPrecisionMagnifier(Size canvasSize, Offset touchPos) {
    const double boxWidth = 126.0;
    const double boxHeight = 126.0;
    const double zoomScale = 2.5;

    // Position fixe stable : en haut à droite (ou à gauche si le doigt est dans le coin droit)
    final bool placeOnLeft = touchPos.dx > (canvasSize.width * 0.55) && touchPos.dy < (boxHeight + 40.0);

    final double left = placeOnLeft ? 24.0 : (canvasSize.width - boxWidth - 10.0);
    const double top = 24.0;

    final centerOfBox = Offset(left + boxWidth / 2, top + boxHeight / 2);
    final focalOffset = touchPos - centerOfBox;

    final handleTitle = _guideDragId != null
        ? 'Guide Repère'
        : _getHandleDescription(_activeHandle ?? '');

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: boxWidth,
          height: boxHeight,
          decoration: BoxDecoration(
            color: const Color(0xF0141424),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accentTeal, width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // ── Vue zoomée x2.5 centrée sur le point touché ──
              Positioned.fill(
                child: RawMagnifier(
                  decoration: const MagnifierDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  size: const Size(boxWidth, boxHeight),
                  magnificationScale: zoomScale,
                  focalPointOffset: focalOffset,
                  child: const CustomPaint(
                    size: Size(boxWidth, boxHeight),
                    painter: _MagnifierReticlePainter(),
                  ),
                ),
              ),

              // ── Bandeau supérieur HUD fixe ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: const BoxDecoration(
                    color: Color(0xE60D1B2A),
                    border: Border(
                      bottom: BorderSide(color: Color(0x4000E5FF), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location_rounded, size: 10, color: AppTheme.accentTeal),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          handleTitle,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'x2.5',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<File?> _generateAnnotatedImageFile() async {
    try {
      final basePhotoPath = widget.rawPhotoPath?.isNotEmpty == true
          ? widget.rawPhotoPath!
          : widget.photoPath;
      final originalFile = File(basePhotoPath);
      if (!originalFile.existsSync()) return null;

      final bytes = await originalFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final w = image.width.toDouble();
      final h = image.height.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

      // 1. Dessiner l'image originale avec le filtre actif
      final imgPaint = Paint();
      if (_measureFilterMatrix != null) {
        imgPaint.colorFilter = ColorFilter.matrix(_measureFilterMatrix!);
      }
      canvas.drawImage(image, Offset.zero, imgPaint);

      // 2. Dessiner le calque de mesure complet (toutes les lignes)
      final overlayPainter = _WeldOverlayPainter(
        epTop: _epTop,
        epBottom: _epBottom,
        extTop: _extTop,
        extLeft: _extLeft,
        extRight: _extRight,
        extDeep: _extDeep,
        extFlankLeft1: _effectiveExtFlankLeft1,
        extFlankLeft2: _effectiveExtFlankLeft2,
        extFlankRight1: _effectiveExtFlankRight1,
        extFlankRight2: _effectiveExtFlankRight2,
        extCapFlankRight1: _effectiveExtCapFlankRight1,
        extCapFlankRight2: _effectiveExtCapFlankRight2,
        extCapFlankLeft1: _effectiveExtCapFlankLeft1,
        extCapFlankLeft2: _effectiveExtCapFlankLeft2,
        intBottom: _intBottom,
        intLeft: _intLeft,
        intRight: _intRight,
        intDeep: _intDeep,
        intFlankLeft1: _effectiveIntFlankLeft1,
        intFlankLeft2: _effectiveIntFlankLeft2,
        intFlankRight1: _effectiveIntFlankRight1,
        intFlankRight2: _effectiveIntFlankRight2,
        intCapFlankRight1: _effectiveIntCapFlankRight1,
        intCapFlankRight2: _effectiveIntCapFlankRight2,
        intCapFlankLeft1: _effectiveIntCapFlankLeft1,
        intCapFlankLeft2: _effectiveIntCapFlankLeft2,
        interLeft: _effectiveInterLeft,
        interRight: _effectiveInterRight,
        activeMode: 'all',
        showHandles: false,
        epReel: double.tryParse(_epReelCtrl.text.replaceAll(',', '.')) ?? 11.0,
        imageRect: Rect.fromLTWH(0, 0, w, h),
        strokeThickness: _repereThickness,
        repereTheme: _repereTheme,
        displayFilter: _displayFilter,
      );
      overlayPainter.paint(canvas, Size(w, h));

      // 3. Dessiner les guides Inkscape si présents
      if (_hGuides.isNotEmpty || _vGuides.isNotEmpty) {
        final guidesPainter = _GuidesPainter(
          hGuides: _hGuides,
          vGuides: _vGuides,
          imageRect: Rect.fromLTWH(0, 0, w, h),
          pdfPhotoHeightMm: _getPdfImageHeightMm(),
        );
        guidesPainter.paint(canvas, Size(w, h));
      }

      final picture = recorder.endRecording();
      final imgAnnotated = await picture.toImage(image.width, image.height);
      final pngData = await imgAnnotated.toByteData(format: ui.ImageByteFormat.png);

      if (pngData != null) {
        final String dirPath = originalFile.parent.path;
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String newPath = '$dirPath/photo_annotated_$timestamp.png';
        final newFile = File(newPath);
        await newFile.writeAsBytes(pngData.buffer.asUint8List());
        return newFile;
      }
    } catch (e) {
      debugPrint('Erreur lors de la génération de la photo annotée: $e');
    }
    return null;
  }

  void _saveAndReturn() async {
    final rawPath = widget.rawPhotoPath?.isNotEmpty == true
        ? widget.rawPhotoPath!
        : widget.photoPath;

    String? annotatedPath;
    if (_exportAnnotatedPhoto) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Génération de l\'image annotée pour le PV...'),
                ],
              ),
            ),
          ),
        ),
      );
      final file = await _generateAnnotatedImageFile();
      if (mounted) Navigator.pop(context);
      if (file != null) annotatedPath = file.path;
    } else {
      annotatedPath = rawPath;
    }

    final measureDataMap = {
      'version': 1,
      'epTop': _offsetToList(_epTop),
      'epBottom': _offsetToList(_epBottom),
      'extTop': _offsetToList(_extTop),
      'extLeft': _offsetToList(_extLeft),
      'extRight': _offsetToList(_extRight),
      'extDeep': _offsetToList(_extDeep),
      'intBottom': _offsetToList(_intBottom),
      'intLeft': _offsetToList(_intLeft),
      'intRight': _offsetToList(_intRight),
      'intDeep': _offsetToList(_intDeep),
      'extFlankLeft1': _offsetToList(_extFlankLeft1),
      'extFlankLeft2': _offsetToList(_extFlankLeft2),
      'extFlankRight1': _offsetToList(_extFlankRight1),
      'extFlankRight2': _offsetToList(_extFlankRight2),
      'extCapFlankLeft1': _offsetToList(_extCapFlankLeft1),
      'extCapFlankLeft2': _offsetToList(_extCapFlankLeft2),
      'extCapFlankRight1': _offsetToList(_extCapFlankRight1),
      'extCapFlankRight2': _offsetToList(_extCapFlankRight2),
      'intFlankLeft1': _offsetToList(_intFlankLeft1),
      'intFlankLeft2': _offsetToList(_intFlankLeft2),
      'intFlankRight1': _offsetToList(_intFlankRight1),
      'intFlankRight2': _offsetToList(_intFlankRight2),
      'intCapFlankLeft1': _offsetToList(_intCapFlankLeft1),
      'intCapFlankLeft2': _offsetToList(_intCapFlankLeft2),
      'intCapFlankRight1': _offsetToList(_intCapFlankRight1),
      'intCapFlankRight2': _offsetToList(_intCapFlankRight2),
      'manualInterLeft': _offsetToList(_manualInterLeft),
      'manualInterRight': _offsetToList(_manualInterRight),
      'hGuides': _hGuides,
      'vGuides': _vGuides,
      'exportAnnotatedPhoto': _exportAnnotatedPhoto,
      'activeMode': _activeMode,
      'showHandles': _showHandles,
      'repereThickness': _repereThickness,
      'repereTheme': _repereTheme,
      'displayFilter': _displayFilter,
    };
    final measureDataJson = jsonEncode(measureDataMap);

    final result = PhotoMeasureResult(
      epReel: _epReelCtrl.text.trim(),
      grossissement: _grossissementCtrl.text.trim(),
      surepExt: _surepExtCtrl.text.trim(),
      surepInt: _surepIntCtrl.text.trim(),
      largeurExt: _largeurExtCtrl.text.trim(),
      largeurInt: _largeurIntCtrl.text.trim(),
      penetrationExt: _pExtPctCtrl.text.trim(),
      penetrationInt: _pIntPctCtrl.text.trim(),
      desaxage: _desaxageCtrl.text.trim(),
      interpenetration: _interpCtrl.text.trim(),
      annotatedPhotoPath: annotatedPath,
      rawPhotoPath: rawPath,
      measureData: measureDataJson,
    );
    if (mounted) Navigator.pop(context, result);
  }
}

class _WeldOverlayPainter extends CustomPainter {
  final Offset epTop;
  final Offset epBottom;
  final Offset extTop;
  final Offset extLeft;
  final Offset extRight;
  final Offset extDeep;
  final Offset extFlankLeft1, extFlankLeft2;
  final Offset extFlankRight1, extFlankRight2;
  final Offset extCapFlankRight1, extCapFlankRight2;
  final Offset extCapFlankLeft1, extCapFlankLeft2;
  final Offset intBottom;
  final Offset intLeft;
  final Offset intRight;
  final Offset intDeep;
  final Offset intFlankLeft1, intFlankLeft2;
  final Offset intFlankRight1, intFlankRight2;
  final Offset intCapFlankRight1, intCapFlankRight2;
  final Offset intCapFlankLeft1, intCapFlankLeft2;
  final Offset interLeft;
  final Offset interRight;
  final String activeMode;
  final bool showHandles;
  final double epReel;
  final Rect imageRect;
  final double strokeThickness;
  final String repereTheme;
  final String displayFilter;

  _WeldOverlayPainter({
    required this.epTop,
    required this.epBottom,
    required this.extTop,
    required this.extLeft,
    required this.extRight,
    required this.extDeep,
    required this.extFlankLeft1,
    required this.extFlankLeft2,
    required this.extFlankRight1,
    required this.extFlankRight2,
    required this.extCapFlankRight1,
    required this.extCapFlankRight2,
    required this.extCapFlankLeft1,
    required this.extCapFlankLeft2,
    required this.intBottom,
    required this.intLeft,
    required this.intRight,
    required this.intDeep,
    required this.intFlankLeft1,
    required this.intFlankLeft2,
    required this.intFlankRight1,
    required this.intFlankRight2,
    required this.intCapFlankRight1,
    required this.intCapFlankRight2,
    required this.intCapFlankLeft1,
    required this.intCapFlankLeft2,
    required this.interLeft,
    required this.interRight,
    required this.activeMode,
    this.showHandles = true,
    required this.epReel,
    required this.imageRect,
    this.strokeThickness = 2.4,
    this.repereTheme = 'auto',
    this.displayFilter = 'none',
  });

  Color get colorBase {
    if (repereTheme == 'monochrome_white') return Colors.white;
    if (repereTheme == 'monochrome_yellow') return const Color(0xFFFFEA00);
    if (repereTheme == 'rx_neon') return const Color(0xFFFFFF00);
    if (repereTheme == 'bw_highvis') return const Color(0xFFFFD600);
    if (repereTheme == 'auto') {
      if (displayFilter == 'negative') return const Color(0xFFFFEE58);
      if (displayFilter == 'radio_macro') return const Color(0xFFFFD600);
      if (displayFilter == 'contrast') return const Color(0xFFFFD600);
    }
    return Colors.amberAccent;
  }

  Color get colorExt {
    if (repereTheme == 'monochrome_white') return Colors.white;
    if (repereTheme == 'monochrome_yellow') return const Color(0xFFFFEA00);
    if (repereTheme == 'rx_neon') return const Color(0xFF00FFCC);
    if (repereTheme == 'bw_highvis') return const Color(0xFF00E5FF);
    if (repereTheme == 'auto') {
      if (displayFilter == 'negative') return const Color(0xFF00FFCC);
      if (displayFilter == 'radio_macro') return const Color(0xFF00E5FF);
      if (displayFilter == 'contrast') return const Color(0xFF00E5FF);
    }
    return const Color(0xFF00E5FF);
  }

  Color get colorInt {
    if (repereTheme == 'monochrome_white') return Colors.white.withValues(alpha: 0.85);
    if (repereTheme == 'monochrome_yellow') return const Color(0xFFFFB300);
    if (repereTheme == 'rx_neon') return const Color(0xFFFF3366);
    if (repereTheme == 'bw_highvis') return const Color(0xFFFF9100);
    if (repereTheme == 'auto') {
      if (displayFilter == 'negative') return const Color(0xFFFF3366);
      if (displayFilter == 'radio_macro') return const Color(0xFFFF9100);
      if (displayFilter == 'contrast') return const Color(0xFFFF6D00);
    }
    return const Color(0xFFFF9100);
  }

  Color get colorArrow {
    if (repereTheme == 'monochrome_white') return Colors.white;
    if (repereTheme == 'monochrome_yellow') return const Color(0xFFFFEA00);
    if (repereTheme == 'rx_neon') return const Color(0xFFFF007F);
    if (repereTheme == 'bw_highvis') return const Color(0xFFE040FB);
    if (repereTheme == 'auto') {
      if (displayFilter == 'negative') return const Color(0xFFFF007F);
      if (displayFilter == 'radio_macro') return const Color(0xFFE040FB);
      if (displayFilter == 'contrast') return const Color(0xFFD500F9);
    }
    return const Color(0xFFE040FB);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pEpTop = Offset(imageRect.left + epTop.dx * imageRect.width, imageRect.top + epTop.dy * imageRect.height);
    final pEpBottom = Offset(imageRect.left + epBottom.dx * imageRect.width, imageRect.top + epBottom.dy * imageRect.height);

    final pExtTop = Offset(imageRect.left + extTop.dx * imageRect.width, imageRect.top + extTop.dy * imageRect.height);
    final pExtLeft = Offset(imageRect.left + extLeft.dx * imageRect.width, imageRect.top + extLeft.dy * imageRect.height);
    final pExtRight = Offset(imageRect.left + extRight.dx * imageRect.width, imageRect.top + extRight.dy * imageRect.height);
    final pExtDeep = Offset(imageRect.left + extDeep.dx * imageRect.width, imageRect.top + extDeep.dy * imageRect.height);

    final pIntBottom = Offset(imageRect.left + intBottom.dx * imageRect.width, imageRect.top + intBottom.dy * imageRect.height);
    final pIntLeft = Offset(imageRect.left + intLeft.dx * imageRect.width, imageRect.top + intLeft.dy * imageRect.height);
    final pIntRight = Offset(imageRect.left + intRight.dx * imageRect.width, imageRect.top + intRight.dy * imageRect.height);
    final pIntDeep = Offset(imageRect.left + intDeep.dx * imageRect.width, imageRect.top + intDeep.dy * imageRect.height);

    final sf = (imageRect.height / 550.0).clamp(1.0, 10.0);
    final effThick = (strokeThickness * sf).clamp(0.8, 25.0);

    final showEp = activeMode == 'all' || activeMode == 'epaisseur';
    final showExt = activeMode == 'all' || activeMode == 'ext';
    final showInt = activeMode == 'all' || activeMode == 'int';
    final showDesaxage = activeMode == 'all' || activeMode == 'desaxage';

    final paintBase = Paint()
      ..color = colorBase
      ..strokeWidth = effThick
      ..style = PaintingStyle.stroke;

    final paintExt = Paint()
      ..color = colorExt
      ..strokeWidth = effThick
      ..style = PaintingStyle.stroke;

    final paintInt = Paint()
      ..color = colorInt
      ..strokeWidth = effThick
      ..style = PaintingStyle.stroke;

    // Règle Graduée Métallurgique (Visual Ruler Bar)
    _drawGraduatedRuler(canvas, size, pEpTop, pEpBottom);

    // Lignes Épaisseur métal de base
    if (showEp) {
      canvas.drawLine(Offset(imageRect.left, pEpTop.dy), Offset(imageRect.right, pEpTop.dy), paintBase);
      canvas.drawLine(Offset(imageRect.left, pEpBottom.dy), Offset(imageRect.right, pEpBottom.dy), paintBase);
      if (showHandles) {
        _drawSolidWorksArrowHandle(canvas, pEpTop, AxisDirection.up, colorBase, sf);
        _drawSolidWorksArrowHandle(canvas, pEpBottom, AxisDirection.down, colorBase, sf);
      }
    }

    // ── Cordon Extérieur ───────────────────────────────────────────────────
    if (showExt) {
      // Poignées de flanc de pénétration
      final pExtFlankLeft1 = Offset(imageRect.left + extFlankLeft1.dx * imageRect.width, imageRect.top + extFlankLeft1.dy * imageRect.height);
      final pExtFlankLeft2 = Offset(imageRect.left + extFlankLeft2.dx * imageRect.width, imageRect.top + extFlankLeft2.dy * imageRect.height);
      final pExtFlankRight1 = Offset(imageRect.left + extFlankRight1.dx * imageRect.width, imageRect.top + extFlankRight1.dy * imageRect.height);
      final pExtFlankRight2 = Offset(imageRect.left + extFlankRight2.dx * imageRect.width, imageRect.top + extFlankRight2.dy * imageRect.height);

      // Poignées de flanc de surépaisseur (chapeau)
      final pExtCapFlankRight1 = Offset(imageRect.left + extCapFlankRight1.dx * imageRect.width, imageRect.top + extCapFlankRight1.dy * imageRect.height);
      final pExtCapFlankRight2 = Offset(imageRect.left + extCapFlankRight2.dx * imageRect.width, imageRect.top + extCapFlankRight2.dy * imageRect.height);
      final pExtCapFlankLeft1 = Offset(imageRect.left + extCapFlankLeft1.dx * imageRect.width, imageRect.top + extCapFlankLeft1.dy * imageRect.height);
      final pExtCapFlankLeft2 = Offset(imageRect.left + extCapFlankLeft2.dx * imageRect.width, imageRect.top + extCapFlankLeft2.dy * imageRect.height);

      // Profil complet EXT (Bézier Cubique sur les 4 quadrants)
      final pathExtWeld = Path()
        ..moveTo(pExtLeft.dx, pExtLeft.dy)
        ..cubicTo(pExtFlankLeft1.dx, pExtFlankLeft1.dy, pExtFlankLeft2.dx, pExtFlankLeft2.dy, pExtDeep.dx, pExtDeep.dy)
        ..cubicTo(pExtFlankRight1.dx, pExtFlankRight1.dy, pExtFlankRight2.dx, pExtFlankRight2.dy, pExtRight.dx, pExtRight.dy)
        ..cubicTo(pExtCapFlankRight1.dx, pExtCapFlankRight1.dy, pExtCapFlankRight2.dx, pExtCapFlankRight2.dy, pExtTop.dx, pExtTop.dy)
        ..cubicTo(pExtCapFlankLeft1.dx, pExtCapFlankLeft1.dy, pExtCapFlankLeft2.dx, pExtCapFlankLeft2.dy, pExtLeft.dx, pExtLeft.dy)
        ..close();

      canvas.drawPath(pathExtWeld, Paint()..color = colorExt.withValues(alpha: 0.12)..style = PaintingStyle.fill);
      canvas.drawPath(pathExtWeld, Paint()..color = colorExt.withValues(alpha: 0.90)..strokeWidth = (effThick * 0.85).clamp(1.0, 20.0)..style = PaintingStyle.stroke);

      // Ligne horizontale de base (largeur de cordon)
      _drawDashedLine(canvas, pExtLeft, pExtRight,
          Paint()..color = colorExt.withValues(alpha: 0.5)..strokeWidth = (effThick * 0.5).clamp(0.8, 10.0)..style = PaintingStyle.stroke);

      // Axes de mesure
      canvas.drawLine(pExtTop, Offset(pExtTop.dx, pEpTop.dy), paintExt);
      canvas.drawLine(Offset(pExtDeep.dx, pEpTop.dy), pExtDeep, paintExt);

      if (showHandles) {
        // Poignées de contrôle principales
        _drawSolidWorksArrowHandle(canvas, pExtTop, AxisDirection.up, colorExt, sf);
        _drawSolidWorksArrowHandle(canvas, pExtLeft, AxisDirection.left, colorExt, sf);
        _drawSolidWorksArrowHandle(canvas, pExtRight, AxisDirection.right, colorExt, sf);
        _drawSolidWorksArrowHandle(canvas, pExtDeep, AxisDirection.down, colorExt, sf);

        // 8 Poignées de flanc en losange (◆)
        _drawFlankHandle(canvas, pExtFlankLeft1, colorExt, sf);
        _drawFlankHandle(canvas, pExtFlankLeft2, colorExt, sf);
        _drawFlankHandle(canvas, pExtFlankRight1, colorExt, sf);
        _drawFlankHandle(canvas, pExtFlankRight2, colorExt, sf);

        _drawFlankHandle(canvas, pExtCapFlankRight1, colorExt, sf);
        _drawFlankHandle(canvas, pExtCapFlankRight2, colorExt, sf);
        _drawFlankHandle(canvas, pExtCapFlankLeft1, colorExt, sf);
        _drawFlankHandle(canvas, pExtCapFlankLeft2, colorExt, sf);

        // Lignes de connexion des polygones de contrôle en pointillés
        final pDash = Paint()..color = colorExt.withValues(alpha: 0.35)..strokeWidth = (effThick * 0.45).clamp(0.8, 8.0)..style = PaintingStyle.stroke;
        _drawDashedLine(canvas, pExtLeft, pExtFlankLeft1, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtFlankLeft1, pExtFlankLeft2, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtFlankLeft2, pExtDeep, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtDeep, pExtFlankRight1, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtFlankRight1, pExtFlankRight2, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtFlankRight2, pExtRight, pDash, dashLen: 3, gapLen: 3);

        _drawDashedLine(canvas, pExtRight, pExtCapFlankRight1, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtCapFlankRight1, pExtCapFlankRight2, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtCapFlankRight2, pExtTop, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtTop, pExtCapFlankLeft1, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtCapFlankLeft1, pExtCapFlankLeft2, pDash, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pExtCapFlankLeft2, pExtLeft, pDash, dashLen: 3, gapLen: 3);
      }
    }

    // ── Cordon Intérieur ────────────────────────────────────────────────────
    if (showInt) {
      // Poignées de flanc INT pénétration
      final pIntFlankLeft1 = Offset(imageRect.left + intFlankLeft1.dx * imageRect.width, imageRect.top + intFlankLeft1.dy * imageRect.height);
      final pIntFlankLeft2 = Offset(imageRect.left + intFlankLeft2.dx * imageRect.width, imageRect.top + intFlankLeft2.dy * imageRect.height);
      final pIntFlankRight1 = Offset(imageRect.left + intFlankRight1.dx * imageRect.width, imageRect.top + intFlankRight1.dy * imageRect.height);
      final pIntFlankRight2 = Offset(imageRect.left + intFlankRight2.dx * imageRect.width, imageRect.top + intFlankRight2.dy * imageRect.height);

      // Poignées de flanc INT surépaisseur (chapeau)
      final pIntCapFlankRight1 = Offset(imageRect.left + intCapFlankRight1.dx * imageRect.width, imageRect.top + intCapFlankRight1.dy * imageRect.height);
      final pIntCapFlankRight2 = Offset(imageRect.left + intCapFlankRight2.dx * imageRect.width, imageRect.top + intCapFlankRight2.dy * imageRect.height);
      final pIntCapFlankLeft1 = Offset(imageRect.left + intCapFlankLeft1.dx * imageRect.width, imageRect.top + intCapFlankLeft1.dy * imageRect.height);
      final pIntCapFlankLeft2 = Offset(imageRect.left + intCapFlankLeft2.dx * imageRect.width, imageRect.top + intCapFlankLeft2.dy * imageRect.height);

      // Profil complet INT (Bézier Cubique sur les 4 quadrants)
      final pathIntWeld = Path()
        ..moveTo(pIntLeft.dx, pIntLeft.dy)
        ..cubicTo(pIntFlankLeft1.dx, pIntFlankLeft1.dy, pIntFlankLeft2.dx, pIntFlankLeft2.dy, pIntDeep.dx, pIntDeep.dy)
        ..cubicTo(pIntFlankRight1.dx, pIntFlankRight1.dy, pIntFlankRight2.dx, pIntFlankRight2.dy, pIntRight.dx, pIntRight.dy)
        ..cubicTo(pIntCapFlankRight1.dx, pIntCapFlankRight1.dy, pIntCapFlankRight2.dx, pIntCapFlankRight2.dy, pIntBottom.dx, pIntBottom.dy)
        ..cubicTo(pIntCapFlankLeft1.dx, pIntCapFlankLeft1.dy, pIntCapFlankLeft2.dx, pIntCapFlankLeft2.dy, pIntLeft.dx, pIntLeft.dy)
        ..close();

      canvas.drawPath(pathIntWeld, Paint()..color = colorInt.withValues(alpha: 0.12)..style = PaintingStyle.fill);
      canvas.drawPath(pathIntWeld, Paint()..color = colorInt.withValues(alpha: 0.90)..strokeWidth = (effThick * 0.85).clamp(1.0, 20.0)..style = PaintingStyle.stroke);

      // Ligne horizontale de base (largeur de cordon)
      _drawDashedLine(canvas, pIntLeft, pIntRight,
          Paint()..color = colorInt.withValues(alpha: 0.5)..strokeWidth = (effThick * 0.5).clamp(0.8, 10.0)..style = PaintingStyle.stroke);

      // Axes de mesure
      canvas.drawLine(pIntBottom, Offset(pIntBottom.dx, pEpBottom.dy), paintInt);
      canvas.drawLine(Offset(pIntDeep.dx, pEpBottom.dy), pIntDeep, paintInt);

      if (showHandles) {
        // Poignées de contrôle Principales SolidWorks
        _drawSolidWorksArrowHandle(canvas, pIntBottom, AxisDirection.down, colorInt, sf);
        _drawSolidWorksArrowHandle(canvas, pIntLeft, AxisDirection.left, colorInt, sf);
        _drawSolidWorksArrowHandle(canvas, pIntRight, AxisDirection.right, colorInt, sf);
        _drawSolidWorksArrowHandle(canvas, pIntDeep, AxisDirection.up, colorInt, sf);

        // 8 Poignées de flanc INT en losange (◆)
        _drawFlankHandle(canvas, pIntFlankLeft1, colorInt, sf);
        _drawFlankHandle(canvas, pIntFlankLeft2, colorInt, sf);
        _drawFlankHandle(canvas, pIntFlankRight1, colorInt, sf);
        _drawFlankHandle(canvas, pIntFlankRight2, colorInt, sf);

        _drawFlankHandle(canvas, pIntCapFlankRight1, colorInt, sf);
        _drawFlankHandle(canvas, pIntCapFlankRight2, colorInt, sf);
        _drawFlankHandle(canvas, pIntCapFlankLeft1, colorInt, sf);
        _drawFlankHandle(canvas, pIntCapFlankLeft2, colorInt, sf);

        // Lignes de connexion des flancs en pointillés
        final pDashInt = Paint()..color = colorInt.withValues(alpha: 0.35)..strokeWidth = (effThick * 0.45).clamp(0.8, 8.0)..style = PaintingStyle.stroke;
        _drawDashedLine(canvas, pIntLeft, pIntFlankLeft1, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntFlankLeft1, pIntFlankLeft2, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntFlankLeft2, pIntDeep, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntDeep, pIntFlankRight1, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntFlankRight1, pIntFlankRight2, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntFlankRight2, pIntRight, pDashInt, dashLen: 3, gapLen: 3);

        _drawDashedLine(canvas, pIntRight, pIntCapFlankRight1, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntCapFlankRight1, pIntCapFlankRight2, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntCapFlankRight2, pIntBottom, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntBottom, pIntCapFlankLeft1, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntCapFlankLeft1, pIntCapFlankLeft2, pDashInt, dashLen: 3, gapLen: 3);
        _drawDashedLine(canvas, pIntCapFlankLeft2, pIntLeft, pDashInt, dashLen: 3, gapLen: 3);
      }
    }

    // ── Désaxage API 5L § 9.10.2 / Figure 4 c) ─────────────────────────────
    if (showDesaxage) {
      final pIntG = Offset(
        imageRect.left + interLeft.dx * imageRect.width,
        imageRect.top + interLeft.dy * imageRect.height,
      );
      final pIntD = Offset(
        imageRect.left + interRight.dx * imageRect.width,
        imageRect.top + interRight.dy * imageRect.height,
      );

      final yExtTargetNorm = interLeft.dy < interRight.dy ? interLeft.dy : interRight.dy;
      final yIntTargetNorm = interLeft.dy > interRight.dy ? interLeft.dy : interRight.dy;

      final yExtPx = imageRect.top + yExtTargetNorm * imageRect.height;
      final yIntPx = imageRect.top + yIntTargetNorm * imageRect.height;

      final (xExtLNorm, xExtRNorm) = _PhotoMeasureScreenState._evalBeadEndpointsAtY(
        yTarget: yExtTargetNorm,
        toeLeft: extLeft,
        flankLeft1: extFlankLeft1,
        flankLeft2: extFlankLeft2,
        deep: extDeep,
        flankRight1: extFlankRight1,
        flankRight2: extFlankRight2,
        toeRight: extRight,
      );
      final (xIntLNorm, xIntRNorm) = _PhotoMeasureScreenState._evalBeadEndpointsAtY(
        yTarget: yIntTargetNorm,
        toeLeft: intLeft,
        flankLeft1: intFlankLeft1,
        flankLeft2: intFlankLeft2,
        deep: intDeep,
        flankRight1: intFlankRight1,
        flankRight2: intFlankRight2,
        toeRight: intRight,
      );

      final pExtLineL = Offset(imageRect.left + xExtLNorm * imageRect.width, yExtPx);
      final pExtLineR = Offset(imageRect.left + xExtRNorm * imageRect.width, yExtPx);
      final pM1 = Offset((pExtLineL.dx + pExtLineR.dx) / 2.0, yExtPx);

      final pIntLineL = Offset(imageRect.left + xIntLNorm * imageRect.width, yIntPx);
      final pIntLineR = Offset(imageRect.left + xIntRNorm * imageRect.width, yIntPx);
      final pM2 = Offset((pIntLineL.dx + pIntLineR.dx) / 2.0, yIntPx);

      final midY = (yExtPx + yIntPx) / 2.0;

      // ── Styles ─────────────────────────────────────────────────────────────
      final paintArrow = Paint()
        ..color = colorArrow
        ..strokeWidth = (effThick * 0.85).clamp(1.0, 15.0)
        ..style = PaintingStyle.stroke;
      final dotPaint = Paint()..color = colorArrow..style = PaintingStyle.fill;

      // ── 1. LES DEUX LIGNES PARALLÈLES À LA TANGENTE TRAVERSANT LES CORDONS (API 5L) ──
      canvas.drawLine(
        pExtLineL,
        pExtLineR,
        Paint()..color = colorExt..strokeWidth = effThick..style = PaintingStyle.stroke,
      );
      canvas.drawLine(
        pIntLineL,
        pIntLineR,
        Paint()..color = colorInt..strokeWidth = effThick..style = PaintingStyle.stroke,
      );

      // Extensions légères en pointillés
      _drawDashedLine(canvas, Offset(pExtLineL.dx - 18 * sf, yExtPx), pExtLineL,
          Paint()..color = colorExt.withValues(alpha: 0.5)..strokeWidth = (effThick * 0.45).clamp(0.8, 8.0)..style = PaintingStyle.stroke, dashLen: 3.0, gapLen: 2.5);
      _drawDashedLine(canvas, pExtLineR, Offset(pExtLineR.dx + 18 * sf, yExtPx),
          Paint()..color = colorExt.withValues(alpha: 0.5)..strokeWidth = (effThick * 0.45).clamp(0.8, 8.0)..style = PaintingStyle.stroke, dashLen: 3.0, gapLen: 2.5);

      _drawDashedLine(canvas, Offset(pIntLineL.dx - 18 * sf, yIntPx), pIntLineL,
          Paint()..color = colorInt.withValues(alpha: 0.5)..strokeWidth = (effThick * 0.45).clamp(0.8, 8.0)..style = PaintingStyle.stroke, dashLen: 3.0, gapLen: 2.5);
      _drawDashedLine(canvas, pIntLineR, Offset(pIntLineR.dx + 18 * sf, yIntPx),
          Paint()..color = colorInt.withValues(alpha: 0.5)..strokeWidth = (effThick * 0.45).clamp(0.8, 8.0)..style = PaintingStyle.stroke, dashLen: 3.0, gapLen: 2.5);

      // ── 2. POIGNÉES ÉPURÉES DES 2 INTERSECTIONS (I1 et I2) AU MILIEU ────────
      if (showHandles) {
        void drawInterHandle(Canvas c, Offset pt, String tag, {bool isLeft = true}) {
          c.drawCircle(pt, 7.0 * sf, Paint()..color = Colors.black.withValues(alpha: 0.65)..style = PaintingStyle.fill);
          c.drawCircle(pt, 5.5 * sf, Paint()..color = colorArrow..style = PaintingStyle.stroke..strokeWidth = 1.8 * sf);
          c.drawCircle(pt, 2.5 * sf, Paint()..color = Colors.white..style = PaintingStyle.fill);
          c.drawLine(Offset(pt.dx - 4 * sf, pt.dy), Offset(pt.dx + 4 * sf, pt.dy), Paint()..color = colorArrow..strokeWidth = 1.2 * sf);
          c.drawLine(Offset(pt.dx, pt.dy - 4 * sf), Offset(pt.dx, pt.dy + 4 * sf), Paint()..color = colorArrow..strokeWidth = 1.2 * sf);

          final tp = TextPainter(
            text: TextSpan(
              text: tag,
              style: TextStyle(
                color: colorArrow,
                fontSize: 9.0 * sf,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4), Shadow(color: Colors.black, blurRadius: 2)],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final tagX = isLeft ? pt.dx - tp.width - 6 * sf : pt.dx + 6 * sf;
          final tagY = pt.dy - tp.height / 2;
          tp.paint(c, Offset(tagX, tagY));
        }

        drawInterHandle(canvas, pIntG, 'I₁', isLeft: true);
        drawInterHandle(canvas, pIntD, 'I₂', isLeft: false);
      }

      // ── 3. LIGNES PERPENDICULAIRES À LA TANGENTE PASSANT PAR M1 ET M2 ───────
      final topRef = (pEpTop.dy < pM1.dy ? pEpTop.dy : pM1.dy) - 14 * sf;
      final bottomRef = (pEpBottom.dy > pM2.dy ? pEpBottom.dy : pM2.dy) + 14 * sf;

      _drawDashedLine(canvas, Offset(pM1.dx, topRef), Offset(pM1.dx, bottomRef),
          Paint()..color = colorExt.withValues(alpha: 0.70)..strokeWidth = (effThick * 0.5).clamp(0.8, 8.0)..style = PaintingStyle.stroke,
          dashLen: 4.0, gapLen: 3.0);
      _drawDashedLine(canvas, Offset(pM2.dx, topRef), Offset(pM2.dx, bottomRef),
          Paint()..color = colorInt.withValues(alpha: 0.70)..strokeWidth = (effThick * 0.5).clamp(0.8, 8.0)..style = PaintingStyle.stroke,
          dashLen: 4.0, gapLen: 3.0);

      // ── 4. POINTS M1 ET M2 ──────────────────────────────────────────────────
      canvas.drawCircle(pM1, 5.0 * sf, Paint()..color = Colors.black..style = PaintingStyle.fill);
      canvas.drawCircle(pM1, 3.8 * sf, dotPaint);
      canvas.drawCircle(pM2, 5.0 * sf, Paint()..color = Colors.black..style = PaintingStyle.fill);
      canvas.drawCircle(pM2, 3.8 * sf, dotPaint);

      void drawMiniLabel(String text, Offset pos, Color col, {bool above = true}) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: col,
              fontSize: 9.5 * sf,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4), Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lx = pos.dx - tp.width / 2;
        final ly = above ? pos.dy - tp.height - 3 * sf : pos.dy + 3 * sf;
        tp.paint(canvas, Offset(lx, ly));
      }

      drawMiniLabel('M₁', pM1, colorExt, above: true);
      drawMiniLabel('M₂', pM2, colorInt, above: false);

      // ── 5. COTE DE DÉSAXAGE ────────────────────────────────────────────────
      if ((pM1.dx - pM2.dx).abs() > 1.5) {
        canvas.drawLine(Offset(pM1.dx, midY), Offset(pM2.dx, midY), paintArrow);
        final arrowH = 4.5 * sf;
        final dir = pM1.dx < pM2.dx ? 1.0 : -1.0;
        canvas.drawLine(Offset(pM2.dx, midY), Offset(pM2.dx - dir * arrowH * 1.5, midY - arrowH), paintArrow);
        canvas.drawLine(Offset(pM2.dx, midY), Offset(pM2.dx - dir * arrowH * 1.5, midY + arrowH), paintArrow);
        canvas.drawLine(Offset(pM1.dx, midY), Offset(pM1.dx + dir * arrowH * 1.5, midY - arrowH), paintArrow);
        canvas.drawLine(Offset(pM1.dx, midY), Offset(pM1.dx + dir * arrowH * 1.5, midY + arrowH), paintArrow);
        canvas.drawLine(Offset(pM1.dx, midY - 5 * sf), Offset(pM1.dx, midY + 5 * sf), paintArrow);
        canvas.drawLine(Offset(pM2.dx, midY - 5 * sf), Offset(pM2.dx, midY + 5 * sf), paintArrow);
      }
    }
  }

  /// Dessine une ligne en pointillés (tirets réguliers)
  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, {double dashLen = 5.0, double gapLen = 3.5}) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = (dx * dx + dy * dy == 0) ? 1.0 : (dx * dx + dy * dy);
    final len = dist == 1.0 ? 0.0 : (dx * dx + dy * dy) == 0 ? 0.0 : (Offset(dx, dy)).distance;
    if (len < 1) return;
    final nx = dx / len;
    final ny = dy / len;
    double drawn = 0.0;
    bool drawing = true;
    while (drawn < len) {
      final segLen = drawing ? dashLen : gapLen;
      final end = (drawn + segLen).clamp(0.0, len);
      if (drawing) {
        canvas.drawLine(
          Offset(p1.dx + nx * drawn, p1.dy + ny * drawn),
          Offset(p1.dx + nx * end, p1.dy + ny * end),
          paint,
        );
      }
      drawn = end;
      drawing = !drawing;
    }
  }

  void _drawSolidWorksArrowHandle(Canvas canvas, Offset pt, AxisDirection direction, Color color, [double sf = 1.0]) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0 * sf
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..strokeWidth = 3.5 * sf
      ..style = PaintingStyle.stroke;

    final arrowLen = 16.0 * sf;
    final arrowHeadSize = 5.0 * sf;

    Offset tail = pt;
    final Path arrowHeadPath = Path();

    switch (direction) {
      case AxisDirection.up:
        tail = Offset(pt.dx, pt.dy + arrowLen);
        arrowHeadPath.moveTo(pt.dx, pt.dy);
        arrowHeadPath.lineTo(pt.dx - arrowHeadSize, pt.dy + arrowHeadSize * 1.5);
        arrowHeadPath.lineTo(pt.dx + arrowHeadSize, pt.dy + arrowHeadSize * 1.5);
        arrowHeadPath.close();
        break;
      case AxisDirection.down:
        tail = Offset(pt.dx, pt.dy - arrowLen);
        arrowHeadPath.moveTo(pt.dx, pt.dy);
        arrowHeadPath.lineTo(pt.dx - arrowHeadSize, pt.dy - arrowHeadSize * 1.5);
        arrowHeadPath.lineTo(pt.dx + arrowHeadSize, pt.dy - arrowHeadSize * 1.5);
        arrowHeadPath.close();
        break;
      case AxisDirection.left:
        tail = Offset(pt.dx + arrowLen, pt.dy);
        arrowHeadPath.moveTo(pt.dx, pt.dy);
        arrowHeadPath.lineTo(pt.dx + arrowHeadSize * 1.5, pt.dy - arrowHeadSize);
        arrowHeadPath.lineTo(pt.dx + arrowHeadSize * 1.5, pt.dy + arrowHeadSize);
        arrowHeadPath.close();
        break;
      case AxisDirection.right:
        tail = Offset(pt.dx - arrowLen, pt.dy);
        arrowHeadPath.moveTo(pt.dx, pt.dy);
        arrowHeadPath.lineTo(pt.dx - arrowHeadSize * 1.5, pt.dy - arrowHeadSize);
        arrowHeadPath.lineTo(pt.dx - arrowHeadSize * 1.5, pt.dy + arrowHeadSize);
        arrowHeadPath.close();
        break;
    }

    // Contraste arrière-plan
    canvas.drawLine(tail, pt, bgPaint);
    canvas.drawLine(tail, pt, linePaint);

    // Flèche solide style SolidWorks
    canvas.drawPath(arrowHeadPath, fillPaint);
    canvas.drawPath(arrowHeadPath, Paint()..color = Colors.white..strokeWidth = 1.0..style = PaintingStyle.stroke);

    // Point de précision exact au sommet de la flèche
    canvas.drawCircle(pt, 2.0, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  /// Losange (◆) pour les poignées de flanc — distinct des flèches SolidWorks
  void _drawFlankHandle(Canvas canvas, Offset pt, Color color, double sf) {
    final r = 6.0 * sf;
    final path = Path()
      ..moveTo(pt.dx, pt.dy - r)
      ..lineTo(pt.dx + r, pt.dy)
      ..lineTo(pt.dx, pt.dy + r)
      ..lineTo(pt.dx - r, pt.dy)
      ..close();

    // Fond sombre pour contraste
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.55)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.7)..strokeWidth = 2.5 * sf..style = PaintingStyle.stroke);

    // Losange coloré semi-transparent
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.8)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.5 * sf..style = PaintingStyle.stroke);

    // Point central
    canvas.drawCircle(pt, 1.5 * sf, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  void _drawGraduatedRuler(Canvas canvas, Size size, Offset pEpTop, Offset pEpBottom) {
    final heightPx = (pEpBottom.dy - pEpTop.dy).abs();
    if (heightPx < 10) return;

    final epVal = epReel > 0 ? epReel : 11.0;
    final pxPerMm = heightPx / epVal;
    if (pxPerMm < 0.3) return;

    const rulerOffset = 14.0;
    final topY = pEpTop.dy;
    final bottomY = pEpBottom.dy;

    final rulerPaint = Paint()
      ..color = colorBase
      ..strokeWidth = (strokeThickness * 0.6).clamp(0.8, 6.0)
      ..style = PaintingStyle.stroke;

    final bgRulerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..strokeWidth = (strokeThickness * 0.6 + 1.4).clamp(1.5, 8.0)
      ..style = PaintingStyle.stroke;

    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = (strokeThickness * 0.5).clamp(0.6, 5.0)
      ..style = PaintingStyle.stroke;

    final numStyle = TextStyle(
      color: colorBase,
      fontSize: 8.5,
      fontWeight: FontWeight.w600,
      shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
    );

    // 1. RÈGLE VERTICALE (Axe Y à gauche)
    canvas.drawLine(Offset(rulerOffset, topY - 10), Offset(rulerOffset, bottomY + 10), bgRulerPaint);
    canvas.drawLine(Offset(rulerOffset, topY - 10), Offset(rulerOffset, bottomY + 10), rulerPaint);

    final stepYMm = (epVal > 25) ? 5.0 : (epVal > 12 ? 2.0 : 1.0);

    for (double mm = 0; mm <= epVal + 0.05; mm += stepYMm) {
      final y = topY + (mm * pxPerMm);
      if (y > size.height - 5 || y < 5) continue;

      final isMajor = (mm % (stepYMm * 2) == 0) || mm == 0 || (mm - epVal).abs() < 0.1;
      final tickLen = isMajor ? 8.0 : 4.0;

      canvas.drawLine(Offset(rulerOffset, y), Offset(rulerOffset + tickLen, y), bgRulerPaint);
      canvas.drawLine(Offset(rulerOffset, y), Offset(rulerOffset + tickLen, y), tickPaint);

      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(text: mm.toStringAsFixed(0), style: numStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(rulerOffset + tickLen + 2, y - (tp.height / 2)));
      }
    }

    // 2. RÈGLE HORIZONTALE (Axe X en haut)
    canvas.drawLine(const Offset(0, rulerOffset), Offset(size.width, rulerOffset), bgRulerPaint);
    canvas.drawLine(const Offset(0, rulerOffset), Offset(size.width, rulerOffset), rulerPaint);

    final totalWidthMm = size.width / pxPerMm;
    final stepXMm = (totalWidthMm > 50) ? 10.0 : (totalWidthMm > 25 ? 5.0 : 2.0);

    for (double mm = 0; mm <= totalWidthMm; mm += stepXMm) {
      final x = mm * pxPerMm;
      if (x > size.width - 5 || x < 5) continue;

      final isMajor = (mm % (stepXMm * 2) == 0) || mm == 0;
      final tickLen = isMajor ? 8.0 : 4.0;

      canvas.drawLine(Offset(x, rulerOffset), Offset(x, rulerOffset + tickLen), bgRulerPaint);
      canvas.drawLine(Offset(x, rulerOffset), Offset(x, rulerOffset + tickLen), tickPaint);

      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(text: mm.toStringAsFixed(0), style: numStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - (tp.width / 2), rulerOffset + tickLen + 1));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Painter Guides Repère (style Inkscape)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _GuidesPainter extends CustomPainter {
  final List<double> hGuides;  // normalisés Y (0.0-1.0)
  final List<double> vGuides;  // normalisés X (0.0-1.0)
  final Rect imageRect;
  final double pdfPhotoHeightMm;   // hauteur réelle image en mm (dans le PDF)
  final String? draggingId;
  final int draggingIndex;

  _GuidesPainter({
    required this.hGuides,
    required this.vGuides,
    required this.imageRect,
    required this.pdfPhotoHeightMm,
    this.draggingId,
    this.draggingIndex = -1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Image aspect → largeur en mm
    final imageAspect = imageRect.width > 0 && imageRect.height > 0
        ? imageRect.width / imageRect.height
        : 1.0;
    final pdfPhotoWidthMm = pdfPhotoHeightMm * imageAspect;

    final guidePaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final guidePaintActive = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final labelBg = Paint()
      ..color = const Color(0xCC1A1A2E)
      ..style = PaintingStyle.fill;

    const labelStyle = TextStyle(
      color: Color(0xFF00E5FF),
      fontSize: 9,
      fontWeight: FontWeight.bold,
    );

    // ── Guides horizontaux ──────────────────────────────────────────────────
    for (int i = 0; i < hGuides.length; i++) {
      final normY = hGuides[i];
      final y = imageRect.top + normY * imageRect.height;
      final isActive = draggingId != null &&
          (draggingId == 'h:$i' || (draggingId == 'new_h' && i == draggingIndex));

      guidePaint.color = isActive
          ? const Color(0xFF00E5FF)
          : const Color(0xFF00E5FF).withValues(alpha: 0.65);
      guidePaintActive.color = const Color(0xFF00E5FF);

      final paint = isActive ? guidePaintActive : guidePaint;

      // Tirets (dashed line)
      const dashW = 8.0, gapW = 4.0;
      double x = imageRect.left;
      while (x < imageRect.right) {
        canvas.drawLine(Offset(x, y), Offset((x + dashW).clamp(0, imageRect.right), y), paint);
        x += dashW + gapW;
      }

      // Triangle indicateur à gauche
      final tri = Path()
        ..moveTo(18, y - 6)
        ..lineTo(24, y)
        ..lineTo(18, y + 6)
        ..close();
      canvas.drawPath(tri, Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.fill);

      // Label position en mm
      final posMm = normY * pdfPhotoHeightMm;
      final labelText = '${posMm.toStringAsFixed(1)} mm';
      final tp = TextPainter(
        text: TextSpan(text: labelText, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final lx = imageRect.left + 4;
      final ly = y - tp.height - 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(lx - 2, ly - 1, tp.width + 6, tp.height + 2),
          const Radius.circular(3),
        ),
        labelBg,
      );
      tp.paint(canvas, Offset(lx, ly));
    }

    // ── Guides verticaux ────────────────────────────────────────────────────
    for (int i = 0; i < vGuides.length; i++) {
      final normX = vGuides[i];
      final x = imageRect.left + normX * imageRect.width;
      final isActive = draggingId != null &&
          (draggingId == 'v:$i' || (draggingId == 'new_v' && i == draggingIndex));

      guidePaint.color = isActive
          ? const Color(0xFFFFD600)
          : const Color(0xFFFFD600).withValues(alpha: 0.65);
      guidePaintActive.color = const Color(0xFFFFD600);

      final paint = isActive ? guidePaintActive : guidePaint;

      // Tirets
      const dashH = 8.0, gapH = 4.0;
      double y = imageRect.top;
      while (y < imageRect.bottom) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + dashH).clamp(0, imageRect.bottom)), paint);
        y += dashH + gapH;
      }

      // Triangle indicateur en haut
      final tri = Path()
        ..moveTo(x - 6, 18)
        ..lineTo(x, 24)
        ..lineTo(x + 6, 18)
        ..close();
      canvas.drawPath(tri, Paint()
        ..color = const Color(0xFFFFD600)
        ..style = PaintingStyle.fill);

      // Label position en mm
      final posMm = normX * pdfPhotoWidthMm;
      final labelText = '${posMm.toStringAsFixed(1)} mm';
      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: labelStyle.copyWith(color: const Color(0xFFFFD600)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lx = x + 3;
      final ly = imageRect.top + 4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(lx - 2, ly - 1, tp.width + 6, tp.height + 2),
          const Radius.circular(3),
        ),
        labelBg,
      );
      tp.paint(canvas, Offset(lx, ly));
    }
  }

  @override
  bool shouldRepaint(covariant _GuidesPainter old) =>
      old.hGuides != hGuides ||
      old.vGuides != vGuides ||
      old.imageRect != imageRect ||
      old.draggingId != draggingId ||
      old.draggingIndex != draggingIndex;
}

/// Réticule de visée haute précision dessiné à l'intérieur de la loupe de grossissement
class _MagnifierReticlePainter extends CustomPainter {
  const _MagnifierReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Peinture d'ombre extérieure pour contraste sur toute image
    final shadowPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Peinture de ligne blanche nette
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double crossSize = 18.0;
    const double gap = 4.5;

    // ── Croix horizontale
    canvas.drawLine(Offset(center.dx - crossSize, center.dy), Offset(center.dx - gap, center.dy), shadowPaint);
    canvas.drawLine(Offset(center.dx - crossSize, center.dy), Offset(center.dx - gap, center.dy), linePaint);

    canvas.drawLine(Offset(center.dx + gap, center.dy), Offset(center.dx + crossSize, center.dy), shadowPaint);
    canvas.drawLine(Offset(center.dx + gap, center.dy), Offset(center.dx + crossSize, center.dy), linePaint);

    // ── Croix verticale
    canvas.drawLine(Offset(center.dx, center.dy - crossSize), Offset(center.dx, center.dy - gap), shadowPaint);
    canvas.drawLine(Offset(center.dx, center.dy - crossSize), Offset(center.dx, center.dy - gap), linePaint);

    canvas.drawLine(Offset(center.dx, center.dy + gap), Offset(center.dx, center.dy + crossSize), shadowPaint);
    canvas.drawLine(Offset(center.dx, center.dy + gap), Offset(center.dx, center.dy + crossSize), linePaint);

    // ── Cercle de mire central
    canvas.drawCircle(center, 4.5, shadowPaint);
    canvas.drawCircle(
      center,
      4.5,
      Paint()
        ..color = AppTheme.accentTeal
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    // ── Point central rouge vif
    canvas.drawCircle(
      center,
      1.5,
      Paint()
        ..color = const Color(0xFFFF2A6D)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

