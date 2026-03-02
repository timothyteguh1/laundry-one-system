import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

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
  
  static List<BoxShadow> cardShadow = [
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.09), blurRadius: 16, offset: const Offset(0, 4)),
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
  ];
}

class PrinterSelectionScreen extends StatefulWidget {
  const PrinterSelectionScreen({super.key});

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getDevices();
  }

  Future<void> _getDevices() async {
    setState(() => _isLoading = true);
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } on PlatformException {
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(
        title: const Text('Pilih Printer Bluetooth', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              _getDevices();
            },
            tooltip: 'Refresh Perangkat',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _DS.blue))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _DS.sky, borderRadius: BorderRadius.circular(12), border: Border.all(color: _DS.blue.withOpacity(0.2))),
                    child: Row(
                      children: [
                        const Icon(Icons.bluetooth_searching_rounded, color: _DS.blue, size: 24),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Pastikan printer sudah dinyalakan dan di-pairing di pengaturan Bluetooth HP Anda.', style: TextStyle(color: _DS.blue.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                ),
                
                Expanded(
                  child: _devices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print_disabled_rounded, size: 64, color: _DS.textSecondary.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              const Text('Belum ada printer terhubung', style: TextStyle(color: _DS.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 8),
                              const Text('Silakan pairing perangkat di\nPengaturan HP terlebih dahulu.', textAlign: TextAlign.center, style: TextStyle(color: _DS.textSecondary, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border, width: 1.5), boxShadow: _DS.cardShadow),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    // KEMBALIKAN DATA PRINTER YANG DIPILIH KE HALAMAN INVOICE
                                    Navigator.pop(context, device);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: _DS.ground, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.print_rounded, color: _DS.blue, size: 24),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(device.name ?? 'Perangkat Tidak Dikenal', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary)),
                                              const SizedBox(height: 4),
                                              Text(device.address ?? 'No Address', style: const TextStyle(color: _DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, color: _DS.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
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