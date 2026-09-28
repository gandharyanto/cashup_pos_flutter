import 'package:flutter/material.dart';

import '../../util/debouncer.dart';

/// A text field for in-page or server search, debounced so a fast typist
/// does not fire one request per keystroke.
///
/// This is the one widget in this file that is a [StatefulWidget] — it owns
/// a [TextEditingController] (so it can show/hide the clear button and read
/// the current text) and a [Debouncer] (so [onChanged] fires once per typing
/// pause, not once per keystroke). Both are scoped to exactly this widget:
/// nothing about the current text or debounce timer is lifted any higher.
/// The clear-button visibility itself is driven by a
/// [ValueListenableBuilder] on the controller rather than `setState`, so a
/// keystroke rebuilds only that small suffix icon, not the whole field.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hintText,
    this.initialValue,
    this.debounce = const Duration(milliseconds: 300),
    this.autofocus = false,
    this.onSubmitted,
  });

  final ValueChanged<String> onChanged;
  final String? hintText;
  final String? initialValue;
  final Duration debounce;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late final Debouncer _debouncer = Debouncer(duration: widget.debounce);

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    _debouncer.run(() => widget.onChanged(value));
  }

  void _clear() {
    _debouncer.cancel();
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: _handleChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText ?? 'Cari...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, textValue, _) {
            if (textValue.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Hapus',
              onPressed: _clear,
            );
          },
        ),
      ),
    );
  }
}
