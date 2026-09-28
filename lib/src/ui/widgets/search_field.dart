/// A pill-shaped search input, debounced so a fast typist doesn't fire a
/// server search on every keystroke.
library;

import 'package:flutter/material.dart';

import '../../util/debouncer.dart';

/// A debounced search field. [onChanged] fires [debounce] after typing
/// pauses, not on every keystroke.
class SearchField extends StatefulWidget {
  /// Creates a search field.
  const SearchField({
    super.key,
    required this.onChanged,
    this.hintText,
    this.initialValue,
    this.debounce = const Duration(milliseconds: 300),
    this.autofocus = false,
    this.onSubmitted,
  });

  /// Called with the query text [debounce] after the last keystroke.
  final ValueChanged<String> onChanged;

  /// Placeholder text shown when empty.
  final String? hintText;

  /// Pre-fills the field without triggering [onChanged].
  final String? initialValue;

  /// The debounce window applied to [onChanged].
  final Duration debounce;

  /// Whether the field grabs focus as soon as it is built.
  final bool autofocus;

  /// Called immediately (not debounced) when the field is submitted, e.g.
  /// via the keyboard's search action.
  final ValueChanged<String>? onSubmitted;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  late final Debouncer _debouncer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _debouncer = Debouncer(duration: widget.debounce);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: (text) => _debouncer.run(() => widget.onChanged(text)),
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
