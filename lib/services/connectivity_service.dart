import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool> connectionChangeController = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Stream<bool> get connectionChange => connectionChangeController.stream;

  Future<void> initialize() async {
    _connectivity.onConnectivityChanged.listen(_connectionChange);
    await _updateConnectionStatus(await _connectivity.checkConnectivity());
  }

  void _connectionChange(List<ConnectivityResult> results) {
    _updateConnectionStatus(results);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    bool isOnline = false;
    
    try {
      if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        isOnline = false;
      } else {
        // Verificar conectividad real haciendo una petición
        final response = await http.get(
          Uri.parse('https://www.google.com'),
        ).timeout(const Duration(seconds: 10));
        isOnline = response.statusCode == 200;
      }
    } catch (e) {
      isOnline = false;
    }

    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      connectionChangeController.add(_isOnline);
    }
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(const Duration(seconds: 10));
      _isOnline = response.statusCode == 200;
    } catch (e) {
      _isOnline = false;
    }
    connectionChangeController.add(_isOnline);
    return _isOnline;
  }

  void dispose() {
    connectionChangeController.close();
  }
}
