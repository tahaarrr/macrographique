import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../theme/app_theme.dart';

class BackupDialog {
  static Future<void> show(BuildContext context, {VoidCallback? onRestored}) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sync_rounded, color: AppTheme.primaryNavy, size: 22),
                SizedBox(width: 8),
                Text(
                  'Sauvegarde & Restauration des Données',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Exportez ou importez vos données (clients, PVs macrographiques et configurations) pour la sauvegarde ou le transfert.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Création de la sauvegarde en cours…'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      final res = await BackupService.instance.createBackupAndShare();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message ?? (res.success ? 'Sauvegarde effectuée !' : 'Échec de la sauvegarde.')),
                            backgroundColor: res.success ? AppTheme.accentTeal : Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.file_upload_outlined, size: 20),
                    label: const Text('Exporter (.json)', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
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
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Annuler'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                              child: const Text('Sélectionner le fichier'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final res = await BackupService.instance.importBackupFromFile();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message ?? (res.success ? 'Restauration réussie !' : 'Échec de l\'importation.')),
                              backgroundColor: res.success ? AppTheme.accentTeal : Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          if (res.success) {
                            onRestored?.call();
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.file_download_outlined, size: 20, color: AppTheme.accentTeal),
                    label: const Text('Importer (.json)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
