import 'package:flutter/material.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';

class KatalogTab extends StatelessWidget {
  const KatalogTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Layar Katalog & Tukar Poin akan dibangun di Tahap 3', style: TextStyle(color: CustomerTheme.textSecondary, fontWeight: FontWeight.w600))
    );
  }
}