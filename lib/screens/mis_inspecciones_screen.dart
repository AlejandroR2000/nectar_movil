import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../utils/token_handler.dart';

class MisInspeccionesScreen extends StatefulWidget {
  const MisInspeccionesScreen({super.key});

  @override
  State<MisInspeccionesScreen> createState() => _MisInspeccionesScreenState();
}

class _MisInspeccionesScreenState extends State<MisInspeccionesScreen> with TokenExpirationHandler {
  List<dynamic> inspecciones = [];
  bool isLoading = false;
  bool hasError = false;
  String errorMessage = '';
  
  // Paginación
  int currentPage = 1;
  int pageSize = 20;
  int totalRecords = 0;
  int totalPages = 0;
  
  // Búsqueda y filtros
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String searchField = 'folio'; // 'folio' o 'nombreContribuyente'
  String? statusFilter; // null = Todos, '0' = Verificado, '1' = No verificado

  @override
  void initState() {
    super.initState();
    _loadInspecciones();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInspecciones({bool isSearch = false}) async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      hasError = false;
      if (!isSearch) {
        inspecciones.clear();
        currentPage = 1;
      }
    });

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();

      if (token == null || userId == null) {
        if (mounted) {
          handleTokenExpiration();
        }
        return;
      }

      // Construir la URL con parámetros
      final queryParams = {
        'pageNumber': currentPage.toString(),
        'pageSize': pageSize.toString(),
        'idUsuarioCreacion': userId,
        if (searchQuery.isNotEmpty) 'search': searchQuery,
        if (searchQuery.isNotEmpty) 'searchField': searchField,
        if (statusFilter != null) 'status': statusFilter!,
      };

      final uri = Uri.parse(ApiConfig.obtenerRevisionesPorInspectorUrl).replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            totalRecords = data['totalRecords'] ?? 0;
            totalPages = data['totalPages'] ?? 0;
            
            if (isSearch || currentPage == 1) {
              inspecciones = List<dynamic>.from(data['revisiones'] ?? []);
            } else {
              inspecciones.addAll(List<dynamic>.from(data['revisiones'] ?? []));
            }
            
            isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          handleTokenExpiration();
        }
      } else {
        if (mounted) {
          setState(() {
            hasError = true;
            errorMessage = 'Error al cargar inspecciones: ${response.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasError = true;
          errorMessage = 'Error de conexión: $e';
          isLoading = false;
        });
      }
    }
  }

  void _searchInspecciones() {
    setState(() {
      searchQuery = _searchController.text.trim();
      currentPage = 1;
    });
    _loadInspecciones(isSearch: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      searchQuery = '';
      currentPage = 1;
    });
    _loadInspecciones(isSearch: true);
  }

  void _loadMoreInspecciones() {
    if (currentPage < totalPages && !isLoading) {
      setState(() {
        currentPage++;
      });
      _loadInspecciones();
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case '0':
        return 'Verificado';
      case '1':
        return 'No Verificado';
      default:
        return 'Desconocido';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case '0':
        return Colors.green;
      case '1':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatearFecha(String? fechaStr) {
    if (fechaStr == null) return 'N/A';
    try {
      final fecha = DateTime.parse(fechaStr);
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    } catch (e) {
      return fechaStr;
    }
  }

  void _showInspeccionDetail(Map<String, dynamic> inspeccion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle del modal
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Título con estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Folio: ${inspeccion['folio'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(inspeccion['status']?.toString()),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getStatusText(inspeccion['status']?.toString()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // Información principal
              _buildDetailCard('Información General', [
                _buildDetailRow('Folio Inspeccion', inspeccion['folio']),
                _buildDetailRow('Fecha de Inspeccion', _formatearFecha(inspeccion['fechaRegistro'])),
                _buildDetailRow('Tipo de Verificación', inspeccion['tipoVerificacionDescripcion']),
                _buildDetailRow('Observaciones', inspeccion['observaciones']),
              ]),
              
              
              // Información contribuyente
              _buildDetailCard('Información Contribuyente', [
                _buildDetailRow('RMC', inspeccion['rmc']),
                _buildDetailRow('Contribuyente', inspeccion['nombreContribuyente']),
                _buildDetailRow('Tipo de Verificación', inspeccion['tipoVerificacionDescripcion']),
                _buildDetailRow('Fecha de Registro', _formatearFecha(inspeccion['fechaRegistro'])),
                _buildDetailRow('Observaciones', inspeccion['observaciones']),
              ]),
              
              const SizedBox(height: 16),
              
              // Información de ubicación
              _buildDetailCard('Ubicación', [
                // _buildDetailRow('Dirección Contribuyente', inspeccion['direccionContribuyente']),
                // _buildDetailRow('Dirección Predio', inspeccion['direccionPredio']),
                _buildMapWidget(inspeccion['latitud'], inspeccion['longitud']),
              ]),
              
              const SizedBox(height: 16),
              
              // Información de documento/licencia
              if (inspeccion['idDocumento'] != null)
                _buildDetailCard('Licencia', [
                  _buildDetailRow('Razón Social', inspeccion['razonSocial']),
                  _buildDetailRow('Folio Licencia', inspeccion['folioLicencia']?.toString()),
                  _buildDetailRow('Vigencia', _formatearFecha(inspeccion['vigencia'])),
                ]),
              
              const SizedBox(height: 16),
              
              // Evidencias
              _buildDetailCard('Evidencias', [
                _buildDetailRow('Evidencia 1 (Fachada)', 
                  inspeccion['evidencia1'] == 'True' ? 'Sí' : 'No'),
                _buildDetailRow('Evidencia 2 (Permiso)', 
                  inspeccion['evidencia2'] == 'True' ? 'Sí' : 'No'),
              ]),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Inspecciones'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtros y búsqueda
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Campo de búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: searchField == 'folio' 
                        ? 'Buscar por folio...' 
                        : 'Buscar por nombre de contribuyente...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchInspecciones,
                        ),
                      ],
                    ),
                  ),
                  onSubmitted: (value) => _searchInspecciones(),
                ),
                const SizedBox(height: 12),
                // Filtros en una fila
                Row(
                  children: [
                    // Dropdown para campo de búsqueda
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: searchField,
                        decoration: const InputDecoration(
                          labelText: 'Buscar por',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'folio', child: Text('Folio')),
                          DropdownMenuItem(value: 'nombreContribuyente', child: Text('Contribuyente')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              searchField = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Dropdown para status
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Todos')),
                          DropdownMenuItem(value: '0', child: Text('Verificado')),
                          DropdownMenuItem(value: '1', child: Text('No Verificado')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            statusFilter = value;
                          });
                          _searchInspecciones();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Lista de inspecciones
          Expanded(
            child: isLoading && inspecciones.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(errorMessage),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _loadInspecciones(isSearch: true),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : inspecciones.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No se encontraron inspecciones',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadInspecciones(isSearch: true),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: inspecciones.length + (currentPage < totalPages ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == inspecciones.length) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: ElevatedButton(
                                        onPressed: isLoading ? null : _loadMoreInspecciones,
                                        child: isLoading
                                            ? const CircularProgressIndicator()
                                            : const Text('Cargar más'),
                                      ),
                                    ),
                                  );
                                }

                                final inspeccion = inspecciones[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () => _showInspeccionDetail(inspeccion),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Folio: ${inspeccion['folio'] ?? 'N/A'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(inspeccion['status']?.toString()),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _getStatusText(inspeccion['status']?.toString()),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Contribuyente: ${inspeccion['nombreContribuyente'] ?? 'N/A'}',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tipo: ${inspeccion['tipoVerificacionDescripcion'] ?? 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Fecha: ${_formatearFecha(inspeccion['fechaRegistro'])}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapWidget(dynamic latitud, dynamic longitud) {
    // Verificar que las coordenadas sean válidas
    if (latitud == null || longitud == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Ubicación no disponible',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Convertir a double si es necesario
    double lat = 0.0;
    double lng = 0.0;
    
    try {
      lat = double.parse(latitud.toString());
      lng = double.parse(longitud.toString());
    } catch (e) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 40, color: Colors.red),
                SizedBox(height: 8),
                Text(
                  'Coordenadas inválidas',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mapa de Ubicación:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 16.0,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('inspeccion_location'),
                    position: LatLng(lat, lng),
                    infoWindow: InfoWindow(
                      title: 'Ubicación de Inspección',
                      snippet: 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
                    ),
                  ),
                },
                zoomControlsEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                mapType: MapType.normal,
                compassEnabled: false,
                onTap: (LatLng position) {
                  // Opcional: Mostrar las coordenadas exactas al tocar el mapa
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Coordenadas: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}