import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/core/services/app_state.dart';

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

  // Tambahkan baris ini 👇
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

class KasirManagementScreen extends StatefulWidget {
  const KasirManagementScreen({super.key});

  @override
  State<KasirManagementScreen> createState() => _KasirManagementScreenState();
}

class _KasirManagementScreenState extends State<KasirManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _kasirList = [];
  List<Map<String, dynamic>> _filteredList = [];
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;

  // [MULTI-BRANCH]: Daftar cabang & filter untuk Super Admin
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchFilterId;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _initData(); // Panggil fungsi antrean baru
  }

  // Tambahkan fungsi baru ini tepat di bawah initState
  Future<void> _initData() async {
    await _checkRoleAndBranches(); // Tunggu sampai status Admin dan ID Cabang selesai disiapkan
    await _loadKasir(); // Baru tarik data kasir berdasarkan cabang yang benar
  }

  Future<void> _checkRoleAndBranches() async {
    final role = await AppState.getRole();
    _isSuperAdmin = role == 'super_admin';

    if (_isSuperAdmin) {
      await _loadBranches();
      // [PERBAIKAN]: Default untuk Admin adalah Semua Cabang (null)
      if (mounted) setState(() => _selectedBranchFilterId = null);
    } else {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadBranches() async {
    try {
      final data = await _supabase
          .from('branches')
          .select('id, nama_cabang')
          .eq('is_active', true)
          .order('nama_cabang');
      if (mounted) {
        setState(() => _branches = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('Error loading branches: $e');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =========================================================
  // CUSTOM DIALOG (Sesuai Standar Aplikasi)
  // =========================================================
  void _showCustomDialog({required String title, required String message, required bool isSuccess}) {
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
              BoxShadow(color: _DS.navy.withOpacity(0.15), blurRadius: 32, offset: const Offset(0, 12)),
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
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: _DS.textSecondary, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? _DS.blue : Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _modernInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _DS.textHint, fontSize: 13),
      filled: true,
      fillColor: _DS.ground,
      prefixIcon: icon != null ? Icon(icon, color: _DS.textHint, size: 20) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _DS.blue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ============================================================
  // PENERJEMAH ERROR (UX IMPROVEMENT)
  // ============================================================
  String _getFriendlyErrorMessage(String rawError) {
    final errorStr = rawError.toLowerCase();

    if (errorStr.contains('already been registered') || errorStr.contains('duplicate key')) {
      return 'Nomor HP atau email ini sudah terdaftar di sistem. Silakan gunakan yang lain.';
    } else if (errorStr.contains('user not found')) {
      return 'Akun kasir tidak ditemukan atau sudah terhapus sebelumnya.';
    } else if (errorStr.contains('invalid phone')) {
      return 'Format nomor HP tidak valid. Pastikan nomor dimasukkan dengan benar.';
    } else if (errorStr.contains('password')) {
      return 'Password yang Anda masukkan tidak memenuhi syarat (minimal 6 karakter).';
    } else if (errorStr.contains('sesi') || errorStr.contains('token') || errorStr.contains('jwt')) {
      return 'Sesi login Anda bermasalah. Silakan login ulang.';
    } else if (errorStr.contains('hanya admin')) {
      return 'Akses ditolak. Anda tidak memiliki izin untuk melakukan tindakan ini.';
    }

    try {
      if (rawError.contains('details: {error:')) {
        final startIndex = rawError.indexOf('error: ') + 7;
        final endIndex = rawError.indexOf('}', startIndex);
        if (startIndex > 6 && endIndex > startIndex) {
          return rawError.substring(startIndex, endIndex).trim();
        }
      }
    } catch (_) {}

    return rawError
        .replaceAll(RegExp(r'FunctionException.*details: {error: '), '')
        .replaceAll('}', '')
        .replaceAll('Exception: ', '')
        .trim();
  }

  // =========================================================
  // LOGIKA DATABASE & EDGE FUNCTIONS
  // =========================================================
  Future<void> _loadKasir() async {
    setState(() => _isLoading = true);
    try {
      final branchId = await AppState.getBranchId();
      // Super Admin pakai filter yang dipilih di dropdown; Kasir pakai AppState
      final effectiveBranch = _isSuperAdmin ? _selectedBranchFilterId : branchId;

      var query = _supabase.from('kasir').select('''
          id,
          profile_id,
          status,
          branch_id,
          created_at,
          branches ( nama_cabang ),
          profiles!kasir_profile_id_fkey (
            nama_lengkap,
            nomor_hp
          )
        ''');

      // [MULTI-BRANCH]: Hanya tampilkan kasir dari cabang yang dipilih;
      // Super Admin yang belum pilih cabang akan lihat semua.
      if (effectiveBranch != null) {
        query = query.eq('branch_id', effectiveBranch);
      }

      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _kasirList = List<Map<String, dynamic>>.from(data);
          _filteredList = _kasirList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final pesanRamah = _getFriendlyErrorMessage(e.toString());
        _showCustomDialog(title: 'Gagal Memuat', message: pesanRamah, isSuccess: false);
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredList = _kasirList;
      } else {
        _filteredList = _kasirList.where((k) {
          final profile = k['profiles'];
          final nama = (profile['nama_lengkap'] ?? '').toString().toLowerCase();
          final hp = (profile['nomor_hp'] ?? '').toString().toLowerCase();
          final q = query.toLowerCase();
          return nama.contains(q) || hp.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _ubahStatusKasir(String kasirId, String statusBaru, String namaKasir) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      final adminId = _supabase.auth.currentUser!.id;
      await _supabase.from('kasir').update({
        'status': statusBaru,
        'approved_by': statusBaru == 'approved' ? adminId : null,
        // SESUDAH DIPERBAIKI:
        'approved_at': statusBaru == 'approved' ? DateTime.now().toUtc().toIso8601String() : null,
      }).eq('id', kasirId);
      
      await _loadKasir();
      
      if (mounted) {
        _showCustomDialog(
          title: statusBaru == 'approved' ? 'Kasir Disetujui' : 'Kasir Ditolak',
          message: statusBaru == 'approved' 
            ? 'Akses login $namaKasir telah dibuka.' 
            : 'Akses login $namaKasir telah ditutup.',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final pesanRamah = _getFriendlyErrorMessage(e.toString());
        _showCustomDialog(title: 'Gagal Memperbarui', message: pesanRamah, isSuccess: false);
      }
    }
  }

  Future<void> _dialogApproveDanAssignCabang(Map<String, dynamic> kasirData, String namaKasir) async {
    String? selectedBranchId = kasirData['branch_id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _DS.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Setujui & Pilih Cabang', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tentukan cabang tempat $namaKasir akan bertugas:', style: const TextStyle(color: _DS.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedBranchId,
                hint: const Text('Pilih Cabang Kasir', style: TextStyle(color: _DS.textHint, fontSize: 13)),
                items: _branches
                    .map((b) => DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text(b['nama_cabang'] as String? ?? '-'),
                        ))
                    .toList(),
                onChanged: (val) => setModalState(() => selectedBranchId = val),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _DS.ground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.store_rounded, color: _DS.textHint, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: _DS.textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                if (selectedBranchId != null) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih cabang terlebih dahulu!'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Setujui', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && selectedBranchId != null) {
      setState(() => _isLoading = true);
      try {
        final adminId = _supabase.auth.currentUser!.id;
        await _supabase.from('kasir').update({
          'status': 'approved',
          'branch_id': selectedBranchId,
          'approved_by': adminId,
          'approved_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', kasirData['id']);
        
        await _loadKasir();
        if (mounted) _showCustomDialog(title: 'Berhasil', message: '$namaKasir berhasil disetujui dan ditugaskan ke cabang.', isSuccess: true);
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) _showCustomDialog(title: 'Gagal', message: e.toString(), isSuccess: false);
      }
    }
  }

  Future<void> _resetPassword(String profileId, String namaKasir) async {
    final pwdCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _DS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Sandi Kasir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Masukkan kata sandi baru untuk $namaKasir (minimal 6 karakter).', style: const TextStyle(color: _DS.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(controller: pwdCtrl, obscureText: true, decoration: _modernInputDecoration('Sandi Baru', icon: Icons.lock_reset_rounded)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: _DS.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (pwdCtrl.text.length >= 6) Navigator.pop(ctx, true);
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // [EDGE FUNCTION CALL] Panggil Edge Function reset-kasir-password
        await _supabase.functions.invoke('reset-kasir-password', body: {
          'user_id': profileId,
          'new_password': pwdCtrl.text.trim(),
        });
        
        setState(() => _isLoading = false);
        if (mounted) _showCustomDialog(title: 'Berhasil Reset Sandi', message: 'Kata sandi $namaKasir telah diperbarui.', isSuccess: true);
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          final pesanRamah = _getFriendlyErrorMessage(e.toString());
          _showCustomDialog(title: 'Gagal Reset', message: pesanRamah, isSuccess: false);
        }
      }
    }
  }

  Future<void> _hapusKasir(String profileId, String namaKasir) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Hapus Permanen?', style: TextStyle(fontWeight: FontWeight.bold))]),
        content: Text('Yakin ingin menghapus seluruh akses $namaKasir? Data ini tidak dapat dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // [EDGE FUNCTION CALL] Panggil Edge Function delete-kasir
        await _supabase.functions.invoke('delete-kasir', body: {
          'user_id': profileId,
        });
        
        await _loadKasir();
        if (mounted) _showCustomDialog(title: 'Berhasil Dihapus', message: 'Akun kasir $namaKasir telah dihapus permanen.', isSuccess: true);
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          final pesanRamah = _getFriendlyErrorMessage(e.toString());
          _showCustomDialog(title: 'Gagal Menghapus', message: pesanRamah, isSuccess: false);
        }
      }
    }
  }

  // =========================================================
  // FITUR BARU: RIWAYAT PENJUALAN KASIR (30 HARI)
  // =========================================================
  void _showRiwayatKasirBottomSheet(String kasirId, String namaKasir) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RiwayatKasirSheet(
        kasirId: kasirId,
        namaKasir: namaKasir,
        supabase: _supabase,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.navy,
      appBar: AppBar(
        title: const Text('Kelola Kasir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _isSuperAdmin
            ? [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<String?>(
                      value: _selectedBranchFilterId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Semua Cabang', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                        ..._branches.map((b) => DropdownMenuItem<String?>(
                              value: b['id'] as String,
                              child: Text(b['nama_cabang'] as String? ?? '-', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedBranchFilterId = val);
                        _loadKasir();
                      },
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: _DS.blue,
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    ),
                  ),
                )
              ]
            : null,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: _DS.ground)),

          Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_DS.navy, _DS.blue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau nomor HP...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  color: _DS.blue,
                  backgroundColor: _DS.surface,
                  onRefresh: _loadKasir,
                  child: _filteredList.isEmpty && !_isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: const Center(
                                child: Text('Belum ada data kasir', style: TextStyle(color: _DS.textHint)),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          itemCount: _filteredList.length,
                          itemBuilder: (ctx, i) {
                            final k = _filteredList[i];
                            final profile = k['profiles'];
                            final status = k['status'];
                            final nama = profile['nama_lengkap'] ?? 'Tanpa Nama';
                            final hp = profile['nomor_hp'] ?? '-';
                            // [FITUR BARU] Tarik nama cabang
                            final namaCabang = k['branches']?['nama_cabang'] ?? 'Belum Ditugaskan';

                            // Konfigurasi Badge Status
                            Color badgeColor = Colors.grey;
                            Color badgeBg = Colors.grey.shade100;
                            String badgeText = status.toString().toUpperCase();
                            if (status == 'approved') {
                              badgeColor = Colors.green.shade700;
                              badgeBg = Colors.green.shade50;
                            } else if (status == 'pending') {
                              badgeColor = Colors.amber.shade700;
                              badgeBg = Colors.amber.shade50;
                            } else if (status == 'rejected') {
                              badgeColor = Colors.red.shade700;
                              badgeBg = Colors.red.shade50;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: _DS.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _DS.border, width: 1.5),
                                boxShadow: _DS.cardShadow,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: status == 'approved' 
                                      ? () => _showRiwayatKasirBottomSheet(k['profile_id'], nama)
                                      : null, 
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(color: _DS.sky, borderRadius: BorderRadius.circular(12)),
                                              child: Center(
                                                child: Text(
                                                  nama[0].toUpperCase(),
                                                  style: const TextStyle(color: _DS.blue, fontWeight: FontWeight.w800, fontSize: 16),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary)),
                                                  const SizedBox(height: 4),
                                                  Text(hp, style: const TextStyle(color: _DS.textSecondary, fontSize: 12)),
                                                  const SizedBox(height: 6),
                                                  // [FITUR BARU] Indikator Cabang
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: _DS.ground, borderRadius: BorderRadius.circular(6)),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.store_rounded, size: 10, color: _DS.textSecondary),
                                                        const SizedBox(width: 4),
                                                        Text(namaCabang, style: const TextStyle(color: _DS.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                                              child: Text(
                                                badgeText,
                                                style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: _DS.border, height: 1)),
                                        
                                        // TOMBOL AKSI BERDASARKAN STATUS
                                        if (status == 'pending') ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green.shade50, foregroundColor: Colors.green.shade700, elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  // [FITUR BARU] Ganti fungsi klik persetujuan
                                                  onPressed: () => _dialogApproveDanAssignCabang(k, nama),
                                                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                                                  label: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade700, elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  onPressed: () => _ubahStatusKasir(k['id'], 'rejected', nama),
                                                  icon: const Icon(Icons.cancel_rounded, size: 16),
                                                  label: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (status == 'approved')
                                                TextButton.icon(
                                                  onPressed: () => _ubahStatusKasir(k['id'], 'rejected', nama),
                                                  icon: const Icon(Icons.block_rounded, size: 16, color: Colors.orange),
                                                  label: const Text('Cabut Akses', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                              if (status == 'rejected')
                                                TextButton.icon(
                                                  onPressed: () => _ubahStatusKasir(k['id'], 'approved', nama),
                                                  icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                                                  label: const Text('Pulihkan', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                              const Spacer(),
                                              IconButton(
                                                tooltip: 'Reset Sandi',
                                                icon: const Icon(Icons.lock_reset_rounded, color: _DS.blue),
                                                onPressed: () => _resetPassword(k['profile_id'], nama),
                                              ),
                                              IconButton(
                                                tooltip: 'Hapus Kasir',
                                                icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                                                onPressed: () => _hapusKasir(k['profile_id'], nama),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),

          // LOADING OVERLAY
          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: _DS.navy.withOpacity(0.2),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(24)),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _DS.blue, strokeWidth: 3.5),
                          SizedBox(height: 20),
                          Text('Memproses...', style: TextStyle(fontWeight: FontWeight.w800, color: _DS.textPrimary, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: _DS.fabShadow),
        child: FloatingActionButton.extended(
            onPressed: () async {
              final nameCtrl = TextEditingController();
              final phoneCtrl = TextEditingController();
              final pwdCtrl = TextEditingController();
              String? selectedFormBranchId;

              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx, setModalState) => AlertDialog(
                    backgroundColor: _DS.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Tambah Kasir Baru', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Akun yang dibuat di sini akan langsung berstatus APPROVED.', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(controller: nameCtrl, decoration: _modernInputDecoration('Nama Lengkap', icon: Icons.badge_outlined)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl, 
                        keyboardType: TextInputType.phone, 
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _modernInputDecoration('Nomor WhatsApp', icon: Icons.phone_android_outlined)
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: pwdCtrl, obscureText: true, decoration: _modernInputDecoration('Password (Min 6 Karakter)', icon: Icons.lock_outline)),

                      // [MULTI-BRANCH]: Dropdown cabang khusus Super Admin
                      if (_isSuperAdmin) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedFormBranchId,
                          hint: const Text('Pilih Cabang Kasir', style: TextStyle(color: _DS.textHint, fontSize: 13)),
                          items: _branches
                              .map((b) => DropdownMenuItem(
                                    value: b['id'] as String,
                                    child: Text(b['nama_cabang'] as String? ?? '-'),
                                  ))
                              .toList(),
                          onChanged: (val) => setModalState(() => selectedFormBranchId = val),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: _DS.ground,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _DS.blue, width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: const Icon(Icons.store_rounded, color: _DS.textHint, size: 20),
                          ),
                          validator: (val) => (val == null || val.isEmpty) ? 'Pilih cabang dulu' : null,
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: _DS.textSecondary))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      final branchOk = !_isSuperAdmin || (selectedFormBranchId != null && selectedFormBranchId!.isNotEmpty);
                      if (nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().length >= 10 && pwdCtrl.text.length >= 6 && branchOk) {
                        Navigator.pop(ctx, true);
                      }
                    },
                    child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );

           if (confirm == true) {
              setState(() => _isLoading = true);
              try {
                // ==========================================
                // [PERBAIKAN KUNCI]: Auto-Format ke E.164
                // ==========================================
                String finalPhone = phoneCtrl.text.trim();
                
                // Jika diawali angka 0, ganti dengan +62
                if (finalPhone.startsWith('0')) {
                  finalPhone = '+62${finalPhone.substring(1)}';
                } 
                // Jika belum ada tanda +, tambahkan (berjaga-jaga jika user mengetik 628...)
                else if (!finalPhone.startsWith('+')) {
                  finalPhone = '+$finalPhone';
                }
                // ==========================================

                // Panggil Edge Function create-kasir
                final appBranchId = await AppState.getBranchId();
                final branchId = _isSuperAdmin ? selectedFormBranchId ?? appBranchId : appBranchId;
                await _supabase.functions.invoke('create-kasir', body: {
                  'full_name': nameCtrl.text.trim(),
                  'phone': finalPhone,
                  'password': pwdCtrl.text.trim(),
                  'branch_id': branchId,
                });
                
                await _loadKasir(); 
                if (mounted) {
                  _showCustomDialog(title: 'Berhasil Dibuat', message: 'Akun kasir ${nameCtrl.text} siap digunakan.', isSuccess: true); 
                }
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  final pesanRamah = _getFriendlyErrorMessage(e.toString());
                  _showCustomDialog(title: 'Gagal Membuat', message: pesanRamah, isSuccess: false); 
                }
              }
            }
          },
          elevation: 0,
          backgroundColor: _DS.blue,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
          label: const Text('Tambah Kasir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
    );
  }
}

