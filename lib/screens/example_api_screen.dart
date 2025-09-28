import 'package:flutter/material.dart';
import '../utils/token_handler.dart';

// Ejemplo de pantalla que consume otra API con validación automática de token
class ExampleApiScreen extends StatefulWidget {
  const ExampleApiScreen({super.key});

  @override
  State<ExampleApiScreen> createState() => _ExampleApiScreenState();
}

class _ExampleApiScreenState extends State<ExampleApiScreen> with TokenExpirationHandler {
  List<dynamic> data = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    // No cargar datos automáticamente al iniciar
  }

  // Ejemplo de cómo consumir una API con validación automática de token
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Primero validar que el token sigue siendo válido
      final isTokenValid = await checkTokenValidity();
      
      if (!isTokenValid) {
        // Si el token no es válido, checkTokenValidity ya maneja la navegación
        return;
      }

      // Si el token es válido, hacer la petición a la API
      final result = await makeAuthenticatedRequest(
        endpoint: '/users', // Ejemplo: endpoint para obtener usuarios
        method: 'GET',
      );

      if (mounted) {
        if (result['success']) {
          setState(() {
            data = result['data'] ?? [];
            isLoading = false;
          });
        } else if (result['tokenExpired'] == true) {
          // El token expiró durante la petición - se maneja automáticamente
        } else {
          setState(() {
            errorMessage = result['message'] ?? 'Error desconocido';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error de conexión: $e';
          isLoading = false;
        });
      }
    }
  }

  // Ejemplo de validación manual del token
  Future<void> _validateTokenManually() async {
    setState(() {
      isLoading = true;
    });

    try {
      final isValid = await checkTokenValidity();
      
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        if (isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Token válido - Puedes hacer peticiones'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Token expirado - Redirigiendo al login'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
        title: const Text('Ejemplo API con Token'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: _validateTokenManually,
            tooltip: 'Validar Token',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Cargar Datos',
          ),
        ],
      ),
      body: Column(
        children: [
          // Información sobre el funcionamiento
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Validación Automática de Token',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Presiona ✓ para validar el token manualmente\n'
                  '• Presiona ↻ para hacer una petición de ejemplo\n'
                  '• Si el token expira, serás redirigido automáticamente al login\n'
                  '• La validación usa: /api/Login/ValidarToken',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          
          // Botones de acción
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _validateTokenManually,
                    icon: const Icon(Icons.security),
                    label: const Text('Validar Token'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _loadData,
                    icon: const Icon(Icons.api),
                    label: const Text('Probar API'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Contenido principal
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Validando token o cargando datos...'),
                      ],
                    ),
                  )
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 80,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : data.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.data_usage,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No hay datos cargados\nPresiona "Probar API" para cargar datos',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: data.length,
                            itemBuilder: (context, index) {
                              final item = data[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(item['name'] ?? 'Sin nombre'),
                                  subtitle: Text(item['email'] ?? 'Sin email'),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
