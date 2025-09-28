import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/token_handler.dart';
import 'apoyos_menu_screen.dart';
import 'revisiones_menu_screen.dart';
import 'offline_map_manager_screen.dart';
import '../services/connectivity_service.dart';
// Importar FontAwesome para iconos
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TokenExpirationHandler {
  String? userName;
  String? userId;
  String? userEmail;
  String? userRole;
  bool isLoading = true;
  
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Permisos del usuario
  Map<String, bool> apoyosPermissions = {};
  Map<String, bool> revisionesPermissions = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _inicializarConectividad();
  }

  Future<void> _inicializarConectividad() async {
    await _connectivityService.initialize();
    
    _connectivityService.connectionChange.listen((isOnline) {
      // Por ahora solo mantenemos la conectividad sin hacer nada específico
    });
  }

  Future<void> _loadUserData() async {
    try {
      // Verificar si el token sigue siendo válido
      final isTokenValid = await checkTokenValidity();
      if (!isTokenValid) return; // Si el token no es válido, se maneja automáticamente

      final loadedUserName = await AuthService.getUserName();
      final loadedUserId = await AuthService.getUserId();
      final loadedUserEmail = await AuthService.getUserEmail();
      final loadedUserRole = await AuthService.getUserRole();
      
      // Cargar permisos del usuario
      final loadedApoyosPermissions = await AuthService.getApoyosPermissions();
      final loadedRevisionesPermissions = await AuthService.getRevisionesPermissions();
      
      if (mounted) {
        setState(() {
          userName = loadedUserName;
          userId = loadedUserId;
          userEmail = loadedUserEmail;
          userRole = loadedUserRole;
          apoyosPermissions = loadedApoyosPermissions;
          revisionesPermissions = loadedRevisionesPermissions;
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
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      // Mostrar diálogo de confirmación
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      );

      if (shouldLogout == true) {
        // Limpiar completamente todos los SharedPreferences
        await AuthService.logout();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesión cerrada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navegar al login y remover todas las rutas anteriores
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Future<void> _validateToken() async {
  //   setState(() {
  //     isLoading = true;
  //   });

  //   try {
  //     // Usar el método de validación que verifica contra el servidor
  //     final isValid = await checkTokenValidity();
      
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //       });

  //       if (isValid) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //             content: Text('Token válido - Sesión activa'),
  //             backgroundColor: Colors.green,
  //           ),
  //         );
  //         // Recargar datos del usuario
  //         _loadUserData();
  //       } else {
  //         // Si el token no es válido, el método checkTokenValidity ya maneja la navegación al login
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //             content: Text('Token expirado - Redirigiendo al login'),
  //             backgroundColor: Colors.orange,
  //           ),
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //       });
        
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error al validar token: $e'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nectar Móvil'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: _validateToken,
          //   tooltip: 'Validar Token',
          // ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
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
                  // Información del usuario
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 40,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bienvenido',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      userName ?? 'Cargando...',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (userRole != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          userRole!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (userEmail != null)
                            Row(
                              children: [
                                const Icon(Icons.email, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    userEmail!,
                                    style: const TextStyle(color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Menú principal
                  const Text(
                    'Menú Principal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tarjeta de Apoyos - Mostrar solo si el usuario tiene permisos
                  if ((apoyosPermissions['beneficiarios'] ?? false) || (apoyosPermissions['apoyos'] ?? false))
                    Card(
                      elevation: 6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ApoyosMenuScreen(),
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
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                                ),
                                child: const Icon(
                                  FontAwesomeIcons.handHoldingHand,
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
                                      'Gestionar beneficiarios y apoyos',
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
                  
                  // Mostrar SizedBox solo si se mostró la tarjeta de Apoyos
                  if ((apoyosPermissions['beneficiarios'] ?? false) || (apoyosPermissions['apoyos'] ?? false))
                    const SizedBox(height: 16),
                  
                  // Tarjeta de Revisiones - Mostrar solo si el usuario tiene permisos
                  if (revisionesPermissions['mostrarRevisiones'] ?? false)
                    Card(
                      elevation: 6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RevisionesMenuScreen(),
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
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                                ),
                                child: const Icon(
                                  FontAwesomeIcons.clipboardCheck,
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
                                      'Inspecciones',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Gestionar inspecciones',
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

                  // Mostrar SizedBox solo si el usuario tiene algún permiso (para separar del "Próximamente")
                  if (((apoyosPermissions['beneficiarios'] ?? false) || (apoyosPermissions['apoyos'] ?? false)) || 
                      (revisionesPermissions['mostrarRevisiones'] ?? false))
                    const SizedBox(height: 24),
                  
                  // Herramientas Adicionales
                  const Text(
                    'Herramientas Adicionales',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Mapas Offline
                  Card(
                    elevation: 4,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OfflineMapManagerScreen(),
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
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                              ),
                              child: const Icon(
                                Icons.map,
                                size: 32,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(width: 20),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mapas Offline',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Descargar mapas para uso sin conexión',
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
                  ),
                ],
                ),
              ),
            ),
    );
  }
}
