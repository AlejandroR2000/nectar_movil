import 'package:flutter/material.dart';
import '../models/inspeccion_offline.dart';
import '../services/inspeccion_offline_service.dart';
import 'registrar_revision_screen.dart';

class InspeccionesPendientesScreen extends StatefulWidget {
  const InspeccionesPendientesScreen({Key? key}) : super(key: key);

  @override
  State<InspeccionesPendientesScreen> createState() => _InspeccionesPendientesScreenState();
}

class _InspeccionesPendientesScreenState extends State<InspeccionesPendientesScreen> {
  List<InspeccionOffline> _inspeccionesPendientes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarInspeccionesPendientes();
  }

  Future<void> _cargarInspeccionesPendientes() async {
    setState(() => _isLoading = true);
    
    final inspecciones = await InspeccionOfflineService.obtenerInspeccionesPendientes();
    
    setState(() {
      _inspeccionesPendientes = inspecciones;
      _isLoading = false;
    });
  }

  Future<void> _eliminarInspeccion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Inspección'),
        content: const Text('¿Estás seguro de que quieres eliminar esta inspección? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await InspeccionOfflineService.eliminarInspeccion(id);
      _cargarInspeccionesPendientes();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspección eliminada correctamente'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Notificar al menú de revisiones que hubo cambios
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _editarInspeccion(InspeccionOffline inspeccion) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegistrarRevisionScreen(
          inspeccionOffline: inspeccion,
        ),
      ),
    );

    if (result == true) {
      _cargarInspeccionesPendientes();
      // Notificar al menú de revisiones que se completó una inspección
      Navigator.pop(context, true);
    }
  }

  Widget _buildInspeccionCard(InspeccionOffline inspeccion) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12), // Reducido de 16 a 12
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Importante para evitar overflow
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    'PENDIENTE',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 10, // Reducido de 12 a 10
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  inspeccion.fechaInspeccion,
                  style: const TextStyle(
                    fontSize: 10, // Reducido de 12 a 10
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // Reducido de 12 a 8
            
            if (inspeccion.contribuyenteNombre != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.blue), // Reducido de 16 a 14
                  const SizedBox(width: 6), // Reducido de 8 a 6
                  Expanded(
                    child: Text(
                      'Contribuyente: ${inspeccion.contribuyenteNombre}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13, // Agregado tamaño específico
                      ),
                      maxLines: 2, // Agregado para evitar overflow
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6), // Reducido de 8 a 6
            ],
            
            if (inspeccion.predioDireccion != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.green), // Reducido de 16 a 14
                  const SizedBox(width: 6), // Reducido de 8 a 6
                  Expanded(
                    child: Text(
                      'Predio: ${inspeccion.predioDireccion}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13, // Agregado tamaño específico
                      ),
                      maxLines: 2, // Agregado para evitar overflow
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6), // Reducido de 8 a 6
            ],
            
            if (inspeccion.observaciones.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 14, color: Colors.grey), // Reducido de 16 a 14
                  const SizedBox(width: 6), // Reducido de 8 a 6
                  Expanded(
                    child: Text(
                      'Observaciones: ${inspeccion.observaciones}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12, // Agregado tamaño específico
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6), // Reducido de 8 a 6
            ],

            Wrap(
              spacing: 6, // Reducido de 8 a 6
              runSpacing: 4, // Agregado para mejor manejo en pantallas pequeñas
              children: [
                if (inspeccion.fotoFachadaPath != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt, size: 10, color: Colors.green.shade700), // Reducido de 12 a 10
                        const SizedBox(width: 3), // Reducido de 4 a 3
                        Text(
                          'Fachada',
                          style: TextStyle(
                            fontSize: 9, // Reducido de 10 a 9
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (inspeccion.fotoPermisoPath != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description, size: 10, color: Colors.blue.shade700), // Reducido de 12 a 10
                        const SizedBox(width: 3), // Reducido de 4 a 3
                        Text(
                          'Permiso',
                          style: TextStyle(
                            fontSize: 9, // Reducido de 10 a 9
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12), // Reducido de 16 a 12
            
            // Reorganizar botones para pantallas pequeñas
            LayoutBuilder(
              builder: (context, constraints) {
                // Si el ancho es muy pequeño, poner botones en columna
                if (constraints.maxWidth < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 36, // Altura fija más pequeña
                        child: OutlinedButton.icon(
                          onPressed: () => _editarInspeccion(inspeccion),
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Completar', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36, // Altura fija más pequeña
                        child: OutlinedButton.icon(
                          onPressed: () => _eliminarInspeccion(inspeccion.id),
                          icon: const Icon(Icons.delete, size: 14),
                          label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Pantallas normales - botones en fila
                  return Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36, // Altura fija más pequeña
                          child: OutlinedButton.icon(
                            onPressed: () => _editarInspeccion(inspeccion),
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Completar', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8), // Reducido de 12 a 8
                      Expanded(
                        child: SizedBox(
                          height: 36, // Altura fija más pequeña
                          child: OutlinedButton.icon(
                            onPressed: () => _eliminarInspeccion(inspeccion.id),
                            icon: const Icon(Icons.delete, size: 14),
                            label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspecciones Pendientes'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarInspeccionesPendientes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inspeccionesPendientes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_turned_in,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay inspecciones pendientes',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Las inspecciones guardadas sin conexión\naparecerán aquí',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reducido padding vertical
                      color: Colors.orange.shade50,
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16), // Reducido tamaño del icono
                          const SizedBox(width: 8), // Reducido de 12 a 8
                          Expanded(
                            child: Text(
                              '${_inspeccionesPendientes.length} inspección${_inspeccionesPendientes.length != 1 ? 'es' : ''} pendiente${_inspeccionesPendientes.length != 1 ? 's' : ''} de completar',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 13, // Reducido tamaño de fuente
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16), // Agregar padding inferior
                        itemCount: _inspeccionesPendientes.length,
                        itemBuilder: (context, index) {
                          return _buildInspeccionCard(_inspeccionesPendientes[index]);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
