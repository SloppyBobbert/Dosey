import 'package:flutter/material.dart';

class SettingsAccordion extends StatefulWidget {
  const SettingsAccordion({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.expanded,
    this.onExpansionChanged,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<SettingsAccordion> createState() => _SettingsAccordionState();
}

class _SettingsAccordionState extends State<SettingsAccordion> {
  late bool _isExpanded = widget.initiallyExpanded;

  bool get _expanded => widget.expanded ?? _isExpanded;

  void _toggle() {
    final value = !_expanded;
    if (widget.expanded == null) {
      setState(() => _isExpanded = value);
    }
    widget.onExpansionChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: true,
            enabled: true,
            expanded: _expanded,
            label: widget.title,
            child: InkWell(
              onTap: _toggle,
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}
