import 'package:flutter/material.dart';
import '../services/offline_map_service.dart';

class OfflineMapManagerScreen extends StatefulWidget {
  const OfflineMapManagerScreen({super.key});

  @override
  State<OfflineMapManagerScreen> createState() => _OfflineMapManagerScreenState();
}

class _OfflineMapManagerScreenState extends State<OfflineMapManagerScreen> {
  bool _isDownloading = false;
  bool _mapsDownloaded = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  double _cacheSize = 0.0;
  int _currentTile = 0;
  int _totalTiles = 0;

  @override
  void initState() {
    super.initState();
    _checkMapStatus();
  }

  Future<void> _checkMapStatus() async {
    final downloaded = await OfflineMapService.areMapTilesDownloaded();
    final size = await OfflineMapService.getCacheSize();
    
    setState(() {
      _mapsDownloaded = downloaded;
      _cacheSize = size;
    });
  }

  Future<void> _downloadMaps() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Iniciando descarga...';
      _currentTile = 0;
      _totalTiles = 0;
    });

    try {
      await OfflineMapService.downloadMapTilesForValladolid(
        onProgress: (current, total) {
          setState(() {
            _currentTile = current;
            _totalTiles = total;
            _downloadProgress = current / total;
          });
        },
        onStatusUpdate: (message) {
          setState(() {
            _statusMessage = message;
          });
        },
      );

      await _checkMapStatus();
      
      setState(() {
        _isDownloading = false;
        _statusMessage = '¡Descarga completada exitosamente!';
      });

      _showMessage('Mapas de Valladolid descargados correctamente', Colors.green);

    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = 'Error durante la descarga: $e';
      });

      _showMessage('Error al descargar mapas: $e', Colors.red);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await _showConfirmDialog(
      'Eliminar Mapas Offline',
      '¿Estás seguro de que quieres eliminar todos los mapas descargados? Esto liberará espacio de almacenamiento pero requerirá conexión a internet para usar mapas.',
    );

    if (confirmed) {
      try {
        await OfflineMapService.clearMapCache();
        await _checkMapStatus();
        _showMessage('Cache de mapas eliminado correctamente', Colors.green);
      } catch (e) {
        _showMessage('Error al eliminar cache: $e', Colors.red);
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mapas Offline',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado de Mapas Offline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          _mapsDownloaded ? Icons.check_circle : Icons.error,
                          color: _mapsDownloaded ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _mapsDownloaded 
                              ? 'Mapas de Valladolid descargados' 
                              : 'Mapas no descargados',
                          style: TextStyle(
                            color: _mapsDownloaded ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (_cacheSize > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Espacio utilizado: ${_cacheSize.toStringAsFixed(1)} MB',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            if (_isDownloading) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Descargando Mapas...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(1)}% - $_currentTile de $_totalTiles tiles',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '• Los mapas offline permiten usar la aplicación sin conexión a internet',
                        style: TextStyle(height: 1.5),
                      ),
                      Text(
                        '• Se descargarán mapas de Valladolid, Yucatán (radio de 15 km)',
                        style: TextStyle(height: 1.5),
                      ),
                      Text(
                        '• La descarga puede tomar varios minutos dependiendo de tu conexión',
                        style: TextStyle(height: 1.5),
                      ),
                      Text(
                        '• Los mapas ocuparán aproximadamente 50-100 MB de almacenamiento',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              if (!_mapsDownloaded) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _downloadMaps,
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text(
                      'Descargar Mapas de Valladolid',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _downloadMaps,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Actualizar Mapas',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'Eliminar Mapas Offline',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ],
            
            if (_statusMessage.isNotEmpty && !_isDownloading) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
