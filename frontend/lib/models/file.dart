class FileAccess {
  final int pid;
  final String processName;
  final String filePath;
  final String accessType;

  FileAccess({
    required this.pid,
    required this.processName,
    required this.filePath,
    required this.accessType,
  });

  factory FileAccess.fromJson(Map<String, dynamic> json) {
    return FileAccess(
      pid: json['pid'] ?? 0,
      processName: json['processName'] ?? '',
      filePath: json['filePath'] ?? '',
      accessType: json['accessType'] ?? 'None',
    );
  }
}
