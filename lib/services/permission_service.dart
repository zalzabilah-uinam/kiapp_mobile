import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Cek & minta izin akses penyimpanan sesuai versi Android.
///
/// - Android 13+ (API 33+): pake [Permission.manageExternalStorage] buat SAF,
///   fallback [Permission.storage] kalo gak dapet.
/// - Android 10-12 (API 29-32): [Permission.storage].
/// - Android <10 (API <29): [Permission.storage].
/// - iOS: skip.
Future<bool> requestStoragePermission() async {
  // Cuma Android yg perlu permission storage
  if (!Platform.isAndroid) return true;

  // Android 11+ (API 30+): butuh MANAGE_EXTERNAL_STORAGE kalo mau akses folder bebas
  // Tapi SAF (file_picker.getDirectoryPath) gak butuh permission khusus,
  // karena SAF pake system picker. Ini buat jaga-jaga aja.
  if (await Permission.manageExternalStorage.isGranted) return true;

  // Coba minta manageExternalStorage (khusus Android 11+)
  var status = await Permission.manageExternalStorage.request();
  if (status.isGranted) return true;

  // Fallback: storage biasa
  status = await Permission.storage.request();
  if (status.isGranted) return true;

  // Android 13+ granular
  if (await Permission.photos.isGranted || await Permission.videos.isGranted) {
    return true;
  }

  // Minta sekaligus
  final photos = await Permission.photos.request();
  final videos = await Permission.videos.request();
  if (photos.isGranted || videos.isGranted) return true;

  final audio = await Permission.audio.request();
  if (audio.isGranted) return true;

  return false;
}

/// Cek status permission, return [PermissionStatus].
Future<PermissionStatus> checkStoragePermission() async {
  if (!Platform.isAndroid) return PermissionStatus.granted;

  if (await Permission.manageExternalStorage.isGranted) {
    return PermissionStatus.granted;
  }

  final storage = await Permission.storage.status;
  if (storage.isGranted) return PermissionStatus.granted;

  // Android 13+
  if (await Permission.photos.isGranted ||
      await Permission.videos.isGranted ||
      await Permission.audio.isGranted) {
    return PermissionStatus.granted;
  }

  return storage;
}

/// Tampilkan dialog permission dengan penjelasan kenapa butuh akses.
Future<bool> showPermissionDialog(BuildContext context) async {
  final granted = await requestStoragePermission();
  if (granted) return true;

  if (!context.mounted) return false;

  final shouldOpenSettings = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Izin Penyimpanan Diperlukan',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: const Text(
        'Aplikasi perlu akses penyimpanan untuk menyimpan file download '
        'dan memilih folder tujuan. '
        'Silakan berikan izin di Pengaturan > Aplikasi.',
        style: TextStyle(color: Color(0xFFB0B0C8), fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal',
              style: TextStyle(color: Color(0xFF8888A0))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Buka Pengaturan',
              style: TextStyle(color: Color(0xFF6C63FF))),
        ),
      ],
    ),
  );

  if (shouldOpenSettings == true) {
    await openAppSettings();
    return await requestStoragePermission();
  }

  return false;
}
