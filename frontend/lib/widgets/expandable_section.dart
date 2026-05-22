import 'package:flutter/material.dart';

class ExpandableSection extends StatefulWidget {
  final String title;
  final List<ExpandableItem> items;
  final Function(int, Offset)? onItemRightClick;
  final VoidCallback? onExpandToggle;
  final List<String>? columnHeaders;

  const ExpandableSection({
    super.key,
    required this.title,
    required this.items,
    this.onItemRightClick,
    this.onExpandToggle,
    this.columnHeaders,
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  bool isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
              widget.onExpandToggle?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[850],
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '(${widget.items.length})',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            if (widget.columnHeaders != null && widget.columnHeaders!.isNotEmpty)
              _buildHeaderRow(),
            Column(
              children: widget.items.asMap().entries.map((entry) {
                int index = entry.key;
                ExpandableItem item = entry.value;
                return _buildItemRow(index, item);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade700),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              'Name',
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...widget.columnHeaders!
              .map((header) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: SizedBox(
                  width: 80,
                  child: Text(
                    header,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ))
              ,
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, ExpandableItem item) {
    return GestureDetector(
      onSecondaryTapDown: widget.onItemRightClick != null
          ? (details) => widget.onItemRightClick!(index, details.globalPosition)
          : null,
      child: MouseRegion(
        cursor: widget.onItemRightClick != null
            ? SystemMouseCursors.contextMenu
            : MouseCursor.defer,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: index.isEven ? Colors.grey[800]! : Colors.grey[700]!,
            border: Border(
              top: BorderSide(color: Colors.grey.shade700),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              ...item.details
                  .map((detail) => Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: SizedBox(
                      width: 80,
                      child: Text(
                        detail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ))
                  ,
            ],
          ),
        ),
      ),
    );
  }
}

class ExpandableItem {
  final String title;
  final String? subtitle;
  final List<String> details;

  ExpandableItem({
    required this.title,
    this.subtitle,
    required this.details,
  });
}
