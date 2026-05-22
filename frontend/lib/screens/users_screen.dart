import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/context_menu.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  OverlayEntry? _overlayEntry;
  Map<int, bool> expandedUsers = {};
  late ScrollController _horizontalScrollController;
  late ScrollController _verticalScrollController;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();
    expandedUsers = {};
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _hideContextMenu();
    super.dispose();
  }

  void _showContextMenu(Offset position, UserProcess process) {
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
        label: 'Open File Location',
        onTap: () => _openFileLocation(process),
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

  void _endTask(UserProcess process) {
    _hideContextMenu();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ended task: ${process.processName}')),
    );
  }

  void _endProcessTree(UserProcess process) {
    _hideContextMenu();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ended process tree for: ${process.processName}')),
    );
  }

  void _openFileLocation(UserProcess process) {
    _hideContextMenu();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening file location for: ${process.processName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: ApiService.fetchUsers(),
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
              'No users found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final users = snapshot.data!;
        
        if (expandedUsers.isEmpty) {
          expandedUsers = {for (int i = 0; i < users.length; i++) i: false};
        } else {
          final newExpandedUsers = <int, bool>{};
          for (int i = 0; i < users.length; i++) {
            newExpandedUsers[i] = expandedUsers[i] ?? false;
          }
          expandedUsers = newExpandedUsers;
        }

        double minContentWidth = 24 + 100 + (100 * 5) + (24 * 5);
        double totalWidth = minContentWidth < MediaQuery.of(context).size.width
            ? MediaQuery.of(context).size.width
            : minContentWidth;

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
                      children: users.asMap().entries.map((userEntry) {
                        int userIndex = userEntry.key;
                        User user = userEntry.value;
                        return _buildUserSection(userIndex, user);
                      }).toList(),
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

  Widget _buildUserSection(int userIndex, User user) {
    return Container(
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                expandedUsers[userIndex] = !expandedUsers[userIndex]!;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[850],
              child: Row(
                children: [
                  Icon(
                    expandedUsers[userIndex]!
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180, // Fixed width for username/process name column
                    child: Text(
                      '${user.username} (${user.processes.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: _buildUserStatItem('CPU', '${user.totalCpuUsage.toStringAsFixed(1)}%'),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: _buildUserStatItem('Memory', '${user.totalMemoryUsage} MB'),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: _buildUserStatItem('Disk', '${user.totalDiskUsage.toStringAsFixed(1)} MB/s'),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: _buildUserStatItem('Network', '${user.totalNetworkUsage.toStringAsFixed(1)} Mbps'),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: _buildUserStatItem('GPU', '${user.totalGpuUsage.toStringAsFixed(1)}%'),
                  ),
                ],
              ),
            ),
          ),
          if (expandedUsers[userIndex]!)
            Column(
              children: user.processes.asMap().entries.map((processEntry) {
                int processIndex = processEntry.key;
                UserProcess process = processEntry.value;
                return _buildUserProcessRow(userIndex, processIndex, process);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildUserStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProcessRow(int userIndex, int processIndex, UserProcess process) {
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(details.globalPosition, process),
      child: MouseRegion(
        cursor: SystemMouseCursors.contextMenu,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: processIndex.isEven
                ? Colors.grey[800]!
                : Colors.grey[700]!,
            border: Border(
              top: BorderSide(color: Colors.grey.shade700),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 32), // 24 + 8 for icon/spacing
              SizedBox(
                width: 180,
                child: Text(
                  process.processName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: Text(
                  '${process.cpuUsage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: Text(
                  '${(process.memoryUsage / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: Text(
                  '${process.diskUsage.toStringAsFixed(1)} MB/s',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: Text(
                  '${process.networkUsage.toStringAsFixed(1)} Mbps',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: Text(
                  '${process.gpuUsage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

