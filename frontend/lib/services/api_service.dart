import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user.dart';
import '../models/process.dart';
import '../models/file.dart';
import '../models/socket.dart';
import '../models/service.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8765';

  static Future<List<User>> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((user) => User.fromJson(user)).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching users: $e');
    }
  }

  static Future<List<Process>> fetchProcesses(String type) async {
    try {
      String endpoint;
      switch (type.toLowerCase()) {
        case 'background':
          endpoint = '$baseUrl/processes/background';
          break;
        case 'system':
          endpoint = '$baseUrl/processes/system';
          break;
        case 'app':
        default:
          endpoint = '$baseUrl/processes/app';
      }
      
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        List<Process> processes = jsonResponse.map((process) => Process.fromJson(process)).toList();
        
        Map<int, Process> pidMap = {};
        for (var process in processes) {
          if (!pidMap.containsKey(process.pid)) {
            pidMap[process.pid] = process;
          }
        }
        
        return pidMap.values.toList();
      } else {
        throw Exception('Failed to load processes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching processes: $e');
    }
  }

  static Future<List<Process>> fetchDetails() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/details'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((process) => Process.fromJson(process)).toList();
      } else {
        throw Exception('Failed to load details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching details: $e');
    }
  }

  static Future<List<FileAccess>> fetchFiles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/files'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((file) => FileAccess.fromJson(file)).toList();
      } else {
        throw Exception('Failed to load files: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching files: $e');
    }
  }

  static Future<List<SocketConnection>> fetchSockets() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sockets'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((socket) => SocketConnection.fromJson(socket))
            .toList();
      } else {
        throw Exception('Failed to load sockets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching sockets: $e');
    }
  }

  static Future<List<Service>> fetchServices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/services'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((service) => Service.fromJson(service)).toList();
      } else {
        throw Exception('Failed to load services: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching services: $e');
    }
  }

  static Future<Map<String, dynamic>> endProcess(int pid) async {
    try {
      final url = '$baseUrl/processes/$pid/end';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return {
          'success': jsonResponse['success'] ?? false,
          'message': jsonResponse['message'] ?? 'No message provided'
        };
      }
      return {
        'success': false,
        'message': 'HTTP ${response.statusCode}: ${response.reasonPhrase}'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error ending process: $e'
      };
    }
  }

  static Future<void> startService(String serviceName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/services/$serviceName/start'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to start service: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error starting service: $e');
    }
  }

  static Future<void> stopService(String serviceName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/services/$serviceName/stop'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to stop service: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error stopping service: $e');
    }
  }
}
