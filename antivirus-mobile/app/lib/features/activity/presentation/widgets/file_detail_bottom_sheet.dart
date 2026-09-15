import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';

class FileDetailBottomSheet extends StatefulWidget {
  final ActivityLogItem item;
  final Function(List<QuarantinedFileDetail> selectedFiles) onDeleteSelected;
  final Function(List<QuarantinedFileDetail> selectedFiles) onRestoreSelected;
  final Function(List<QuarantinedFileDetail> selectedFiles) onWhitelistSelected;
  final Function(List<QuarantinedFileDetail> selectedFiles)? onQuarantineSelected;

  const FileDetailBottomSheet({
    super.key,
    required this.item,
    required this.onDeleteSelected,
    required this.onRestoreSelected,
    required this.onWhitelistSelected,
    this.onQuarantineSelected,
  });

  @override
  State<FileDetailBottomSheet> createState() => _FileDetailBottomSheetState();
}

class _FileDetailBottomSheetState extends State<FileDetailBottomSheet> {
  late Set<int> _selectedIndices;

  @override
  void initState() {
    super.initState();
    // Initially select all files in the item
    _selectedIndices = Set.from(
      List.generate(widget.item.files.length, (index) => index),
    );
  }

  List<QuarantinedFileDetail> get _selectedFiles {
    if (widget.item.files.isEmpty) {
      return [
        QuarantinedFileDetail(
          fileName: widget.item.title,
          filePath: widget.item.mainFilePath,
          threatType: widget.item.mainThreatType,
          fileSize: widget.item.mainFileSize,
        )
      ];
    }

    if (widget.item.files.length == 1) {
      return widget.item.files;
    }

    final selected = _selectedIndices
        .where((i) => i < widget.item.files.length)
        .map((i) => widget.item.files[i])
        .toList();

    return selected.isNotEmpty ? selected : widget.item.files;
  }

