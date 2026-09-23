import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PosMode { simple, pos }

final posModeProvider = StateProvider<PosMode>((ref) => PosMode.pos);

/// Switches the selling surface between a direct amount and the catalogue.
class PosModeSelector extends StatelessWidget {
  const PosModeSelector({
    super.key,
    required this.isSimple,
    required this.onChanged,
  });

  final bool isSimple;
  final ValueChanged<PosMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PosMode>(
      segments: const [
        ButtonSegment<PosMode>(value: PosMode.simple, label: Text('Simple')),
        ButtonSegment<PosMode>(value: PosMode.pos, label: Text('POS')),
      ],
      selected: {isSimple ? PosMode.simple : PosMode.pos},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}
