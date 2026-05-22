class Process {
  final int pid;
  final String name;
  final double cpuUsage; // cpuPercent from backend
  final int memoryUsage; // memoryKB from backend
  final double diskUsage; // MB/s (not provided by backend)
  final double networkUsage; // Mbps (not provided by backend)
  final double gpuUsage; // Percentage (not provided by backend)
  final String powerUsage; // (not provided by backend)
  final String? imagePath;
  final List<Process> subProcesses;
  final ProcessType type;
  final String status; // from details endpoint
  final String? username; // from details endpoint
  final String? uacVirtualization;
  final int processCount; // Number of processes in group
  final List<int> allPids; // All PIDs in the group

  Process({
    required this.pid,
    required this.name,
    required this.cpuUsage,
    required this.memoryUsage,
    this.diskUsage = 0.0,
    this.networkUsage = 0.0,
    this.gpuUsage = 0.0,
    this.powerUsage = 'Low',
    this.imagePath,
    this.subProcesses = const [],
    this.type = ProcessType.app,
    this.status = 'Running',
    this.username,
    this.processCount = 1,
    this.allPids = const [],
    this.uacVirtualization,
  });

  // For expandable processes
  bool isExpanded = false;

  factory Process.fromJson(Map<String, dynamic> json) {
    // Convert KB to MB (divide by 1024)
    int memoryKB = json['memoryKB'] ?? json['memoryUsage'] ?? 0;
    int memoryMB = (memoryKB / 1024).round();
    
    return Process(
      pid: json['pid'] ?? 0,
      name: json['name'] ?? '',
      cpuUsage: (json['cpuPercent'] ?? json['cpuUsage'] ?? 0).toDouble(),
      memoryUsage: memoryMB,
      diskUsage: (json['diskUsage'] ?? 0).toDouble(),
      networkUsage: (json['networkUsage'] ?? 0).toDouble(),
      gpuUsage: (json['gpuUsage'] ?? 0).toDouble(),
      powerUsage: json['powerUsage'] ?? 'Low',
      imagePath: json['imagePath'],
      subProcesses: json['subProcesses'] != null
          ? List<Process>.from(
              (json['subProcesses'] as List).map((p) => Process.fromJson(p)))
          : [],
      type: _parseProcessType(json['type'] ?? 'app'),
      status: json['status'] ?? 'Running',
      username: json['username'],
      uacVirtualization: json['uacVirtualization'],
      processCount: json['processCount'] ?? 1,
      allPids: json['allPids'] != null
          ? List<int>.from(json['allPids'])
          : [],
    );
  }

  static ProcessType _parseProcessType(String type) {
    switch (type.toLowerCase()) {
      case 'background':
        return ProcessType.background;
      case 'system':
        return ProcessType.system;
      default:
        return ProcessType.app;
    }
  }
}

enum ProcessType {
  app,
  background,
  system,
}
