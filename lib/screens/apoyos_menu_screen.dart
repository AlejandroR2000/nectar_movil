import 'package:flutter/material.dart';
import 'apoyos_screen.dart';
import 'lista_beneficiarios_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApoyosMenuScreen extends StatefulWidget {
  const ApoyosMenuScreen({super.key});

  @override
  State<ApoyosMenuScreen> createState() => _ApoyosMenuScreenState();
}

class _ApoyosMenuScreenState extends State<ApoyosMenuScreen> {
  Map<String, bool> apoyosPermissions = {};
  bool isLoading = true;
  Map<String, dynamic>? saldoApoyo;
  bool isSaldoLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadSaldoApoyo();
  }

  Future<void> _loadSaldoApoyo() async {
    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();
      
      if (token == null || userId == null) {
        throw Exception('Token o ID de usuario no disponible');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.obtenerSaldoApoyoUrl}?id=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            saldoApoyo = data;
            isSaldoLoading = false;
          });
        }
      } else if (response.statusCode == 404) {
      // Manejo específico para saldo no encontrado
      if (mounted) {
        setState(() {
          saldoApoyo = null;
          isSaldoLoading = false;
        });
      }
    } else if (response.statusCode == 401) {
        await AuthService.logout();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        throw Exception('Error al obtener saldo: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSaldoLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar saldo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _tieneSaldoDisponible {
    return saldoApoyo != null && 
           (saldoApoyo!['cantidadDisponible'] ?? 0) > 0;
  }

  Future<void> _loadPermissions() async {
    try {
      final permissions = await AuthService.getApoyosPermissions();
      if (mounted) {
        setState(() {
          apoyosPermissions = permissions;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar permisos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sección Apoyos'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado de la sección
                  Card(
                    elevation: 4,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.1),
                            Theme.of(context).primaryColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                FontAwesomeIcons.handHoldingHand,
                                size: 40,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sección de Apoyos',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Gestiona beneficiarios y apoyos',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sección de Saldo para Apoyo
                  Card(
                    elevation: 4,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.withOpacity(0.1),
                            Colors.green.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                FontAwesomeIcons.wallet,
                                size: 32,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Saldo para Apoyo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isSaldoLoading)
                            const Center(
                              child: CircularProgressIndicator(),
                            )
                          else if (saldoApoyo == null)
                            const Text(
                              'No tienes saldo autorizado. Contacta al soporte.',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSaldoItem(
                                    'Autorizado',
                                    saldoApoyo!['cantidadAutorizada']?.toDouble(),
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSaldoItem(
                                    'Disponible',
                                    saldoApoyo!['cantidadDisponible']?.toDouble(),
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSaldoItem(
                                    'Usado',
                                    saldoApoyo!['cantidadUsada']?.toDouble(),
                                    Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            if (!_tieneSaldoDisponible) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'No tienes saldo disponible. Contacta al soporte.',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Selecciona una opción:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Card para Beneficiarios - Solo mostrar si tiene permisos y cantidad autorizada
                  if (!isSaldoLoading && (apoyosPermissions['beneficiarios'] ?? false) && _tieneSaldoDisponible)
                    Card(
                      elevation: 6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () {
                          //print('Navegando directamente a Lista de Beneficiarios');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ListaBeneficiariosScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                                ),
                                child: const Icon(
                                  Icons.people,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Beneficiarios',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Gestionar información de beneficiarios',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Espacio entre cards solo si ambas están visibles
                  if (!isSaldoLoading && (apoyosPermissions['beneficiarios'] ?? false) && _tieneSaldoDisponible && (apoyosPermissions['apoyos'] ?? false) && _tieneSaldoDisponible)
                    const SizedBox(height: 16),
                  
                  // Card para Apoyos - Solo mostrar si tiene permiso para ver apoyos (no crear) y cantidad autorizada
                  if (!isSaldoLoading && (apoyosPermissions['apoyos'] ?? false) && _tieneSaldoDisponible)
                    Card(
                      elevation: 6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () {
                          //print('Navegando a pantalla de Apoyos');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ApoyosScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                                ),
                                child: const Icon(
                                  Icons.support,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Apoyos',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Gestionar apoyos y seguimiento',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Mensaje si no tiene permisos o no tiene cantidad autorizada
                  if (!(apoyosPermissions['beneficiarios'] ?? false) && !(apoyosPermissions['apoyos'] ?? false) || !_tieneSaldoDisponible)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 20),
                      child: Card(
                          elevation: 4,
                          child: Container(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  !_tieneSaldoDisponible 
                                    ? 'Sin saldo disponible'
                                    : 'Sin acceso a esta sección',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  !_tieneSaldoDisponible
                                    ? 'No tienes saldo disponible para acceder a las funciones de apoyos.'
                                    : 'No tienes permisos para acceder a las funciones de esta sección.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ),
                ],
                ),
              ),
            ),
    );
  }

  Widget _buildSaldoItem(String titulo, double? monto, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            monto != null ? '\$${monto.toStringAsFixed(2)}' : 'N/A',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}