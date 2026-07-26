import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/download_location_service.dart';
import '../services/permission_service.dart';
import '../widgets/index.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DownloadLocationService _locationService = DownloadLocationService();
  String _appVersion = '';
  String _downloadPath = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadDownloadPath();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = '${info.version}+${info.buildNumber}');
  }

  Future<void> _loadDownloadPath() async {
    await _locationService.init();
    final path = await _locationService.getCurrentPath();
    if (!mounted) return;
    setState(() {
      _downloadPath = path;
      _loading = false;
    });
  }

  Future<void> _pickFolder() async {
    // Minta izin penyimpanan dulu sebelum pilih folder
    final granted = await showPermissionDialog(context);
    if (!granted || !mounted) return;

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih folder download',
    );
    if (result != null) {
      await _locationService.setCustomPath(result);
      final path = await _locationService.getCurrentPath();
      if (!mounted) return;
      setState(() => _downloadPath = path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Folder download berhasil diubah!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _resetFolder() async {
    await _locationService.resetToDefault();
    final path = await _locationService.getCurrentPath();
    if (!mounted) return;
    setState(() => _downloadPath = path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Folder download kembali ke default'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final auth = context.read<AuthProvider>();
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.bgGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF555570),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Ubah Foto Profil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.image, color: AppTheme.primaryLight),
                title: const Text('Pilih dari Galeri',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (auth.avatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppTheme.error),
                  title: const Text('Hapus Foto',
                      style: TextStyle(color: AppTheme.error)),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    if (source == 'delete') {
      final ok = await auth.removeAvatar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Foto profil dihapus'
            : (auth.error ?? 'Gagal menghapus foto')),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final picked = result.files.first;
    final path = picked.path;
    if (path == null) return;
    final file = File(path);
    final ok = await auth.updateAvatar(file);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Foto profil diperbarui'
          : (auth.error ?? 'Gagal upload foto')),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure1 = true;
    bool obscure2 = true;
    bool obscure3 = true;
    bool saving = false;
    String? formError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final viewInsets = MediaQuery.of(ctx).viewInsets;
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.bgGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF555570),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.lock_reset_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Ubah Password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Password lama dipakai untuk verifikasi, lalu masukkan password baru.',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),

                      // Password lama
                      TextFormField(
                        controller: currentCtrl,
                        obscureText: obscure1,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password Lama',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscure1
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setSheet(() => obscure1 = !obscure1),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password lama wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Password baru
                      TextFormField(
                        controller: newCtrl,
                        obscureText: obscure2,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password Baru',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(obscure2
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setSheet(() => obscure2 = !obscure2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password baru wajib diisi';
                          }
                          if (v.length < 6) {
                            return 'Minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Konfirmasi
                      TextFormField(
                        controller: confirmCtrl,
                        obscureText: obscure3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi Password Baru',
                          prefixIcon:
                              const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(obscure3
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setSheet(() => obscure3 = !obscure3),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Konfirmasi password wajib diisi';
                          }
                          if (v != newCtrl.text) {
                            return 'Password tidak cocok';
                          }
                          return null;
                        },
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setSheet(() {
                                      saving = true;
                                      formError = null;
                                    });
                                    final auth = context.read<AuthProvider>();
                                    final ok = await auth.changePassword(
                                      currentPassword: currentCtrl.text,
                                      newPassword: newCtrl.text,
                                    );
                                    if (!ctx.mounted) return;
                                    if (ok) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                              'Password berhasil diperbarui!'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                      );
                                    } else {
                                      setSheet(() {
                                        saving = false;
                                        formError = auth.error ??
                                            'Gagal mengubah password';
                                      });
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Simpan Password'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const GradientHeader(text: 'Pengaturan'),
              const SizedBox(height: 4),
              Text('Kelola akun dan API key',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),

              // ── Profile Card ──
              GlassCard(
                radius: 20,
                blur: 30,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _changeAvatar,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: auth.avatarUrl == null
                              ? AppTheme.primaryGradient
                              : null,
                          color: auth.avatarUrl != null
                              ? const Color(0xFF2A2A3E)
                              : null,
                          borderRadius: BorderRadius.circular(18),
                          image: auth.avatarUrl != null
                              ? DecorationImage(
                                  // Cache buster: timestamp di query string
                                  // supaya Flutter gak pakai cache lama setelah upload baru.
                                  image: NetworkImage(
                                    auth.avatarUrl!.contains('?')
                                        ? '${auth.avatarUrl!}&t=${DateTime.now().millisecondsSinceEpoch}'
                                        : '${auth.avatarUrl!}?t=${DateTime.now().millisecondsSinceEpoch}',
                                  ),
                                  fit: BoxFit.cover,
                                  onError: (e, s) {
                                    // ignore: avoid_print
                                    debugPrint('Avatar load failed: $e');
                                  },
                                )
                              : null,
                        ),
                        child: auth.avatarUrl == null
                            ? const Icon(Icons.person,
                                size: 32, color: Colors.white)
                            : const Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.fullName?.isNotEmpty == true
                                ? auth.fullName!
                                : (auth.email ?? 'User'),
                            style:
                                Theme.of(context).textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${auth.userId?.substring(0, 8) ?? "-"}...',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Akun Section ──
              Text('Akun', style: Theme.of(context).textTheme.titleLarge),
              GlassCard(
                dark: true,
                radius: 16,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Keamanan Akun',
                                style: TextStyle(
                                  color: AppTheme.primaryLight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ganti password login akun kamu',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _changePassword,
                        icon: const Icon(Icons.lock_reset_rounded, size: 18),
                        label: const Text('Ubah Password'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryLight,
                          side: BorderSide(
                            color: AppTheme.primaryLight
                                .withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Folder Download Section ──
              Text('Folder Download',
                  style: Theme.of(context).textTheme.titleLarge),
              GlassCard(
                dark: true,
                radius: 16,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.folder_open_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Lokasi penyimpanan',
                                  style: TextStyle(
                                      color: AppTheme.primaryLight,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                _loading ? 'Memuat...' : _downloadPath,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8888A0),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFolder,
                            icon: const Icon(Icons.create_new_folder, size: 18),
                            label: const Text('Pilih Folder'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryLight,
                              side: BorderSide(
                                  color: AppTheme.primaryLight.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        if (_locationService.hasCustomPath) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: _resetFolder,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Icon(Icons.refresh, size: 20),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── API Key Section ──
              Text('API Key',
                  style: Theme.of(context).textTheme.titleLarge),
              GlassCard(
                dark: true,
                radius: 16,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            auth.apiKey ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Color(0xFFB0B0C8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.copy,
                                color: AppTheme.primaryLight, size: 20),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: auth.apiKey ?? ''));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('API Key tersalin!'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => auth.refreshKey(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh API Key'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryLight,
                          side: BorderSide(
                              color: AppTheme.primaryLight
                                  .withValues(alpha: 0.4)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ── Sign Out ──
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.error.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => auth.signout(),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Keluar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── App Version ──
              Center(
                child: Text(
                  'KIAPP Downloader v$_appVersion',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8888A0),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
