import 'dart:io';
import 'dart:typed_data';

import '../models/app_settings.dart';
import '../models/rapport.dart';
import 'pdf_service.dart';

class PdfServiceInterne {
  /// Génère le PDF de Commande Interne sur 1 SEULE PAGE A4 en utilisant le format officiel.
  static Future<File> generateRapportPdf(
    Rapport r, {
    required AppSettings settings,
  }) async {
    return PdfService.generateRapportPdf(r, settings: settings);
  }

  /// Retourne les bytes du PDF sans écrire sur disque (pour l'aperçu en-app).
  static Future<Uint8List> generateRapportBytes(
    Rapport r, {
    required AppSettings settings,
  }) async {
    final file = await generateRapportPdf(r, settings: settings);
    return file.readAsBytesSync();
  }
}
