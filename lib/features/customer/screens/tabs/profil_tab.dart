import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';

class ProfilTab extends StatefulWidget {
  final String nama;
  final String noHp;
  final String? avatarUrl; 
  final VoidCallback onLogout;

  const ProfilTab({
    super.key,
    required this.nama,
    required this.noHp,
    this.avatarUrl,
    required this.onLogout,
  });

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<ProfilTab> {
  final _supabase = Supabase.instance.client;
  bool _isUploading = false; 

  // ==========================================\
  // FUNGSI CHAT ADMIN (WHATSAPP)
  // ==========================================\
  Future<void> _hubungiAdmin() async {
    final Uri url = Uri.parse('https://wa.me/6281248004818?text=Halo%20Admin%20Laundry%20One,%20saya%20butuh%20bantuan%20terkait%20cucian%20saya.');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Tidak dapat membuka WhatsApp');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka WhatsApp. Pastikan aplikasi ter-install.')));
    }
  }

  // ==========================================\
  // FUNGSI GANTI PASSWORD (MANDIRI)
  // ==========================================\
  void _showGantiPasswordDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    
    bool isSubmitting = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 16),
          decoration: const BoxDecoration(color: CustomerTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Ganti Password Keamanan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CustomerTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text('Masukkan password lama Anda untuk mengatur password yang baru.', style: TextStyle(color: CustomerTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),

              // PASSWORD LAMA
              TextField(
                controller: oldPassCtrl, obscureText: obscureOld,
                decoration: InputDecoration(
                  labelText: 'Password Saat Ini', filled: true, fillColor: CustomerTheme.ground,
                  prefixIcon: const Icon(Icons.lock_clock_rounded, color: CustomerTheme.textHint),
                  suffixIcon: IconButton(icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility, color: CustomerTheme.textHint), onPressed: () => setModalState(() => obscureOld = !obscureOld)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // PASSWORD BARU
              TextField(
                controller: newPassCtrl, obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'Password Baru', filled: true, fillColor: CustomerTheme.ground,
                  prefixIcon: const Icon(Icons.lock_reset_rounded, color: CustomerTheme.textHint),
                  suffixIcon: IconButton(icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: CustomerTheme.textHint), onPressed: () => setModalState(() => obscureNew = !obscureNew)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // KONFIRMASI PASSWORD BARU
              TextField(
                controller: confirmPassCtrl, obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Ulangi Password Baru', filled: true, fillColor: CustomerTheme.ground,
                  prefixIcon: const Icon(Icons.lock_rounded, color: CustomerTheme.textHint),
                  suffixIcon: IconButton(icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, color: CustomerTheme.textHint), onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: CustomerTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                  onPressed: isSubmitting ? null : () async {
                    if (oldPassCtrl.text.isEmpty || newPassCtrl.text.isEmpty || confirmPassCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua kolom wajib diisi.'), backgroundColor: Colors.red)); return;
                    }
                    if (newPassCtrl.text != confirmPassCtrl.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password baru tidak cocok!'), backgroundColor: Colors.red)); return;
                    }
                    if (newPassCtrl.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password baru minimal 6 karakter.'), backgroundColor: Colors.red)); return;
                    }

                    setModalState(() => isSubmitting = true);
                    try {
                      final email = _supabase.auth.currentUser!.email!;
                      
                      // 1. Verifikasi Password Lama (Auth Sign In)
                      await _supabase.auth.signInWithPassword(email: email, password: oldPassCtrl.text);

                      // 2. Update Password Baru
                      await _supabase.auth.updateUser(UserAttributes(password: newPassCtrl.text));

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Password berhasil diganti!'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setModalState(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal: Password lama salah atau jaringan error.'), backgroundColor: Colors.red));
                    }
                  },
                  child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan Password Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================\
  // GANTI FOTO PROFIL
  // ==========================================\
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (image == null) return;
    
    setState(() => _isUploading = true);
    try {
      final file = File(image.path);
      final userId = _supabase.auth.currentUser!.id;
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/$fileName';

      await _supabase.storage.from('avatars').upload(filePath, file, fileOptions: const FileOptions(upsert: true));
      final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

      await _supabase.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil berhasil diperbarui! 🎉'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ==========================================
  // MODAL KEBIJAKAN PRIVASI STANDAR
  // ==========================================
  void _showKebijakanPrivasi() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CustomerTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: CustomerTheme.primary),
            SizedBox(width: 12),
            Text('Kebijakan Privasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CustomerTheme.textPrimary)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Laundry One sangat menghargai privasi data Anda.\n\n'
            '1. Data Pribadi\nKami hanya menyimpan data esensial seperti Nama dan Nomor HP untuk keperluan identifikasi cucian, login, dan keamanan.\n\n'
            '2. Keamanan Data\nSeluruh data transaksi dan profil Anda disimpan secara aman di server kami dan tidak akan disebarluaskan ke pihak ketiga.\n\n'
            '3. Riwayat Transaksi\nRiwayat pesanan dan poin Anda direkam secara transparan agar Anda dapat melacaknya kapan saja.\n\n'
            'Dengan menggunakan aplikasi ini, Anda dianggap telah menyetujui kebijakan privasi standar kami.',
            style: TextStyle(color: CustomerTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Saya Mengerti', style: TextStyle(color: CustomerTheme.primary, fontWeight: FontWeight.w800)),
          )
        ],
      )
    );
  }

  // ==========================================
  // BOTTOM SHEET EDIT PROFIL
  // ==========================================
  void _showEditProfilDialog() {
    final namaController = TextEditingController(text: widget.nama);
    bool isLoading = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, top: 24, left: 24, right: 24),
          decoration: const BoxDecoration(color: CustomerTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: CustomerTheme.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('Edit Profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CustomerTheme.textPrimary)),
              const SizedBox(height: 24),
              
              const Text('Nama Lengkap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CustomerTheme.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: namaController,
                decoration: InputDecoration(filled: true, fillColor: CustomerTheme.ground, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              ),
              const SizedBox(height: 16),

              const Text('Nomor HP (Tidak dapat diubah)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CustomerTheme.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: widget.noHp), enabled: false,
                decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade200, suffixIcon: const Icon(Icons.lock_outline_rounded, color: CustomerTheme.textHint), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                style: const TextStyle(color: CustomerTheme.textSecondary),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: CustomerTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                  onPressed: isLoading ? null : () async {
                    if (namaController.text.trim().isEmpty) return;
                    setModalState(() => isLoading = true);
                    try {
                      final user = _supabase.auth.currentUser;
                      if (user != null) await _supabase.from('profiles').update({'nama_lengkap': namaController.text.trim()}).eq('id', user.id);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      setModalState(() => isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
                    }
                  },
                  child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan Perubahan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              )
            ],
          ),
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profil Saya', style: TextStyle(color: CustomerTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: CustomerTheme.cardDecoration,
              child: Row(
                children: [
                  // AVATAR AREA
                  GestureDetector(
                    onTap: _isUploading ? null : _pickAndUploadImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 64, height: 64, 
                          decoration: BoxDecoration(
                            // 👇 FIX: Error Theme warna diubah ke primaryLight
                            color: CustomerTheme.primaryLight, 
                            shape: BoxShape.circle,
                            image: widget.avatarUrl != null 
                                ? DecorationImage(image: NetworkImage(widget.avatarUrl!), fit: BoxFit.cover)
                                : null,
                          ), 
                          child: _isUploading 
                              ? const CircularProgressIndicator(color: CustomerTheme.primary)
                              : widget.avatarUrl == null 
                                  ? Center(child: Text(widget.nama.isNotEmpty ? widget.nama[0].toUpperCase() : '?', style: const TextStyle(color: CustomerTheme.primary, fontSize: 24, fontWeight: FontWeight.w800)))
                                  : null,
                        ),
                        if (!_isUploading)
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: CustomerTheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                            ),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // NAMA & HP
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.nama, style: const TextStyle(color: CustomerTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(widget.noHp, style: const TextStyle(color: CustomerTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  
                  // TOMBOL EDIT PENSIL
                  IconButton(icon: const Icon(Icons.edit_rounded, color: CustomerTheme.textHint), onPressed: _showEditProfilDialog)
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Text('Pengaturan & Bantuan', style: TextStyle(color: CustomerTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            
            _buildProfileMenu(Icons.headset_mic_rounded, 'Bantuan & Chat Admin', _hubungiAdmin),
            _buildProfileMenu(Icons.lock_reset_rounded, 'Keamanan & Ganti Password', _showGantiPasswordDialog),
            _buildProfileMenu(Icons.shield_outlined, 'Kebijakan Privasi', _showKebijakanPrivasi),
            
            const Spacer(),
            
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text('Keluar Akun', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 15)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: widget.onLogout,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenu(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CustomerTheme.menuDecoration,
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: CustomerTheme.ground, borderRadius: BorderRadius.all(Radius.circular(8))), child: Icon(icon, color: CustomerTheme.primary, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CustomerTheme.textPrimary)),
        trailing: const Icon(Icons.chevron_right_rounded, color: CustomerTheme.textHint),
        onTap: onTap,
      ),
    );
  }
}