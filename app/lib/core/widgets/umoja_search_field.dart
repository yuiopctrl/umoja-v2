import 'package:flutter/material.dart';

import '../localization/app_localizations_x.dart';

/// A clean, dedicated search field: search icon, clear button that
/// appears once there is text. Purely presentational — debounce and
/// query wiring stay with the caller.
class UmojaSearchField extends StatefulWidget {
  const UmojaSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  State<UmojaSearchField> createState() => _UmojaSearchFieldState();
}

class _UmojaSearchFieldState extends State<UmojaSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: context.l10n.clearSearchTooltip,
                onPressed: _clear,
              ),
        isDense: true,
      ),
    );
  }
}
