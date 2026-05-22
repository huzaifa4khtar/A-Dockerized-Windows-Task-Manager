import 'package:flutter/material.dart';
import '../models/process.dart';
import '../services/api_service.dart';
import '../widgets/data_table.dart' as custom_table;
import '../widgets/context_menu.dart';

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
  }

  List<List<String>> _buildTableRows(List<Process> allProcesses) {
    return allProcesses
        .map((process) => [
          process.name,
          process.pid.toString(),
          process.status,
          process.username ?? 'N/A',
          process.cpuUsage.toStringAsFixed(2),
          '${process.memoryUsage} K',
          process.uacVirtualization ?? 'N/A',
        ])
        .toList();
  }

  void _showContextMenu(Offset position, Process process) {
    _hideContextMenu();

    final options = [
      ContextMenuOption(
        label: 'End Task',
        onTap: () => _endTask(process),
      ),
      ContextMenuOption(
        label: 'End Process Tree',
        onTap: () => _endProcessTree(process),
      ),
      ContextMenuOption(
        label: 'Go to Files',
        onTap: () => Navigator.of(context).pop(),
      ),
      ContextMenuOption(
        label: 'Go to Socket',
        onTap: () => Navigator.of(context).pop(),
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

  void _endTask(Process process) async {
    _hideContextMenu();
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final result = await ApiService.endProcess(process.pid);
      if (!mounted) return;
      Navigator.of(context).pop();
      
      final success = result['success'] ?? false;
      final message = result['message'] ?? 'No message provided';
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Refresh the process list after successful termination
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _endProcessTree(Process process) {
    _hideContextMenu();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ended process tree for: ${process.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Process>>(
      future: ApiService.fetchDetails(),
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
              'No processes found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final allProcesses = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: custom_table.DataTable(
            columns: [
              'Name',
              'PID',
              'Status',
              'Username',
              'CPU',
              'Memory',
              'UAC Virtualization',
            ],
            rows: _buildTableRows(allProcesses),
            columnWidths: [150, 80, 100, 100, 80, 100, 150],
            onRowRightClick: (index, position) {
              _showContextMenu(position, allProcesses[index]);
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _hideContextMenu();
    super.dispose();
  }
}

