import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/core/services/app_state.dart';
import 'package:laundry_one/core/tokens/app_tokens.dart';
import 'package:intl/intl.dart';

// ============================================================
// DESIGN SYSTEM - KONSISTEN
// ============================================================
class _DS {
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const sky = Color(0xFFE8F0FE);
  static const ground = Color(0xFFEAF0F6);
  static const surface = Colors.white;
  static const border = Color(0xFFD2DCE8);
  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);
  static const textHint = Color(0xFFB0BAD1);

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.09),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> fabShadow = [
    BoxShadow(
      color: const Color(0xFF1565C0).withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _branches = [];
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =========================================================
  // CUSTOM DIALOG
  // =========================================================
  void _showCustomDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _DS.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _DS.navy.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _DS.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: _DS.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DS.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // LOAD BRANCHES
  // =========================================================
  Future<void> _loadBranches() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('branches')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _branches = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }

      if (_branches.isEmpty && mounted) {
        await _ensureDefaultBranch();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_isRlsError(e)) {
          _showCustomDialog(
            title: 'RLS Policy Diperlukan',
            message:
                'Tabel branches belum memiliki policy RLS.\n'
                'Hubungi dev untuk jalankan SQL:\n'
                'CREATE POLICY super_admin_manage_branches ON branches FOR ALL TO authenticated USING (true) WITH CHECK (true);',
            isSuccess: false,
          );
        } else {
          _showCustomDialog(
            title: 'Gagal Memuat',
            message: e.toString(),
            isSuccess: false,
          );
        }
      }
    }
  }

  bool _isRlsError(dynamic e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('row-level security') || msg.contains('42501');
  }

  Future<void> _ensureDefaultBranch() async {
    try {
      await _supabase.from('branches').insert({
        'id': '11111111-1111-1111-1111-111111111111',
        'nama_cabang': 'Cabang Utama',
        'alamat': '-',
        'kontak_hp': '-',
        'is_active': true,
      });
      await _loadBranches();
    } catch (e) {
      debugPrint('Seed default branch result: $e');
    }
  }

  // =========================================================
  // ADD / EDIT BRANCH DIALOG
  // =========================================================
  Future<void> _showFormDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final namaCtrl = TextEditingController(
      text: existing?['nama_cabang'] ?? '',
    );
    final alamatCtrl = TextEditingController(text: existing?['alamat'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _DS.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _DS.navy.withOpacity(0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEdit ? Colors.blue.shade50 : Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_rounded,
                    color: isEdit ? Colors.blue : Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Edit Cabang' : 'Tambah Cabang Baru',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _DS.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: namaCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Nama Cabang',
                          labelStyle: const TextStyle(
                            color: _DS.textHint,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: _DS.ground,
                          prefixIcon: const Icon(
                            Icons.store_rounded,
                            color: _DS.textHint,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: _DS.blue,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        validator: (v) => v == null || v.trim().length < 3
                            ? 'Nama cabang minimal 3 karakter'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: alamatCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Alamat Cabang',
                          labelStyle: const TextStyle(
                            color: _DS.textHint,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: _DS.ground,
                          prefixIcon: const Icon(
                            Icons.location_on_rounded,
                            color: _DS.textHint,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: _DS.blue,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        validator: (v) => v == null || v.trim().length < 5
                            ? 'Alamat minimal 5 karakter'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: Text(
                            'Batal',
                            style: TextStyle(
                              color: _DS.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEdit ? _DS.blue : Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final nama = namaCtrl.text.trim();
                                    final alamat = alamatCtrl.text.trim();

                                    if (isEdit) {
                                      // [UPDATE]: Perbarui cabang yang ada
                                      await _supabase
                                          .from('branches')
                                          .update({
                                            'nama_cabang': nama,
                                            'alamat': alamat,
                                          })
                                          .eq('id', existing!['id']);
                                    } else {
                                      // [MULTI-BRANCH]: Buat cabang baru
                                      // (biarkan DB generate UUID otomatis via gen_random_uuid)
                                      await _supabase.from('branches').insert({
                                        'nama_cabang': nama,
                                        'alamat': alamat,
                                        'is_active': true,
                                      });
                                    }

                                    if (mounted) {
                                      Navigator.pop(ctx);
                                      await _loadBranches();
                                      _showCustomDialog(
                                        title: isEdit
                                            ? 'Berhasil Diperbarui'
                                            : 'Berhasil Ditambahkan',
                                        message: isEdit
                                            ? 'Data cabang "$nama" telah diperbarui.'
                                            : 'Cabang "$nama" telah ditambahkan.',
                                        isSuccess: true,
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setModalState(() => isSubmitting = false);
                                      final isRls = _isRlsError(e);
                                      _showCustomDialog(
                                        title: isRls
                                            ? 'RLS Policy Error'
                                            : 'Gagal',
                                        message: isRls
                                            ? 'Gagal karena RLS policy. Hanya Super Admin yang dapat menambah cabang.'
                                            : e.toString(),
                                        isSuccess: false,
                                      );
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white70,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit
                                .scaleDown, // Teks akan mengecil otomatis jika ruang tidak cukup
                            child: Text(
                              isEdit ? 'Simpan Perubahan' : 'Konfirmasi',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
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

  // =========================================================
  // TOGGLE ACTIVE STATUS
  // =========================================================
  Future<void> _toggleActive(Map<String, dynamic> branch) async {
    final currentStatus = branch['is_active'] as bool? ?? false;
    final newStatus = !currentStatus;
    try {
      await _supabase
          .from('branches')
          .update({'is_active': newStatus})
          .eq('id', branch['id']);
      await _loadBranches();
    } catch (e) {
      _showCustomDialog(
        title: 'Gagal',
        message: e.toString(),
        isSuccess: false,
      );
    }
  }

  // =========================================================
  // DELETE (soft delete via is_active = false already covered by toggle)
  // We provide a permanent delete for admin purposes
  // =========================================================
  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Hapus Cabang?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus cabang "${branch['nama_cabang']}" secara permanen? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await _supabase.from('branches').delete().eq('id', branch['id']);
        await _loadBranches();
        if (mounted) {
          _showCustomDialog(
            title: 'Terhapus',
            message: 'Cabang berhasil dihapus.',
            isSuccess: true,
          );
        }
      } catch (e) {
        if (mounted) {
          _showCustomDialog(
            title: 'Gagal',
            message: e.toString(),
            isSuccess: false,
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  // =========================================================
  // SET AS CURRENT BRANCH (Super Admin override)
  // =========================================================
  Future<void> _setCurrentBranch(String branchId, String branchName) async {
    await AppState.saveBranch(branchId: branchId, branchName: branchName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cabang saat ini: $branchName'),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBranches = _searchCtrl.text.trim().isNotEmpty
        ? _branches
              .where(
                (b) => (b['nama_cabang'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(_searchCtrl.text.trim().toLowerCase()),
              )
              .toList()
        : _branches;

    return Scaffold(
      backgroundColor: _DS.navy,
      appBar: AppBar(
        title: const Text(
          'Kelola Cabang',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadBranches,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                decoration: const BoxDecoration(color: _DS.navy),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari nama cabang...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: _DS.ground,
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: _DS.blue),
                              SizedBox(height: 16),
                              Text(
                                'Memuat data cabang...',
                                style: TextStyle(
                                  color: _DS.textHint,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : filteredBranches.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.store_rounded,
                                      size: 60,
                                      color: _DS.textHint.withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Belum ada cabang yang terdaftar.',
                                      style: TextStyle(
                                        color: _DS.textHint,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : RefreshIndicator(
                          color: _DS.blue,
                          backgroundColor: _DS.surface,
                          onRefresh: _loadBranches,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                            itemCount: filteredBranches.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final branch = filteredBranches[i];
                              final isActive =
                                  branch['is_active'] as bool? ?? false;
                              final createdAt = branch['created_at'] != null
                                  ? DateFormat('dd MMM yyyy').format(
                                      DateTime.parse(
                                        branch['created_at'],
                                      ).toLocal(),
                                    )
                                  : '-';

                              return Container(
                                decoration: BoxDecoration(
                                  color: _DS.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _DS.border,
                                    width: 1.5,
                                  ),
                                  boxShadow: _DS.cardShadow,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.green.shade50
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.store_rounded,
                                        color: isActive
                                            ? Colors.green
                                            : _DS.textHint,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    branch['nama_cabang'] ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: _DS.textPrimary,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        branch['alamat'] ?? '-',
                                        style: const TextStyle(
                                          color: _DS.textSecondary,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Dibuat: $createdAt • ${isActive ? 'Aktif' : 'Non-aktif'}',
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.green.shade700
                                              : _DS.textHint,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _showFormDialog(existing: branch);
                                      } else if (val == 'toggle') {
                                        _toggleActive(branch);
                                      } else if (val == 'set_current') {
                                        _setCurrentBranch(
                                          branch['id'] as String,
                                          branch['nama_cabang'] ?? 'Cabang',
                                        );
                                      } else if (val == 'delete') {
                                        _deleteBranch(branch);
                                      }
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_rounded, size: 18),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isActive
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isActive
                                                  ? 'Non-aktifkan'
                                                  : 'Aktifkan',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'set_current',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Jadikan Cabang Aktif'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.red,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Hapus Permanen',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: _DS.navy.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 32,
                      ),
                      decoration: BoxDecoration(
                        color: _DS.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _DS.navy.withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: _DS.blue,
                            strokeWidth: 3.5,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Memproses...',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _DS.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 8,
        highlightElevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Tambah Cabang',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
