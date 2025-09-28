import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../utils/token_handler.dart';

class ListaApoyosScreen extends StatefulWidget {
  const ListaApoyosScreen({super.key});

  @override
  State<ListaApoyosScreen> createState() => _ListaApoyosScreenState();
}

class _ListaApoyosScreenState extends State<ListaApoyosScreen> with TokenExpirationHandler {
  List<dynamic> apoyos = [];
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
  String searchField = 'Beneficiario'; // Campo por defecto para buscar
  
  @override
  void initState() {
    super.initState();
    _loadApoyos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApoyos({bool isSearch = false}) async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      hasError = false;
      if (!isSearch) {
        apoyos.clear();
      }
    });

    try {
      // Verificar token válido
      final isTokenValid = await checkTokenValidity();
      if (!isTokenValid) return;

      // Construir URL
      String baseUrl = ApiConfig.obtenerApoyosPaginadoUrl;
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

      // print('📡 Respuesta API - Status: ${response.statusCode}');
      // print('📡 Respuesta API - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            apoyos = data['apoyos'] ?? [];
            currentPage = data['currentPage'] ?? 1;
            pageSize = data['pageSize'] ?? 20;
            totalRecords = data['totalRecords'] ?? 0;
            totalPages = data['totalPages'] ?? 0;
            isLoading = false;
          });
        }
        
      } else if (response.statusCode == 401) {
        // Token expirado
        handleTokenExpiration();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al cargar apoyos: $e');
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
      _loadApoyos();
    } else {
      _loadApoyos(isSearch: true);
    }
  }

  void _onSearchFieldChanged(String? newField) {
    if (newField != null) {
      setState(() {
        searchField = newField;
        currentPage = 1;
      });
      
      if (searchQuery.isNotEmpty) {
        _loadApoyos(isSearch: true);
      }
    }
  }

  void _loadNextPage() {
    if (currentPage < totalPages && !isLoading) {
      setState(() {
        currentPage++;
      });
      _loadApoyos();
    }
  }

  void _loadPreviousPage() {
    if (currentPage > 1 && !isLoading) {
      setState(() {
        currentPage--;
      });
      _loadApoyos();
    }
  }

  void _showApoyoDetail(dynamic apoyo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Apoyo - Folio ${apoyo['folio'] ?? 'N/A'}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Beneficiario', apoyo['beneficiario'] ?? 'N/A'),
                _buildDetailRow('CURP', apoyo['curp'] ?? 'N/A'),
                _buildDetailRow('RFC', apoyo['rfc'] ?? 'N/A'),
                const SizedBox(height: 16),
                
                const Text('Información del Apoyo:', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _buildDetailRow('Tipo de Apoyo', apoyo['tipoApoyo'] ?? 'N/A'),
                _buildDetailRow('Monto', '\$${apoyo['monto'] ?? '0'}'),
                _buildDetailRow('Folio', apoyo['folio'] ?? 'N/A'),
                _buildDetailRow('Fecha de Pago', _formatDate(apoyo['fechaPago'])),
                _buildDetailRow('Fecha de Registro', _formatDate(apoyo['fechaRegistro'])),
                
                if (apoyo['comentario'] != null && apoyo['comentario'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Comentario', apoyo['comentario']),
                ],
                
                const SizedBox(height: 16),
                const Text('Dirección:', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                
                if (apoyo['direccion'] != null) ...[
                  _buildDetailRow('Sector', apoyo['direccion']['sectorHabitacional'] ?? 'N/A'),
                  _buildDetailRow('Colonia', apoyo['direccion']['colonia'] ?? 'N/A'),
                  _buildDetailRow('Calle', apoyo['direccion']['calle'] ?? 'N/A'),
                  _buildDetailRow('Número', apoyo['direccion']['numeroPredio'] ?? 'N/A'),
                  if (apoyo['direccion']['numeroInterior'] != null && 
                      apoyo['direccion']['numeroInterior'].isNotEmpty &&
                      apoyo['direccion']['numeroInterior'] != '-')
                    _buildDetailRow('Número Interior', apoyo['direccion']['numeroInterior']),
                  _buildDetailRow('Cruzamientos', 
                    '${apoyo['direccion']['cruzamiento1'] ?? ''} - ${apoyo['direccion']['cruzamiento2'] ?? ''}'),
                  if (apoyo['direccion']['observaciones'] != null && 
                      apoyo['direccion']['observaciones'].isNotEmpty &&
                      apoyo['direccion']['observaciones'] != '-')
                    _buildDetailRow('Observaciones', apoyo['direccion']['observaciones']),
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
            width: 120,
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Apoyos'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
                          hintText: 'Buscar apoyos...',
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
                          DropdownMenuItem(value: 'Beneficiario', child: Text('Beneficiario')),
                          DropdownMenuItem(value: 'Folio', child: Text('Folio')),
                        ],
                        onChanged: _onSearchFieldChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: $totalRecords apoyos | Página $currentPage de $totalPages',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Lista de apoyos
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
                              onPressed: _loadApoyos,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : apoyos.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.support_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No se encontraron apoyos'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: apoyos.length,
                            itemBuilder: (context, index) {
                              final apoyo = apoyos[index];
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green,
                                    child: Text(
                                      '\$',
                                      style: const TextStyle(
                                        color: Colors.white, 
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    apoyo['beneficiario'] ?? 'Sin nombre',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('CURP: ${apoyo['curp'] ?? 'N/A'}'),
                                      Text('Tipo: ${apoyo['tipoApoyo'] ?? 'N/A'}', 
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Monto: \$${apoyo['monto'] ?? '0'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                          Text(
                                            'Folio: ${apoyo['folio'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () => _showApoyoDetail(apoyo),
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
    );
  }
}
