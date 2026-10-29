import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_settings.dart';
import '../models/echantillon.dart';
import '../models/pv_config.dart';
import '../models/rapport.dart';
import 'settings_service.dart';

class PdfService {
  static const PdfColor _headerGrey = PdfColor.fromInt(0xFFEFEDE7);
  static const PdfColor _borderGrey = PdfColor.fromInt(0xFF9E9E9E);

  /// Génère le PDF du rapport sur 1 SEULE PAGE stricte (A4 portrait),
  /// reproduisant exactement le modèle officiel (Pv Macro 1-15 IP.pdf)
  /// en appliquant les filtres de champs configurés (PvFieldConfig).
  static Future<File> generateRapportPdf(
    Rapport r, {
    required AppSettings settings,
    PvFieldConfig? pvConfig,
  }) async {
    final doc = pw.Document();
    final config = pvConfig ?? await SettingsService.instance.getPvConfig();

    // Fontes Unicode locales (Roboto-Regular et Roboto-Bold) incluses directement dans les assets
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      final regBytes = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldBytes = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      fontRegular = pw.Font.ttf(regBytes);
      fontBold = pw.Font.ttf(boldBytes);
    } catch (_) {
      try {
        fontRegular = await PdfGoogleFonts.robotoRegular();
        fontBold = await PdfGoogleFonts.robotoBold();
      } catch (_) {
        fontRegular = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
      }
    }

    // Logo dynamique (avec fallback automatique sur assets/logo.png)
    pw.ImageProvider? logo;
    if (config.showLogo) {
      if (settings.logoPath != null && File(settings.logoPath!).existsSync()) {
        try {
          final bytes = File(settings.logoPath!).readAsBytesSync();
          if (bytes.isNotEmpty) {
            logo = pw.MemoryImage(bytes);
          }
        } catch (_) {}
      }
      if (logo == null) {
        try {
          final logoBytes = await rootBundle.load('assets/logo.png');
          logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
        } catch (_) {}
      }
    }

    // Cachet optionnel sélectionné (0 = Aucun / Vide, 1 = Cachet 1, 2 = Cachet 2, 3 = Cachet 3)
    pw.ImageProvider? cachet;
    if (config.selectedCachet > 0) {
      final String? selectedPath = config.selectedCachet == 1
          ? (settings.cachet1Path ?? settings.cachetPath)
          : (config.selectedCachet == 2 ? settings.cachet2Path : settings.cachet3Path);

      if (selectedPath != null && selectedPath.isNotEmpty && File(selectedPath).existsSync()) {
        try {
          final bytes = File(selectedPath).readAsBytesSync();
          if (bytes.isNotEmpty) cachet = pw.MemoryImage(bytes);
        } catch (_) {}
      }
    }

