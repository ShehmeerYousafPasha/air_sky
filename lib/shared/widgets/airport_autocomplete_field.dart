import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AirportAutocompleteField extends StatefulWidget {
  const AirportAutocompleteField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.options,
    required this.onSelected,
    this.prefixIcon,
    this.errorText,
  });

  final String label;
  final String initialValue;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final IconData? prefixIcon;
  final String? errorText;

  @override
  State<AirportAutocompleteField> createState() =>
      _AirportAutocompleteFieldState();
}

class _AirportAutocompleteFieldState extends State<AirportAutocompleteField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant AirportAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialValue != oldWidget.initialValue &&
        !_focusNode.hasFocus &&
        _controller.text != widget.initialValue) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        if (value.text.trim().isEmpty) {
          return widget.options;
        }

        return widget.options.where(
          (String airport) =>
              airport.toLowerCase().contains(value.text.trim().toLowerCase()),
        );
      },
      onSelected: (String selected) =>
          widget.onSelected(selected.toUpperCase()),
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            final ThemeData theme = Theme.of(context);
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.only(top: 6.h),
                  width: 320.w,
                  constraints: BoxConstraints(maxHeight: 220.h),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                          _focusNode.unfocus();
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          child: Text(option),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode textFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: textEditingController,
              focusNode: textFocusNode,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: widget.label,
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon)
                    : null,
                errorText: widget.errorText,
              ),
              onChanged: (String value) =>
                  widget.onSelected(value.toUpperCase()),
              onTapOutside: (_) => textFocusNode.unfocus(),
              onFieldSubmitted: (_) {
                textFocusNode.unfocus();
                onFieldSubmitted();
              },
              onEditingComplete: () {
                textFocusNode.unfocus();
                onFieldSubmitted();
              },
            );
          },
    );
  }
}
