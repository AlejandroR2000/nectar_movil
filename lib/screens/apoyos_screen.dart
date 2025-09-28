import 'package:flutter/material.dart';
import 'lista_apoyos_screen.dart';
import 'registrar_apoyo_screen.dart';
import '../services/auth_service.dart';

class ApoyosScreen extends StatefulWidget {
  const ApoyosScreen({super.key});

  @override
  State<ApoyosScreen> createState() => _ApoyosScreenState();
}

class _ApoyosScreenState extends State<ApoyosScreen> {
  Map<String, bool> apoyosPermissions = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
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
        title: const Text('Apoyos'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.support,
                                size: 32,
                                color: Colors.green,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Gestión de Apoyos',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'En esta sección podrás gestionar los apoyos y reportes.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Funcionalidades disponibles:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // Registrar Apoyo - Solo mostrar si tiene permiso para crear
                  if (apoyosPermissions['crearApoyo'] ?? false)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.add_box, color: Colors.green),
                        title: const Text('Registrar Apoyo'),
                        subtitle: const Text('Registrar nuevo apoyo para beneficiario'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegistrarApoyoScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  
                  // Lista de Apoyos - Mostrar si tiene permiso para ver apoyos
                  if (apoyosPermissions['apoyos'] ?? false)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.list_alt, color: Colors.orange),
                        title: const Text('Lista de Apoyos'),
                        subtitle: const Text('Ver todos los apoyos registrados'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ListaApoyosScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  
                  // Reportes - Solo mostrar si tiene permiso para crear apoyos
                  if (apoyosPermissions['crearApoyo'] ?? false)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.assessment, color: Colors.purple),
                        title: const Text('Reportes'),
                        subtitle: const Text('Generar reportes de apoyos entregados'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // TODO: Implementar reportes
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Funcionalidad en desarrollo')),
                          );
                        },
                      ),
                    ),
                  
                  // Mensaje si no tiene permisos
                  if (!(apoyosPermissions['apoyos'] ?? false) && !(apoyosPermissions['crearApoyo'] ?? false))
                    Expanded(
                      child: Center(
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
                                  'Sin acceso a funcionalidades',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No tienes permisos para acceder a las funciones de apoyos.',
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
                    ),
                ],
              ),
            ),
    );
  }
}
