import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:antivirus_mobile/config/api_config.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/subscription_screen.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';
import 'package:antivirus_mobile/features/auth/domain/auth_models.dart';
import 'package:antivirus_mobile/shared/services/device_id_service.dart';

class ConnectedDeviceItem {
  final String id;
  final String name;
  final String statusKey;
  final String? osVersion;
  final DateTime? lastActiveAt;
  final IconData icon;
  final bool isCurrent;

  const ConnectedDeviceItem({
    required this.id,
    required this.name,
    required this.statusKey,
    this.osVersion,
    this.lastActiveAt,
    required this.icon,
    this.isCurrent = false,
  });

  String getFormattedLastActive() {
    if (isCurrent) {
      return 'Aktif Saat Ini';
    }
    if (lastActiveAt == null) {
      return 'Terhubung di Cloud';
    }

    final diff = DateTime.now().difference(lastActiveAt!);
    if (diff.inMinutes < 5) {
      return 'Aktif saat ini';
    } else if (diff.inMinutes < 60) {
      return 'Aktif ${diff.inMinutes} mnt lalu';
    } else if (diff.inHours < 24) {
      return 'Aktif ${diff.inHours} jam lalu';
    } else {
      return 'Aktif ${diff.inDays} hari lalu';
    }
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _realDeviceId = 'Memuat ID Perangkat...';
  List<ConnectedDeviceItem> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadRealDeviceId();
  }

