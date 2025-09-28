import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../utils/token_handler.dart';
import 'agregar_beneficiario_screen.dart';

class ListaBeneficiariosScreen extends StatefulWidget {
  const ListaBeneficiariosScreen({super.key});

  @override
  State<ListaBeneficiariosScreen> createState() => _ListaBeneficiariosScreenState();
}

class _ListaBeneficiariosScreenState extends State<ListaBeneficiariosScreen> with TokenExpirationHandler {
  List<dynamic> beneficiarios = [];
  bool isLoading = false;
  bool hasError = false;
  String errorMessage = '';
  
  // Paginación
  int currentPage = 1;
  int pageSize = 20;
  int totalRecords = 0;
  int totalPages = 0;
  
  // Búsqueda
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String searchField = 'nombre'; // Campo por defecto para buscar
  
  // Permisos
  Map<String, bool> apoyosPermissions = {};
  bool permissionsLoaded = false;
  
  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadBeneficiarios();
  }

  Future<void> _loadPermissions() async {
    try {
      final permissions = await AuthService.getApoyosPermissions();
      if (mounted) {
        setState(() {
          apoyosPermissions = permissions;
          permissionsLoaded = true;
        });
      }
    } catch (e) {
      print('❌ Error al cargar permisos: $e');
      if (mounted) {
        setState(() {
          permissionsLoaded = true; // Marcar como cargado aunque haya error
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBeneficiarios({bool isSearch = false}) async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      hasError = false;
      if (!isSearch) {
        beneficiarios.clear();
      }
    });

    try {
      // Verificar token válido
      final isTokenValid = await checkTokenValidity();
      if (!isTokenValid) return;

      // Construir URL
      String baseUrl = ApiConfig.obtenerBeneficiariosUrl;
      Map<String, String> queryParams = {
        'pageNumber': currentPage.toString(),
        'pageSize': pageSize.toString(),
      };

      // Agregar parámetros de búsqueda si existen
      if (searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
        queryParams['searchField'] = searchField;
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      
      //print('🌐 Llamando API: $uri');

      // Obtener headers con autenticación
      final headers = await AuthService.getAuthHeaders();
      
      final response = await http.get(uri, headers: headers);

      //print('📡 Respuesta API - Status: ${response.statusCode}');
      //print('📡 Respuesta API - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            beneficiarios = data['beneficiarios'] ?? [];
            currentPage = data['currentPage'] ?? 1;
            pageSize = data['pageSize'] ?? 20;
            totalRecords = data['totalRecords'] ?? 0;
            totalPages = data['totalPages'] ?? 0;
            isLoading = false;
          });
        }
        
        //print('✅ Beneficiarios cargados: ${beneficiarios.length}');
      } else if (response.statusCode == 401) {
        // Token expirado
        handleTokenExpiration();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al cargar beneficiarios: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = e.toString();
        });
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.trim();
      currentPage = 1; // Resetear a la primera página al buscar
    });
    
    if (searchQuery.isEmpty) {
      _loadBeneficiarios();
    } else {
      _loadBeneficiarios(isSearch: true);
    }
  }

  void _onSearchFieldChanged(String? newField) {
    if (newField != null) {
      setState(() {
        searchField = newField;
        currentPage = 1;
      });
      
      if (searchQuery.isNotEmpty) {
        _loadBeneficiarios(isSearch: true);
      }
    }
  }

  void _loadNextPage() {
    if (currentPage < totalPages && !isLoading) {
      setState(() {
        currentPage++;
      });
      _loadBeneficiarios();
    }
  }

  void _loadPreviousPage() {
    if (currentPage > 1 && !isLoading) {
      setState(() {
        currentPage--;
      });
      _loadBeneficiarios();
    }
  }

  void _showBeneficiarioDetail(dynamic beneficiario) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${beneficiario['nombre']} ${beneficiario['apellidoPaterno']} ${beneficiario['apellidoMaterno']}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('ID Beneficiario', beneficiario['idBeneficiario'].toString()),
                _buildDetailRow('CURP', beneficiario['curp'] ?? 'N/A'),
                _buildDetailRow('RFC', beneficiario['rfc'] ?? 'N/A'),
                _buildDetailRow('Fecha Registro', beneficiario['fechaRegistro'] ?? 'N/A'),
                const SizedBox(height: 16),
                const Text('Dirección:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (beneficiario['direccion'] != null) ...[
                  _buildDetailRow('Sector', beneficiario['direccion']['sectorHabitacional'] ?? 'N/A'),
                  _buildDetailRow('Colonia', beneficiario['direccion']['colonia'] ?? 'N/A'),
                  _buildDetailRow('Calle', beneficiario['direccion']['calle'] ?? 'N/A'),
                  _buildDetailRow('Número', beneficiario['direccion']['numeroPredio'] ?? 'N/A'),
                  _buildDetailRow('Cruzamientos', 
                    '${beneficiario['direccion']['cruzamiento1'] ?? ''} - ${beneficiario['direccion']['cruzamiento2'] ?? ''}'),
                ] else ...[
                  const Text('Sin información de dirección'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Beneficiarios'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Solo mostrar el botón si tiene permiso para crear beneficiarios
          if (permissionsLoaded && (apoyosPermissions['crearBeneficiario'] ?? false))
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () async {
                print('Navegando a Agregar Beneficiario');
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AgregarBeneficiarioScreen(),
                  ),
                );
                
                // Si se agregó un beneficiario exitosamente, recargar la lista
                if (result == true) {
                  _loadBeneficiarios();
                }
              },
              tooltip: 'Agregar Beneficiario',
            ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar beneficiarios...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged();
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) => _onSearchChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: searchField,
                        decoration: const InputDecoration(
                          labelText: 'Campo',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'nombre', child: Text('Nombre')),
                          DropdownMenuItem(value: 'curp', child: Text('CURP')),
                        ],
                        onChanged: _onSearchFieldChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: $totalRecords beneficiarios | Página $currentPage de $totalPages',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Lista de beneficiarios
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $errorMessage'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadBeneficiarios,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : beneficiarios.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No se encontraron beneficiarios'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: beneficiarios.length,
                            itemBuilder: (context, index) {
                              final beneficiario = beneficiarios[index];
                              final nombreCompleto = '${beneficiario['nombre']} ${beneficiario['apellidoPaterno']} ${beneficiario['apellidoMaterno']}';
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    child: Text(
                                      '${beneficiario['nombre']?.substring(0, 1) ?? '?'}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    nombreCompleto,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('CURP: ${beneficiario['curp'] ?? 'N/A'}'),
                                      Text('RFC: ${beneficiario['rfc'] ?? 'N/A'}'),
                                      if (beneficiario['direccion'] != null)
                                        Text('${beneficiario['direccion']['colonia'] ?? 'N/A'}'),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () => _showBeneficiarioDetail(beneficiario),
                                ),
                              );
                            },
                          ),
          ),
          
          // Controles de paginación
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: currentPage > 1 ? _loadPreviousPage : null,
                    child: const Text('Anterior'),
                  ),
                  Text('$currentPage / $totalPages'),
                  ElevatedButton(
                    onPressed: currentPage < totalPages ? _loadNextPage : null,
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
            ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () async {
      //     print('Navegando a Agregar Beneficiario desde FAB');
      //     final result = await Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (context) => const AgregarBeneficiarioScreen(),
      //       ),
      //     );
          
      //     // Si se agregó un beneficiario exitosamente, recargar la lista
      //     if (result == true) {
      //       _loadBeneficiarios();
      //     }
      //   },
      //   backgroundColor: Theme.of(context).primaryColor,
      //   foregroundColor: Colors.white,
      //   child: const Icon(Icons.person_add),
      //   tooltip: 'Agregar Beneficiario',
      // ),
    );
  }
}
