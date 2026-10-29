import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/app_settings.dart';
import '../models/echantillon.dart';
import '../models/pv_config.dart';
import '../models/rapport.dart';
import 'settings_service.dart';

/// ══════════════════════════════════════════════════════════════════
/// MODÈLE V2 — RAPPORT INDUSTRIEL & LABORATOIRE PROFESSIONNEL
/// Respect intégral des normes d'essais (ISO 17025 style)
/// Structure aérée, équilibrée, harmonieuse et ultra-professionnelle
/// ══════════════════════════════════════════════════════════════════
class PdfServiceModern {
  // ── Palette institutionnelle V2 — ÉCRITURE 100% NOIRE ──
  static const PdfColor _primaryDark   = PdfColors.black; // Noir pur pour tous les textes principaux & titres
  static const PdfColor _accentBlue    = PdfColors.black; // Noir pur
  static const PdfColor _headerBg      = PdfColor.fromInt(0xFFE8EEF5); // Bleu pâle (fonds d'entêtes)
  static const PdfColor _subtleBg      = PdfColor.fromInt(0xFFF5F7FA); // Fond très doux
  static const PdfColor _border        = PdfColor.fromInt(0xFFB0BDD0); // Gris bleuté clair
  static const PdfColor _borderLight   = PdfColor.fromInt(0xFFD4DCE8); // Bordure ultra-légère
  static const PdfColor _textSecondary = PdfColors.black; // Noir pur pour libellés et métadonnées
  static const PdfColor _textLight     = PdfColor.fromInt(0xFF222222); // Noir / gris très foncé (disclaimer)

