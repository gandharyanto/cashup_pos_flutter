import 'package:cashup_pos/cashup_pos.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CashupPos.initialize(
    bannerImageUrls: const [
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=1200&q=80',
    ],
    theme: const PosTheme(
      shellBackground: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      surfaceSoft: Color(0xFFF8FAFC),
      textOnShell: Color(0xFF0F172A),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF475569),
      strokeSoft: Color(0xFFE2E8F0),
      accentSuccess: Color(0xFF00AA13),
    ),
  );

  runApp(const CashupPosApp());
}
