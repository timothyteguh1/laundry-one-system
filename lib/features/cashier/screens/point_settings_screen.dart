import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// DESIGN SYSTEM
// ============================================================
class _DS {
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const sky = Color(0xFFE8F0FE); // <--- INI YANG SEBELUMNYA KELUPAAN
  static const surface = Colors.white;
  static const ground = Color(0xFFEAF0F6);
  static const border = Color(0xFFD2DCE8);
  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);
}

class PointSettingsScreen extends StatefulWidget {
  const PointSettingsScreen({super.key});

  @override
  State<PointSettingsScreen> createState() => _PointSettingsScreenState();
}

class _PointSettingsScreenState extends State<PointSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _nominalCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final data = await _supabase.from('app_settings').select('value').eq('id', 'rupiah_per_poin').maybeSingle();
      if (data != null && mounted) {
        _nominalCtrl.text = (data['value'] as num).toInt().toString();
      } else {
        _nominalCtrl.text = '50000'; // Default jika belum pernah disetting
      }
    } catch (e) {
      debugPrint('Error load setting: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting() async {
    final val = int.tryParse(_nominalCtrl.text.trim()) ?? 0;
    if (val < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nominal tidak valid (minimal Rp 1.000)'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();
    try {
      // Upsert: Update jika ada, Insert jika belum ada
      await _supabase.from('app_settings').upsert({
        'id': 'rupiah_per_poin',
        'value': val,
        'keterangan': 'Nominal transaksi (Rupiah) untuk mendapat 1 Poin Loyalitas'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Pengaturan Poin Berhasil Disimpan!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(
        title: const Text('Pengaturan Koin/Poin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _DS.blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _DS.border), boxShadow: [BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.stars_rounded, color: Colors.amber.shade600, size: 24)),
                            const SizedBox(width: 16),
                            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Aturan Poin Loyalitas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _DS.textPrimary)), SizedBox(height: 4), Text('Berapa Rupiah pelanggan harus belanja untuk mendapatkan 1 Poin?', style: TextStyle(color: _DS.textSecondary, fontSize: 12))])),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _nominalCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _DS.blue),
                          decoration: InputDecoration(
                            labelText: 'Rasio Konversi (Rp)',
                            prefixText: 'Rp ',
                            prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _DS.textPrimary),
                            filled: true, fillColor: _DS.ground,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _DS.blue, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _DS.sky, borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [const Icon(Icons.info_outline_rounded, color: _DS.blue, size: 16), const SizedBox(width: 8), Expanded(child: Text('Perubahan ini akan langsung berlaku pada transaksi kasir berikutnya.', style: TextStyle(color: _DS.blue.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600)))]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _DS.surface, boxShadow: [BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))]),
        child: SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Simpan Pengaturan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            onPressed: _isSaving ? null : _saveSetting, 
          ),
        ),
      ),
    );
  }
}