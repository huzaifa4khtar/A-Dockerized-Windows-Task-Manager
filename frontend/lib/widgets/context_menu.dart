import 'package:flutter/material.dart';

class ContextMenu extends StatelessWidget {
  final Offset position;
  final List<ContextMenuOption> options;

  const ContextMenu({
    super.key,
    required this.position,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map((option) => ContextMenuItemWidget(option: option))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class ContextMenuItemWidget extends StatelessWidget {
  final ContextMenuOption option;

  const ContextMenuItemWidget({super.key, required this.option});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: option.enabled ? option.onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          option.label,
          style: TextStyle(
            color: option.enabled ? Colors.white : Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class ContextMenuOption {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  ContextMenuOption({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
}
