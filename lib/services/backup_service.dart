import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/app_settings.dart';
import '../models/echantillon.dart';
import '../models/pv_config.dart';
import '../models/rapport.dart';
import 'settings_service.dart';

class BackupResult {
  final bool success;
  final int countRapports;
  final int countEchantillons;
  final int countPhotos;
  final String? message;
  final String? filePath;

  BackupResult({
    required this.success,
    this.countRapports = 0,
    this.countEchantillons = 0,
    this.countPhotos = 0,
    this.message,
    this.filePath,
  });
}

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  /// Génère une sauvegarde complète (Database + Échantillons + Configurations + Photos + Paramètres) au format JSON.
  Future<BackupResult> createBackupAndShare() async {
    try {
      final db = DatabaseHelper.instance;
      final rapports = await db.getAllRapports();
      final settings = await SettingsService.instance.getSettings();
      final pvConfigInterne = await SettingsService.instance.getPvConfigInterne();
      final pvConfigPrestation = await SettingsService.instance.getPvConfigPrestation();

      int countEchantillons = 0;
      int countPhotos = 0;
      final Map<String, String> base64Photos = {};

      final appDir = await getApplicationDocumentsDirectory();

      for (final r in rapports) {
        countEchantillons += r.echantillons.length;
        for (final e in r.echantillons) {
          if (e.photoPath != null && e.photoPath!.isNotEmpty) {
            final photoFile = File(e.photoPath!);
            if (photoFile.existsSync()) {
              try {
                final bytes = photoFile.readAsBytesSync();
                if (bytes.isNotEmpty) {
                  final key = p.basename(e.photoPath!);
                  if (!base64Photos.containsKey(key)) {
                    base64Photos[key] = base64Encode(bytes);
                    countPhotos++;
                  }
                }
              } catch (_) {}
            }
          }
          if (e.rawPhotoPath != null && e.rawPhotoPath!.isNotEmpty) {
            final rawFile = File(e.rawPhotoPath!);
            if (rawFile.existsSync()) {
              try {
                final bytes = rawFile.readAsBytesSync();
                if (bytes.isNotEmpty) {
                  final key = p.basename(e.rawPhotoPath!);
                  if (!base64Photos.containsKey(key)) {
                    base64Photos[key] = base64Encode(bytes);
                    countPhotos++;
                  }
                }
              } catch (_) {}
            }
          }
        }
      }

      // Encoder aussi le logo de l'application s'il existe
      if (settings.logoPath != null && File(settings.logoPath!).existsSync()) {
        try {
          final logoBytes = File(settings.logoPath!).readAsBytesSync();
          if (logoBytes.isNotEmpty) {
            base64Photos['__app_logo.png'] = base64Encode(logoBytes);
          }
        } catch (_) {}
      }

      // Encoder aussi les cachets s'ils existent (jusqu'à 3)
      for (int i = 1; i <= 3; i++) {
        final path = i == 1
            ? settings.cachet1Path
            : (i == 2 ? settings.cachet2Path : settings.cachet3Path);
        if (path != null && File(path).existsSync()) {
          try {
            final cachetBytes = File(path).readAsBytesSync();
            if (cachetBytes.isNotEmpty) {
              base64Photos['__app_cachet$i.png'] = base64Encode(cachetBytes);
            }
          } catch (_) {}
        }
      }

      final backupData = {
        'version': 2,
        'appName': 'Macrographique',
        'exportDate': DateTime.now().toIso8601String(),
        'settings': settings.toMap(),
        'pvConfigInterne': pvConfigInterne.toMap(),
        'pvConfigPrestation': pvConfigPrestation.toMap(),
        'rapports': rapports.map((r) => r.toMapWithEchantillons()).toList(),
        'photos': base64Photos,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
      final timestamp = DateFormat('dd-MM-yyyy_HHmm').format(DateTime.now());
      final defaultFileName = 'Backup_Macrographique_$timestamp.json';

      String? finalFilePath;

      // Sur Windows / Desktop : proposer à l'utilisateur de choisir où sauvegarder
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        try {
          final chosenPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Enregistrer le fichier de sauvegarde JSON',
            fileName: defaultFileName,
            type: FileType.custom,
            allowedExtensions: ['json'],
          );
          if (chosenPath != null && chosenPath.isNotEmpty) {
            final file = File(chosenPath);
            await file.writeAsString(jsonStr, flush: true);
            finalFilePath = file.path;
          }
        } catch (_) {}
      }

      // Si l'utilisateur n'a pas sélectionné un chemin ou sur mobile
      if (finalFilePath == null) {
        final fallbackFile = File(p.join(appDir.path, defaultFileName));
        await fallbackFile.writeAsString(jsonStr, flush: true);
        finalFilePath = fallbackFile.path;

        try {
          await Share.shareXFiles(
            [XFile(fallbackFile.path)],
            text: '💾 Sauvegarde complète Macrographique ($timestamp)',
            subject: 'Sauvegarde Macrographique $timestamp',
          );
        } catch (_) {}
      }

      return BackupResult(
        success: true,
        countRapports: rapports.length,
        countEchantillons: countEchantillons,
        countPhotos: countPhotos,
        filePath: finalFilePath,
        message: 'Sauvegarde exportée avec succès !\n(${rapports.length} PVs, $countEchantillons échantillons, $countPhotos photos)',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Erreur lors de la création de la sauvegarde : $e',
      );
    }
  }

  /// Restaure une sauvegarde à partir d'un fichier JSON sélectionné par l'utilisateur.
  Future<BackupResult> importBackupFromFile() async {
    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'bak'],
        allowMultiple: false,
      );

      if (pickerResult == null || pickerResult.files.isEmpty) {
        return BackupResult(
          success: false,
          message: 'Aucun fichier sélectionné.',
        );
      }

      final selectedPath = pickerResult.files.single.path;
      if (selectedPath == null) {
        return BackupResult(
          success: false,
          message: 'Impossible d\'accéder au fichier sélectionné.',
        );
      }

      final file = File(selectedPath);
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);

      if (data['appName'] != 'Macrographique' && !data.containsKey('rapports')) {
        return BackupResult(
          success: false,
          message: 'Format de fichier de sauvegarde invalide.',
        );
      }

      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'macro_photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      // 1. Restauration des photos physiques
      final photosMap = Map<String, dynamic>.from(data['photos'] ?? {});
      final restoredPhotoPaths = <String, String>{}; // oldBasename -> newPath

      int restoredPhotosCount = 0;
      photosMap.forEach((filename, base64Str) {
        try {
          final bytes = base64Decode(base64Str.toString());
          if (bytes.isNotEmpty) {
            final destFile = File(p.join(photosDir.path, filename));
            destFile.writeAsBytesSync(bytes, flush: true);
            restoredPhotoPaths[filename] = destFile.path;
            restoredPhotosCount++;
          }
        } catch (_) {}
      });

      // 2. Restauration des paramètres généraux (Settings)
      if (data.containsKey('settings') && data['settings'] is Map) {
        final settingsMap = Map<String, dynamic>.from(data['settings']);
        if (restoredPhotoPaths.containsKey('__app_logo.png')) {
          settingsMap['logoPath'] = restoredPhotoPaths['__app_logo.png'];
        }
        if (restoredPhotoPaths.containsKey('__app_cachet1.png')) {
          settingsMap['cachet1Path'] = restoredPhotoPaths['__app_cachet1.png'];
        } else if (restoredPhotoPaths.containsKey('__app_cachet.png')) {
          settingsMap['cachet1Path'] = restoredPhotoPaths['__app_cachet.png'];
        }
        if (restoredPhotoPaths.containsKey('__app_cachet2.png')) {
          settingsMap['cachet2Path'] = restoredPhotoPaths['__app_cachet2.png'];
        }
        if (restoredPhotoPaths.containsKey('__app_cachet3.png')) {
          settingsMap['cachet3Path'] = restoredPhotoPaths['__app_cachet3.png'];
        }
        final newSettings = AppSettings.fromMap(settingsMap);
        await SettingsService.instance.saveSettings(newSettings);
      }

      // 3. Restauration des configurations PV (Champs Interne & Prestation)
      if (data.containsKey('pvConfigInterne') && data['pvConfigInterne'] is Map) {
        try {
          final map = Map<String, String?>.from(data['pvConfigInterne']);
          final cfg = PvFieldConfig.fromMap(map);
          await SettingsService.instance.savePvConfigInterne(cfg);
        } catch (_) {}
      }
      if (data.containsKey('pvConfigPrestation') && data['pvConfigPrestation'] is Map) {
        try {
          final map = Map<String, String?>.from(data['pvConfigPrestation']);
          final cfg = PvFieldConfig.fromMap(map);
          await SettingsService.instance.savePvConfigPrestation(cfg);
        } catch (_) {}
      }

      // 4. Restauration des Rapports & de tous les Échantillons
      final rapportsList = List<Map<String, dynamic>>.from(data['rapports'] ?? []);
      int restoredRapportsCount = 0;
      int restoredEchantillonsCount = 0;

      final db = DatabaseHelper.instance;

      for (final rMap in rapportsList) {
        final rawEchantillons = List<Map<String, dynamic>>.from(rMap['echantillons'] ?? []);
        
        final restoredEchantillons = <Echantillon>[];
        for (final eMap in rawEchantillons) {
          final updatedEMap = Map<String, dynamic>.from(eMap);
          final photoPath = updatedEMap['photo_path'] as String?;
          if (photoPath != null && photoPath.isNotEmpty) {
            final baseName = p.basename(photoPath);
            if (restoredPhotoPaths.containsKey(baseName)) {
              updatedEMap['photo_path'] = restoredPhotoPaths[baseName];
            }
          }
          final rawPhotoPath = updatedEMap['raw_photo_path'] as String?;
          if (rawPhotoPath != null && rawPhotoPath.isNotEmpty) {
            final baseName = p.basename(rawPhotoPath);
            if (restoredPhotoPaths.containsKey(baseName)) {
              updatedEMap['raw_photo_path'] = restoredPhotoPaths[baseName];
            }
          }
          restoredEchantillons.add(Echantillon.fromMap(updatedEMap));
        }

        // Formater le rapport pour la ré-insertion SQL avec ses vrais échantillons
        final r = Rapport.fromMap(rMap, echantillons: restoredEchantillons);
        
        // Insérer ou mettre à jour le PV
        final existingRapport = await db.getRapportById(r.id ?? -1);
        if (existingRapport != null) {
          await db.updateRapport(r);
        } else {
          final newMap = Map<String, dynamic>.from(rMap);
          newMap.remove('id');
          await db.insertRapport(Rapport.fromMap(newMap, echantillons: restoredEchantillons));
        }

        restoredRapportsCount++;
        restoredEchantillonsCount += restoredEchantillons.length;
      }

      return BackupResult(
        success: true,
        countRapports: restoredRapportsCount,
        countEchantillons: restoredEchantillonsCount,
        countPhotos: restoredPhotosCount,
        message: 'Restauration réussie !\n($restoredRapportsCount PVs, $restoredEchantillonsCount échantillons, $restoredPhotosCount photos restaurés)',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Erreur lors de la restauration : $e',
      );
    }
  }
}

