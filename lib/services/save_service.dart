import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:animal_warfare/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/local_auth_service.dart';

class SaveService {
  static Future<void> exportSaveData(
    BuildContext context,
    UserData currentUser,
    Function(bool) setLoading,
  ) async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'EXPORT OPTIONS',
          style: TextStyle(
            color: AppColors.highlight,
            fontFamily: 'PressStart2P',
            fontSize: 12,
          ),
        ),
        content: Text(
          'How would you like to save your data?',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'overwrite'),
            child: Text(
              'Overwrite Old',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'date'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save with Date',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    setLoading(true);
    try {
      Directory? downloadDir;

      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getExternalStorageDirectory();
        }
      } else {
        downloadDir = await getDownloadsDirectory();
      }

      if (downloadDir != null) {
        final String username = currentUser.username;
        String fileName = '';
        File? file;

        if (choice == 'date') {
          final now = DateTime.now();
          final dateSuffix =
              '_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
          fileName = 'animal_warfare_save_$username$dateSuffix.json';
          file = File('${downloadDir.path}/$fileName');
        } else {
          // choice == 'overwrite'
          fileName = 'animal_warfare_save_$username.json';
          file = File('${downloadDir.path}/$fileName');

          if (await file.exists()) {
            try {
              // Attempt to delete it first to avoid EEXIST / EACCES issues if we own the file.
              await file.delete();
            } catch (e) {
              // If we cannot delete it, it might be owned by another install instance (Android Scoped Storage).
              // In this case, we cannot overwrite it. Fallback to a timestamped file.
              final now = DateTime.now();
              final dateSuffix =
                  '_fallback_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
              fileName = 'animal_warfare_save_$username$dateSuffix.json';
              file = File('${downloadDir.path}/$fileName');
            }
          }
        }

        final String jsonData = jsonEncode(currentUser.toJson());
        await file.writeAsString(jsonData);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to Downloads/$fileName')),
          );
        }
      } else {
        throw Exception('Could not find Downloads directory');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      setLoading(false);
    }
  }
}
