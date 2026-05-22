import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/file.dart';
import '../services/api_service.dart';
import '../widgets/data_table.dart' as custom_table;
import '../widgets/context_menu.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
  }

  void _showContextMenu(Offset position, FileAccess fileAccess) {
    _hideContextMenu();

    final options = [
      ContextMenuOption(
        label: 'End Task',
        onTap: () => _endTask(fileAccess),
      ),
      ContextMenuOption(
        label: 'End Process Tree',
        onTap: () => _endProcessTree(fileAccess),
      ),
      ContextMenuOption(
        label: 'Go to Socket',
        onTap: () => Navigator.of(context).pop(),
      ),
      ContextMenuOption(
        label: 'Go to Details',
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

  void _endTask(FileAccess fileAccess) async {
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
      final result = await ApiService.endProcess(fileAccess.pid);
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
        // Refresh the file list after successful termination
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

  void _endProcessTree(FileAccess fileAccess) {
    _hideContextMenu();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ended process tree for: ${fileAccess.processName}')),
    );
  }

  void _copyFilePath(String filePath) {
    Clipboard.setData(ClipboardData(text: filePath));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: $filePath')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FileAccess>>(
      future: ApiService.fetchFiles(),
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
              'No files found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final fileAccesses = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onSecondaryTapDown: (details) {
              // Find which row was right-clicked based on position
              final fileAccesses = snapshot.data!;
              if (fileAccesses.isNotEmpty) {
                _showContextMenu(details.globalPosition, fileAccesses[0]);
              }
            },
            child: custom_table.DataTable(
              columns: [
                'Process Name',
                'PID',
                'File Path (Click to Copy)',
                'Access Type',
              ],
              rows: fileAccesses.map((fileAccess) {
                return [
                  fileAccess.processName,
                  fileAccess.pid.toString(),
                  fileAccess.filePath,
                  fileAccess.accessType,
                ];
              }).toList(),
              columnWidths: [150, 80, 500, 120],
              onRowRightClick: (index, position) {
                _showContextMenu(position, snapshot.data![index]);
              },
              onRowTap: (rowIndex) {
                // Copy file path when clicking on row (File Path)
                if (snapshot.data![rowIndex].filePath != 'none') {
                  _copyFilePath(snapshot.data![rowIndex].filePath);
                }
              },
            ),
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


