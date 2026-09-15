import 'dart:io';
import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/activity/data/local/activity_store.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';
import 'package:antivirus_mobile/features/activity/presentation/widgets/activity_filter_pills.dart';
import 'package:antivirus_mobile/features/activity/presentation/widgets/quarantine_item_card.dart';
import 'package:antivirus_mobile/features/activity/presentation/widgets/file_detail_bottom_sheet.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';

import 'package:antivirus_mobile/shared/services/local_quarantine_service.dart';
import 'package:antivirus_mobile/features/scan/data/local/local_heuristic_engine.dart';
import 'package:antivirus_mobile/features/scan/data/remote/threat_verifier_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _selectedCategoryKey = 'filter_all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ActivityStore.loadFromDisk();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFileDetailBottomSheet(ActivityLogItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FileDetailBottomSheet(
        item: item,
        onQuarantineSelected: (selectedFiles) {
          _quarantineSelectedFiles(item, selectedFiles);
        },
        onDeleteSelected: (selectedFiles) {
          _deleteSelectedFiles(item, selectedFiles);
        },
        onRestoreSelected: (selectedFiles) {
          _restoreSelectedFiles(item, selectedFiles);
        },
        onWhitelistSelected: (selectedFiles) {
          _whitelistSelectedFiles(item, selectedFiles);
        },
      ),
    );
  }

  void _quarantineSelectedFiles(ActivityLogItem item, List<QuarantinedFileDetail> selectedFiles) async {
    final now = DateTime.now();
    final quarantinedThreats = <QuarantinedFileDetail>[];

    for (final sf in selectedFiles) {
      String? qPath = sf.quarantinedPath;

      if (qPath != null && await File(qPath).exists()) {
        quarantinedThreats.add(
          QuarantinedFileDetail(
            fileName: sf.fileName,
            filePath: sf.filePath,
            quarantinedPath: qPath,
            threatType: 'Malware (Dikarantina Pengguna)',
            fileSize: sf.fileSize,
            isSafe: false,
          ),
        );
        continue;
      }

      final vaultPath = await LocalQuarantineService.findQuarantinedVaultPath(sf.fileName);
      if (vaultPath != null && await File(vaultPath).exists()) {
        quarantinedThreats.add(
          QuarantinedFileDetail(
            fileName: sf.fileName,
            filePath: sf.filePath,
            quarantinedPath: vaultPath,
            threatType: 'Malware (Dikarantina Pengguna)',
            fileSize: sf.fileSize,
            isSafe: false,
          ),
        );
        continue;
      }

      final origFile = File(sf.filePath);
      if (await origFile.exists()) {
        final newQPath = await LocalQuarantineService.quarantineFile(origFile);
        if (newQPath != null) {
          quarantinedThreats.add(
            QuarantinedFileDetail(
              fileName: sf.fileName,
              filePath: sf.filePath,
              quarantinedPath: newQPath,
              threatType: 'Malware (Dikarantina Pengguna)',
              fileSize: sf.fileSize,
              isSafe: false,
            ),
          );
        }
      }
    }

    ActivityStore.removeMultipleFilesFromLog(
      item.id,
      selectedFiles.map((sf) => sf.fileName).toList(),
    );

    if (quarantinedThreats.isNotEmpty) {
      final count = quarantinedThreats.length;
      final logId = 'log_${now.millisecondsSinceEpoch}';
      ActivityStore.addLog(
        ActivityLogItem(
          id: logId,
          title: 'Karantina Ancaman ($count File)',
          subtitle: '$count file terindikasi malware berhasil diisolasikan',
          time: 'Hari ini, ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}',
          category: 'Karantina',
          badgeText: '$count File Dikarantina',
          isQuarantined: true,
          files: quarantinedThreats,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedFiles.length} file berhasil dipindahkan ke Vault Karantina.'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _restoreSelectedFiles(ActivityLogItem item, List<QuarantinedFileDetail> selectedFiles) async {
    for (final sf in selectedFiles) {
      final qPath = sf.quarantinedPath ?? await LocalQuarantineService.findQuarantinedVaultPath(sf.fileName);
      if (qPath != null) {
        await LocalQuarantineService.restoreFile(qPath, sf.filePath);
      }
    }

    ActivityStore.removeMultipleFilesFromLog(
      item.id,
      selectedFiles.map((sf) => sf.fileName).toList(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedFiles.length} file berhasil dipulihkan ke lokasi asalnya.'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _deleteSelectedFiles(ActivityLogItem item, List<QuarantinedFileDetail> selectedFiles) async {
    for (final sf in selectedFiles) {
      final qPath = sf.quarantinedPath ?? await LocalQuarantineService.findQuarantinedVaultPath(sf.fileName);
      if (qPath != null) {
        await LocalQuarantineService.deletePermanently(qPath);
      }
      await LocalQuarantineService.deleteNativeFilePhysically(sf.filePath, sf.fileName);
    }

    ActivityStore.removeMultipleFilesFromLog(
      item.id,
      selectedFiles.map((sf) => sf.fileName).toList(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedFiles.length} file dihapus permanen dari perangkat.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _whitelistSelectedFiles(ActivityLogItem item, List<QuarantinedFileDetail> selectedFiles) async {
    final now = DateTime.now();
    final whitelistedFiles = <QuarantinedFileDetail>[];

    for (final sf in selectedFiles) {
      final qPath = sf.quarantinedPath ?? await LocalQuarantineService.findQuarantinedVaultPath(sf.fileName);
      if (qPath != null) {
        await LocalQuarantineService.restoreFile(qPath, sf.filePath);
      }
      LocalHeuristicEngine.addHashToWhitelist(sf.filePath);
      ThreatVerifierService().reportWhitelistToBackend(sf.filePath);
      whitelistedFiles.add(
        QuarantinedFileDetail(
          fileName: sf.fileName,
          filePath: sf.filePath,
          quarantinedPath: null,
          threatType: 'Aman (False Positive)',
          fileSize: sf.fileSize,
          isSafe: true,
        ),
      );
    }

    ActivityStore.removeMultipleFilesFromLog(
      item.id,
      selectedFiles.map((sf) => sf.fileName).toList(),
    );

    if (whitelistedFiles.isNotEmpty) {
      final count = whitelistedFiles.length;
      final logId = 'log_${now.millisecondsSinceEpoch}';
      ActivityStore.addLog(
        ActivityLogItem(
          id: logId,
          title: 'Whitelist File ($count File)',
          subtitle: '$count file ditandai aman & masuk daftar putih (False Positive)',
          time: 'Hari ini, ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}',
          category: 'Perlindungan',
          badgeText: '$count File Whitelist',
          isQuarantined: false,
          files: whitelistedFiles,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedFiles.length} file ditambahkan ke daftar putih (Aman - False Positive).'),
          backgroundColor: const Color(0xFF3B82F6),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showClearHistoryDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LanguageController.tr('clear_history_title'),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageController.tr('clear_history_desc'),
          style: TextStyle(
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              LanguageController.tr('btn_cancel'),
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ActivityStore.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(LanguageController.tr('clear_history_toast')),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: Text(
              LanguageController.tr('clear_history_btn'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final categoriesMap = {
      'filter_all': LanguageController.tr('filter_all'),
      'filter_threats': LanguageController.tr('filter_threats'),
      'filter_quarantine': LanguageController.tr('filter_quarantine'),
      'filter_whitelist': LanguageController.tr('filter_whitelist'),
      'filter_scan': LanguageController.tr('filter_scan'),
      'filter_protection': LanguageController.tr('filter_protection'),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 20 : 5),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF10B981).withAlpha(20) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: Color(0xFF10B981),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LanguageController.tr('activity_title'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            LanguageController.tr('activity_desc'),
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<List<ActivityLogItem>>(
                      valueListenable: ActivityStore.logsNotifier,
                      builder: (context, logs, _) {
                        if (logs.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          onPressed: _showClearHistoryDialog,
                          tooltip: LanguageController.tr('clear_history_btn'),
                          icon: Icon(
                            Icons.delete_sweep_outlined,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            size: 22,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar Input
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: LanguageController.tr('search_activity_placeholder'),
                    hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: subTextColor, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Filter Category Pills
              ActivityFilterPills(
                categories: categoriesMap.values.toList(),
                selectedCategory: categoriesMap[_selectedCategoryKey] ?? LanguageController.tr('filter_all'),
                onCategorySelected: (catLabel) {
                  final matchedEntry = categoriesMap.entries.firstWhere(
                    (entry) => entry.value == catLabel,
                    orElse: () => const MapEntry('filter_all', 'Semua'),
                  );
                  setState(() {
                    _selectedCategoryKey = matchedEntry.key;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Activity Log List using ValueListenableBuilder
              ValueListenableBuilder<List<ActivityLogItem>>(
                valueListenable: ActivityStore.logsNotifier,
                builder: (context, logs, _) {
                  final categoryFiltered = _selectedCategoryKey == 'filter_all'
                      ? logs
                      : logs.where((item) {
                          if (_selectedCategoryKey == 'filter_threats') return item.category == 'Ancaman' || item.files.any((f) => !f.isSafe);
                          if (_selectedCategoryKey == 'filter_quarantine') return item.category == 'Karantina' || item.isQuarantined;
                          if (_selectedCategoryKey == 'filter_whitelist') return item.category == 'Whitelist' || item.title.contains('Whitelist') || item.files.any((f) => f.isSafe || f.threatType.contains('Aman'));
                          if (_selectedCategoryKey == 'filter_scan') return item.category == 'Pemindaian';
                          if (_selectedCategoryKey == 'filter_protection') return item.category == 'Perlindungan';
                          return true;
                        }).toList();

                  final filteredLogs = _searchQuery.isEmpty
                      ? categoryFiltered
                      : categoryFiltered.where((item) {
                          final matchesTitle = item.title.toLowerCase().contains(_searchQuery);
                          final matchesSubtitle = item.subtitle.toLowerCase().contains(_searchQuery);
                          final matchesCategory = item.category.toLowerCase().contains(_searchQuery);
                          final matchesFiles = item.files.any((f) =>
                              f.fileName.toLowerCase().contains(_searchQuery) ||
                              f.threatType.toLowerCase().contains(_searchQuery));
                          return matchesTitle || matchesSubtitle || matchesCategory || matchesFiles;
                        }).toList();

                  if (filteredLogs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Color(0xFF10B981),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            LanguageController.tr('quarantine_empty'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            LanguageController.tr('quarantine_empty_desc'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredLogs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filteredLogs[index];
                      return QuarantineItemCard(
                        item: item,
                        onTap: () {
                          if (item.files.isNotEmpty) {
                            _openFileDetailBottomSheet(item);
                          }
                        },
                        onQuarantinePressed: () {
                          final unresolved = item.files.where((f) => !f.isSafe).toList();
                          _quarantineSelectedFiles(item, unresolved.isNotEmpty ? unresolved : item.files);
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
