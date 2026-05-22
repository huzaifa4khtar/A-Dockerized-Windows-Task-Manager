class User {
  final String username;
  final double totalCpuUsage; // Percentage
  final int totalMemoryUsage; // MB
  final double totalDiskUsage; // MB/s
  final double totalNetworkUsage; // Mbps
  final double totalGpuUsage; // Percentage
  final List<UserProcess> processes;

  User({
    required this.username,
    required this.totalCpuUsage,
    required this.totalMemoryUsage,
    required this.totalDiskUsage,
    required this.totalNetworkUsage,
    required this.totalGpuUsage,
    this.processes = const [],
  });

  bool isExpanded = false;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      totalCpuUsage: (json['totalCpuUsage'] ?? 0).toDouble(),
      totalMemoryUsage: json['totalMemoryUsage'] ?? 0,
      totalDiskUsage: (json['totalDiskUsage'] ?? 0).toDouble(),
      totalNetworkUsage: (json['totalNetworkUsage'] ?? 0).toDouble(),
      totalGpuUsage: (json['totalGpuUsage'] ?? 0).toDouble(),
      processes: json['processes'] != null
          ? List<UserProcess>.from(
              (json['processes'] as List).map((p) => UserProcess.fromJson(p)))
          : [],
    );
  }
}

class UserProcess {
  final int pid;
  final String processName;
  final double cpuUsage; // cpuPercent from backend
  final int memoryUsage; // memoryKB from backend
  final double diskUsage; // MB/s (not from backend)
  final double networkUsage; // Mbps (not from backend)
  final double gpuUsage; // Percentage (not from backend)

  UserProcess({
    required this.pid,
    required this.processName,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskUsage,
    required this.networkUsage,
    required this.gpuUsage,
  });

  factory UserProcess.fromJson(Map<String, dynamic> json) {
    return UserProcess(
      pid: json['pid'] ?? 0,
      processName: json['name'] ?? json['processName'] ?? '',
      cpuUsage: (json['cpuPercent'] ?? json['cpuUsage'] ?? 0).toDouble(),
      memoryUsage: json['memoryKB'] ?? json['memoryUsage'] ?? 0,
      diskUsage: (json['diskUsage'] ?? 0).toDouble(),
      networkUsage: (json['networkUsage'] ?? 0).toDouble(),
      gpuUsage: (json['gpuUsage'] ?? 0).toDouble(),
    );
  }
}