  static Future<File> generateRapportPdf(
    Rapport r, {
    required AppSettings settings,
    PvFieldConfig? pvConfig,
  }) async {
    final pdf = await _buildDocument(r, settings, pvConfig);
    final bytes = await pdf.save();
    final outputDir = await getTemporaryDirectory();
    final fileName = '${r.defaultPdfFileName}.pdf';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<Uint8List> generateRapportBytes(
    Rapport r, {
    required AppSettings settings,
    PvFieldConfig? pvConfig,
  }) async {
    final pdf = await _buildDocument(r, settings, pvConfig);
    return await pdf.save();
  }

  static pw.Font? _cachedFontRegular;
  static pw.Font? _cachedFontBold;
  static bool _fontInitDone = false;

  /// Appeler une fois au démarrage de l'app (main.dart ou avant le 1er PDF)
  static Future<void> preloadFonts() async {
    if (_fontInitDone) return;
    await _initFonts();
  }

  static Future<void> _initFonts() async {
    if (_cachedFontRegular != null && _cachedFontBold != null) {
      _fontInitDone = true;
      return;
    }
    // 1. Polices locales (assets/fonts/) — instantané
    try {
      final regBytes = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldBytes = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      _cachedFontRegular = pw.Font.ttf(regBytes);
      _cachedFontBold = pw.Font.ttf(boldBytes);
      _fontInitDone = true;
      return;
    } catch (_) {}
    // 2. Polices système intégrées (offline, sans réseau)
    _cachedFontRegular = pw.Font.helvetica();
    _cachedFontBold = pw.Font.helveticaBold();
    _fontInitDone = true;
  }

  static Future<pw.Document> _buildDocument(
    Rapport r,
    AppSettings settings,
    PvFieldConfig? pvConfig,
  ) async {
    await _initFonts();
    final config = pvConfig ?? await SettingsService.instance.getPvConfig();
    final doc = pw.Document();

    final fontRegular = _cachedFontRegular!;
    final fontBold = _cachedFontBold!;

    pw.MemoryImage? logo;
    if (config.showLogo) {
      if (settings.logoPath != null &&
          settings.logoPath!.isNotEmpty &&
          File(settings.logoPath!).existsSync()) {
        try {
          logo = pw.MemoryImage(File(settings.logoPath!).readAsBytesSync());
        } catch (_) {}
      }
      if (logo == null) {
        for (final path in ['assets/images/logo.png', 'assets/logo.png']) {
          try {
            final b = await rootBundle.load(path);
            logo = pw.MemoryImage(b.buffer.asUint8List());
            break;
          } catch (_) {}
        }
      }
    }

    // Cachet optionnel sélectionné (0 = Aucun / Vide, 1 = Cachet 1, 2 = Cachet 2, 3 = Cachet 3)
    pw.MemoryImage? cachet;
    if (config.selectedCachet > 0) {
      final String? selectedPath = config.selectedCachet == 1
          ? (settings.cachet1Path ?? settings.cachetPath)
          : (config.selectedCachet == 2 ? settings.cachet2Path : settings.cachet3Path);

      if (selectedPath != null &&
          selectedPath.isNotEmpty &&
          File(selectedPath).existsSync()) {
        try {
          cachet = pw.MemoryImage(File(selectedPath).readAsBytesSync());
        } catch (_) {}
      }
    }

    final isCmd = r.isCommandeInterne;
    final hasTechTables = config.showTableParametres ||
        config.showTableMetalBase ||
        config.showTableSoudure;
    final showDetailedGrid = isCmd || hasTechTables;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (ctx) => _buildHeader(logo, r, settings, config),
        footer: (ctx) => config.showPageNumber
            ? pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text(
                  'Page ${ctx.pageNumber} sur ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7.5, color: _textSecondary),
                ),
              )
            : pw.Container(),
        build: (ctx) => [
          // 2. Tableau des caractéristiques (avec dates intégrées)
          _buildInfoTable(r, config),
          pw.SizedBox(height: showDetailedGrid ? 6 : 8),

          // 3. Mention légale / Disclaimer (Plein format 100% largeur)
          if (config.showDisclaimer) ...[
            _buildDisclaimer(),
            pw.SizedBox(height: showDetailedGrid ? 6 : 8),
          ],

          // 4. Bannière section
          if (config.showSectionTitle) ...[
            _buildSectionTitle('EXAMEN MACROGRAPHIQUE'),
            pw.SizedBox(height: showDetailedGrid ? 7 : 10),
          ],

          // 5. Zone photos & tableaux (CMD Interne ou Prestation avec tableaux techniques)
          if (showDetailedGrid)
            _buildCmdInterneGrid(r, config)
          else
            _buildPrestationGrid(r, config),
          pw.SizedBox(height: showDetailedGrid ? 8 : 12),

          // 6. Constat / Résultat
          if (config.showObservation &&
              (r.observation.isNotEmpty || settings.defaultObservation.isNotEmpty)) ...[
            _buildObservation(r, settings),
            pw.SizedBox(height: showDetailedGrid ? 8 : 12),
          ],

          // 7. Tableau des signataires
          if (config.showSignatures) ...[
            _buildSignatureTable(r, cachet: cachet),
            pw.SizedBox(height: showDetailedGrid ? 6 : 9),
          ],

          // 8. Mentions d'autorisation
          if (config.showFootnotes) _buildFootNote(settings),
        ],
      ),
    );

    return doc;
  }

  // ══════════════════════════════════════════════════════════════════
  // 1. EN-TÊTE PROFESSIONNEL (3 colonnes + Coordonnées Labo)
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _buildHeader(
    pw.ImageProvider? logo,
    Rapport r,
    AppSettings s,
    PvFieldConfig config,
  ) {
    final hasLeft = config.showLogo || config.showCompanyHeader;
    final hasRight = config.showDocMeta;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── 1.1 Cadre En-tête 3 colonnes ──
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: 0.7),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.75),
            1: pw.FlexColumnWidth(5.0),
            2: pw.FlexColumnWidth(1.75),
          },
          children: [
            pw.TableRow(children: [
              // Col 1 : Logo & Société
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                alignment: pw.Alignment.center,
                child: hasLeft
                    ? pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          if (logo != null && config.showLogo)
                            pw.Image(logo,
                                height: 1.6 * PdfPageFormat.cm,
                                width: 3.4 * PdfPageFormat.cm,
                                fit: pw.BoxFit.contain),
                          if (config.showCompanyHeader) ...[
                            pw.SizedBox(height: 1.5),
                            pw.Text(s.companyName,
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                    fontSize: 8.0,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _primaryDark)),
                            pw.Text(s.uniteName,
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                    fontSize: 7.6,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _primaryDark)),
                          ],
                        ],
                      )
                    : pw.Container(),
              ),

              // Col 2 : Titre Principal parfaitement centré au milieu de sa cellule
              pw.Container(
                alignment: pw.Alignment.center,
                height: 2.2 * PdfPageFormat.cm,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                child: pw.Center(
                  child: pw.Text(
                    "RAPPORT D'ESSAI",
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 18.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryDark,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),

              // Col 3 : Métadonnées document
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                alignment: pw.Alignment.center,
                child: hasRight
                    ? pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          _metaRow('Réf.',
                              r.isCommandeInterne ? s.docRefInterne : s.docRef),
                          _metaRow('Version',
                              r.isCommandeInterne ? s.docVersionInterne : s.docVersion),
                          _metaRow('Date',
                              r.isCommandeInterne ? s.docDateInterne : s.docDate),
                          _metaRow('Page', '01'),
                        ],
                      )
                    : pw.Container(),
              ),
            ]),
          ],
        ),

        // ── 1.2 Coordonnées complètes du Laboratoire + N° PV à droite (sans espace vide) ──
        pw.SizedBox(height: 3),
        pw.Stack(
          alignment: pw.Alignment.topCenter,
          children: [
            // Coordonnées du Laboratoire au centre
            if (config.showLabInfo)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    s.labName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9.2,
                      color: _primaryDark,
                    ),
                  ),
                  if (s.labAddress.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.RichText(
                      textAlign: pw.TextAlign.center,
                      text: pw.TextSpan(
                        style: const pw.TextStyle(fontSize: 7.6, color: _primaryDark),
                        children: [
                          pw.TextSpan(
                            text: 'ADRESSE DU LABORATOIRE : ',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.TextSpan(text: s.labAddress),
                        ],
                      ),
                    ),
                  ],
                  if (s.labLieu.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.RichText(
                      textAlign: pw.TextAlign.center,
                      text: pw.TextSpan(
                        style: const pw.TextStyle(fontSize: 7.6, color: _primaryDark),
                        children: [
                          pw.TextSpan(
                            text: "Lieu d'exécution des essais : ",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.TextSpan(text: s.labLieu),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

            // N° PV fixé en haut à droite sans créer d'espace vide en dessous
            if (config.showPvNumero)
              pw.Positioned(
                top: 0,
                right: 0,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _primaryDark, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                    color: _headerBg,
                  ),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: pw.Text(
                    'N° ${r.pvNumero}',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 9.0,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryDark,
                    ),
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String val) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
        child: pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 7.6),
            children: [
              pw.TextSpan(
                  text: '$label : ',
                  style: const pw.TextStyle(color: _textSecondary)),
              pw.TextSpan(
                  text: val,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: _primaryDark)),
            ],
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════
  // 2. TABLEAU DES CARACTÉRISTIQUES (avec Dates sur la même ligne)
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _buildInfoTable(Rapport r, PvFieldConfig config) {
    pw.Widget cell(String text, {bool bold = false}) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5.5, vertical: 3.2),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: _primaryDark,
            ),
          ),
        );

    final nb = r.nbEchantillons.toString().padLeft(2, '0');

    final allCells = <pw.Widget>[];
    final allCellsText = <String>[];

    void addCell(String text, {bool bold = false}) {
      allCells.add(cell(text, bold: bold));
      allCellsText.add(text);
    }

    // Parse custom fields once, keyed by section
    Map<String, String> cfLabels = {};
    Map<String, Map<String, String>> cfSections = {};
    try {
      if (r.customFieldsJson.isNotEmpty && r.customFieldsJson != '{}') {
        final decoded = jsonDecode(r.customFieldsJson);
        if (decoded is Map) {
          if (decoded['_labels'] is Map) {
            (decoded['_labels'] as Map).forEach((k, v) {
              if (v != null) cfLabels[k.toString()] = v.toString();
            });
          }
          decoded.forEach((secKey, fields) {
            if (secKey != '_labels' && fields is Map) {
              cfSections[secKey.toString()] = {};
              fields.forEach((k, v) {
                if (v != null && v.toString().trim().isNotEmpty) {
                  cfSections[secKey.toString()]![k.toString()] = v.toString();
                }
              });
            }
          });
        }
      }
    } catch (_) {}

    void addCustomSection(String sKey) {
      if (!config.showCustomFields) return;
      final fields = cfSections[sKey];
      if (fields == null) return;
      fields.forEach((k, v) {
        final label = cfLabels['${sKey}_$k'] ?? cfLabels[k] ?? k;
        addCell('$label : $v', bold: true);
      });
    }

    // ── 1. Dates (si activé individuellement)
    if (config.showDateReception && r.dateReception.isNotEmpty) {
      addCell('${_lbl(r, 'Date Réception', "Date de Réception d'échantillon")} : ${r.dateReception}', bold: true);
    }
    if (config.showDateEssai && r.dateEssai.isNotEmpty) {
      addCell('${_lbl(r, "Date d'essai", "Date d'essai")} : ${r.dateEssai}', bold: true);
    }
    if (config.showDateEmission && r.dateEmission.isNotEmpty) {
      addCell('${_lbl(r, 'Date Émission', "Date d'émission du Rapport")} : ${r.dateEmission}', bold: true);
    }

    // ── 2. Client & Informations Générales
    if (config.showNomClient) {
      addCell('${_lbl(r, 'Nom Client / Demandeur (ex: SONALGEZ)', 'Client / Demandeur')} : ${r.nomClient}', bold: true);
    }
    if (config.showDimensions) {
      final dimStr = r.dimensions.trim();
      final dimDisplay = dimStr.isEmpty ? '' : (dimStr.toLowerCase().endsWith('mm') ? dimStr : '$dimStr mm');
      addCell('${_lbl(r, 'Dimensions (mm)', 'Dimensions')} : $dimDisplay', bold: true);
    }
    if (config.showNuance) {
      addCell('${_lbl(r, 'Nuance (ex: API 5L X60M)', 'Nuance')} : ${r.nuance}', bold: true);
    }
    if (config.showCoordonneesClient) {
      addCell('${_lbl(r, 'Coordonnées / Adresse du client', 'Coordonnées')} : ${r.coordonneesClient}', bold: true);
    }
    if (config.showNWps) {
      addCell('${_lbl(r, 'N° WPS (ex: 38)', 'N° WPS')} : ${r.nWps}', bold: true);
    }
    if (config.showNPqr) {
      addCell('${_lbl(r, 'N° PQR (ex: 41)', 'N° PQR')} : ${r.nPqr}', bold: true);
    }

    addCustomSection('client');
    addCustomSection('caracteristiques');
    addCustomSection('ident');

    if (config.showMethodeEssai) {
      addCell("${_lbl(r, "Méthode d'essai (ex: /)", "Méthode d'Essai")} : ${r.methodeEssai}", bold: true);
    }
    if (config.showNbEchantillons) {
      addCell("${_lbl(r, "Nombre d'Échantillons", "Nb d'échantillon(s)")} : $nb", bold: true);
    }

    // ── 3. Paramètres Soudage (si présents et activés)
    if (config.showSectionSoudage) {
      // Ordre : Procédé | Métal d'Apport | Position → même ligne
      if (config.showProcedeSoudage && r.procedeSoudage.isNotEmpty) {
        addCell('${_lbl(r, 'Procédé de Soudage (ex: SAWH)', 'Procédé')} : ${r.procedeSoudage}', bold: true);
      }
      if (config.showMetalApport && r.metalApport.isNotEmpty) {
        addCell("${_lbl(r, "Métal d'apport / Lot (ex: E 8018 -G H4)", "Métal d'Apport")} : ${r.metalApport}", bold: true);
      }
      if (config.showPositionSoudage && r.positionSoudage.isNotEmpty) {
        addCell('${_lbl(r, 'Position de Soudage (ex: 5G)', 'Position')} : ${r.positionSoudage}', bold: true);
      }
      if (config.showNJoint && r.nJoint.isNotEmpty) {
        addCell('${_lbl(r, 'N° Joint / Repère', 'N° Joint')} : ${r.nJoint}', bold: true);
      }
      if (config.showTraitementThermique && r.traitementThermique.isNotEmpty) {
        addCell('${_lbl(r, 'Traitement Thermique (PWHT)', 'PWHT')} : ${r.traitementThermique}', bold: true);
      }
      addCustomSection('soudage');
    }

    // Méthode d'échantillonnage — après Métal d'Apport (inversée avec Position)
    if (config.showMethodeEchantillonnage) {
      addCell("${_lbl(r, "Méthode d'échantillonnage (ex: /)", "Méthode d'échantillonnage")} : ${r.methodeEchantillonnage}", bold: true);
    }

    // ── 4. Spécifications & Projet
    if (config.showSpecificationEssai) {
      addCell("${_lbl(r, "Spécification d'essai (ex: /)", "Spécification d'essai")} : ${r.specificationEssai}", bold: true);
    }
    if (config.showProjet) {
      addCell('${_lbl(r, 'Projet / BC (ex: REALISATION EN EPC...)', 'Projet / BC')} : ${r.projet}', bold: true);
    }

    // Remaining custom sections not yet placed in a known section
    final handledSecs = {'client', 'caracteristiques', 'ident', 'soudage', 'constat', 'signatures'};
    cfSections.forEach((sKey, _) {
      if (!handledSecs.contains(sKey)) {
        addCustomSection(sKey);
      }
    });

    if (allCells.isEmpty) return pw.Container();

    // Répartition sans aucun vide : lignes de 3 cellules avec largeurs adaptées à chaque ligne
    final total = allCells.length;
    final remainder = total % 3;
    final int fullRowsCount = (total - remainder) ~/ 3;
    final leftoverCells = allCells.sublist(fullRowsCount * 3);
    final hasLeftover = leftoverCells.isNotEmpty;

    final tableList = <pw.Widget>[];

    for (int rIdx = 0; rIdx < fullRowsCount; rIdx++) {
      final i = rIdx * 3;
      final c0 = allCells[i];
      final c1 = allCells[i + 1];
      final c2 = allCells[i + 2];

      final isFirst = rIdx == 0;

      final text0 = allCellsText[i];
      final text1 = allCellsText[i + 1];
      final text2 = allCellsText[i + 2];

      Map<int, pw.TableColumnWidth> widths;
      if (text1.contains('WPS') || text2.contains('PQR') || text0.contains('Adresse') || text0.contains('Coordonnées')) {
        // Ligne spéciale : Adresse élargie + WPS / PQR resserrés
        widths = const {
          0: pw.FlexColumnWidth(5.2),
          1: pw.FlexColumnWidth(2.4),
          2: pw.FlexColumnWidth(2.4),
        };
      } else if (text2.contains('échantillonnage') || text2.contains('Spécification')) {
        // Ligne spéciale : donne plus de place à la colonne 3 pour éviter les retours à la ligne
        widths = const {
          0: pw.FlexColumnWidth(3.4),
          1: pw.FlexColumnWidth(2.6),
          2: pw.FlexColumnWidth(4.0),
        };
      } else if (text2.contains('Date Émission') || text2.contains("d'émission")) {
        // Ligne Dates : répartition équilibrée
        widths = const {
          0: pw.FlexColumnWidth(3.6),
          1: pw.FlexColumnWidth(2.7),
          2: pw.FlexColumnWidth(3.7),
        };
      } else {
        widths = const {
          0: pw.FlexColumnWidth(3.8),
          1: pw.FlexColumnWidth(3.1),
          2: pw.FlexColumnWidth(3.1),
        };
      }

      tableList.add(
        pw.Table(
          border: pw.TableBorder(
            left: const pw.BorderSide(color: _border, width: 0.65),
            right: const pw.BorderSide(color: _border, width: 0.65),
            top: isFirst ? const pw.BorderSide(color: _border, width: 0.65) : pw.BorderSide.none,
            bottom: const pw.BorderSide(color: _border, width: 0.65),
            verticalInside: const pw.BorderSide(color: _border, width: 0.65),
          ),
          columnWidths: widths,
          children: [
            pw.TableRow(children: [c0, c1, c2]),
          ],
        ),
      );
    }

    if (hasLeftover) {
      if (leftoverCells.length == 2) {
        tableList.add(
          pw.Table(
            border: pw.TableBorder(
              left: const pw.BorderSide(color: _border, width: 0.65),
              right: const pw.BorderSide(color: _border, width: 0.65),
              bottom: const pw.BorderSide(color: _border, width: 0.65),
              top: tableList.isNotEmpty ? pw.BorderSide.none : const pw.BorderSide(color: _border, width: 0.65),
              verticalInside: const pw.BorderSide(color: _border, width: 0.65),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(5.0),
              1: pw.FlexColumnWidth(5.0),
            },
            children: [
              pw.TableRow(children: [
                leftoverCells[0],
                leftoverCells[1],
              ]),
            ],
          ),
        );
      } else if (leftoverCells.length == 1) {
        tableList.add(
          pw.Table(
            border: pw.TableBorder(
              left: const pw.BorderSide(color: _border, width: 0.65),
              right: const pw.BorderSide(color: _border, width: 0.65),
              bottom: const pw.BorderSide(color: _border, width: 0.65),
              top: tableList.isNotEmpty ? pw.BorderSide.none : const pw.BorderSide(color: _border, width: 0.65),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(10.0),
            },
            children: [
              pw.TableRow(children: [
                leftoverCells[0],
              ]),
            ],
          ),
        );
      }
    }

    return pw.Column(children: tableList);
  }



  // ══════════════════════════════════════════════════════════════════
  // 3. DISCLAIMER / MENTION LÉGALE (100% Largeur, italique grisé)
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _buildDisclaimer() => pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: _subtleBg,
          border: pw.Border.all(color: _borderLight, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 14),
        child: pw.Column(
          children: [
            pw.Text(
              "Les résultats se rapportent aux échantillons tels qu'ils ont été fournis par le client.",
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7.2, color: _textLight),
            ),
            pw.SizedBox(height: 1.5),
            pw.Text(
              "Les parties du rapport ne doivent pas être reproduites sans l'accord du laboratoire.",
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7.2, color: _textLight),
            ),
          ],
        ),
      );

  // ══════════════════════════════════════════════════════════════════
  // 4. BANNIÈRE DE SECTION (Bleu acier institutionnel, filet bas)
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _buildSectionTitle(String title) => pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          color: _headerBg,
          border: pw.Border(
            bottom: pw.BorderSide(color: _border, width: 0.8),
            top: pw.BorderSide(color: _border, width: 0.8),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(vertical: 5.5, horizontal: 16),
        alignment: pw.Alignment.center,
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9.2,
            fontWeight: pw.FontWeight.bold,
            color: _primaryDark,
            letterSpacing: 2.0,
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════
  // 5A. GRILLE PHOTOS — PRESTATION (Photos avec labels)
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _buildPrestationGrid(Rapport r, PvFieldConfig config) {
    if (r.echantillons.isEmpty) {
      return pw.Text('Aucun échantillon.',
          style: const pw.TextStyle(fontSize: 7.5, color: _textSecondary));
    }

    final count = r.echantillons.length;
    // Hauteur aérée et généreuse selon le nombre d'échantillons
    final double photoH;
    if (count == 1) {
      photoH = 170.0;
    } else if (count == 2) {
      photoH = (r.photoHeightPdf.toDouble() * 1.05).clamp(130.0, 180.0);
    } else {
      photoH = (r.photoHeightPdf.toDouble() * 0.90).clamp(100.0, 150.0);
    }

    final labelFz = count >= 3 ? 7.8 : 8.5;

    final cards = <pw.Widget>[];
    for (final e in r.echantillons) {
      cards.add(
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border, width: 0.65),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                color: _headerBg,
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 8),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  e.label,
                  style: pw.TextStyle(
                    fontSize: labelFz,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryDark,
                  ),
                ),
              ),
              if (config.showTypeLot && e.typeLot.isNotEmpty)
                pw.Container(
                  color: _subtleBg,
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.0, horizontal: 6),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'TYPE : ${e.typeLot}',
                    style: const pw.TextStyle(fontSize: 7.2, color: _textSecondary),
                  ),
                ),
              pw.Container(
                height: photoH,
                width: double.infinity,
                padding: const pw.EdgeInsets.all(4.0),
                alignment: pw.Alignment.center,
                child: _sampleImage(e.photoPath),
              ),
              if (config.showGrossissement && e.grossissement.isNotEmpty)
                pw.Container(
                  color: _headerBg,
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'GROSSISSEMENT : ${e.grossissement}',
                    style: pw.TextStyle(
                      fontSize: 7.4,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (count == 1) {
      return pw.Center(child: pw.SizedBox(width: 320, child: cards.first));
    }

    int perRow = r.photosPerRow.clamp(2, 4);
    if (count == 3) perRow = 3;

    final rows = <pw.Widget>[];
    for (int i = 0; i < cards.length; i += perRow) {
      final rowChildren = <pw.Widget>[];
      for (int j = 0; j < perRow; j++) {
        if (j > 0) rowChildren.add(pw.SizedBox(width: perRow >= 3 ? 6 : 8));
        final idx = i + j;
        rowChildren.add(pw.Expanded(
            child: idx < cards.length ? cards[idx] : pw.Container()));
      }
      rows.add(pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: rowChildren),
      ));
    }
    return pw.Column(children: rows);
  }

  // ══════════════════════════════════════════════════════════════════
  // 5B. GRILLE CMD INTERNE (4 Tableaux par échantillon : Soudage, Photo, Métal, Soudure)
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _buildCmdInterneGrid(Rapport r, PvFieldConfig config) {
    if (r.echantillons.isEmpty) {
      return pw.Text('Aucun échantillon.',
          style: const pw.TextStyle(fontSize: 7.5, color: _textSecondary));
    }
    return pw.Column(
      children: r.echantillons
          .map((e) => _buildDetailCard(
              e, config, r.photoHeightPdf.toDouble()))
          .toList(),
    );
  }

  static pw.Widget _buildDetailCard(
      Echantillon e, PvFieldConfig config, double photoHeightPdf) {
    pw.Widget cellT(String txt,
            {bool bold = false,
            pw.TextAlign align = pw.TextAlign.left,
            double fs = 7.2}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.6),
          child: pw.Text(txt,
              textAlign: align,
              style: pw.TextStyle(
                  fontSize: fs,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: _primaryDark)),
        );

    pw.Widget banner(String txt) => pw.Container(
          decoration: const pw.BoxDecoration(
            color: _headerBg,
            border: pw.Border(
              bottom: pw.BorderSide(color: _borderLight, width: 0.7),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(vertical: 3.0, horizontal: 6),
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Text(txt,
              style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _accentBlue)),
        );

    final tb = pw.TableBorder.all(color: _borderLight, width: 0.6);

    // ── 1. PARAMETRES DE SOUDAGE ──
    final paramRows1 = <pw.TableRow>[];
    if (config.showParamVitesse) {
      paramRows1.add(pw.TableRow(children: [
        cellT('VITESSE (m/min)', bold: true),
        pw.Container(
            alignment: pw.Alignment.center,
            child: cellT(
                e.vitesse,
                bold: true,
                align: pw.TextAlign.center)),
        pw.Container(),
        pw.Container(),
      ]));
    }
    if (config.showParamTension) {
      paramRows1.add(pw.TableRow(children: [
        cellT('U  INT', bold: true),
        cellT(e.uInt, bold: true, align: pw.TextAlign.center),
        cellT('U  EXT', bold: true),
        cellT(e.uExt, bold: true, align: pw.TextAlign.center),
      ]));
    }
    if (config.showParamCourant) {
      paramRows1.add(pw.TableRow(children: [
        cellT('I   INT', bold: true),
        cellT(e.iInt, bold: true, align: pw.TextAlign.center),
        cellT('I   EXT', bold: true),
        cellT(e.iExt, bold: true, align: pw.TextAlign.center),
      ]));
    }
    final paramRows2 = <pw.TableRow>[];
    if (config.showParamFils) {
      paramRows2.add(pw.TableRow(children: [
        cellT('Ø DU FIL INT', bold: true),
        cellT(e.filInt1, bold: true),
      ]));
      paramRows2.add(pw.TableRow(children: [
        cellT('Ø DU FIL EXT', bold: true),
        cellT(e.filInt2, bold: true),
      ]));
    }
    if (config.showParamFlux) {
      paramRows2.add(pw.TableRow(children: [
        cellT('FLUX', bold: true),
        cellT(e.flux, bold: true),
      ]));
    }

    pw.Widget? tableParam;
    if (config.showTableParametres) {
      tableParam = pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border, width: 0.65)),
        child: pw.Column(children: [
          banner('PARAMETRES DE SOUDAGE'),
          if (paramRows1.isNotEmpty)
            pw.Table(
                border: tb,
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(0.6),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(0.6),
                },
                children: paramRows1),
          if (paramRows2.isNotEmpty)
            pw.Table(
                border: tb,
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.4),
                },
                children: paramRows2),
        ]),
      );
    }

    // ── 2. CADRE PHOTO AVEC TYPE & GROSSISSEMENT (100% Calibré Optique) ──
    final photoH = (photoHeightPdf * 0.51).clamp(36.0, 153.0);
    final boxPhoto = pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border, width: 0.65)),
      child: pw.Column(children: [
        if (config.showTypeLot && e.typeLot.isNotEmpty)
          banner('TYPE : ${e.typeLot}'),
        pw.Container(
          height: photoH,
          width: double.infinity,
          padding: const pw.EdgeInsets.all(3.0),
          alignment: pw.Alignment.center,
          child: _sampleImage(e.photoPath),
        ),
        if (config.showGrossissement && e.grossissement.isNotEmpty)
          banner('GROSSISSEMENT : ${e.grossissement}'),
      ]),
    );

    // ── 3. METAL DE BASE ──
    final gClean = e.grossissement
        .replaceAll(RegExp(r'[^0-9.,]'), '')
        .replaceAll(',', '.')
        .trim();
    final gVal = double.tryParse(gClean) ?? 1.8;
    final epReelClean = e.epReel
        .replaceAll(RegExp(r'[^0-9.,]'), '')
        .replaceAll(',', '.')
        .trim();
    final epReelVal = double.tryParse(epReelClean) ?? 11.0;
    final epPhotoStr =
        (gVal * epReelVal).toStringAsFixed(2).replaceAll('.', ',');

    final metalRows = <pw.TableRow>[];
    if (config.showMetalNuance) {
      metalRows.add(pw.TableRow(children: [
        cellT('NUANCE', bold: true),
        cellT(e.metalNuance, bold: true)
      ]));
    }
    if (config.showNCoulee) {
      metalRows.add(pw.TableRow(children: [
        cellT('N° COULEE', bold: true),
        cellT(e.nCoulee, bold: true)
      ]));
    }
    if (config.showNBobine) {
      metalRows.add(pw.TableRow(children: [
        cellT('N° BOBINE', bold: true),
        cellT(e.nBobine, bold: true)
      ]));
    }
    if (config.showDiametreTube) {
      metalRows.add(pw.TableRow(children: [
        cellT('Ø TUBE (mm)', bold: true),
        cellT(e.diametreTube, bold: true)
      ]));
    }
    if (config.showEpNominale) {
      metalRows.add(pw.TableRow(children: [
        cellT('EP. NOMINALE (mm)', bold: true),
        cellT(e.epNominale, bold: true)
      ]));
    }
    if (config.showEpReel) {
      metalRows.add(pw.TableRow(children: [
        cellT('EP. REEL (mm)', bold: true),
        cellT(e.epReel, bold: true)
      ]));
    }
    if (config.showEpSurPhoto) {
      metalRows.add(pw.TableRow(children: [
        cellT('EP. SUR PHOTO (mm)', bold: true),
        cellT(epPhotoStr, bold: true)
      ]));
    }
    if (config.showFournisseur) {
      metalRows.add(pw.TableRow(children: [
        cellT('FOURNISSEUR', bold: true),
        cellT(e.fournisseur, bold: true)
      ]));
    }

    pw.Widget? tableMetalBase;
    if (config.showTableMetalBase && metalRows.isNotEmpty) {
      tableMetalBase = pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border, width: 0.65)),
        child: pw.Column(children: [
          banner('METAL DE BASE'),
          pw.Table(
              border: tb,
              columnWidths: const {
                0: pw.FlexColumnWidth(1.4),
                1: pw.FlexColumnWidth(1.6)
              },
              children: metalRows),
        ]),
      );
    }

    // ── 4. SOUDURE ──
    final extIntRows = <pw.TableRow>[
      pw.TableRow(children: [
        cellT('CORDON', bold: true),
        cellT('EXT', bold: true, align: pw.TextAlign.center),
        cellT('INT', bold: true, align: pw.TextAlign.center)
      ]),
    ];
    if (config.showSurepaisseur) {
      extIntRows.add(pw.TableRow(children: [
        cellT('SUREPAISSEUR (mm)', bold: true),
        cellT(e.surepExt, bold: true, align: pw.TextAlign.center),
        cellT(e.surepInt, bold: true, align: pw.TextAlign.center),
      ]));
    }
    if (config.showLargeur) {
      extIntRows.add(pw.TableRow(children: [
        cellT('LARGEUR (mm)', bold: true),
        cellT(e.largeurExt, bold: true, align: pw.TextAlign.center),
        cellT(e.largeurInt, bold: true, align: pw.TextAlign.center),
      ]));
    }
    if (config.showPenetration) {
      extIntRows.add(pw.TableRow(children: [
        cellT('PENETRATION (%)', bold: true),
        cellT(e.penetrationExt, bold: true, align: pw.TextAlign.center),
        cellT(e.penetrationInt, bold: true, align: pw.TextAlign.center),
      ]));
    }
    final globalRows = <pw.TableRow>[];
    if (config.showDesaxage) {
      globalRows.add(pw.TableRow(children: [
        cellT('DESAXAGE (mm)', bold: true),
        cellT(e.desaxage, bold: true, align: pw.TextAlign.center),
      ]));
    }
    if (config.showInterpenetration) {
      globalRows.add(pw.TableRow(children: [
        cellT('INTERPENETRATION (mm)', bold: true),
        cellT(e.interpenetration, bold: true, align: pw.TextAlign.center),
      ]));
    }

    pw.Widget? tableSoudure;
    if (config.showTableSoudure) {
      tableSoudure = pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border, width: 0.65)),
        child: pw.Column(children: [
          if (config.showNTube && e.nTube.isNotEmpty)
            pw.Table(
                border: tb,
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.4),
                  1: pw.FlexColumnWidth(1.6)
                },
                children: [
                  pw.TableRow(children: [
                    banner('N° TUBE'),
                    cellT(
                        e.nTube,
                        bold: true,
                        align: pw.TextAlign.center),
                  ]),
                ]),
          banner('SOUDURE'),
          if (extIntRows.length > 1)
            pw.Table(
                border: tb,
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(0.75),
                  2: pw.FlexColumnWidth(0.75),
                },
                children: extIntRows),
          if (globalRows.isNotEmpty)
            pw.Table(
                border: tb,
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(1.5)
                },
                children: globalRows),
        ]),
      );
    }

    // Agencement 2 colonnes parfaitement harmonieux
    final leftCol = pw.Column(
      children: [
        if (tableParam != null) tableParam,
        if (tableParam != null && tableMetalBase != null) pw.SizedBox(height: 7),
        if (tableMetalBase != null) tableMetalBase,
      ],
    );

    final rightCol = pw.Column(
      children: [
        boxPhoto,
        if (tableSoudure != null) pw.SizedBox(height: 7),
        if (tableSoudure != null) tableSoudure,
      ],
    );

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: leftCol),
          pw.SizedBox(width: 8),
          pw.Expanded(child: rightCol),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 6. CONSTAT MACROGRAPHIQUE
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _buildObservation(Rapport r, AppSettings settings) {
    final text = r.observation.isNotEmpty
        ? r.observation
        : settings.defaultObservation;
    return pw.Container(
      width: double.infinity,
      // NOTE: borderRadius interdit avec Border non-uniforme dans le pkg pdf
      // → filet gauche rendu via un Row imbriqué
      decoration: const pw.BoxDecoration(
        color: _subtleBg,
        border: pw.Border(
          left: pw.BorderSide(color: _accentBlue, width: 3.0),
          top: pw.BorderSide(color: _borderLight, width: 0.8),
          right: pw.BorderSide(color: _borderLight, width: 0.8),
          bottom: pw.BorderSide(color: _borderLight, width: 0.8),
        ),
        // Pas de borderRadius ici : la lib pdf l'interdit quand les côtés sont inégaux
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 7.0),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 8.6,
          color: _primaryDark,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 7. TABLEAU DES SIGNATAIRES (5 Colonnes : DATE + 4 Signataires)
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _buildSignatureTable(Rapport r, {pw.ImageProvider? cachet}) {
    final tb = pw.TableBorder.all(color: _border, width: 0.65);

    pw.Widget hdr(String t) => pw.Container(
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(
            color: _headerBg,
          ),
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4.0),
          child: pw.Text(t,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 7.2,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryDark)),
        );

    pw.Widget nom(String t) => pw.Container(
          alignment: pw.Alignment.center,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.8),
          child: pw.Text(
            t.isNotEmpty ? t : ' ',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 7.0,
                fontWeight: pw.FontWeight.bold,
                color: _accentBlue),
          ),
        );

    pw.Widget sigSpace({bool withCachet = false}) {
      const h = 2.8 * PdfPageFormat.cm;
      if (withCachet && cachet != null) {
        return pw.SizedBox(
          height: h,
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.45,
              child: pw.Image(cachet, height: h * 0.85, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }
      return pw.SizedBox(height: h);
    }

    pw.Widget colCell(String name, {bool withCachet = false}) {
      final trimmed = name.trim();
      final hasThisName = trimmed.isNotEmpty && trimmed != '/';
      if (!hasThisName) return sigSpace(withCachet: withCachet);
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          nom(name),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  top: pw.BorderSide(color: _border, width: 0.65)),
            ),
          ),
          sigSpace(withCachet: withCachet),
        ],
      );
    }

    final lab = r.laboratoire;
    final c2h = r.sigCol2Header;
    final c3h = r.sigCol3Header;
    final c4h = r.sigCol4Header;

    return pw.Table(
      border: tb,
      columnWidths: const {
        0: pw.FlexColumnWidth(0.9),
        1: pw.FlexColumnWidth(1.1),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(0.9),
      },
      children: [
        pw.TableRow(children: [
          hdr('DATE'),
          hdr(lab),
          hdr(c2h),
          hdr(c3h),
          hdr(c4h),
        ]),
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(r.dateSignature,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 8.0,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryDark)),
            ),
            colCell(r.sigCol1Value, withCachet: true), // Colonne Laboratoire → cachet ici
            colCell(r.sigCol2Value),
            colCell(r.sigCol3Value),
            colCell(r.sigCol4Value),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 8. MENTIONS LÉGALES / PERSONNES AUTORISANT LE RAPPORT
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _buildFootNote(AppSettings s) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Personnes autorisant le rapport :',
              style: pw.TextStyle(
                  fontSize: 7.8,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryDark)),
          pw.SizedBox(height: 1.5),
          pw.Text(s.footNote1,
              style: const pw.TextStyle(fontSize: 7.0, color: _textSecondary)),
          pw.Text(s.footNote2,
              style: const pw.TextStyle(fontSize: 7.0, color: _textSecondary)),
        ],
      );

  // ══════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════
  static pw.Widget _sampleImage(String? photoPath) {
    if (photoPath != null && File(photoPath).existsSync()) {
      try {
        final bytes = File(photoPath).readAsBytesSync();
        if (bytes.isNotEmpty) {
          return pw.Image(pw.MemoryImage(bytes),
              fit: pw.BoxFit.contain, alignment: pw.Alignment.center);
        }
      } catch (_) {}
    }
    return pw.Text('Pas de photo',
        style: const pw.TextStyle(fontSize: 7.2, color: _textSecondary));
  }

  static String _lbl(Rapport r, String key, String def, {String? fieldKey}) {
    try {
      if (r.customFieldsJson.isNotEmpty && r.customFieldsJson != '{}') {
        final d = jsonDecode(r.customFieldsJson);
        if (d is Map && d['_labels'] is Map) {
          final labels = d['_labels'] as Map;

          // 1. Direct match on fieldKey
          if (fieldKey != null &&
              labels.containsKey(fieldKey) &&
              labels[fieldKey].toString().trim().isNotEmpty) {
            return labels[fieldKey].toString().trim();
          }
          // 2. Direct match on key
          if (labels.containsKey(key) &&
              labels[key].toString().trim().isNotEmpty) {
            return labels[key].toString().trim();
          }
          // 3. Direct match on def
          if (labels.containsKey(def) &&
              labels[def].toString().trim().isNotEmpty) {
            return labels[def].toString().trim();
          }

          // 4. Fuzzy & synonym search across all user saved labels
          for (final entry in labels.entries) {
            final entryK = entry.key.toString().trim().toLowerCase();
            final entryVal = entry.value?.toString().trim() ?? '';
            if (entryVal.isEmpty) continue;

            final targetK = key.toLowerCase();
            final targetDef = def.toLowerCase();
            final targetFk = fieldKey?.toLowerCase() ?? '';

            // Exact match in lower
            if (entryK == targetK ||
                entryK == targetDef ||
                (targetFk.isNotEmpty && entryK == targetFk)) {
              return entryVal;
            }
            // Substring containment
            if (entryK.contains(targetK) ||
                targetK.contains(entryK) ||
                entryK.contains(targetDef) ||
                targetDef.contains(entryK)) {
              return entryVal;
            }

            // Domain-specific aliases: Métal d'apport / Fil de soudage
            final isMetalTarget = targetDef.contains('métal') ||
                targetDef.contains('metal') ||
                targetDef.contains('apport') ||
                targetK.contains('métal') ||
                targetK.contains('metal') ||
                targetK.contains('apport') ||
                targetFk == 'metal_apport';
            final isMetalEntry = entryK.contains('métal') ||
                entryK.contains('metal') ||
                entryK.contains('fil') ||
                entryK.contains('apport');
            if (isMetalTarget && isMetalEntry) {
              return entryVal;
            }

            // Procédé
            final isProcedeTarget = targetDef.contains('procédé') ||
                targetDef.contains('procede') ||
                targetFk == 'procede_soudage';
            final isProcedeEntry =
                entryK.contains('procédé') || entryK.contains('procede');
            if (isProcedeTarget && isProcedeEntry) {
              return entryVal;
            }

            // Position
            final isPositionTarget = targetDef.contains('position') ||
                targetFk == 'position_soudage';
            final isPositionEntry = entryK.contains('position');
            if (isPositionTarget && isPositionEntry) {
              return entryVal;
            }

            // Dimensions
            final isDimensionTarget = targetDef.contains('dimension') ||
                targetDef.contains('dim') ||
                targetFk == 'dimensions';
            final isDimensionEntry =
                entryK.contains('dimension') || entryK.contains('dim');
            if (isDimensionTarget && isDimensionEntry) {
              return entryVal;
            }

            // Nuance
            final isNuanceTarget =
                targetDef.contains('nuance') || targetFk == 'nuance';
            final isNuanceEntry = entryK.contains('nuance');
            if (isNuanceTarget && isNuanceEntry) {
              return entryVal;
            }

            // Méthode d'échantillonnage
            final isEchantillonnageTarget =
                targetDef.contains('échantillonnage') ||
                    targetDef.contains('echantillonnage') ||
                    targetFk == 'methode_echantillonnage';
            final isEchantillonnageEntry =
                entryK.contains('échantillonnage') ||
                    entryK.contains('echantillonnage');
            if (isEchantillonnageTarget && isEchantillonnageEntry) {
              return entryVal;
            }

            // Méthode d'essai
            final isEssaiTarget = targetDef.contains('méthode d\'essai') ||
                targetDef.contains('methode d\'essai') ||
                targetFk == 'methode_essai';
            final isEssaiEntry = entryK.contains('méthode d\'essai') ||
                entryK.contains('methode d\'essai');
            if (isEssaiTarget && isEssaiEntry) {
              return entryVal;
            }
          }
        }
      }
    } catch (_) {}
    return def;
  }
}