  Future<void> _loadRealDeviceId() async {
    final id = await DeviceIdService.getMotherboardDeviceId();
    final modelName = await DeviceIdService.getDeviceModelName();
    final currentOsVersion = await DeviceIdService.getDeviceOsVersion();

    List<ConnectedDeviceItem> loadedDevices = [
      ConnectedDeviceItem(
        id: id,
        name: modelName,
        statusKey: 'active_now',
        osVersion: currentOsVersion,
        icon: Icons.devices_rounded,
        isCurrent: true,
      ),
    ];

    if (UserSession.isLoggedIn && UserSession.accessToken != null) {
      try {
        const baseUrl = ApiConfig.baseUrl;
        final response = await http.get(
          Uri.parse('$baseUrl/devices'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${UserSession.accessToken}',
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final List<dynamic> listJson = jsonDecode(response.body);
          if (listJson.isNotEmpty) {
            loadedDevices = listJson.map((item) {
              final devId = item['device_id'] as String? ?? '';
              final rawDevName = item['device_name'] as String? ?? '';
              final rawOsVer = item['os_version'] as String? ?? '';
              final isCurrent = devId == id;
              final displayName = (rawDevName.isEmpty || rawDevName == 'Perangkat Terhubung') ? modelName : rawDevName;
              final rawLastActive = item['last_active_at'] as String?;
              DateTime? parsedLastActive;
              if (rawLastActive != null) {
                try {
                  parsedLastActive = DateTime.parse(rawLastActive);
                } catch (_) {}
              }

              final displayOsVer = (rawOsVer.isEmpty || rawOsVer == 'Android') ? (isCurrent ? currentOsVersion : rawOsVer) : rawOsVer;

              return ConnectedDeviceItem(
                id: devId,
                name: displayName,
                statusKey: isCurrent ? 'active_now' : 'active_now',
                osVersion: displayOsVer.isNotEmpty ? displayOsVer : null,
                lastActiveAt: parsedLastActive,
                icon: isCurrent ? Icons.devices_rounded : Icons.laptop_rounded,
                isCurrent: isCurrent,
              );
            }).toList();
          }
        }
      } catch (e) {
        debugPrint('⚠️ [DEVICES API] Failed to fetch device list: $e');
      }
    }

    if (mounted) {
      setState(() {
        _realDeviceId = id;
        _devices = loadedDevices;
      });
    }
  }

  void _showDeleteDeviceDialog(ConnectedDeviceItem device) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Row(
          children: [
            const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LanguageController.tr('delete_device_title'),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hapus akses untuk perangkat "${device.name}"?',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageController.tr('delete_device_desc'),
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              LanguageController.tr('btn_cancel'),
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (UserSession.isLoggedIn && UserSession.accessToken != null) {
                try {
                  const baseUrl = ApiConfig.baseUrl;
                  await http.delete(
                    Uri.parse('$baseUrl/devices/${device.id}'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${UserSession.accessToken}',
                    },
                  );
                } catch (e) {
                  debugPrint('⚠️ [DEVICES API] Failed to delete device: $e');
                }
              }

              if (mounted) {
                setState(() {
                  _devices.removeWhere((d) => d.id == device.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(LanguageController.tr('device_removed_toast')),
                    backgroundColor: Colors.redAccent,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: Text(
              LanguageController.tr('btn_remove_access'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              LanguageController.tr('logout_dialog_title'),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          LanguageController.tr('logout_dialog_desc'),
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              LanguageController.tr('btn_cancel'),
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              UserSession.logout();
              if (mounted) Navigator.pop(context); // Return to previous screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Anda telah berhasil keluar dari akun.'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: Text(
              LanguageController.tr('btn_logout'),
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
    final backgroundColor = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF161B26) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderTileColor = isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0);

    return ValueListenableBuilder<String>(
      valueListenable: LanguageController.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: cardBgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              LanguageController.tr('account_title'),
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: borderTileColor),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageController.tr('account_detail_title'),
                      style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LanguageController.tr('account_detail_desc'),
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 18),

                    // USER PROFILE HERO HEADER CARD (APPLE/iOS MINIMALIST STYLE)
                    ValueListenableBuilder<UserModel?>(
                      valueListenable: UserSession.currentUserNotifier,
                      builder: (context, user, _) {
                        final displayName = user?.username.isNotEmpty == true ? user!.username : 'Pengguna Mangodefend';
                        final displayEmail = user?.email.isNotEmpty == true ? user!.email : 'user@mangodefend.com';
                        final initials = displayName.trim().isNotEmpty
                            ? displayName.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase()
                            : 'MD';
                        final planBadgeText = UserSession.isLoggedIn ? 'Free Plan' : 'Guest';

                        return Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(color: borderTileColor, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(isDark ? 20 : 5),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF10B981).withAlpha(25) : const Color(0xFFECFDF5),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 17),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(6.0),
                                              ),
                                              child: Text(
                                                planBadgeText,
                                                style: const TextStyle(color: Color(0xFF059669), fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          displayEmail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: subTextColor, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
                                  label: Text(
                                    LanguageController.tr('sidebar_upgrade_btn'),
                                    style: const TextStyle(color: Color(0xFFD97706), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFFDE68A), width: 1.0),
                                    backgroundColor: const Color(0xFFFEF3C7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // PROFILE INFORMATION SECTION
                    Text(
                      LanguageController.tr('section_profile_info'),
                      style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<UserModel?>(
                      valueListenable: UserSession.currentUserNotifier,
                      builder: (context, user, _) {
                        final realName = user?.username.isNotEmpty == true ? user!.username : 'Pengguna Guest (Belum Login)';
                        final realEmail = user?.email.isNotEmpty == true ? user!.email : 'Belum Terdaftar';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(color: borderTileColor, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(isDark ? 20 : 4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildProfileRow(isDark, Icons.person_outline, LanguageController.tr('label_name'), realName),
                              Divider(height: 20, color: borderTileColor),
                              _buildProfileRow(isDark, Icons.email_outlined, LanguageController.tr('label_email'), realEmail),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // CONNECTED DEVICES SECTION WITH REAL HARDWARE ID
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LanguageController.tr('section_devices'),
                          style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF262C3A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            '${_devices.length} Perangkat',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: borderTileColor, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 20 : 4),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _devices.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: borderTileColor,
                        ),
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          return _buildDeviceTile(isDark, device);
                        },
                      ),
                    ),
                    const SizedBox(height: 28),

                    // LOGOUT ACTION BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _showLogoutConfirmationDialog,
                        icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                        label: Text(
                          LanguageController.tr('menu_logout'),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.0),
                          backgroundColor: isDark ? const Color(0xFF991B1B).withAlpha(20) : const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceTile(bool isDark, ConnectedDeviceItem device) {
    final String subtitleText;
    if (device.isCurrent) {
      subtitleText = device.osVersion != null && device.osVersion!.isNotEmpty
          ? 'Aktif Saat Ini • ${device.osVersion}'
          : 'Aktif Saat Ini';
    } else {
      subtitleText = device.osVersion != null && device.osVersion!.isNotEmpty
          ? 'Terhubung • ${device.osVersion}'
          : 'Terhubung di Cloud';
    }

    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: device.isCurrent
                  ? (isDark ? const Color(0xFF10B981).withAlpha(20) : const Color(0xFFECFDF5))
                  : (isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(
              device.isCurrent ? Icons.phone_android_rounded : device.icon,
              color: device.isCurrent
                  ? const Color(0xFF10B981)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (device.isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          LanguageController.tr('current_device_badge'),
                          style: TextStyle(
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitleText,
                  style: TextStyle(
                    color: device.isCurrent
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    fontSize: 11.5,
                    fontWeight: device.isCurrent ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (!device.isCurrent)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              onPressed: () => _showDeleteDeviceDialog(device),
              tooltip: 'Hapus Akses Perangkat',
            ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(bool isDark, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