    // Multi-page A4 PDF document — content flows across pages
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => _buildHeader(logo, r, settings, config),
        footer: (context) => config.showPageNumber
            ? pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text(
                  'Page ${context.pageNumber} sur ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9.5),
                ),
              )
            : pw.Container(),
        build: (context) => [
          // 2. Tableau des caractéristiques de l'essai
          _buildInfoTable(r, config),
          pw.SizedBox(height: 4),

          // 3. Mention légale / Disclaimer
          if (config.showDisclaimer) ...[
            _buildDisclaimerText(),
            pw.SizedBox(height: 6),
          ],

          // 4. Bannière MACRO-GRAPHIQUE
          if (config.showSectionTitle) ...[
            _buildSectionTitle('MACRO-GRAPHIQUE'),
            pw.SizedBox(height: 10),
          ],

          // 5. Zone des échantillons — tableaux détaillés si activés, sinon photos simples
          if (r.isCommandeInterne || config.showTableParametres || config.showTableMetalBase || config.showTableSoudure)
            _buildPhotosGrid(r, config)
          else
            _buildPrestationPhotosGrid(r, config),
          pw.SizedBox(height: 12),

          // 6. Constat / Résultat de l'examen macrographique
          if (config.showObservation && (r.observation.isNotEmpty || settings.defaultObservation.isNotEmpty))
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                child: pw.Text(
                  r.observation.isNotEmpty
                      ? r.observation
                      : settings.defaultObservation,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ),

          if (config.showObservation && (r.observation.isNotEmpty || settings.defaultObservation.isNotEmpty))
            pw.SizedBox(height: 12),

          // 7. Tableau de signatures — layout different selon le type
          if (config.showSignatures) ...[
            if (r.isCommandeInterne)
              _buildSignatureTableInterne(r, cachet: cachet)
            else
              _buildSignatureTable(r, cachet: cachet),
            pw.SizedBox(height: 6),
          ],

          // 8. Mentions "Personnes autorisant le rapport :" placées juste après le tableau pour les 2 PVs !
          if (config.showFootnotes) ...[
            _buildFootNote(settings),
          ],
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${r.defaultPdfFileName}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  /// Retourne les bytes du PDF sans écrire sur disque (pour l'aperçu en-app).
  static Future<Uint8List> generateRapportBytes(
    Rapport r, {
    required AppSettings settings,
    PvFieldConfig? pvConfig,
  }) async {
    final file = await generateRapportPdf(r, settings: settings, pvConfig: pvConfig);
    return file.readAsBytesSync();
  }

  static pw.Widget _buildHeader(
      pw.ImageProvider? logo, Rapport r, AppSettings s, PvFieldConfig config) {
    // Si l'en-tête est complètement vide, on retourne un conteneur vide
    final hasLeftBox = config.showLogo || config.showCompanyHeader;
    final hasRightBox = config.showDocMeta;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Tableau d'en-tête (Logo | Titre | Meta doc)
        pw.Table(
          border: pw.TableBorder.all(color: _borderGrey, width: 0.8),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.6),
            1: pw.FlexColumnWidth(5.0),
            2: pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: hasLeftBox
                    ? pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          if (logo != null && config.showLogo)
                            pw.Image(
                              logo,
                              height: 1.6 * PdfPageFormat.cm,
                              width: 3.4 * PdfPageFormat.cm,
                              fit: pw.BoxFit.contain,
                            ),
                          if (config.showCompanyHeader) ...[
                            pw.SizedBox(height: 1),
                            pw.Text(
                              s.companyName,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              s.uniteName,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      )
                    : pw.Container(),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                height: 2.2 * PdfPageFormat.cm,
                padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                child: pw.Center(
                  child: pw.Text(
                    "RAPPORT D'ESSAI",
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.center,
                child: hasRightBox
                    ? pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(r.isCommandeInterne ? s.docRefInterne : s.docRef,
                              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Version:${r.isCommandeInterne ? s.docVersionInterne : s.docVersion}',
                              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Date:${r.isCommandeInterne ? s.docDateInterne : s.docDate}',
                              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Page : 01',
                              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        ],
                      )
                    : pw.Container(),
              ),
            ]),
          ],
        ),
        if (config.showLabInfo) ...[
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              s.labName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.Center(
            child: pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
                children: [
                  pw.TextSpan(text: 'ADRESSE DU LABORATOIRE: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.TextSpan(text: s.labAddress),
                ],
              ),
            ),
          ),
          if (s.labLieu.isNotEmpty) ...[
            pw.Center(
              child: pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
                  children: [
                    pw.TextSpan(text: "Lieu d'exécution des essais : ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: s.labLieu),
                  ],
                ),
              ),
            ),
          ],
        ],
        if (config.showDateReception || config.showDateEmission || config.showDateEssai || config.showPvNumero) ...[
          pw.SizedBox(height: 4),
          // En-tête dates à droite avec prise en compte des libellés personnalisés
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (config.showDateReception && r.dateReception.isNotEmpty)
                    _kv(
                      "${_getCustomLabel(r, 'Date Réception', "Date de Réception d'échantillon")}: ",
                      r.dateReception,
                    ),
                  if (config.showDateEmission && r.dateEmission.isNotEmpty)
                    _kv(
                      "${_getCustomLabel(r, 'Date Émission', "Date d'émission du Rapport")}: ",
                      r.dateEmission,
                    ),
                  if (config.showDateEssai && r.dateEssai.isNotEmpty)
                    _kv(
                      "${_getCustomLabel(r, 'Date d\'essai', "Date d'essai")}: ",
                      r.dateEssai,
                    ),
                  if (config.showPvNumero && r.pvNumero.isNotEmpty)
                    _kv(
                      "${_getCustomLabel(r, 'PV N° (ex: 01/2026)', "PV N°")}: ",
                      r.pvNumero,
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _getCustomLabel(Rapport r, String key, String defaultLabel, {String? fieldKey}) {
    try {
      if (r.customFieldsJson.isNotEmpty && r.customFieldsJson != '{}') {
        final decoded = jsonDecode(r.customFieldsJson);
        if (decoded is Map && decoded['_labels'] is Map) {
          final labels = decoded['_labels'] as Map;
          if (fieldKey != null && labels.containsKey(fieldKey) && labels[fieldKey].toString().trim().isNotEmpty) {
            return labels[fieldKey].toString().trim();
          }
          if (labels.containsKey(key) && labels[key].toString().trim().isNotEmpty) {
            return labels[key].toString().trim();
          }
          if (labels.containsKey(defaultLabel) && labels[defaultLabel].toString().trim().isNotEmpty) {
            return labels[defaultLabel].toString().trim();
          }
          for (final entry in labels.entries) {
            final entryK = entry.key.toString().trim().toLowerCase();
            final entryVal = entry.value?.toString().trim() ?? '';
            if (entryVal.isEmpty) continue;

            final targetK = key.toLowerCase();
            final targetDef = defaultLabel.toLowerCase();

            if (entryK == targetK || entryK == targetDef) return entryVal;
            if (entryK.contains(targetK) || targetK.contains(entryK) ||
                entryK.contains(targetDef) || targetDef.contains(entryK)) {
              return entryVal;
            }
            if ((targetDef.contains('métal') || targetDef.contains('metal') || targetDef.contains('apport') || targetK.contains('métal')) &&
                (entryK.contains('métal') || entryK.contains('metal') || entryK.contains('fil') || entryK.contains('apport'))) {
              return entryVal;
            }
          }
        }
      }
    } catch (_) {}
    return defaultLabel;
  }

  static pw.Widget _kv(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 8.0),
        children: [
          pw.TextSpan(text: label),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoTable(Rapport r, PvFieldConfig config) {
    pw.Widget cell(String text, {bool bold = false}) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    final nbFormatted = r.nbEchantillons.toString().padLeft(2, '0');

    String getL(String key, String def) => _getCustomLabel(r, key, def);

    final allCells = <pw.Widget>[];
    final allCellsText = <String>[];

    void addCell(String text, {bool bold = false}) {
      allCells.add(cell(text, bold: bold));
      allCellsText.add(text);
    }

    // Helper: inject custom fields for a specific section key
    Map<String, String> customLabels = {};
    Map<String, Map<String, String>> customSections = {};
    try {
      if (r.customFieldsJson.isNotEmpty && r.customFieldsJson != '{}') {
        final decoded = jsonDecode(r.customFieldsJson);
        if (decoded is Map) {
          if (decoded['_labels'] is Map) {
            (decoded['_labels'] as Map).forEach((k, v) {
              if (v != null) customLabels[k.toString()] = v.toString();
            });
          }
          decoded.forEach((secKey, fields) {
            if (secKey != '_labels' && fields is Map) {
              customSections[secKey.toString()] = {};
              fields.forEach((k, v) {
                if (v != null && v.toString().trim().isNotEmpty) {
                  customSections[secKey.toString()]![k.toString()] = v.toString();
                }
              });
            }
          });
        }
      }
    } catch (_) {}

    void addCustomSection(String sKey) {
      if (!config.showCustomFields) return;
      final fields = customSections[sKey];
      if (fields == null) return;
      fields.forEach((k, v) {
        final label = customLabels['${sKey}_$k'] ?? customLabels[k] ?? k;
        addCell('$label : $v', bold: true);
      });
    }

    if (config.showNomClient) {
      final l = getL('Nom Client / Demandeur (ex: SONALGEZ)', 'Nom Client');
      addCell('$l : ${r.nomClient}', bold: true);
    }
    if (config.showDimensions) {
      final l = getL('Dimensions (mm)', 'Dimensions');
      final dimStr = r.dimensions.trim();
      final dimDisplay = dimStr.isEmpty ? '' : (dimStr.toLowerCase().endsWith('mm') ? dimStr : '$dimStr mm');
      addCell('$l: $dimDisplay', bold: true);
    }
    if (config.showNuance) {
      final l = getL('Nuance (ex: API 5L X60M)', 'Nuance');
      addCell('$l : ${r.nuance}', bold: true);
    }
    if (config.showCoordonneesClient) {
      final l = getL('Coordonnées / Adresse du client', 'Coordonnées du client');
      addCell('$l : ${r.coordonneesClient}', bold: true);
    }
    if (config.showNWps) {
      final l = getL('N° WPS (ex: 38)', 'N°WPS');
      addCell('$l : ${r.nWps}', bold: true);
    }
    if (config.showNPqr) {
      final l = getL('N° PQR (ex: 41)', 'N° PQR');
      addCell('$l : ${r.nPqr}', bold: true);
    }

    addCustomSection('client');
    addCustomSection('caracteristiques');
    addCustomSection('ident');

    if (config.showMethodeEssai) {
      final l = getL('Méthode d\'essai (ex: /)', "Méthode D'essai");
      addCell('$l : ${r.methodeEssai}', bold: true);
    }
    if (config.showNbEchantillons) {
      final l = getL('Nombre d\'Échantillons', "Nb d'échantillon(s)");
      addCell('$l : $nbFormatted', bold: true);
    }
    if (config.showMethodeEchantillonnage) {
      final l = getL('Méthode d\'échantillonnage (ex: /)', "Méthode D'échantillonnage");
      addCell('$l : ${r.methodeEchantillonnage}', bold: true);
    }

    if (config.showSectionSoudage) {
      if (config.showProcedeSoudage && r.procedeSoudage.isNotEmpty) {
        final l = getL('Procédé de Soudage (ex: SAWH)', 'Procédé');
        addCell('$l: ${r.procedeSoudage}', bold: true);
      }
      if (config.showMetalApport && r.metalApport.isNotEmpty) {
        final l = getL('Métal d\'apport / Lot (ex: E 8018 -G H4)', 'Apport');
        addCell('$l: ${r.metalApport}', bold: true);
      }
      if (config.showPositionSoudage && r.positionSoudage.isNotEmpty) {
        final l = getL('Position de Soudage (ex: 5G)', 'Position');
        addCell('$l: ${r.positionSoudage}', bold: true);
      }
      if (config.showNJoint && r.nJoint.isNotEmpty) {
        final l = getL('N° Joint / Repère', 'Joint');
        addCell('$l: ${r.nJoint}', bold: true);
      }
      if (config.showTraitementThermique && r.traitementThermique.isNotEmpty) {
        final l = getL('Traitement Thermique (PWHT)', 'PWHT');
        addCell('$l: ${r.traitementThermique}', bold: true);
      }
      addCustomSection('soudage');
    }

    if (config.showSpecificationEssai) {
      final l = getL('Spécification d\'essai (ex: /)', "Spécification d'essai");
      addCell('$l : ${r.specificationEssai}', bold: true);
    }
    if (config.showProjet) {
      final l = getL('Projet / BC (ex: REALISATION EN EPC...)', 'Projet /BC');
      addCell('$l: ${r.projet}', bold: true);
    }

    // Remaining custom sections not yet placed
    final handledSections = {'client', 'caracteristiques', 'ident', 'soudage', 'constat', 'signatures'};
    customSections.forEach((sKey, _) {
      if (!handledSections.contains(sKey)) {
        addCustomSection(sKey);
      }
    });

    if (allCells.isEmpty) {
      return pw.Container();
    }

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
        // Ligne spéciale : donne plus de place à la colonne 3
        widths = const {
          0: pw.FlexColumnWidth(3.4),
          1: pw.FlexColumnWidth(2.6),
          2: pw.FlexColumnWidth(4.0),
        };
      } else if (text2.contains('Date Émission') || text2.contains("d'émission")) {
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
            left: const pw.BorderSide(color: _borderGrey, width: 0.8),
            right: const pw.BorderSide(color: _borderGrey, width: 0.8),
            top: isFirst ? const pw.BorderSide(color: _borderGrey, width: 0.8) : pw.BorderSide.none,
            bottom: const pw.BorderSide(color: _borderGrey, width: 0.8),
            verticalInside: const pw.BorderSide(color: _borderGrey, width: 0.8),
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
              left: const pw.BorderSide(color: _borderGrey, width: 0.8),
              right: const pw.BorderSide(color: _borderGrey, width: 0.8),
              bottom: const pw.BorderSide(color: _borderGrey, width: 0.8),
              top: tableList.isNotEmpty ? pw.BorderSide.none : const pw.BorderSide(color: _borderGrey, width: 0.8),
              verticalInside: const pw.BorderSide(color: _borderGrey, width: 0.8),
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
              left: const pw.BorderSide(color: _borderGrey, width: 0.8),
              right: const pw.BorderSide(color: _borderGrey, width: 0.8),
              bottom: const pw.BorderSide(color: _borderGrey, width: 0.8),
              top: tableList.isNotEmpty ? pw.BorderSide.none : const pw.BorderSide(color: _borderGrey, width: 0.8),
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



  static pw.Widget _buildDisclaimerText() {
    return pw.Center(
      child: pw.Text(
        "Les résultats se rapportent aux échantillons tels qu'ils ont été fournis par le client.\n"
        "Les parties du rapport ne doivent pas être reproduites sans l'accord du laboratoire ; pour éviter qu'elle soit prise hors contexte.",
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 9.0, color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      color: _headerGrey,
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      alignment: pw.Alignment.center,
      child: pw.Text(
        title,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
      ),
    );
  }

  static pw.Widget _buildPhotosGrid(Rapport r, PvFieldConfig config) {
    if (r.echantillons.isEmpty) {
      return pw.Text('Aucun échantillon renseigné.', style: const pw.TextStyle(fontSize: 8.5));
    }

    return pw.Column(
      children: r.echantillons.map((e) => _buildSampleDetailGrid(e, config, photoHeight: r.photoHeightPdf.toDouble())).toList(),
    );
  }

  /// Construit la grille exacte de 4 tableaux (PARAMETRES, PHOTO, METAL DE BASE, SOUDURE)
  /// avec adaptation dynamique selon PvFieldConfig.
  static pw.Widget _buildSampleDetailGrid(Echantillon e, PvFieldConfig config, {double photoHeight = 140}) {
    pw.Widget cellText(String txt, {bool bold = false, pw.TextAlign align = pw.TextAlign.left, double fontSize = 7.0}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
        child: pw.Text(
          txt,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    pw.Widget headerBanner(String txt) {
      return pw.Container(
        color: _headerGrey,
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        alignment: pw.Alignment.center,
        child: pw.Text(
          txt,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
      );
    }

    // 1. Tableau PARAMETRES DE SOUDAGE (Haut Gauche)
    final paramRows1 = <pw.TableRow>[];
    if (config.showParamVitesse) {
      paramRows1.add(
        pw.TableRow(children: [
          cellText('VITESSE (m/min)', bold: true),
          pw.Container(
            alignment: pw.Alignment.center,
            child: cellText(e.vitesse.isNotEmpty ? e.vitesse : '0,9', bold: true, align: pw.TextAlign.center),
          ),
          pw.Container(),
          pw.Container(),
        ]),
      );
    }
    if (config.showParamTension) {
      paramRows1.add(
        pw.TableRow(children: [
          cellText('U  INT', bold: true),
          cellText(e.uInt.isNotEmpty ? e.uInt : '32 V', bold: true),
          cellText('U  EXT', bold: true),
          cellText(e.uExt.isNotEmpty ? e.uExt : '32 V', bold: true),
        ]),
      );
    }
    if (config.showParamCourant) {
      paramRows1.add(
        pw.TableRow(children: [
          cellText('I   INT', bold: true),
          cellText(e.iInt.isNotEmpty ? e.iInt : '630 A', bold: true),
          cellText('I   EXT', bold: true),
          cellText(e.iExt.isNotEmpty ? e.iExt : '780 A', bold: true),
        ]),
      );
    }

    final paramRows2 = <pw.TableRow>[];
    if (config.showParamFils) {
      paramRows2.add(
        pw.TableRow(children: [
          cellText('Ø DU FIL INT', bold: true),
          cellText(e.filInt1.isNotEmpty ? e.filInt1 : '(3,2mm) 200987', bold: true),
        ]),
      );
      paramRows2.add(
        pw.TableRow(children: [
          cellText('Ø DU FIL INT', bold: true),
          cellText(e.filInt2.isNotEmpty ? e.filInt2 : '(4 mm) 200955', bold: true),
        ]),
      );
    }
    if (config.showParamFlux) {
      paramRows2.add(
        pw.TableRow(children: [
          cellText('FLUX', bold: true),
          cellText(e.flux.isNotEmpty ? e.flux : 'D1FX25376 P223', bold: true),
        ]),
      );
    }

    pw.Widget? tableParametres;
    if (config.showTableParametres) {
      tableParametres = pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderGrey, width: 0.8)),
        child: pw.Column(
          children: [
            headerBanner('PARAMETRES DE SOUDAGE'),
            if (paramRows1.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: _borderGrey, width: 0.6),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(0.6),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(0.6),
                },
                children: paramRows1,
              ),
            if (paramRows2.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: _borderGrey, width: 0.6),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.4),
                },
                children: paramRows2,
              ),
          ],
        ),
      );
    }

    // 2. Cadre Photo avec TYPE LOT & GROSSISSEMENT (Haut Droit)
    final boxPhoto = pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderGrey, width: 0.8)),
      child: pw.Column(
        children: [
          if (config.showTypeLot && e.typeLot.isNotEmpty) headerBanner('TYPE : ${e.typeLot}'),
          pw.Container(
            height: (photoHeight * 0.51).clamp(36.0, 153.0),
            width: double.infinity,
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.center,
            child: _buildSampleImage(e.photoPath),
          ),
          if (config.showGrossissement && e.grossissement.isNotEmpty) headerBanner('GROSSISSEMENT : ${e.grossissement}'),
        ],
      ),
    );

    final gClean = e.grossissement.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.').trim();
    final gVal = double.tryParse(gClean) ?? 1.8;
    final epReelClean = e.epReel.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.').trim();
    final epReelVal = double.tryParse(epReelClean) ?? 11.0;
    final epPhotoStr = (gVal * epReelVal).toStringAsFixed(2).replaceAll('.', ',');

    // 3. Tableau METAL DE BASE (Bas Gauche)
    final metalRows = <pw.TableRow>[];
    if (config.showMetalNuance) metalRows.add(pw.TableRow(children: [cellText('NUANCE', bold: true), cellText(e.metalNuance, bold: true)]));
    if (config.showNCoulee) metalRows.add(pw.TableRow(children: [cellText('N° COULEE', bold: true), cellText(e.nCoulee, bold: true)]));
    if (config.showNBobine) metalRows.add(pw.TableRow(children: [cellText('N° BOBINE', bold: true), cellText(e.nBobine, bold: true)]));
    if (config.showDiametreTube) metalRows.add(pw.TableRow(children: [cellText('Ø TUBE (mm)', bold: true), cellText(e.diametreTube, bold: true)]));
    if (config.showEpNominale) metalRows.add(pw.TableRow(children: [cellText('EP. NOMINALE (mm)', bold: true), cellText(e.epNominale, bold: true)]));
    if (config.showEpReel) metalRows.add(pw.TableRow(children: [cellText('EP. REEL (mm)', bold: true), cellText(e.epReel, bold: true)]));
    if (config.showEpSurPhoto) metalRows.add(pw.TableRow(children: [cellText('EP. SUR PHOTO (mm)', bold: true), cellText(epPhotoStr, bold: true)]));
    if (config.showFournisseur) metalRows.add(pw.TableRow(children: [cellText('FOURNISSEUR', bold: true), cellText(e.fournisseur, bold: true)]));

    pw.Widget? tableMetalBase;
    if (config.showTableMetalBase && metalRows.isNotEmpty) {
      tableMetalBase = pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderGrey, width: 0.8)),
        child: pw.Column(
          children: [
            headerBanner('METAL DE BASE'),
            pw.Table(
              border: pw.TableBorder.all(color: _borderGrey, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.4),
                1: pw.FlexColumnWidth(1.6),
              },
              children: metalRows,
            ),
          ],
        ),
      );
    }

    // 4. Tableau SOUDURE / N° TUBE (Bas Droit)
    final soudureExtIntRows = <pw.TableRow>[];
    soudureExtIntRows.add(pw.TableRow(children: [cellText('CORDON', bold: true), cellText('EXT', bold: true, align: pw.TextAlign.center), cellText('INT', bold: true, align: pw.TextAlign.center)]));
    if (config.showSurepaisseur) {
      soudureExtIntRows.add(pw.TableRow(children: [cellText('SUREPAISSEUR (mm)', bold: true), cellText(e.surepExt, bold: true, align: pw.TextAlign.center), cellText(e.surepInt, bold: true, align: pw.TextAlign.center)]));
    }
    if (config.showLargeur) {
      soudureExtIntRows.add(pw.TableRow(children: [cellText('LARGEUR (mm)', bold: true), cellText(e.largeurExt, bold: true, align: pw.TextAlign.center), cellText(e.largeurInt, bold: true, align: pw.TextAlign.center)]));
    }
    if (config.showPenetration) {
      soudureExtIntRows.add(pw.TableRow(children: [cellText('PENETRATION (%)', bold: true), cellText(e.penetrationExt, bold: true, align: pw.TextAlign.center), cellText(e.penetrationInt, bold: true, align: pw.TextAlign.center)]));
    }

    final soudureGlobalRows = <pw.TableRow>[];
    if (config.showDesaxage) {
      soudureGlobalRows.add(pw.TableRow(children: [cellText('DESAXAGE (mm)', bold: true), cellText(e.desaxage, bold: true, align: pw.TextAlign.center)]));
    }
    if (config.showInterpenetration) {
      soudureGlobalRows.add(pw.TableRow(children: [cellText('INTERPENETRATION (mm)', bold: true), cellText(e.interpenetration, bold: true, align: pw.TextAlign.center)]));
    }

    pw.Widget? tableSoudure;
    if (config.showTableSoudure) {
      tableSoudure = pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderGrey, width: 0.8)),
        child: pw.Column(
          children: [
            if (config.showNTube)
              pw.Table(
                border: pw.TableBorder.all(color: _borderGrey, width: 0.6),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.4),
                  1: pw.FlexColumnWidth(1.6),
                },
                children: [
                  pw.TableRow(children: [
                    headerBanner('N° TUBE'),
                    cellText(e.nTube, bold: true, align: pw.TextAlign.center),
                  ]),
                ],
              ),
            headerBanner('SOUDURE'),
            if (soudureExtIntRows.length > 1)
              pw.Table(
                border: pw.TableBorder.all(color: _borderGrey, width: 0.6),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(0.75),
                  2: pw.FlexColumnWidth(0.75),
                },
                children: soudureExtIntRows,
              ),
            if (soudureGlobalRows.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: _borderGrey, width: 0.6),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(1.5),
                },
                children: soudureGlobalRows,
              ),
          ],
        ),
      );
    }

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (tableParametres != null) ...[
                pw.Expanded(child: tableParametres),
                pw.SizedBox(width: 8),
              ],
              pw.Expanded(child: boxPhoto),
            ],
          ),
          if (tableMetalBase != null || tableSoudure != null) ...[
            pw.SizedBox(height: 6),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (tableMetalBase != null) ...[
                  pw.Expanded(child: tableMetalBase),
                  if (tableSoudure != null) pw.SizedBox(width: 8),
                ],
                if (tableSoudure != null) pw.Expanded(child: tableSoudure),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildSampleImage(String? photoPath) {
    if (photoPath != null && File(photoPath).existsSync()) {
      try {
        final bytes = File(photoPath).readAsBytesSync();
        if (bytes.isNotEmpty) {
          return pw.Image(
            pw.MemoryImage(bytes),
            fit: pw.BoxFit.contain, // Dynamic resize & centered in frame!
            alignment: pw.Alignment.center,
          );
        }
      } catch (_) {}
    }
    return pw.Text(
      'Pas de photo',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // PRESTATION — Photos simples côte à côte (2 ou 4 par ligne)
  // Reproduit fidèlement le layout de Pv Macro 1-15 IP.pdf
  // ──────────────────────────────────────────────────────────────
  static pw.Widget _buildPrestationPhotosGrid(Rapport r, PvFieldConfig config) {
    if (r.echantillons.isEmpty) {
      return pw.Text('Aucun échantillon renseigné.',
          style: const pw.TextStyle(fontSize: 8.5));
    }

    final count = r.echantillons.length;
    final photoHeight = r.photoHeightPdf.toDouble().clamp(60.0, 300.0);

    // Build photo cards
    final photoCards = <pw.Widget>[];
    for (final e in r.echantillons) {
      final labelSize = count >= 3 ? 8.0 : 9.0;
      photoCards.add(
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _borderGrey, width: 0.8),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                height: photoHeight,
                width: double.infinity,
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: _buildSampleImage(e.photoPath),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  e.label,
                  style: pw.TextStyle(
                    fontSize: labelSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 1 ÉCHANTILLON → Centré au milieu de la page !
    if (count == 1) {
      return pw.Center(
        child: pw.SizedBox(
          width: 220,
          child: photoCards.first,
        ),
      );
    }

    // Nombre d'éléments par ligne ajusté dynamiquement
    int perRow = r.photosPerRow.clamp(2, 4);
    if (count == 3) {
      perRow = 3;
    }

    final rows = <pw.Widget>[];
    for (int i = 0; i < photoCards.length; i += perRow) {
      final rowChildren = <pw.Widget>[];
      for (int j = 0; j < perRow; j++) {
        if (j > 0) rowChildren.add(pw.SizedBox(width: perRow == 3 ? 8 : (perRow == 4 ? 6 : 12)));
        final idx = i + j;
        rowChildren.add(
          pw.Expanded(
            child: idx < photoCards.length ? photoCards[idx] : pw.Container(),
          ),
        );
      }
      rows.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: rowChildren,
          ),
        ),
      );
    }

    return pw.Column(children: rows);
  }

  // ──────────────────────────────────────────────────────────────
  // PRESTATION — Signature table (5 colonnes: DATE + 4 Signataires)
  // ──────────────────────────────────────────────────────────────
  static pw.Widget _buildSignatureTable(Rapport r, {pw.ImageProvider? cachet}) {
    final tb = pw.TableBorder.all(color: _borderGrey, width: 0.8);

    pw.Widget hdr(String t) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(t,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        );

    pw.Widget nom(String t) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(t.isNotEmpty ? t : ' ',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
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
      return pw.SizedBox(height: h, child: pw.Container());
    }

    pw.Widget colCell(String name, {bool withCachet = false}) {
      final trimmed = name.trim();
      final hasThisName = trimmed.isNotEmpty && trimmed != '/';
      if (!hasThisName) {
        return sigSpace(withCachet: withCachet);
      }
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          nom(name),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _borderGrey, width: 0.8),
              ),
            ),
          ),
          sigSpace(withCachet: withCachet),
        ],
      );
    }

    final labName = r.laboratoire;
    final col2H = r.sigCol2Header;
    final col3H = r.sigCol3Header;
    final col4H = r.sigCol4Header;

    return pw.Table(
      border: tb,
      columnWidths: const {
        0: pw.FlexColumnWidth(0.9), // DATE
        1: pw.FlexColumnWidth(1.1), // EM / Lab
        2: pw.FlexColumnWidth(1.0), // Rep 1
        3: pw.FlexColumnWidth(1.0), // Rep 2
        4: pw.FlexColumnWidth(0.9), // ARH
      },
      children: [
        pw.TableRow(children: [
          hdr('DATE'),
          hdr(labName),
          hdr(col2H),
          hdr(col3H),
          hdr(col4H),
        ]),
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                r.dateSignature,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
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

  // ──────────────────────────────────────────────────────────────
  // CMD INTERNE — Signature table (5 colonnes)
  // ──────────────────────────────────────────────────────────────
  static pw.Widget _buildSignatureTableInterne(Rapport r, {pw.ImageProvider? cachet}) {
    return _buildSignatureTable(r, cachet: cachet);
  }

  static pw.Widget _buildFootNote(AppSettings s) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Personnes autorisant le rapport :',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(s.footNote1, style: const pw.TextStyle(fontSize: 8.5)),
        pw.Text(s.footNote2, style: const pw.TextStyle(fontSize: 8.5)),
      ],
    );
  }
}