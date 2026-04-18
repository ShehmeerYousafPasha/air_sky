import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AirportAutocompleteField extends StatelessWidget {
  const AirportAutocompleteField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.options,
    required this.onSelected,
    this.prefixIcon,
  });

  final String label;
  final String initialValue;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      key: ValueKey<String>('$label-$initialValue'),
      initialValue: TextEditingValue(text: initialValue),
      optionsBuilder: (TextEditingValue value) {
        if (value.text.trim().isEmpty) {
          return options;
        }

        return options.where(
          (String airport) =>
              airport.toLowerCase().contains(value.text.trim().toLowerCase()),
        );
      },
      onSelected: (String selected) => onSelected(selected.toUpperCase()),
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
                        onTap: () => onSelected(option),
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
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
              ),
              onChanged: (String value) => onSelected(value.toUpperCase()),
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
    );
  }
}
