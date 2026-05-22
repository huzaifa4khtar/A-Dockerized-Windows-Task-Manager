import 'package:flutter/material.dart';
import '../models/process.dart';
import '../services/api_service.dart';
import '../widgets/expandable_section.dart';
import '../widgets/context_menu.dart';

class ProcessScreen extends StatefulWidget {
  const ProcessScreen({super.key});

  @override
  State<ProcessScreen> createState() => _ProcessScreenState();
}

class _ProcessScreenState extends State<ProcessScreen> {
  OverlayEntry? _overlayEntry;
  List<ContextMenuOption>? _currentContextMenu;
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

  void _showContextMenu(Offset position, Process process, ProcessType type) {
    _hideContextMenu();

    _currentContextMenu = [
      ContextMenuOption(
        label: 'End Task',
        onTap: () => _endTask(process),
      ),
      ContextMenuOption(
        label: 'Go to Details',
        onTap: () => Navigator.of(context).pop(),
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
            options: _currentContextMenu!,
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

  @override
  Widget build(BuildContext context) {
    double minContentWidth = 24 + 150 + (16 * 6) + (80 * 6);
    double totalWidth = minContentWidth < MediaQuery.of(context).size.width
        ? MediaQuery.of(context).size.width
        : minContentWidth;

    return FutureBuilder<List<List<Process>>>(
      future: Future.wait([
        ApiService.fetchProcesses('app'),
        ApiService.fetchProcesses('background'),
        ApiService.fetchProcesses('system'),
      ]),
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

        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'No processes found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final data = snapshot.data!;
        final appsProcesses = data[0];
        final backgroundProcesses = data[1];
        final systemProcesses = data[2];

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
                    child: Column(
                      children: [
                        _buildProcessSection('Apps (${appsProcesses.length})', appsProcesses),
                        _buildProcessSection('Background Processes (${backgroundProcesses.length})', backgroundProcesses),
                        _buildProcessSection('Windows Processes (${systemProcesses.length})', systemProcesses),
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

  Widget _buildProcessSection(String title, List<Process> processes) {
    return ExpandableSection(
      title: title,
      columnHeaders: const ['CPU', 'Memory', 'Disk', 'Network', 'GPU', 'Power'],
      items: processes
          .map((process) => ExpandableItem(
            title: process.name,
            details: [
              '${process.cpuUsage.toStringAsFixed(1)}%',
              '${process.memoryUsage} MB',
              '${process.diskUsage.toStringAsFixed(1)} MB/s',
              '${process.networkUsage.toStringAsFixed(1)} Mbps',
              '${process.gpuUsage.toStringAsFixed(1)}%',
              process.powerUsage,
            ],
          ))
          .toList(),
      onItemRightClick: (index, position) {
        _showContextMenu(position, processes[index], processes[index].type);
      },
    );
  }
}