  bool get _allSelected =>
      widget.item.files.isNotEmpty &&
      _selectedIndices.length == widget.item.files.length;

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIndices.clear();
      } else {
        _selectedIndices = Set.from(
          List.generate(widget.item.files.length, (index) => index),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMultiFile = widget.item.files.length > 1;
    final selectedCount = _selectedFiles.length;
    final hasSelection = selectedCount > 0;
    final hasActiveThreats = widget.item.isQuarantined ||
        widget.item.category == 'Ancaman' ||
        (widget.item.files.isNotEmpty && widget.item.files.any((f) => !f.isSafe));
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title & Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFD97706).withAlpha(30) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: const Icon(
                  Icons.gavel_outlined,
                  color: Color(0xFFD97706),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMultiFile
                          ? 'Status: $selectedCount dari ${widget.item.totalFiles} File Dipilih'
                          : 'Status: ${widget.item.subtitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Informational Alert Banner for Multi-Selection (Only for multi-file items)
          if (isMultiFile) ...[
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A).withAlpha(40) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist_rtl_rounded,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pilih satu atau beberapa file dengan centang kotak, lalu lakukan aksi Whitelist atau Pulihkan secara bersamaan.',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Content Box: Multi-file list OR Single file details
          Flexible(
            child: SingleChildScrollView(
              child: isMultiFile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // List Header + Select All Checkbox
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Daftar File (${widget.item.totalFiles} Item):',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _toggleSelectAll,
                              borderRadius: BorderRadius.circular(6.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _allSelected
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank_rounded,
                                      color: _allSelected
                                          ? const Color(0xFF10B981)
                                          : subTextColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _allSelected ? 'Batal Semua' : LanguageController.tr('btn_select_all'),
                                      style: TextStyle(
                                        color: _allSelected
                                            ? const Color(0xFF10B981)
                                            : subTextColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.item.files.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final file = widget.item.files[index];
                            final isSelected = _selectedIndices.contains(index);
                            return _buildFileItemCard(isDark, file, index + 1, isSelected, () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIndices.remove(index);
                                } else {
                                  _selectedIndices.add(index);
                                }
                              });
                            });
                          },
                        ),
                      ],
                    )
                  : _buildSingleFileDetailsBox(isDark),
            ),
          ),
          const SizedBox(height: 20),

          if (!hasActiveThreats) ...[
            // ITEM AMAN / TER-WHITELIST / BERSIH: HANYA PESAN & TOMBOL SELESAI
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF10B981).withAlpha(20) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                  color: isDark ? const Color(0xFF10B981) : const Color(0xFF86EFAC),
                  width: 1.0,
                ),
              ),
              child: Text(
                widget.item.title.contains('Dibatalkan')
                    ? 'Pemindaian dihentikan oleh pengguna. Seluruh berkas yang sempat terperiksa terdeteksi aman.'
                    : (widget.item.category == 'Perlindungan'
                        ? 'File telah ditandai aman & dipulihkan ke daftar putih (Whitelist).'
                        : 'File terverifikasi aman. Tidak ada tindakan keamanan yang diperlukan.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                child: Text(
                  LanguageController.tr('btn_done'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ] else ...[
            // ITEM DENGAN ANCAMAN AKTIF: ACTION BUTTONS (KARANTINA/PULIHKAN, HAPUS, WHITELIST)
            if (!widget.item.isQuarantined && widget.onQuarantineSelected != null) ...[
              // 1. Primary Action Button for New Threats: Karantina (Isolasi)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: hasSelection
                      ? () {
                          Navigator.pop(context);
                          widget.onQuarantineSelected!(_selectedFiles);
                        }
                      : null,
                  icon: const Icon(Icons.gavel_outlined, size: 20, color: Colors.white),
                  label: Text(
                    isMultiFile ? 'Karantina / Isolasi ($selectedCount File)' : 'Karantina / Isolasi Berkas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else if (widget.item.isQuarantined) ...[
              // 1. Primary Action Button for Quarantined Vault Items: Pulihkan (Restore)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: hasSelection
                      ? () {
                          Navigator.pop(context);
                          widget.onRestoreSelected(_selectedFiles);
                        }
                      : null,
                  icon: const Icon(Icons.restore_page_outlined, size: 20, color: Colors.white),
                  label: Text(
                    isMultiFile ? 'Pulihkan Berkas ($selectedCount File)' : 'Pulihkan Berkas Ke Lokasi Asal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 2. Secondary Action Button: Hapus Permanen (Outlined Red)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: hasSelection
                    ? () {
                        Navigator.pop(context);
                        widget.onDeleteSelected(_selectedFiles);
                      }
                    : null,
                icon: const Icon(Icons.delete_forever_outlined, size: 20, color: Colors.redAccent),
                label: Text(
                  isMultiFile ? 'Hapus Permanen ($selectedCount File)' : 'Hapus Permanen Berkas',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 3. Tertiary Action Button: Whitelist (Izinkan - Subtle Outlined)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: hasSelection
                    ? () {
                        Navigator.pop(context);
                        widget.onWhitelistSelected(_selectedFiles);
                      }
                    : null,
                icon: Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                label: Text(
                  isMultiFile ? 'Whitelist & Tandai Aman ($selectedCount File)' : 'Whitelist & Tandai Aman Berkas',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSingleFileDetailsBox(bool isDark) {
    final file = widget.item.files.isNotEmpty ? widget.item.files.first : null;
    final isSafe = file?.isSafe ?? false;
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final statusText = file?.threatType == 'Aman (False Positive)'
        ? 'Aman (False Positive)'
        : (isSafe ? 'Aman' : file?.threatType ?? 'Terindikasi Malware');

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            isDark,
            'Indikasi Sistem:',
            statusText,
            isBold: true,
            valueColor: isSafe ? const Color(0xFF10B981) : Colors.redAccent,
          ),
          Divider(height: 16, color: dividerColor),
          _buildDetailRow(isDark, 'Lokasi File:', file?.filePath ?? widget.item.mainFilePath),
          Divider(height: 16, color: dividerColor),
          _buildDetailRow(isDark, 'Ukuran File:', file?.fileSize ?? widget.item.mainFileSize),
          Divider(height: 16, color: dividerColor),
          _buildDetailRow(isDark, 'Waktu Karantina:', widget.item.time),
        ],
      ),
    );
  }

  Widget _buildFileItemCard(
    bool isDark,
    QuarantinedFileDetail file,
    int index,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final isSafe = file.isSafe;

    final badgeText = file.threatType == 'Aman (False Positive)'
        ? 'Aman (False Positive)'
        : (isSafe ? 'Aman' : 'Terindikasi Malware');

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF0F172A) : (isSafe ? const Color(0xFFF8FAFC) : Colors.white)),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF334155) : (isSafe ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0))),
          width: isSelected ? 2.0 : 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.0),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Multi-select Checkbox indicator
                Icon(
                  isSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$index. ${file.fileName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: isSafe
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: isSafe
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jalur: ${file.filePath}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    bool isDark,
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
