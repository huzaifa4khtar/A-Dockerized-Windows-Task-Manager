import 'package:flutter/material.dart';
import '../models/service.dart';
import '../services/api_service.dart';
import '../widgets/context_menu.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  OverlayEntry? _overlayEntry;
  late ScrollController _horizontalScrollController;
  late ScrollController _verticalScrollController;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _hideContextMenu();
    super.dispose();
  }

  void _showContextMenu(Offset position, int index, List<Service> services) {
    _hideContextMenu();
    Service service = services[index];

    final options = [
      if (service.status == 'Stopped')
        ContextMenuOption(
          label: 'Start',
          onTap: () => _startService(service),
        ),
      if (service.status == 'Running')
        ContextMenuOption(
          label: 'Stop',
          onTap: () => _stopService(service),
        ),
      if (service.status == 'Running')
        ContextMenuOption(
          label: 'Restart',
          onTap: () => _restartService(service),
        ),
    ];

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _hideContextMenu,
            child: Container(color: Colors.transparent),
          ),
          ContextMenu(
            position: position,
            options: options,
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideContextMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _startService(Service service) {
    _hideContextMenu();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Started service: ${service.name}')),
    );
    ApiService.startService(service.name);
  }

  void _stopService(Service service) {
    _hideContextMenu();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stopped service: ${service.name}')),
    );
    ApiService.stopService(service.name);
  }

  void _restartService(Service service) {
    _hideContextMenu();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restarted service: ${service.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalWidth = 150 + 80 + 250 + 100 + 150;
    totalWidth = totalWidth < MediaQuery.of(context).size.width 
        ? MediaQuery.of(context).size.width 
        : totalWidth;

    return FutureBuilder<List<Service>>(
      future: ApiService.fetchServices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                )
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No services found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final services = snapshot.data!;

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
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(150),
                        1: FixedColumnWidth(80),
                        2: FixedColumnWidth(250),
                        3: FixedColumnWidth(100),
                        4: FixedColumnWidth(150),
                      },
                      border: TableBorder(
                        horizontalInside: BorderSide(color: Colors.grey.shade700),
                        bottom: BorderSide(color: Colors.grey.shade700),
                      ),
                      children: [
                        _buildServiceHeaderRow(),
                        ..._buildServiceRows(services),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TableRow _buildServiceHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade900),
      children: [
        'Name',
        'PID',
        'Description',
        'Status',
      ]
          .map((col) => TableCell(
            child: Container(
              padding: const EdgeInsets.all(12),
              alignment: Alignment.centerLeft,
              child: Text(
                col,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ))
          .toList(),
    );
  }

  List<TableRow> _buildServiceRows(List<Service> services) {
    return services.asMap().entries.map((entry) {
      int index = entry.key;
      Service service = entry.value;

      return TableRow(
        decoration: BoxDecoration(
          color: index.isEven ? Colors.grey[850]! : Colors.grey[800]!,
        ),
        children: [
          _buildServiceCell(service.name, index, services),
          _buildServiceCell(service.pid?.toString() ?? '-', index, services),
          _buildServiceCell(service.description, index, services),
          _buildStatusCell(service.status, index, services),
        ],
      );
    }).toList();
  }

  Widget _buildServiceCell(String cellValue, int rowIndex, List<Service> services) {
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(details.globalPosition, rowIndex, services),
      child: MouseRegion(
        cursor: SystemMouseCursors.contextMenu,
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

  Widget _buildStatusCell(String status, int rowIndex, List<Service> services) {
    Color statusColor;
    if (status == 'Running') {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.red;
    }

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(details.globalPosition, rowIndex, services),
      child: MouseRegion(
        cursor: SystemMouseCursors.contextMenu,
        child: Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              border: Border.all(color: statusColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


