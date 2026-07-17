import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadKasir();
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
      // Mengambil data dari tabel kasir dan JOIN dengan tabel profiles
      final data = await _supabase.from('kasir').select('''
        id,
        profile_id,
        status,
        created_at,
        profiles!kasir_profile_id_fkey (
          nama_lengkap,
          nomor_hp
        )
      ''').order('created_at', ascending: false);

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
        'approved_at': statusBaru == 'approved' ? DateTime.now().toIso8601String() : null,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.navy,
      appBar: AppBar(
        title: const Text('Kelola Kasir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
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
                                              onPressed: () => _ubahStatusKasir(k['id'], 'approved', nama),
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

            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
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
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: _DS.textSecondary))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      if (nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().length >= 10 && pwdCtrl.text.length >= 6) {
                        Navigator.pop(ctx, true);
                      }
                    },
                    child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
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
                await _supabase.functions.invoke('create-kasir', body: {
                  'full_name': nameCtrl.text.trim(),
                  'phone': finalPhone, 
                  'password': pwdCtrl.text.trim(),
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