// ============================================================
// KOMPONEN BOTTOM SHEET: RIWAYAT 30 HARI KASIR
// ============================================================
class _RiwayatKasirSheet extends StatefulWidget {
  final String kasirId;
  final String namaKasir;
  final SupabaseClient supabase;

  const _RiwayatKasirSheet({
    required this.kasirId,
    required this.namaKasir,
    required this.supabase,
  });

  @override
  State<_RiwayatKasirSheet> createState() => _RiwayatKasirSheetState();
}

class _RiwayatKasirSheetState extends State<_RiwayatKasirSheet> {
  bool _isLoading = true;
  
  // Format data: { '21 Jul 2026': { 'cash': 500000, 'non_cash': 200000, 'total': 700000 } }
  final Map<String, Map<String, double>> _dailyData = {};
  final List<String> _sortedDates = [];

  @override
  void initState() {
    super.initState();
    _fetch30DaysHistory();
  }

  Future<void> _fetch30DaysHistory() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toUtc().toIso8601String();

      // Menarik data murni dari order_payments berdasarkan kasir yang menerima
      final payments = await widget.supabase
          .from('order_payments')
          .select('jumlah, metode, created_at')
          .eq('diterima_oleh', widget.kasirId)
          .gte('created_at', thirtyDaysAgo)
          .order('created_at', ascending: false);

      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];

      for (var p in payments) {
        final date = DateTime.parse(p['created_at']).toLocal();
        final dateStr = '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';

        if (!_dailyData.containsKey(dateStr)) {
          _dailyData[dateStr] = {'cash': 0, 'non_cash': 0, 'total': 0};
          _sortedDates.add(dateStr);
        }

        final amount = (p['jumlah'] as num).toDouble();
        _dailyData[dateStr]!['total'] = _dailyData[dateStr]!['total']! + amount;

        if (p['metode'] == 'cash') {
          _dailyData[dateStr]!['cash'] = _dailyData[dateStr]!['cash']! + amount;
        } else {
          // Gabungan TF dan QRIS
          _dailyData[dateStr]!['non_cash'] = _dailyData[dateStr]!['non_cash']! + amount;
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatRupiah(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _DS.ground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: BoxDecoration(
              color: _DS.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: _DS.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Riwayat Kasir (30 Hari)',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _DS.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.namaKasir,
                            style: const TextStyle(color: _DS.blue, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _DS.sky, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.analytics_rounded, color: _DS.blue),
                    )
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _DS.blue))
                : _sortedDates.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada transaksi dalam 30 hari terakhir.',
                          style: TextStyle(color: _DS.textHint),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount: _sortedDates.length,
                        itemBuilder: (ctx, i) {
                          final dateStr = _sortedDates[i];
                          final data = _dailyData[dateStr]!;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _DS.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _DS.border),
                              boxShadow: _DS.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateStr,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary),
                                    ),
                                    Text(
                                      _formatRupiah(data['total']!),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _DS.blue),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(color: _DS.border, height: 1),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatPill(
                                        title: 'Setoran Tunai (Cash)',
                                        amount: _formatRupiah(data['cash']!),
                                        icon: Icons.payments_rounded,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatPill(
                                        title: 'Non-Tunai (TF/QRIS)',
                                        amount: _formatRupiah(data['non_cash']!),
                                        icon: Icons.qr_code_scanner_rounded,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final MaterialColor color;

  const _StatPill({required this.title, required this.amount, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700, size: 18),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: color.shade800, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(amount, style: TextStyle(color: color.shade900, fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}