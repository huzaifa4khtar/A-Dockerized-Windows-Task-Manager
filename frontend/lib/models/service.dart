class Service {
  final String name;
  final int? pid;
  final String description;
  final String status; // Running, Stopped
  final String group;

  Service({
    required this.name,
    this.pid,
    required this.description,
    required this.status,
    required this.group,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      name: json['serviceName'] ?? json['name'] ?? '',
      pid: json['pid'],
      description: json['displayName'] ?? json['description'] ?? '',
      status: json['status'] ?? 'Stopped',
      group: json['group'] ?? '',
    );
  }
}
