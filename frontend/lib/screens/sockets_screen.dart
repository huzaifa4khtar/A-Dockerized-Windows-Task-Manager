import 'package:flutter/material.dart';
import '../models/socket.dart';
import '../services/api_service.dart';
import '../widgets/data_table.dart' as custom_table;
import '../widgets/context_menu.dart';

class SocketsScreen extends StatefulWidget {
  const SocketsScreen({super.key});

  @override
  State<SocketsScreen> createState() => _SocketsScreenState();
}

class _SocketsScreenState extends State<SocketsScreen> {
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
  }

  List<List<String>> _buildTableRows(List<SocketConnection> sockets) {
    return sockets
        .map((socket) => [
          socket.processName,
          socket.protocol,
          socket.localAddress,
          socket.localPort.toString(),
          socket.remoteAddress,
          socket.remotePort.toString(),
        ])
        .toList();
  }

  void _showContextMenu(Offset position, SocketConnection socket) {
    _hideContextMenu();

    final options = [
      ContextMenuOption(
        label: 'End Task',
        onTap: () => _endTask(socket),
      ),
      ContextMenuOption(
        label: 'End Process Tree',
        onTap: () => _endProcessTree(socket),
      ),
      ContextMenuOption(
        label: 'Go to Files',
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

  void _endTask(SocketConnection socket) async {
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
      final result = await ApiService.endProcess(socket.pid);
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
        // Refresh the socket list after successful termination
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

  void _endProcessTree(SocketConnection socket) {
    _hideContextMenu();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ended process tree for: ${socket.processName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SocketConnection>>(
      future: ApiService.fetchSockets(),
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
              'No sockets found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final sockets = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: custom_table.DataTable(
            columns: [
              'Name',
              'Protocol',
              'Local Address',
              'Local Port',
              'Remote Address',
              'Remote Port',
            ],
            rows: _buildTableRows(sockets),
            columnWidths: [150, 100, 150, 100, 150, 100],
            onRowRightClick: (index, position) {
              _showContextMenu(position, sockets[index]);
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

