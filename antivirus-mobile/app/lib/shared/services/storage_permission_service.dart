import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:antivirus_mobile/shared/services/local_quarantine_service.dart';
import 'package:antivirus_mobile/shared/widgets/manage_storage_permission_dialog.dart';

class StoragePermissionService {
  /// Meminta & Memeriksa Izin Akses Semua File (MANAGE_EXTERNAL_STORAGE)
  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    try {
      // 0. Minta Izin Notifikasi Sistem (Android 13+)
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // 1. Cek MANAGE_EXTERNAL_STORAGE via Native Kotlin & permission_handler
      final isNativeGranted = await LocalQuarantineService.checkNativeManageStoragePermission();
      if (isNativeGranted) {
        return true;
      }

      if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) {
        return true;
      }

      // 2. Tampilkan Modal Dialog Petunjuk Pengaturan HANYA jika belum diizinkan
      if (context.mounted) {
        await ManageStoragePermissionDialog.show(context);
      }
    } catch (_) {}

    return await LocalQuarantineService.checkNativeManageStoragePermission();
  }
}
