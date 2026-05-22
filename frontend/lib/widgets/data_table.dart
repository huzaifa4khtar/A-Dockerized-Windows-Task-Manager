import 'package:flutter/material.dart';

class DataTable extends StatefulWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final List<double>? columnWidths;
  final Function(int)? onRowTap;
  final Function(int, Offset)? onRowRightClick;

  const DataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnWidths,
    this.onRowTap,
    this.onRowRightClick,
  });

  @override
  State<DataTable> createState() => _DataTableState();
}

class _DataTableState extends State<DataTable> {
  late ScrollController _horizontalScrollController;
  late ScrollController _verticalScrollController;
  late List<double> _columnWidths;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();
    _columnWidths = widget.columnWidths != null
        ? List<double>.from(widget.columnWidths!)
        : List<double>.filled(widget.columns.length, 120.0);
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double totalWidth = _columnWidths.fold<double>(0, (sum, width) => sum + width);
    totalWidth = totalWidth < MediaQuery.of(context).size.width
        ? MediaQuery.of(context).size.width
        : totalWidth;

    return Scrollbar(
      controller: _horizontalScrollController,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _horizontalScrollController,
        child: Scrollbar(
          controller: _verticalScrollController,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            controller: _verticalScrollController,
            child: SizedBox(
              width: totalWidth,
              child: Table(
                columnWidths: _getColumnWidths(),
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey.shade700),
                  bottom: BorderSide(color: Colors.grey.shade700),
                ),
                children: [
                  _buildHeaderRow(),
                  ..._buildDataRows(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<int, TableColumnWidth> _getColumnWidths() {
    return Map.fromIterable(
      List.generate(_columnWidths.length, (i) => i),
      value: (i) => FixedColumnWidth(_columnWidths[i as int]),
    );
  }

  TableRow _buildHeaderRow() {
    List<Widget> headerCells = [];
    for (int i = 0; i < widget.columns.length; i++) {
      headerCells.add(
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              alignment: Alignment.centerLeft,
              child: Text(
                widget.columns[i],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
            if (i < widget.columns.length - 1)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        double newWidth = _columnWidths[i] + details.delta.dx;
                        if (newWidth > 40 && newWidth < 800) {
                          _columnWidths[i] = newWidth;
                        }
                      });
                    },
                    child: Container(
                      width: 8,
                      color: Colors.transparent,
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 2,
                        height: double.infinity,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade900),
      children: headerCells,
    );
  }

  List<TableRow> _buildDataRows() {
    return widget.rows.asMap().entries.map((entry) {
      int rowIndex = entry.key;
      List<String> row = entry.value;

      return TableRow(
        decoration: BoxDecoration(
          color: rowIndex.isEven ? Colors.grey[850]! : Colors.grey[800]!,
        ),
        children: row
            .map((cell) => _buildTableCell(cell, rowIndex))
            .toList(),
      );
    }).toList();
  }

  Widget _buildTableCell(String cellValue, int rowIndex) {
    return GestureDetector(
      onTap: widget.onRowTap != null ? () => widget.onRowTap!(rowIndex) : null,
      onSecondaryTapDown: widget.onRowRightClick != null
          ? (details) => widget.onRowRightClick!(rowIndex, details.globalPosition)
          : null,
      child: MouseRegion(
        cursor: widget.onRowTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerLeft,
          child: Text(
            cellValue,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
