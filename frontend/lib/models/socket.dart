class SocketConnection {
  final int pid;
  final String processName;
  final String protocol; // TCP, UDP
  final String localAddress;
  final int localPort;
  final String remoteAddress;
  final int remotePort;

  SocketConnection({
    required this.pid,
    required this.processName,
    required this.protocol,
    required this.localAddress,
    required this.localPort,
    required this.remoteAddress,
    required this.remotePort,
  });

  factory SocketConnection.fromJson(Map<String, dynamic> json) {
    return SocketConnection(
      pid: json['pid'] ?? 0,
      processName: json['processName'] ?? json['name'] ?? 'Unknown',
      protocol: json['protocol'] ?? 'TCP',
      localAddress: json['localAddress'] ?? '',
      localPort: json['localPort'] ?? 0,
      remoteAddress: json['remoteAddress'] ?? '',
      remotePort: json['remotePort'] ?? 0,
    );
  }
}
