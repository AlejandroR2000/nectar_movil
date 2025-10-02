import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'registrar_revision_screen.dart';
import 'inspecciones_pendientes_screen.dart';
import 'mis_inspecciones_screen.dart';
import '../services/auth_service.dart';
import '../services/inspeccion_offline_service.dart';
import '../services/connectivity_service.dart';

class RevisionesMenuScreen extends StatefulWidget {
  const RevisionesMenuScreen({super.key});

  @override
  State<RevisionesMenuScreen> createState() => _RevisionesMenuScreenState();
}

class _RevisionesMenuScreenState extends State<RevisionesMenuScreen> {
  Map<String, bool> revisionesPermissions = {};
  bool isLoading = true;
  int _inspeccionesPendientes = 0;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _cargarInspeccionesPendientes();
    _inicializarConectividad();
  }

  Future<void> _inicializarConectividad() async {
    final connectivityService = ConnectivityService();
    await connectivityService.initialize();
    _isOnline = connectivityService.isOnline;
    
    // Cargar inspecciones pendientes cuando está online
    if (_isOnline) {
      _cargarInspeccionesPendientes();
    }
    
    connectivityService.connectionChange.listen((bool isConnected) {
      if (mounted) {
        setState(() {
          _isOnline = isConnected;
        });
        
        // Actualizar contador cuando se conecte a internet
        if (isConnected) {
          _cargarInspeccionesPendientes();
        }
      }
    });
    
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _cargarInspeccionesPendientes() async {
    final inspecciones = await InspeccionOfflineService.obtenerInspeccionesPendientes();
    if (mounted) {
      setState(() {
        _inspeccionesPendientes = inspecciones.length;
      });
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final permissions = await AuthService.getRevisionesPermissions();
      if (mounted) {
        setState(() {
          revisionesPermissions = permissions;
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
        title: const Text('Sección Inspecciones'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView( // Agregar scroll para evitar overflow
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
                            Colors.blue.withOpacity(0.1),
                            Colors.blue.withOpacity(0.05),
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
                              FaIcon(
                                FontAwesomeIcons.clipboardCheck,
                                size: 40,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sección de Inspecciones',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Gestiona inspecciones de construcción, licencias comerciales y ambulantes',
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
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Selecciona una opción:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Card para Registrar Revisión - Solo mostrar si tiene permiso para crear
                  if (revisionesPermissions['crearRevision'] ?? false)
                    Card(
                      elevation: 6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegistrarRevisionScreen(),
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
                                child: const FaIcon(
                                  FontAwesomeIcons.rectangleList,
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
                                      'Registrar Inspección',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Registrar una nueva inspección en el sistema',
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
                  
                  // Mostrar SizedBox solo si tiene permisos para crear revisiones
                  if (revisionesPermissions['crearRevision'] ?? false)
                    const SizedBox(height: 16),
                  
                  // Card para Inspecciones Pendientes - Solo mostrar si hay conexión a internet
                  if (_isOnline)
                    Card(
                      elevation: 6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const InspeccionesPendientesScreen(),
                            ),
                          );
                          if (result == true) {
                            _cargarInspeccionesPendientes();
                          }
                        },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: _inspeccionesPendientes > 0 ? Colors.orange : Colors.grey,
                                borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                              ),
                              child: FaIcon(
                                FontAwesomeIcons.clockRotateLeft,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Inspecciones Pendientes',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (_inspeccionesPendientes > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$_inspeccionesPendientes',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _inspeccionesPendientes > 0
                                        ? (_inspeccionesPendientes == 1 
                                            ? '1 inspección guardada sin conexión'
                                            : '$_inspeccionesPendientes inspecciones guardadas sin conexión')
                                        : 'No hay inspecciones pendientes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _inspeccionesPendientes > 0 ? Colors.orange.shade700 : Colors.grey,
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
                  
                  const SizedBox(height: 16),
                  
                  // Card para Mis Inspecciones - Solo mostrar si tiene permisos para mostrar revisiones
                  if (revisionesPermissions['mostrarRevisiones'] ?? false)
                    Card(
                      elevation: 6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MisInspeccionesScreen(),
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
                                child: const FaIcon(
                                  FontAwesomeIcons.listCheck,
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
                                      'Mis Inspecciones',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Ver historial de inspecciones realizadas',
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
                  
                  // Mostrar SizedBox solo si tiene permisos para mostrar revisiones
                  if (revisionesPermissions['mostrarRevisiones'] ?? false)
                    const SizedBox(height: 16),
                  
                  // Card para futuras opciones (disponible siempre)
                  Card(
                    elevation: 6,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.3),
                              borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                            ),
                            child: const Icon(
                              Icons.more_horiz,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Próximamente',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Más funcionalidades estarán disponibles pronto',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Mensaje si no tiene permisos para crear revisiones
                  if (!(revisionesPermissions['crearRevision'] ?? false))
                    Center( // Removido Expanded y reemplazado por Center simple
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
                                  'Sin acceso a esta sección',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No tienes permisos para crear inspecciones.',
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
}
