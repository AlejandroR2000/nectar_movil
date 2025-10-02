import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'map_location_picker_screen.dart';
import 'offline_map_location_picker_screen.dart';
import 'editar_contribuyente_screen.dart';
import 'qr_scan_screen.dart';
import '../services/offline_map_service.dart';
import '../services/connectivity_service.dart';
import '../services/inspeccion_offline_service.dart';
import '../models/inspeccion_offline.dart';

class RegistrarRevisionScreen extends StatefulWidget {
  final InspeccionOffline? inspeccionOffline;
  
  const RegistrarRevisionScreen({
    super.key,
    this.inspeccionOffline,
  });

  @override
  State<RegistrarRevisionScreen> createState() =>
      _RegistrarRevisionScreenState();
}

class _RegistrarRevisionScreenState extends State<RegistrarRevisionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contribuyenteController = TextEditingController();
  final _predioController = TextEditingController();
  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _vigenciaController = TextEditingController();
  final _licenciaController = TextEditingController();
  final _observacionesController = TextEditingController();

  // Estados de carga
  bool _isLoading = false;
  bool _isContribuyenteLoading = false;
  bool _isPredioLoading = false;
  bool _isTiposVerificacionLoading = true;

  // Variables para manejo offline
  bool _isOnline = true;
  final ConnectivityService _connectivityService = ConnectivityService();
  String? _inspeccionOfflineId;

  // Datos de las APIs
  List<Map<String, dynamic>> _tiposVerificacion = [];
  List<Map<String, dynamic>> _contribuyentes = [];
  List<Map<String, dynamic>> _predios = [];
  List<Map<String, dynamic>> _licencias = [];

  // Selecciones
  Map<String, dynamic>? _tipoVerificacionSeleccionado;
  Map<String, dynamic>? _contribuyenteSeleccionado;
  Map<String, dynamic>? _predioSeleccionado;
  Map<String, dynamic>? _licenciaSeleccionada;
  String _metodoCaptura = 'manual'; // 'manual' o 'qr'
  String _tipoBusquedaPredio = 'folio'; // 'folio', 'calle' o 'tablaje'

  // Fotos y ubicación
  File? _fotoFachada; // imgEvidencia1
  File? _fotoPermiso; // imgEvidencia2
  double? _latitud;
  double? _longitud;

  // Variables para manejar el escaneo de QR
  bool _vigenciaPorQR = false;
  bool _qrProcesado = false;
  int? _idDocumentoQR;
  //bool _qrInvalido = false;
  //bool _evitarAutoScanQR = false;

  // Variables para manejar la licencia
  bool _isLicenciaLoading = false;
  bool _ingresandoLicenciaManual = false;
  final FocusNode _licenciaFocusNode = FocusNode();
  final TextEditingController _licenciaManualController =
      TextEditingController();

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _inicializarConectividad();
    _cargarTiposVerificacion();
    _licenciaFocusNode.addListener(() {
      if (_licenciaFocusNode.hasFocus && _licencias.isEmpty && !_isLicenciaLoading) {
        _buscarLicencias('');
      }
    });
  }

  Future<void> _inicializarConectividad() async {
    await _connectivityService.initialize();
    _isOnline = _connectivityService.isOnline;
    
    // Escuchar cambios de conectividad
    _connectivityService.connectionChange.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  Future<void> _cargarDatosOfflineSiExisten() async {
    if (widget.inspeccionOffline != null) {
      final inspeccion = widget.inspeccionOffline!;
      _inspeccionOfflineId = inspeccion.id;
      
      // Cargar datos en los controllers
      if (inspeccion.contribuyenteNombre != null) {
        _contribuyenteController.text = inspeccion.contribuyenteNombre!;
        _contribuyenteSeleccionado = {
          'idContribuyente': inspeccion.contribuyenteId,
          'nombre': inspeccion.contribuyenteNombre,
        };
      }
      
      if (inspeccion.predioDireccion != null) {
        _predioController.text = inspeccion.predioDireccion!;
        _predioSeleccionado = {
          'idPredio': inspeccion.predioId,
          'direccion': inspeccion.predioDireccion,
        };
      }
      
      // Cargar tipo de verificación
      if (inspeccion.tipoVerificacionId != null) {
        // Buscar el tipo de verificación correcto en la lista
        final tipoEncontrado = _tiposVerificacion.firstWhere(
          (tipo) => tipo['id'].toString() == inspeccion.tipoVerificacionId.toString(),
          orElse: () => {
            'id': inspeccion.tipoVerificacionId,
            'descripcion': inspeccion.tipoVerificacionDescripcion,
          },
        );
        _tipoVerificacionSeleccionado = tipoEncontrado;
      }
      
      // Cargar fecha de vigencia
      if (inspeccion.fechaVigencia != null) {
        _vigenciaController.text = inspeccion.fechaVigencia!;
      }
      
      // Cargar licencia/giro comercial
      if (inspeccion.licenciaId != null) {
        _licenciaSeleccionada = {
          'id': inspeccion.licenciaId,
          'descripcion': inspeccion.licenciaDescripcion,
        };
      }
      
      _observacionesController.text = inspeccion.observaciones;
      _latitud = inspeccion.latitud;
      _longitud = inspeccion.longitud;
      
      // Cargar fotos si existen
      if (inspeccion.fotoFachadaPath != null) {
        _fotoFachada = File(inspeccion.fotoFachadaPath!);
      }
      
      if (inspeccion.fotoPermisoPath != null) {
        _fotoPermiso = File(inspeccion.fotoPermisoPath!);
      }
      
      setState(() {});
    }
  }

  @override
  void dispose() {
    _contribuyenteController.dispose();
    _predioController.dispose();
    _calleController.dispose();
    _numeroController.dispose();
    _vigenciaController.dispose();
    _licenciaManualController.dispose();
    _licenciaFocusNode.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _cargarTiposVerificacion() async {
    try {
      // Primero intentar cargar desde cache local
      await _cargarTiposVerificacionDesdeCache();
      
      // Luego intentar actualizar desde la API
      await _actualizarTiposVerificacionDesdeAPI();
    } catch (e) {
      setState(() {
        _isTiposVerificacionLoading = false;
      });
      
      // Si no hay datos en cache, mostrar mensaje de error
      if (_tiposVerificacion.isEmpty) {
        _mostrarMensaje(
          'Error: No hay tipos de verificación disponibles. Necesita conexión a internet para la primera carga.',
          Colors.red,
          Icons.error,
        );
      }
    }
    
    // Asegurar que siempre se quite el loading al final
    if (mounted) {
      setState(() {
        _isTiposVerificacionLoading = false;
      });
      
      // Cargar datos offline después de que se hayan cargado los tipos de verificación
      if (widget.inspeccionOffline != null) {
        _cargarDatosOfflineSiExisten();
      }
    }
  }

  Future<void> _cargarTiposVerificacionDesdeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tiposVerificacionCache = prefs.getString('tipos_verificacion_cache');
      
      if (tiposVerificacionCache != null) {
        final data = json.decode(tiposVerificacionCache);
        setState(() {
          _tiposVerificacion = List<Map<String, dynamic>>.from(data);
          _isTiposVerificacionLoading = false;
        });
      } else {
        // Cargar datos de ejemplo mientras no haya datos de la API
        setState(() {
          _tiposVerificacion = [
            {'id': 1, 'nombre': 'Verificación Predial'},
            {'id': 2, 'nombre': 'Verificación Comercial'},
            {'id': 3, 'nombre': 'Verificación Urbana'},
            {'id': 4, 'nombre': 'Verificación Ambiental'},
          ];
          _isTiposVerificacionLoading = false;
        });
      }
    } catch (e) {
      // Error silencioso, continuar con el flujo normal
    }
  }

  Future<void> _actualizarTiposVerificacionDesdeAPI() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.obtenerTiposVerificacionUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Solo actualizar si hay datos reales de la API
        if (data != null && data is List && data.isNotEmpty) {
          // Guardar en cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('tipos_verificacion_cache', json.encode(data));
          
          setState(() {
            _tiposVerificacion = List<Map<String, dynamic>>.from(data);
            _isTiposVerificacionLoading = false;
          });
          
        } else {
          setState(() {
            _isTiposVerificacionLoading = false;
          });
          
          if (_tiposVerificacion.isEmpty) {
            _mostrarMensaje(
              'No hay tipos de verificación configurados',
              Colors.orange,
              Icons.warning,
            );
          }
        }
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        // Si hay error en la API pero tenemos datos en cache, usar el cache
        if (_tiposVerificacion.isEmpty) {
          setState(() {
            _isTiposVerificacionLoading = false;
          });
          _mostrarMensaje(
            'Error al cargar tipos de verificación',
            Colors.orange,
            Icons.warning,
          );
        }
      }
    } catch (e) {
      // Error de conexión - usar datos de cache si están disponibles
      if (_tiposVerificacion.isEmpty) {
        setState(() {
          _isTiposVerificacionLoading = false;
        });
        _mostrarMensaje(
          'Sin conexión a internet. No hay datos disponibles.',
          Colors.orange,
          Icons.wifi_off,
        );
      } else {
        // Hay datos de cache, mostrar mensaje informativo
        _mostrarMensaje(
          'Sin conexión a internet.',
          Colors.blue,
          Icons.wifi_off,
        );
      }
    }
  }

  Future<void> _buscarContribuyentes(String query) async {
    // No buscar si está offline
    if (!_isOnline) {
      setState(() {
        _contribuyentes = [];
      });
      return;
    }
    
    if (query.length < 1) {
      setState(() {
        _contribuyentes = [];
      });
      return;
    }

    setState(() {
      _isContribuyenteLoading = true;
    });

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.obtenerContribuyentesPaginadoUrl}?pageNumber=1&pageSize=30&search=$query&searchField=nombreContribuyente',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _contribuyentes = List<Map<String, dynamic>>.from(
            data['contribuyentes'] ?? [],
          );
        });
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _contribuyentes = [];
        });
      }
    } catch (e) {
      setState(() {
        _contribuyentes = [];
      });
    } finally {
      setState(() {
        _isContribuyenteLoading = false;
      });
    }
  }

  Future<void> _buscarLicencias(String query) async {
    //print('Buscando giros comerciales: $query');
    // if (query.length < 2) {
    //   setState(() {
    //     _licencias = [];
    //   });
    //   return;
    // }

    setState(() {
      _isLicenciaLoading = true;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.obtenerGirosComercialesUrl}?search=$query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      //print('Respuesta body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _licencias = List<Map<String, dynamic>>.from(data ?? []);
          //print('Giros comerciales mapeados: $_licencias');
        });
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _licencias = [];
        });
      }
    } catch (e) {
      setState(() {
        _licencias = [];
      });
    } finally {
      setState(() {
        _isLicenciaLoading = false;
      });
    }
  }

  Future<void> _buscarContribuyentePorRmc(String rmc) async {
    setState(() {
      _isContribuyenteLoading = true;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.obtenerContribuyentesPaginadoUrl}?pageNumber=1&pageSize=30&search=$rmc&searchField=RMC',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = List<Map<String, dynamic>>.from(
          data['contribuyentes'] ?? [],
        );
        if (lista.isNotEmpty) {
          final contribuyente = lista.first;
          final nombreCompleto =
              '${contribuyente['nombre'] ?? ''} ${contribuyente['apellidoPaterno'] ?? ''} ${contribuyente['apellidoMaterno'] ?? ''}'
                  .trim();
          setState(() {
            _contribuyenteSeleccionado = contribuyente;
            _contribuyenteController.text = nombreCompleto;
          });
          // Guardar como último contribuyente seleccionado
          _guardarUltimoContribuyente(contribuyente);
        }
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      // Puedes mostrar un mensaje de error si quieres
    } finally {
      setState(() {
        _isContribuyenteLoading = false;
      });
    }
  }

  Future<void> _buscarPredios(String query) async {
    // No buscar si está offline
    if (!_isOnline) {
      setState(() {
        _predios = [];
      });
      return;
    }
    
    if (query.length < 2) {
      setState(() {
        _predios = [];
      });
      return;
    }

    setState(() {
      _isPredioLoading = true;
    });

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Usar el tipo de búsqueda seleccionado
      String searchField = _tipoBusquedaPredio;
      String searchQuery = query;

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.obtenerPrediosPaginadoUrl}?pageNumber=1&pageSize=30&search=$searchQuery&searchField=$searchField',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _predios = List<Map<String, dynamic>>.from(data['predios'] ?? []);
        });
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _predios = [];
        });
      }
    } catch (e) {
      setState(() {
        _predios = [];
      });
    } finally {
      setState(() {
        _isPredioLoading = false;
      });
    }
  }

  void _buscarPrediosPorCalle() {
    if (_calleController.text.isEmpty) {
      setState(() {
        _predios = [];
      });
      return;
    }

    // Construir la búsqueda: si hay número, usar formato calle-numero, sino solo calle
    final calle = _calleController.text.trim();
    final numero = _numeroController.text.trim();
    final searchQuery = numero.isNotEmpty ? '$calle-$numero' : calle;

    _buscarPredios(searchQuery);
  }

  Future<void> _seleccionarFechaVigencia() async {
    final fechaInicial = DateTime.now();
    final fechaFinal = DateTime(2030);

    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2000),
      lastDate: fechaFinal,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF1976D2),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada != null) {
      final formatoFecha = DateFormat('dd/MM/yyyy');
      setState(() {
        _vigenciaController.text = formatoFecha.format(fechaSeleccionada);
      });
    }
  }

  Future<void> _guardarInspeccionOffline() async {
    if (!_formKey.currentState!.validate()) {
      _mostrarMensaje(
        'Por favor, complete los campos básicos',
        Colors.orange,
        Icons.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generar ID único para la inspección offline
      final id = _inspeccionOfflineId ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      final inspeccionOffline = InspeccionOffline(
        id: id,
        contribuyenteId: _contribuyenteSeleccionado?['idContribuyente']?.toString(),
        contribuyenteNombre: _contribuyenteSeleccionado?['nombre'],
        predioId: _predioSeleccionado?['idPredio']?.toString(),
        predioDireccion: _predioSeleccionado?['direccion'],
        fechaInspeccion: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        observaciones: _observacionesController.text,
        fotoFachadaPath: _fotoFachada?.path,
        fotoPermisoPath: _fotoPermiso?.path,
        latitud: _latitud,
        longitud: _longitud,
        fechaCreacion: DateTime.now(),
        isCompleta: false,
        // Nuevos campos
        tipoVerificacionId: _tipoVerificacionSeleccionado?['id']?.toString(),
        tipoVerificacionDescripcion: _tipoVerificacionSeleccionado?['descripcion'],
        fechaVigencia: _vigenciaController.text.isNotEmpty ? _vigenciaController.text : null,
        licenciaId: _licenciaSeleccionada?['id']?.toString(),
        licenciaDescripcion: _licenciaSeleccionada?['descripcion'],
      );

      await InspeccionOfflineService.guardarInspeccion(inspeccionOffline);
      
      setState(() => _isLoading = false);

      _mostrarMensaje(
        'Inspección guardada offline correctamente',
        Colors.green,
        Icons.save_alt,
      );

      // Regresar a la pantalla anterior inmediatamente
      if (mounted) {
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarMensaje(
        'Error al guardar inspección offline: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  Future<void> _registrarRevision() async {
    // VALIDACIÓN REFORZADA - Bloquear completamente si hay problemas

    if (!_formKey.currentState!.validate()) {
      _mostrarMensaje(
        'Por favor, complete todos los campos requeridos',
        Colors.red,
        Icons.error,
      );
      return;
    }

    if (_tipoVerificacionSeleccionado == null) {
      _mostrarMensaje(
        'Debe seleccionar un tipo de verificación',
        Colors.red,
        Icons.error,
      );
      return;
    }

    // Solo validar giro comercial si está online (puede buscarlo)
    if (_isOnline &&
        _tipoVerificacionSeleccionado != null &&
        _tipoVerificacionSeleccionado!['descripcion']
            .toString()
            .toLowerCase()
            .contains('comercial') &&
        _metodoCaptura == 'manual' &&
        !_vigenciaPorQR && // <-- Agrega esto para excluir el caso QR
        _licenciaSeleccionada == null &&
        (!_ingresandoLicenciaManual || _licenciaManualController.text.isEmpty)) {
      _mostrarMensaje('Debe seleccionar un giro comercial', Colors.red, Icons.error);
      return;
    }

    // VALIDACIÓN CRÍTICA: Verificar datos completos del contribuyente solo si hay uno seleccionado
    // if (_contribuyenteSeleccionado != null && _esDireccionIncompleta(_contribuyenteSeleccionado)) {
    //   final mensajeDetallado = _getMensajeDireccionIncompleta(
    //     _contribuyenteSeleccionado,
    //   );
    //   _mostrarMensaje(
    //     'ERROR: No se puede registrar la inspección. $mensajeDetallado Complete la información del contribuyente antes de continuar.',
    //     Colors.red,
    //     Icons.error_outline,
    //   );
    //   return;
    // }

    // Solo validar predio si está online (puede buscarlo) y no es tipo ambulante
    if (_isOnline && _predioSeleccionado == null && !_esTipoAmbulante()) {
      _mostrarMensaje('Debe seleccionar un predio', Colors.red, Icons.error);
      return;
    }

    // VALIDACIÓN CRÍTICA: Verificar ubicación
    if (_latitud == null || _longitud == null) {
      _mostrarMensaje(
        'ERROR: Debe seleccionar una ubicación antes de continuar',
        Colors.red,
        Icons.error_outline,
      );
      return;
    }

    if ((_fotoPermiso != null || _vigenciaPorQR) &&
        _vigenciaController.text.isEmpty) {
      _mostrarMensaje(
        'Debe seleccionar una fecha de vigencia',
        Colors.red,
        Icons.error,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userId = await AuthService.getUserId();
      if (userId == null) {
        throw Exception('No se pudo obtener el ID del usuario');
      }

      // Preparar los datos como multipart/form-data
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.agregarRevisionUrl),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Comparar vigencia con fecha actual
      DateTime? vigencia;
      try {
        vigencia = DateFormat('dd/MM/yyyy').parse(_vigenciaController.text);
      } catch (_) {
        vigencia = null;
      }
      final hoy = DateTime.now();
      // final tieneVigencia =
      //     vigencia != null &&
      //     !vigencia.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
      final descripcion =
          _tipoVerificacionSeleccionado?['descripcion']
              ?.toString()
              .toLowerCase() ??
          '';
      final esComercial = descripcion.contains('comercial');

      String idDocumento = '0';
      String razonSocial = '';
      if (esComercial && _vigenciaPorQR && _idDocumentoQR != null) {
        // Si viene de QR, usa el id del QR
        idDocumento = _idDocumentoQR.toString();
      } else if (esComercial && _metodoCaptura == 'manual') {
        if (_licenciaSeleccionada != null) {
          idDocumento = _licenciaSeleccionada!['id'].toString();
        } else if (_ingresandoLicenciaManual &&
            _licenciaManualController.text.isNotEmpty) {
          idDocumento = '0';
          razonSocial = _licenciaManualController.text;
        }
      }
      // Lógica de status
      String status = '1'; // Por defecto
      // Comparar vigencia con fecha actual
      try {
        vigencia = DateFormat('dd/MM/yyyy').parse(_vigenciaController.text);
      } catch (_) {
        vigencia = null;
      }
      final vigenciaEsValida =
          vigencia != null &&
          !vigencia.isBefore(DateTime(hoy.year, hoy.month, hoy.day));

      if (_vigenciaPorQR && _fotoPermiso == null && vigenciaEsValida) {
        // Vigencia por QR, sin foto de permiso, y la vigencia es válida
        status = '0';
      } else if (_fotoPermiso == null) {
        // No hay foto de permiso (y no cumple el caso especial QR)
        status = '1';
      } else if (_fotoPermiso != null &&
          _vigenciaController.text.isNotEmpty &&
          vigenciaEsValida) {
        // Hay foto de permiso, hay vigencia y la vigencia es válida
        status = '0';
      } else {
        // Cualquier otro caso (incluye vigencia vencida)
        status = '1';
      }

      // Agregar campos
      request.fields['idPredio'] = _esTipoAmbulante()
          ? '0'
          : _predioSeleccionado!['idPredio'].toString();
      request.fields['idUsuarioCreacion'] = userId;
      request.fields['FechaRegistro'] = DateTime.now().toIso8601String();
      request.fields['FechaActualizacion'] = DateTime.now().toIso8601String();
      request.fields['Status'] = status;
      request.fields['idDocumento'] = idDocumento;
      request.fields['razonSocial'] = razonSocial;
      request.fields['idUsuarioUltiAct'] = userId;
      request.fields['Longitud'] = _longitud!
          .toString(); // Usar ! porque ya validamos que no es null
      request.fields['Latitud'] = _latitud!
          .toString(); // Usar ! porque ya validamos que no es null
      request.fields['Atributo'] = _metodoCaptura == 'qr' ? '1' : '0';
      request.fields['idTipoVerificacion'] =
          _tipoVerificacionSeleccionado!['id'].toString();
      request.fields['ID'] = '0';
      request.fields['idContribuyente'] = _contribuyenteSeleccionado != null
          ? _contribuyenteSeleccionado!['idContribuyente'].toString()
          : '0';
      if ((_fotoPermiso != null && _vigenciaController.text.isNotEmpty) ||
          (_vigenciaPorQR && _vigenciaController.text.isNotEmpty)) {
        request.fields['Vigencia'] = DateFormat(
          'dd/MM/yyyy',
        ).parse(_vigenciaController.text).toIso8601String();
      } else {
        request.fields['Vigencia'] = '';
      }
      request.fields['Evidencia1'] = _fotoFachada != null ? '1' : '0';
      request.fields['Evidencia2'] = _fotoPermiso != null ? '1' : '0';
      request.fields['Observaciones'] = _observacionesController.text;

      // Agregar las imágenes si existen
      if (_fotoFachada != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'imgEvidencia1',
            _fotoFachada!.path,
          ),
        );
      }
      if (_fotoPermiso != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'imgEvidencia2',
            _fotoPermiso!.path,
          ),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        _mostrarMensaje(
          'Inspección registrada exitosamente',
          Colors.green,
          Icons.check,
        );

        // Eliminar inspección offline si se registró desde una inspección pendiente
        if (widget.inspeccionOffline != null && _inspeccionOfflineId != null) {
          try {
            await InspeccionOfflineService.eliminarInspeccion(_inspeccionOfflineId!);
            print('Inspección offline eliminada después del registro exitoso');
          } catch (e) {
            print('Error al eliminar inspección offline: $e');
          }
        }

        // Limpiar formulario
        setState(() {
          _tipoVerificacionSeleccionado = null;
          _contribuyenteSeleccionado = null;
          _predioSeleccionado = null;
          _contribuyentes = [];
          _predios = [];
          _fotoFachada = null;
          _fotoPermiso = null;
          _latitud = null;
          _longitud = null;
          _vigenciaPorQR = false;
          //_evitarAutoScanQR = true;
        });
        _contribuyenteController.clear();
        _predioController.clear();
        _calleController.clear();
        _numeroController.clear();
        _vigenciaController.clear();
        _observacionesController.clear();
        _formKey.currentState!.reset();

        // Regresar a la pantalla anterior indicando que se registró exitosamente
        Navigator.pop(context, true);
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        // final responseBody = await response.stream.bytesToString();
        // print('Error al registrar inspección: status=${response.statusCode}, body=$responseBody');
        _mostrarMensaje(
          'Error al registrar la inspección',
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      _mostrarMensaje(
        'Error al registrar la inspección: $e',
        Colors.red,
        Icons.error,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _mostrarMensaje(String mensaje, Color color, IconData icono) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icono, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _seleccionarUbicacion() async {
    try {
      Widget screenToOpen;
      
      if (_isOnline) {
        // CON INTERNET: Usar Google Maps
        screenToOpen = MapLocationPickerScreen(
          initialLatitude: _latitud,
          initialLongitude: _longitud,
        );
      } else {
        // SIN INTERNET: Verificar si hay mapas offline disponibles
        final tieneMapasOffline = await OfflineMapService.areMapTilesDownloaded();
        
        if (tieneMapasOffline) {
          // Usar mapa offline
          screenToOpen = OfflineMapLocationPickerScreen(
            initialLatitude: _latitud,
            initialLongitude: _longitud,
          );
        } else {
          // No hay mapas offline, mostrar error
          _mostrarMensaje(
            'Sin conexión a internet y no hay mapas offline descargados. Descargue los mapas desde el menú principal.',
            Colors.red,
            Icons.wifi_off,
          );
          return;
        }
      }
      
      final resultado = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (context) => screenToOpen),
      );

      if (resultado != null) {
        setState(() {
          _latitud = resultado['latitude'];
          _longitud = resultado['longitude'];
        });
        _mostrarMensaje(
          'Ubicación seleccionada correctamente',
          Colors.green,
          Icons.check,
        );
      }
    } catch (e) {
      _mostrarMensaje(
        'Error al seleccionar ubicación: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  void _mostrarOpcionesFotoFachada() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _tomarFotoFachada();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Seleccionar de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarFotoFachada();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _tomarFotoFachada() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920, // HD width
        maxHeight: 1080, // HD height
        imageQuality: 70, // Calidad optimizada para ~2MB
      );

      if (image != null) {
        setState(() {
          _fotoFachada = File(image.path);
        });
        _mostrarMensaje('Foto de fachada capturada', Colors.green, Icons.check);
      }
    } catch (e) {
      _mostrarMensaje(
        'Error al capturar foto de fachada: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  void _seleccionarFotoFachada() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // HD width
        maxHeight: 1080, // HD height
        imageQuality: 70, // Calidad optimizada para ~2MB
      );

      if (image != null) {
        setState(() {
          _fotoFachada = File(image.path);
        });
        _mostrarMensaje('Foto de fachada seleccionada', Colors.green, Icons.check);
      }
    } catch (e) {
      _mostrarMensaje(
        'Error al seleccionar foto de fachada: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  void _mostrarOpcionesFotoPermiso() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _tomarFotoPermiso();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Seleccionar de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarFotoPermiso();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _tomarFotoPermiso() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920, // HD width
        maxHeight: 1080, // HD height
        imageQuality: 70, // Calidad optimizada para ~2MB
      );

      if (image != null) {
        setState(() {
          _fotoPermiso = File(image.path);
        });
        _mostrarMensaje('Foto de permiso capturada', Colors.green, Icons.check);
      }
    } catch (e) {
      _mostrarMensaje(
        'Error al capturar foto de permiso: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  void _seleccionarFotoPermiso() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // HD width
        maxHeight: 1080, // HD height
        imageQuality: 70, // Calidad optimizada para ~2MB
      );

      if (image != null) {
        setState(() {
          _fotoPermiso = File(image.path);
        });
        _mostrarMensaje('Foto de permiso seleccionada', Colors.green, Icons.check);
      }
    } catch (e) {
      _mostrarMensaje(
        'Error al seleccionar foto de permiso: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  void _eliminarFotoFachada() {
    setState(() {
      _fotoFachada = null;
    });
    _mostrarMensaje('Foto de fachada eliminada', Colors.orange, Icons.delete);
  }

  void _eliminarFotoPermiso() {
    setState(() {
      _fotoPermiso = null;
    });
    _mostrarMensaje('Foto de permiso eliminada', Colors.orange, Icons.delete);
  }

  Future<void> _cargarUltimoContribuyente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ultimoContribuyenteJson = prefs.getString('ultimo_contribuyente');
      
      if (ultimoContribuyenteJson != null) {
        final ultimoContribuyente = jsonDecode(ultimoContribuyenteJson);
        setState(() {
          _contribuyenteSeleccionado = Map<String, dynamic>.from(ultimoContribuyente);
        });
        _mostrarMensaje('Último contribuyente cargado', Colors.green, Icons.check);
      } else {
        _mostrarMensaje('No hay contribuyente anterior guardado', Colors.orange, Icons.info);
      }
    } catch (e) {
      _mostrarMensaje('Error al cargar último contribuyente: $e', Colors.red, Icons.error);
    }
  }

  Future<void> _cargarUltimoPredio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ultimoPredioJson = prefs.getString('ultimo_predio');
      
      if (ultimoPredioJson != null) {
        final ultimoPredio = jsonDecode(ultimoPredioJson);
        setState(() {
          _predioSeleccionado = Map<String, dynamic>.from(ultimoPredio);
          _calleController.text = _predioSeleccionado?['calle'] ?? '';
          _numeroController.text = _predioSeleccionado?['numero'] ?? '';
        });
        _mostrarMensaje('Último predio cargado', Colors.green, Icons.check);
      } else {
        _mostrarMensaje('No hay predio anterior guardado', Colors.orange, Icons.info);
      }
    } catch (e) {
      _mostrarMensaje('Error al cargar último predio: $e', Colors.red, Icons.error);
    }
  }

  Future<void> _guardarUltimoContribuyente(Map<String, dynamic> contribuyente) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ultimo_contribuyente', jsonEncode(contribuyente));
    } catch (e) {
      // No mostrar error al usuario, es funcionalidad secundaria
    }
  }

  Future<void> _guardarUltimoPredio(Map<String, dynamic> predio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ultimo_predio', jsonEncode(predio));
    } catch (e) {
      // No mostrar error al usuario, es funcionalidad secundaria
    }
  }

  // Función helper para verificar si los datos del contribuyente están incompletos
  bool _esDireccionIncompleta(Map<String, dynamic>? contribuyente) {
    if (contribuyente == null) {
      return true;
    }

    // Función helper para verificar si un valor está vacío o es inválido
    bool esCampoInvalido(String? valor) {
      if (valor == null) return true;
      final valorLimpio = valor.toString().trim().toLowerCase();
      return valorLimpio.isEmpty ||
          valorLimpio == 'sin colonia' ||
          valorLimpio == 'sin calle' ||
          valorLimpio == 'sin número' ||
          valorLimpio == 'sin teléfono' ||
          valorLimpio == 'sin email' ||
          valorLimpio == '-' ||
          valorLimpio == '0';
    }

    // Verificar dirección
    bool direccionIncompleta = false;
    if (contribuyente['direccion'] != null) {
      final direccion = contribuyente['direccion'];
      final calle = direccion['calle']?.toString() ?? '';
      final numeroPredio = direccion['numeroPredio']?.toString() ?? '';
      final colonia = direccion['Colonia']?.toString() ?? '';

      direccionIncompleta =
          esCampoInvalido(calle) ||
          esCampoInvalido(numeroPredio) ||
          esCampoInvalido(colonia);
    } else {
      direccionIncompleta = true;
    }

    // Verificar teléfono y email
    final telefono = contribuyente['telefono']?.toString() ?? '';
    final email = contribuyente['email']?.toString() ?? '';
    final telefonoIncompleto =
        esCampoInvalido(telefono) || telefono.replaceAll(' ', '').isEmpty;
    final emailIncompleto = esCampoInvalido(email);

    // Considerar incompleto si falta dirección, teléfono o email
    return direccionIncompleta || telefonoIncompleto || emailIncompleto;
  }

  // Función helper para obtener un mensaje específico sobre qué falta en los datos del contribuyente
  String _getMensajeDireccionIncompleta(Map<String, dynamic>? contribuyente) {
    if (contribuyente == null) {
      return 'No hay información del contribuyente disponible.';
    }

    // Función helper para verificar si un valor está vacío o es inválido
    bool esCampoInvalido(String? valor) {
      if (valor == null) return true;
      final valorLimpio = valor.toString().trim().toLowerCase();
      return valorLimpio.isEmpty ||
          valorLimpio == 'sin colonia' ||
          valorLimpio == 'sin calle' ||
          valorLimpio == 'sin número' ||
          valorLimpio == 'sin teléfono' ||
          valorLimpio == 'sin email' ||
          valorLimpio == '-' ||
          valorLimpio == '0';
    }

    List<String> faltantes = [];

    // Verificar dirección
    if (contribuyente['direccion'] != null) {
      final direccion = contribuyente['direccion'];
      final calle = direccion['calle']?.toString() ?? '';
      final numeroPredio = direccion['numeroPredio']?.toString() ?? '';
      final colonia = direccion['Colonia']?.toString() ?? '';

      if (esCampoInvalido(calle)) faltantes.add('calle');
      if (esCampoInvalido(numeroPredio)) faltantes.add('número de predio');
      if (esCampoInvalido(colonia)) faltantes.add('colonia');
    } else {
      faltantes.add('dirección completa');
    }

    // Verificar teléfono
    final telefono = contribuyente['telefono']?.toString() ?? '';
    if (esCampoInvalido(telefono) || telefono.replaceAll(' ', '').isEmpty) {
      faltantes.add('teléfono');
    }

    // Verificar email
    final email = contribuyente['email']?.toString() ?? '';
    if (esCampoInvalido(email)) {
      faltantes.add('email');
    }

    if (faltantes.isNotEmpty) {
      if (faltantes.length == 1) {
        return 'Falta información contribuyente: ${faltantes.first}.';
      } else if (faltantes.length == 2) {
        return 'Falta información contribuyente: ${faltantes.join(' y ')}.';
      } else {
        final ultimoElemento = faltantes.removeLast();
        return 'Falta información contribuyente: ${faltantes.join(', ')} y $ultimoElemento.';
      }
    }

    return 'Los datos del contribuyente están completos.';
  }

  // Función helper para verificar si el tipo de verificación es ambulante
  bool _esTipoAmbulante() {
    if (_tipoVerificacionSeleccionado == null) return false;
    final descripcion =
        _tipoVerificacionSeleccionado!['descripcion']
            ?.toString()
            .toLowerCase() ??
        '';
    return descripcion.contains('ambulante');
  }

  void _escanearQR() async {
    _qrProcesado = false; // Reinicia la bandera antes de escanear
    //_qrInvalido = false;

    if (_tipoVerificacionSeleccionado == null ||
        !_tipoVerificacionSeleccionado!['descripcion']
            .toString()
            .toLowerCase()
            .contains('comercial')) {
      if (!mounted) return;
      _mostrarMensaje(
        'Solo disponible para verificación comercial',
        Colors.orange,
        Icons.info,
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QrScannerScreen(
          onScan: (qrData) async {
            if (_qrProcesado) return; // Solo procesa el primer escaneo
            _qrProcesado = true;
            final uri = Uri.tryParse(qrData);
            if (!mounted) return;
            if (uri == null ||
                !uri.queryParameters.containsKey('idPredio') ||
                !uri.queryParameters.containsKey('folio')) {
              _mostrarMensaje('QR inválido', Colors.red, Icons.error);
              setState(() {
                //_qrInvalido = true; // Permitir manual si QR es inválido
                _metodoCaptura = 'manual';
              });
              Navigator.pop(context);
              return;
            }
            setState(() {
              //_qrInvalido = false;
            });
            final idPredio = uri.queryParameters['idPredio'];
            final folio = uri.queryParameters['folio'];
            print('ID Predio: $idPredio, Folio: $folio');
            // Consultar la API QR
            final apiUrl =
                '${ApiConfig.obtenerLicenciaQRUrl}?idPredio=$idPredio&folio=$folio';
            try {
              final response = await http.get(Uri.parse(apiUrl));
              if (!mounted) return;
              if (response.statusCode == 200) {
                final data = json.decode(response.body);

                // Buscar el predio por predioFolio usando tu función de búsqueda
                await _buscarPredios(data['predioFolio'].toString());
                final predioEncontrado = _predios.firstWhere(
                  (predio) =>
                      predio['folio'].toString() ==
                      data['predioFolio'].toString(),
                  orElse: () => {},
                );

                // Buscar el contribuyente por RMC usando la nueva función
                await _buscarContribuyentePorRmc(
                  data['contribuyenteRmc'].toString(),
                );

                if (!mounted) return;
                setState(() {
                  _predioSeleccionado = predioEncontrado.isNotEmpty
                      ? predioEncontrado
                      : null;
                  _vigenciaController.text = DateFormat(
                    'dd/MM/yyyy',
                  ).format(DateTime.parse(data['vigencia']));
                  _metodoCaptura = 'manual';
                  _vigenciaPorQR = true;
                  _idDocumentoQR = data['id'];
                  _licenciaController.text = data['descripcion'] ?? '';
                });

                if (!mounted) return;
                _mostrarMensaje(
                  predioEncontrado.isNotEmpty
                      ? 'Licencia escaneada correctamente'
                      : 'Predio no encontrado con el folio',
                  predioEncontrado.isNotEmpty ? Colors.green : Colors.orange,
                  predioEncontrado.isNotEmpty ? Icons.check : Icons.warning,
                );

                Navigator.pop(context);
              } else {
                if (!mounted) return;
                _mostrarMensaje(
                  'No se encontró información para el QR',
                  Colors.red,
                  Icons.error,
                );
                Navigator.pop(context);
              }
            } catch (e) {
              if (!mounted) return;
              _mostrarMensaje(
                'Error al consultar la API QR',
                Colors.red,
                Icons.error,
              );
              Navigator.pop(context);
            }
          },
        ),
      ),
    );

    if (result == 'manual') {
      setState(() {
        //_qrInvalido = true;
        _metodoCaptura = 'manual';
      });
    }
  }

  Future<void> _actualizarContribuyenteSeleccionado() async {
    if (_contribuyenteSeleccionado == null) return;

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final idContribuyente = _contribuyenteSeleccionado!['idContribuyente'];

      // Hacer un GET completo para obtener los datos actualizados con todas las relaciones
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.obtenerContribuyenteUrl}?idContribuyente=$idContribuyente',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Debug: Imprimir los datos recibidos

        // Si la API no devuelve los nombres de Colonia y Municipio, necesitamos obtenerlos
        if (data['direccion'] != null &&
            (data['direccion']['Colonia'] == null ||
                data['direccion']['Municipio'] == null)) {
          // Intentar obtener el nombre de la colonia desde la API de colonias
          final idColonia = data['direccion']['idColonia'];
          if (idColonia != null && idColonia != 0) {
            try {
              // Buscar en sectores para obtener información de la colonia
              final sectoresResponse = await http.get(
                Uri.parse(ApiConfig.obtenerSectoresHabitacionalesUrl),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
              );

              if (sectoresResponse.statusCode == 200) {
                final sectores = json.decode(sectoresResponse.body);

                // Buscar en todos los sectores para encontrar la colonia
                for (final sector in sectores) {
                  final coloniasResponse = await http.get(
                    Uri.parse(
                      '${ApiConfig.obtenerColoniasUrl}?idSectorHabitacional=${sector['id']}',
                    ),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/json',
                    },
                  );

                  if (coloniasResponse.statusCode == 200) {
                    final colonias = json.decode(coloniasResponse.body);
                    final coloniaEncontrada = colonias.firstWhere(
                      (colonia) => colonia['id'] == idColonia,
                      orElse: () => null,
                    );

                    if (coloniaEncontrada != null) {
                      // Actualizar los datos con el nombre de la colonia
                      data['direccion']['Colonia'] =
                          coloniaEncontrada['descripcion'];
                      data['direccion']['Municipio'] =
                          'Valladolid'; // Hardcoded como en la edición
                      break;
                    }
                  }
                }
              }
            } catch (e) {
              print('Error al obtener nombre de colonia: $e');
              // Si no podemos obtener el nombre, usar valores por defecto mejorados
              data['direccion']['Colonia'] = 'Colonia ID: $idColonia';
              data['direccion']['Municipio'] = 'Valladolid';
            }
          }
        }

        final nombreCompleto =
            '${data['nombre'] ?? ''} ${data['apellidoPaterno'] ?? ''} ${data['apellidoMaterno'] ?? ''}'
                .trim();
        setState(() {
          _contribuyenteSeleccionado = data;
          _contribuyenteController.text = nombreCompleto;
        });
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        print('Error al actualizar contribuyente: ${response.statusCode}');
        _mostrarMensaje(
          'Error al actualizar los datos del contribuyente',
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      print('Excepción al actualizar contribuyente: $e');
      _mostrarMensaje(
        'Error de conexión al actualizar contribuyente',
        Colors.red,
        Icons.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Inspección'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      resizeToAvoidBottomInset: false, // Evita que el botón se mueva al abrir teclado
      body: _isTiposVerificacionLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Contenido principal scrolleable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 16.0,
                      bottom: 16.0, // Padding fijo simple
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Información del formulario
                          Card(
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const FaIcon(
                                        FontAwesomeIcons.clipboardCheck,
                                        size: 32,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Nueva Inspección',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Complete los datos para registrar una nueva inspección.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Dropdown de tipo de verificación
                          _buildTipoVerificacionSection(),

                          // Mostrar resto del formulario solo si se ha seleccionado tipo de verificación
                          if (_tipoVerificacionSeleccionado != null) ...[
                            const SizedBox(height: 20),

                            // Método de captura
                            _buildMetodoCapturaSection(),
                            const SizedBox(height: 20),

                            // Mostrar formulario manual si está seleccionado
                            if (_metodoCaptura == 'manual') ...[
                              if (_tipoVerificacionSeleccionado != null &&
                                  _tipoVerificacionSeleccionado!['descripcion']
                                      .toString()
                                      .toLowerCase()
                                      .contains('comercial'))
                                _buildLicenciaSection(),
                              _buildContribuyenteSection(),
                              const SizedBox(height: 20),

                              // Solo mostrar sección de predio si NO es ambulante
                              if (!_esTipoAmbulante()) ...[
                                _buildPredioSection(),
                                const SizedBox(height: 20),
                              ],

                              _buildFotosSection(),
                              const SizedBox(height: 20),
                              _buildUbicacionSection(),
                              const SizedBox(height: 20),
                              // Campo de vigencia
                              _buildVigenciaSection(),
                              const SizedBox(height: 20),
                              // Campo de observaciones
                              _buildObservacionesSection(),
                              // Agregar espacio extra al final para que no se pegue al botón
                              const SizedBox(height: 20),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Botón fijo en la parte inferior con SafeArea
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child:
                          _metodoCaptura == 'manual' &&
                              _tipoVerificacionSeleccionado != null
                          ? _buildBotonRegistrar()
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTipoVerificacionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de Verificación *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Map<String, dynamic>>(
          value: _tipoVerificacionSeleccionado,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.checklist), // O Icons.assignment_outlined
          ),
          hint: const Text('Seleccionar tipo de verificación'),
          items: _tiposVerificacion.map((tipo) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: tipo,
              child: Text(tipo['descripcion'] ?? ''),
            );
          }).toList(),
          onChanged: (value) async {
            setState(() {
              _tipoVerificacionSeleccionado = value;

              // Si se selecciona ambulante, limpiar predio seleccionado
              if (_esTipoAmbulante()) {
                _predioSeleccionado = null;
                _predios = [];
                _predioController.clear();
                _calleController.clear();
                _numeroController.clear();
              }

              // Si es comercial, forzar método QR (solo permitir manual si QR inválido)
              // final descripcion =
              //     value?['descripcion']?.toString().toLowerCase() ?? '';
              // if (descripcion.contains('comercial')) {
              //   _metodoCaptura = 'qr';
              //   _qrInvalido = false;
              // } else {
              //   _metodoCaptura = 'manual';
              //   _qrInvalido = false;
              // }
            });

            // Si quieres que el escáner QR se abra automáticamente al seleccionar comercial, descomenta esto:
            // final descripcion =
            //     value?['descripcion']?.toString().toLowerCase() ?? '';
            // if (descripcion.contains('comercial') && !_evitarAutoScanQR) {
            //   await Future.delayed(
            //     const Duration(milliseconds: 200),
            //   ); // Espera a que el setState termine
            //   _escanearQR();
            // }
            // _evitarAutoScanQR = false;
          },
          validator: (value) {
            if (value == null) {
              return 'Debe seleccionar un tipo de verificación';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMetodoCapturaSection() {
    final descripcion = _tipoVerificacionSeleccionado?['descripcion']?.toString().toLowerCase() ?? '';
    final esComercial = descripcion.contains('comercial');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Método de Captura *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: _metodoCaptura == 'manual' ? 6 : 2,
                color: _metodoCaptura == 'manual' ? Colors.blue.shade50 : null,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _metodoCaptura = 'manual';
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.keyboard,
                          size: 32,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manual',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                elevation: _metodoCaptura == 'qr' ? 6 : 2,
                color: esComercial
                    ? (_metodoCaptura == 'qr' ? Colors.blue.shade50 : Colors.grey.shade100)
                    : Colors.grey.shade200,
                child: InkWell(
                  onTap: esComercial
                      ? () {
                          setState(() {
                            _metodoCaptura = 'qr';
                          });
                          _escanearQR();
                        }
                      : null, // Deshabilitado si no es comercial
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.qrcode,
                          size: 32,
                          color: esComercial ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'QR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: esComercial ? Colors.blue : Colors.grey,
                            fontSize: 12,
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
      ],
    );
  }

  
  // Widget _buildMetodoCapturaSection() {
  //   final descripcion =
  //       _tipoVerificacionSeleccionado?['descripcion']
  //           ?.toString()
  //           .toLowerCase() ??
  //       '';
  //   final esComercial = descripcion.contains('comercial');
  //   final soloQR = esComercial && !_qrInvalido;

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text(
  //         'Método de Captura *',
  //         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //       ),
  //       const SizedBox(height: 8),
  //       Row(
  //         children: [
  //           Expanded(
  //             child: Card(
  //               elevation: _metodoCaptura == 'manual' ? 6 : 2,
  //               color: _metodoCaptura == 'manual' ? Colors.blue.shade50 : null,
  //               child: InkWell(
  //                 onTap: (!soloQR)
  //                     ? () {
  //                         setState(() {
  //                           _metodoCaptura = 'manual';
  //                         });
  //                       }
  //                     : null, // Desactivado si soloQR es true
  //                 child: Padding(
  //                   padding: const EdgeInsets.all(16.0),
  //                   child: Column(
  //                     children: [
  //                       FaIcon(
  //                         FontAwesomeIcons.keyboard,
  //                         size: 32,
  //                         color: (!soloQR) ? Colors.blue : Colors.grey,
  //                       ),
  //                       const SizedBox(height: 8),
  //                       Text(
  //                         'Manual',
  //                         style: TextStyle(
  //                           fontWeight: FontWeight.bold,
  //                           color: (!soloQR) ? Colors.blue : Colors.grey,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ),
  //           const SizedBox(width: 16),
  //           Expanded(
  //             child: Card(
  //               elevation: _metodoCaptura == 'qr' ? 6 : 2,
  //               color: _metodoCaptura == 'qr'
  //                   ? Colors.blue.shade50
  //                   : Colors.grey.shade100,
  //               child: InkWell(
  //                 onTap: esComercial
  //                     ? () {
  //                         setState(() {
  //                           _metodoCaptura = 'qr';
  //                         });
  //                         _escanearQR();
  //                       }
  //                     : null,
  //                 child: Padding(
  //                   padding: const EdgeInsets.all(16.0),
  //                   child: Column(
  //                     children: [
  //                       FaIcon(
  //                         FontAwesomeIcons.qrcode,
  //                         size: 32,
  //                         color: esComercial
  //                             ? Colors.blue
  //                             : Colors.grey.shade400,
  //                       ),
  //                       const SizedBox(height: 8),
  //                       Text(
  //                         esComercial ? 'QR' : 'QR (Próximamente)',
  //                         style: TextStyle(
  //                           fontWeight: FontWeight.bold,
  //                           color: esComercial
  //                               ? Colors.blue
  //                               : Colors.grey.shade400,
  //                           fontSize: 12,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //       // if (soloQR)
  //       //   Padding(
  //       //     padding: const EdgeInsets.only(top: 8.0),
  //       //     child: Text(
  //       //       'Solo puede registrar usando QR para verificación comercial. Si el QR es inválido, podrá usar el modo manual.',
  //       //       style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
  //       //     ),
  //       //   ),
  //     ],
  //   );
  // }

  Widget _buildLicenciaSection() {
    if (_vigenciaPorQR &&
        _idDocumentoQR != null &&
        _licenciaSeleccionada == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Razon Social *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Licencia escaneada:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Razón Social: ${_licenciaController.text.isNotEmpty ? _licenciaController.text : 'Licencia escaneada por QR'}',
                  ),
                  // Puedes agregar más campos si los tienes disponibles del QR
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Giro Comercial *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Mostrar búsqueda solo si no hay licencia seleccionada y NO está ingresando manualmente
        if (_licenciaSeleccionada == null && !_ingresandoLicenciaManual) ...[
          TextFormField(
            controller: _licenciaController,
            focusNode: _licenciaFocusNode,
            decoration: InputDecoration(
              labelText: 'Buscar giro comercial',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isLicenciaLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _buscarLicencias,
            
          ),

          // Lista de licencias encontradas
          if (_licencias.isNotEmpty) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                final availableHeight = MediaQuery.of(context).size.height - keyboardHeight - 200;
                final maxHeight = availableHeight > 120 ? availableHeight * 0.3 : 120.0;
                final minHeight = maxHeight < 100 ? maxHeight : 100.0; // Asegurar que minHeight <= maxHeight
                
                return Container(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                    minHeight: minHeight,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _licencias.length,
                      itemBuilder: (context, index) {
                  final licencia = _licencias[index];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _licenciaSeleccionada = licencia;
                        _licenciaController.text = licencia['descripcion'] ?? '';
                        _licencias = [];
                      });
                      // NO llamar unfocus() - deja que el usuario maneje el teclado
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: index < _licencias.length - 1
                            ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                            : null,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business, color: Color.fromARGB(255, 93, 93, 94), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              licencia['descripcion'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
                );
              },
            ),
          ],

          // Mensaje si no hay licencias encontradas
          if (_licencias.isEmpty &&
              _licenciaController.text.length >= 2 &&
              !_isLicenciaLoading) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'No se encontró el giro comercial. Selecciona "Sin Giro"',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ElevatedButton.icon(
                  //   icon: const Icon(Icons.edit),
                  //   label: const Text('Ingresar Manual'),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.blue,
                  //     foregroundColor: Colors.white,
                  //   ),
                  //   onPressed: () {
                  //     setState(() {
                  //       _ingresandoLicenciaManual = true;
                  //       _licenciaManualController.text = '';
                  //       _licenciaController.clear();
                  //     });
                  //   },
                  // ),
                ],
              ),
            ),
          ],
        ],

        // Campo para ingresar manualmente la licencia
        // if (_ingresandoLicenciaManual && _licenciaSeleccionada == null) ...[
        //   const SizedBox(height: 8),
        //   TextFormField(
        //     controller: _licenciaManualController,
        //     decoration: const InputDecoration(
        //       labelText: 'Nombre de la licencia (manual)',
        //       border: OutlineInputBorder(),
        //       prefixIcon: Icon(Icons.edit),
        //     ),
        //     validator: (value) {
        //       if (_ingresandoLicenciaManual && (value == null || value.isEmpty)) {
        //         return 'Debe ingresar el nombre de la licencia';
        //       }
        //       return null;
        //     },
        //     onChanged: (value) {
        //       setState(() {});
        //     },
        //   ),
        // ],

        // Información de la licencia seleccionada
        if (_licenciaSeleccionada != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Giro Comercial seleccionado:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Giro Comercial: ${_licenciaSeleccionada!['descripcion'] ?? ''}',
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _licenciaSeleccionada = null;
                        _licenciaController.clear();
                      });
                    },
                    child: const Text('Cambiar giro comercial'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContribuyenteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Contribuyente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_contribuyenteSeleccionado == null)
              IconButton(
                onPressed: _cargarUltimoContribuyente,
                icon: const Icon(Icons.history, size: 20),
                tooltip: 'Cargar último contribuyente',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Mostrar búsqueda solo si no hay contribuyente seleccionado
        if (_contribuyenteSeleccionado == null) ...[
          TextFormField(
            controller: _contribuyenteController,
            enabled: _isOnline, // Deshabilitar si está offline
            decoration: InputDecoration(
              labelText: _isOnline ? 'Buscar contribuyente' : 'Buscar contribuyente (Sin conexión)',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(
                _isOnline ? Icons.search : Icons.wifi_off,
                color: _isOnline ? null : Colors.grey,
              ),
              suffixIcon: _isContribuyenteLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              helperText: !_isOnline ? 'Necesita conexión para buscar' : null,
              helperStyle: TextStyle(color: Colors.orange.shade600),
            ),
            onChanged: _buscarContribuyentes,
            validator: (value) {
              // El contribuyente ya no es obligatorio
              return null;
            },
          ),

          // Lista de contribuyentes encontrados
          if (_contribuyentes.isNotEmpty) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                final availableHeight = MediaQuery.of(context).size.height - keyboardHeight - 200; // 200px para otros elementos
                final maxHeight = availableHeight > 150 ? availableHeight * 0.4 : 150.0; // Máximo 40% del espacio disponible
                final minHeight = maxHeight < 100 ? maxHeight : 100.0; // Asegurar que minHeight <= maxHeight
                
                return Container(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                    minHeight: minHeight,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _contribuyentes.length,
                      itemBuilder: (context, index) {
                  final contribuyente = _contribuyentes[index];
                  final nombreCompleto =
                      '${contribuyente['nombre'] ?? ''} ${contribuyente['apellidoPaterno'] ?? ''} ${contribuyente['apellidoMaterno'] ?? ''}'
                          .trim();

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _contribuyenteSeleccionado = contribuyente;
                        _contribuyenteController.text = nombreCompleto;
                        _contribuyentes = [];
                      });
                      // NO llamar unfocus() - deja que el usuario maneje el teclado
                      _guardarUltimoContribuyente(contribuyente);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: index < _contribuyentes.length - 1
                            ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                            : null,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Color.fromARGB(255, 79, 80, 80), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreCompleto,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'RMC: ${contribuyente['rmc'] ?? ''} ',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
                );
              },
            ),
          ],
          if (_contribuyentes.isEmpty &&
              _contribuyenteController.text.length >= 2 &&
              !_isContribuyenteLoading) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'No se encontró el contribuyente.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Agregar nuevo contribuyente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final resultado = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditarContribuyenteScreen(
                            idContribuyente: null,
                            esNuevo: true,
                          ),
                        ),
                      );
                      if (resultado != null &&
                          resultado is Map<String, dynamic> &&
                          resultado['rmc'] != null) {
                        // Si la API de alta responde el RMC, selecciona automáticamente el contribuyente
                        await _buscarContribuyentePorRmc(
                          resultado['rmc'].toString(),
                        );
                      } else if (resultado == true) {
                        // Compatibilidad si solo regresas true
                        _buscarContribuyentes(_contribuyenteController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],

        // Información del contribuyente seleccionado
        if (_contribuyenteSeleccionado != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Contribuyente seleccionado:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nombre: ${_contribuyenteSeleccionado!['nombre']} ${_contribuyenteSeleccionado!['apellidoPaterno'] ?? ''} ${_contribuyenteSeleccionado!['apellidoMaterno'] ?? ''}',
                  ),
                  Text('RMC: ${_contribuyenteSeleccionado!['rmc']}'),
                  Text(
                    'Teléfono: ${_contribuyenteSeleccionado!['telefono'] ?? 'Sin teléfono'}',
                  ),
                  Text(
                    'Email: ${_contribuyenteSeleccionado!['email'] ?? 'Sin email'}',
                  ),

                  // Información de dirección con botón de editar
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dirección:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Calle: ${_contribuyenteSeleccionado!['direccion']?['calle'] ?? 'Sin calle'}',
                            ),
                            Text(
                              'Número: ${_contribuyenteSeleccionado!['direccion']?['numeroPredio'] ?? 'Sin número'}',
                            ),
                            Text(
                              'Colonia: ${_contribuyenteSeleccionado!['direccion']?['Colonia'] ?? 'Sin colonia'}',
                            ),
                            Text(
                              'Municipio: ${_contribuyenteSeleccionado!['direccion']?['Municipio'] ?? 'Sin municipio'}',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final resultado = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditarContribuyenteScreen(
                                idContribuyente:
                                    _contribuyenteSeleccionado!['idContribuyente'],
                              ),
                            ),
                          );

                          if (resultado == true) {
                            // Si se editó exitosamente, actualizar los datos del contribuyente sin quitar la selección
                            // Agregar un pequeño delay para asegurar que el backend procese la actualización
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
                            await _actualizarContribuyenteSeleccionado();
                            _mostrarMensaje(
                              'Contribuyente actualizado exitosamente',
                              Colors.green,
                              Icons.check,
                            );
                          }
                        },
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                    ],
                  ),

                  // Mostrar advertencia si los datos del contribuyente están incompletos
                  if (_esDireccionIncompleta(_contribuyenteSeleccionado)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getMensajeDireccionIncompleta(
                                _contribuyenteSeleccionado,
                              ),
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  if (!(_vigenciaPorQR && _idDocumentoQR != null))
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _contribuyenteSeleccionado = null;
                          _contribuyenteController.clear();
                        });
                      },
                      child: const Text('Cambiar contribuyente'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPredioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Predio *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_predioSeleccionado == null)
              IconButton(
                onPressed: _cargarUltimoPredio,
                icon: const Icon(Icons.history, size: 20),
                tooltip: 'Cargar último predio',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Selector de tipo de búsqueda - solo mostrar si no hay predio seleccionado
        if (_predioSeleccionado == null) ...[
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: _tipoBusquedaPredio == 'folio' ? 4 : 1,
                  color: _tipoBusquedaPredio == 'folio'
                      ? Colors.blue.shade50
                      : null,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _tipoBusquedaPredio = 'folio';
                        _predios = [];
                        _predioSeleccionado = null;
                        _predioController.clear();
                        _calleController.clear();
                        _numeroController.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.numbers,
                            size: 20,
                            color: _tipoBusquedaPredio == 'folio'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Folio',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _tipoBusquedaPredio == 'folio'
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Card(
                  elevation: _tipoBusquedaPredio == 'calle' ? 4 : 1,
                  color: _tipoBusquedaPredio == 'calle'
                      ? Colors.blue.shade50
                      : null,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _tipoBusquedaPredio = 'calle';
                        _predios = [];
                        _predioSeleccionado = null;
                        _predioController.clear();
                        _calleController.clear();
                        _numeroController.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 20,
                            color: _tipoBusquedaPredio == 'calle'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Calle',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _tipoBusquedaPredio == 'calle'
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Card(
                  elevation: _tipoBusquedaPredio == 'tablaje' ? 4 : 1,
                  color: _tipoBusquedaPredio == 'tablaje'
                      ? Colors.blue.shade50
                      : null,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _tipoBusquedaPredio = 'tablaje';
                        _predios = [];
                        _predioSeleccionado = null;
                        _predioController.clear();
                        _calleController.clear();
                        _numeroController.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.landscape,
                            size: 20,
                            color: _tipoBusquedaPredio == 'tablaje'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tablaje',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _tipoBusquedaPredio == 'tablaje'
                                  ? Colors.blue
                                  : Colors.grey,
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
        ],

        const SizedBox(height: 16),

        // Mostrar campos de búsqueda solo si no hay predio seleccionado
        if (_predioSeleccionado == null) ...[
          // Campos de búsqueda según el tipo seleccionado
          if (_tipoBusquedaPredio == 'folio') ...[
            TextFormField(
              controller: _predioController,
              enabled: _isOnline, // Deshabilitar si está offline
              decoration: InputDecoration(
                labelText: _isOnline ? 'Buscar predio por folio' : 'Buscar predio por folio (Sin conexión)',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  _isOnline ? Icons.search : Icons.wifi_off,
                  color: _isOnline ? null : Colors.grey,
                ),
                suffixIcon: _isPredioLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                helperText: !_isOnline ? 'Necesita conexión para buscar' : null,
                helperStyle: TextStyle(color: Colors.orange.shade600),
              ),
              onChanged: _isOnline ? _buscarPredios : null,
              validator: (value) {
                if (_isOnline && _predioSeleccionado == null && !_esTipoAmbulante()) {
                  return 'Debe seleccionar un predio';
                }
                return null;
              },
            ),
          ] else if (_tipoBusquedaPredio == 'tablaje') ...[
            // Búsqueda por tablaje
            TextFormField(
              controller: _predioController,
              enabled: _isOnline, // Deshabilitar si está offline
              decoration: InputDecoration(
                labelText: _isOnline ? 'Buscar predio por tablaje' : 'Buscar predio por tablaje (Sin conexión)',
                hintText: 'Ingrese el número de tablaje',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  _isOnline ? Icons.landscape : Icons.wifi_off,
                  color: _isOnline ? null : Colors.grey,
                ),
                suffixIcon: _isPredioLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                helperText: !_isOnline ? 'Necesita conexión para buscar' : null,
                helperStyle: TextStyle(color: Colors.orange.shade600),
              ),
              keyboardType: TextInputType.number,
              onChanged: _isOnline ? _buscarPredios : null,
              validator: (value) {
                if (_isOnline && _predioSeleccionado == null && !_esTipoAmbulante()) {
                  return 'Debe seleccionar un predio';
                }
                return null;
              },
            ),
          ] else ...[
            // Búsqueda por calle (dos campos)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _calleController,
                    enabled: _isOnline, // Deshabilitar si está offline
                    decoration: InputDecoration(
                      labelText: _isOnline ? 'Calle (ej: 23 D)' : 'Calle (Sin conexión)',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        _isOnline ? Icons.location_city : Icons.wifi_off,
                        color: _isOnline ? null : Colors.grey,
                      ),
                      helperText: !_isOnline ? 'Sin conexión' : null,
                      helperStyle: TextStyle(color: Colors.orange.shade600, fontSize: 10),
                    ),
                    onChanged: _isOnline ? (value) {
                      _buscarPrediosPorCalle();
                    } : null,
                    validator: (value) {
                      if (_isOnline &&
                          _tipoBusquedaPredio == 'calle' &&
                          _predioSeleccionado == null &&
                          !_esTipoAmbulante()) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _numeroController,
                    enabled: _isOnline, // Deshabilitar si está offline
                    decoration: InputDecoration(
                      labelText: _isOnline ? 'Número (ej: 5 E)' : 'Número (Sin conexión)',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        _isOnline ? Icons.home : Icons.wifi_off,
                        color: _isOnline ? null : Colors.grey,
                      ),
                      suffixIcon: _isPredioLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      helperText: !_isOnline ? 'Sin conexión' : null,
                      helperStyle: TextStyle(color: Colors.orange.shade600, fontSize: 10),
                    ),
                    onChanged: _isOnline ? (value) {
                      _buscarPrediosPorCalle();
                    } : null,
                    validator: (value) {
                      if (_isOnline &&
                          _tipoBusquedaPredio == 'calle' &&
                          _predioSeleccionado == null &&
                          !_esTipoAmbulante()) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                '💡 Ejemplo: Calle: "23 D" Número: "5 E"',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // Lista de predios encontrados
          if (_predios.isNotEmpty) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                final availableHeight = MediaQuery.of(context).size.height - keyboardHeight - 200;
                final maxHeight = availableHeight > 150 ? availableHeight * 0.4 : 150.0;
                final minHeight = maxHeight < 100 ? maxHeight : 100.0; // Asegurar que minHeight <= maxHeight
                
                return Container(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                    minHeight: minHeight,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _predios.length,
                      itemBuilder: (context, index) {
                  final predio = _predios[index];

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _predioSeleccionado = predio;
                        if (_tipoBusquedaPredio == 'folio') {
                          _predioController.text =
                              'Folio: ${predio['folio']} - ${predio['direccion']?['calle'] ?? ''} ${predio['direccion']?['numeroPredio'] ?? ''}';
                        } else if (_tipoBusquedaPredio == 'tablaje') {
                          _predioController.text =
                              'Tablaje: ${predio['tablaje'] ?? 'N/A'} - Lote: ${predio['lote'] ?? 'N/A'} - ${predio['direccion']?['calle'] ?? ''} ${predio['direccion']?['numeroPredio'] ?? ''}';
                        } else {
                          _calleController.text = predio['direccion']?['calle'] ?? '';
                          _numeroController.text = predio['direccion']?['numeroPredio'] ?? '';
                        }
                        _predios = [];
                      });
                      // NO llamar unfocus() - deja que el usuario maneje el teclado
                      _guardarUltimoPredio(predio);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: index < _predios.length - 1
                            ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                            : null,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home, color: Color.fromARGB(255, 115, 115, 116), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Folio: ${predio['folio']} - ${predio['Contribuyente'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _tipoBusquedaPredio == 'tablaje'
                                      ? 'Tablaje: ${predio['tablaje'] ?? 'N/A'} • Lote: ${predio['lote'] ?? 'N/A'} • Calle: ${predio['direccion']?['calle'] ?? ''} ${predio['direccion']?['numeroPredio'] ?? ''} • Colonia: ${predio['direccion']?['Colonia'] ?? ''}'
                                      : 'Calle: ${predio['direccion']?['calle'] ?? ''} ${predio['direccion']?['numeroPredio'] ?? ''} • Colonia: ${predio['direccion']?['Colonia'] ?? ''}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
                );
              },
            ),
          ],

          // Mostrar mensaje si no hay predios encontrados
          if (_predios.isEmpty &&
              ((_tipoBusquedaPredio == 'folio' &&
                      _predioController.text.length >= 2) ||
                  (_tipoBusquedaPredio == 'calle' &&
                      _calleController.text.isNotEmpty) ||
                  (_tipoBusquedaPredio == 'tablaje' &&
                      _predioController.text.length >= 2)) &&
              !_isPredioLoading &&
              _predioSeleccionado == null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(4),
                color: Colors.orange.shade50,
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Predio no encontrado',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        // Información del predio seleccionado
        if (_predioSeleccionado != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Predio seleccionado:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Folio: ${_predioSeleccionado!['folio']}'),
                  Text(
                    'Contribuyente: ${_predioSeleccionado!['Contribuyente'] ?? ''}',
                  ),
                  Text(
                    'Uso/Destino: ${_predioSeleccionado!['Uso y/o Destino'] ?? ''}',
                  ),
                  Text('Tipo: ${_predioSeleccionado!['Tipo de Predio'] ?? ''}'),
                  if (_tipoBusquedaPredio == 'tablaje') ...[
                    Text(
                      'Tablaje: ${_predioSeleccionado!['tablaje'] ?? 'N/A'}',
                    ),
                    Text(
                      'Lote: ${_predioSeleccionado!['lote'] ?? 'N/A'}',
                    ),
                    Text(
                      'Dirección: ${_predioSeleccionado!['direccion']?['calle'] ?? ''} ${_predioSeleccionado!['direccion']?['numeroPredio'] ?? ''}',
                    ),
                  ] else ...[
                    Text(
                      'Dirección: ${_predioSeleccionado!['direccion']?['calle'] ?? ''} ${_predioSeleccionado!['direccion']?['numeroPredio'] ?? ''}',
                    ),
                  ],
                  Text(
                    'Colonia: ${_predioSeleccionado!['direccion']?['Colonia'] ?? ''}',
                  ),
                  const SizedBox(height: 8),
                  if (!(_vigenciaPorQR && _idDocumentoQR != null))
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _predioSeleccionado = null;
                          _predioController.clear();
                          _calleController.clear();
                          _numeroController.clear();
                        });
                      },
                      child: const Text('Cambiar predio'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotografías',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Foto Fachada/Puesto (imgEvidencia1)
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0), // Reducido de 16 a 12
                  child: Column(
                    children: [
                      if (_fotoFachada != null) ...[
                        // Mostrar miniatura de la imagen
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_fotoFachada!, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.check_circle,
                          size: 20, // Reducido de 24 a 20
                          color: Colors.green,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Foto Fachada',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12, // Tamaño fijo más pequeño
                          ),
                        ),
                        const Text(
                          'Capturada',
                          style: TextStyle(
                            fontSize: 10, // Reducido de 12 a 10
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 6), // Reducido de 8 a 6
                        // Botones más compactos con solo iconos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: IconButton(
                                onPressed: _mostrarOpcionesFotoFachada,
                                icon: const Icon(Icons.camera_alt, size: 16),
                                tooltip: 'Cambiar foto',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                            Expanded(
                              child: IconButton(
                                onPressed: _eliminarFotoFachada,
                                icon: const Icon(
                                  Icons.delete,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                tooltip: 'Eliminar foto',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Estado sin foto
                        InkWell(
                          onTap: _mostrarOpcionesFotoFachada,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.camera_alt,
                                size: 32,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Foto Fachada',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                'Toca para capturar o seleccionar',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12), // Reducido de 16 a 12
            // Foto Permiso (imgEvidencia2)
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0), // Reducido de 16 a 12
                  child: Column(
                    children: [
                      if (_fotoPermiso != null) ...[
                        // Mostrar miniatura de la imagen
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_fotoPermiso!, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.check_circle,
                          size: 20, // Reducido de 24 a 20
                          color: Colors.green,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Foto Permiso',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12, // Tamaño fijo más pequeño
                          ),
                        ),
                        const Text(
                          'Capturada',
                          style: TextStyle(
                            fontSize: 10, // Reducido de 12 a 10
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 6), // Reducido de 8 a 6
                        // Botones más compactos con solo iconos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: IconButton(
                                onPressed: _mostrarOpcionesFotoPermiso,
                                icon: const Icon(Icons.camera_alt, size: 16),
                                tooltip: 'Cambiar foto',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                            Expanded(
                              child: IconButton(
                                onPressed: _eliminarFotoPermiso,
                                icon: const Icon(
                                  Icons.delete,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                tooltip: 'Eliminar foto',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Estado sin foto
                        InkWell(
                          onTap: _mostrarOpcionesFotoPermiso,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.camera_alt,
                                size: 32,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Foto Permiso',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                'Toca para capturar o seleccionar',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUbicacionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: InkWell(
            onTap: _seleccionarUbicacion,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _latitud != null && _longitud != null
                            ? Icons.check_circle
                            : Icons.location_on,
                        size: 32,
                        color: _latitud != null && _longitud != null
                            ? Colors.green
                            : Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _latitud != null && _longitud != null
                                  ? 'Ubicación seleccionada'
                                  : 'Seleccionar ubicación',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _latitud != null && _longitud != null
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                            if (_latitud != null && _longitud != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Lat: ${_latitud!.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Lng: ${_longitud!.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Toca para obtener ubicación actual o seleccionar en Google Maps',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    ],
                  ),
                  // Botón para cambiar ubicación si ya hay una seleccionada
                  if (_latitud != null && _longitud != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () => _seleccionarUbicacion(),
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text(
                            'Editar Ubicación',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _latitud = null;
                              _longitud = null;
                            });
                          },
                          icon: const Icon(
                            Icons.clear,
                            size: 16,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Limpiar',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVigenciaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fecha de Vigencia *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _vigenciaController,
          readOnly: true,
          enabled:
              _fotoPermiso != null, // Solo habilitado si hay foto de permiso
          decoration: const InputDecoration(
            labelText: 'Seleccionar fecha de vigencia',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          onTap: (_fotoPermiso != null && !_vigenciaPorQR)
              ? _seleccionarFechaVigencia
              : null,
          validator: (value) {
            // Solo obligatorio si hay foto de permiso o si la vigencia viene de QR
            if (_fotoPermiso == null && !_vigenciaPorQR) return null;
            if (value == null || value.isEmpty) {
              return 'Debe seleccionar una fecha de vigencia';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildObservacionesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observaciones',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _observacionesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observaciones adicionales',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.note_alt),
            hintText: 'Ingrese observaciones adicionales...',
          ),
        ),
      ],
    );
  }

  Widget _buildBotonRegistrar() {
    // Verificar si hay datos incompletos del contribuyente
    // final contribuyenteIncompleto =
    //     _contribuyenteSeleccionado != null &&
    //     _esDireccionIncompleta(_contribuyenteSeleccionado);
    final ubicacionFaltante = _latitud == null || _longitud == null;
    final fotoFachadaFaltante = _fotoFachada == null;

    // CORRECCIÓN: Hacer la validación más estricta considerando ambulante
    final puedeRegistrar =
        !_isLoading &&
        _tipoVerificacionSeleccionado != null &&
        // !contribuyenteIncompleto &&
        (_predioSeleccionado != null || _esTipoAmbulante()) &&
        !ubicacionFaltante &&
        !fotoFachadaFaltante &&
        !(_tipoVerificacionSeleccionado != null &&
          _tipoVerificacionSeleccionado!['descripcion']
            .toString()
            .toLowerCase()
            .contains('comercial') &&
          _metodoCaptura == 'manual' && !_vigenciaPorQR &&
          _licenciaSeleccionada == null &&
          (!_ingresandoLicenciaManual || _licenciaManualController.text.isEmpty)) &&
        ((_fotoPermiso != null && _vigenciaController.text.isNotEmpty) ||
          (_vigenciaPorQR && _vigenciaController.text.isNotEmpty) ||
          (_fotoPermiso == null && !_vigenciaPorQR));

    return Column(
      children: [
        // Mostrar advertencias si hay problemas - SIEMPRE mostrar si hay problemas
        if ( //contribuyenteIncompleto ||
            ubicacionFaltante ||
            (_isOnline && _predioSeleccionado == null && !_esTipoAmbulante()) ||
            _tipoVerificacionSeleccionado == null ||
            (
              _tipoVerificacionSeleccionado != null &&
              _tipoVerificacionSeleccionado!['descripcion']
                .toString()
                .toLowerCase()
                .contains('comercial') &&
              _metodoCaptura == 'manual' && !_vigenciaPorQR &&
              _licenciaSeleccionada == null && _isOnline &&
              (
                !_ingresandoLicenciaManual || // Si NO está ingresando manual, mostrar advertencia
                (_ingresandoLicenciaManual && _licenciaManualController.text.isEmpty) // Si está ingresando manual y el campo está vacío, mostrar advertencia
              )
            ) ||
            ((_fotoPermiso != null || _vigenciaPorQR) && _vigenciaController.text.isEmpty)
        ) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(
              bottom: 16,
            ), // Agregar margen en lugar de SizedBox
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Faltan campos obligatorios',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Mostrar todos los problemas específicos
                if (_tipoVerificacionSeleccionado == null)
                  Text(
                    '• Debe seleccionar un tipo de verificación',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                if (_isOnline && _tipoVerificacionSeleccionado != null &&
                    _tipoVerificacionSeleccionado!['descripcion']
                        .toString()
                        .toLowerCase()
                        .contains('comercial') &&
                    _metodoCaptura == 'manual' &&
                    !_vigenciaPorQR &&
                    _licenciaSeleccionada == null && 
                    (!_ingresandoLicenciaManual || _licenciaManualController.text.isEmpty))
                  Text(
                    '• Debe seleccionar o ingresar una razón social',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                // if (contribuyenteIncompleto)
                //   Text(
                //     '• ${_getMensajeDireccionIncompleta(_contribuyenteSeleccionado)}',
                //     style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                //   ),
                if (_isOnline && _predioSeleccionado == null && !_esTipoAmbulante())
                  Text(
                    '• Debe seleccionar un predio',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                if (fotoFachadaFaltante)
                  Text(
                    '• Debe tomar la foto de la fachada',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                if (ubicacionFaltante)
                  Text(
                    '• Debe seleccionar una ubicación',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                if ((_fotoPermiso != null || _vigenciaPorQR) &&
                    _vigenciaController.text.isEmpty)
                  Text(
                    '• Debe seleccionar una fecha de vigencia',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],

        // Botón de registrar
        if (!_isOnline) ...[
          // Modo offline - mostrar advertencia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sin conexión a internet',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Puede guardar la inspección y completarla cuando tenga conexión',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Botón para guardar offline
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _guardarInspeccionOffline,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Guardando...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_alt, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Guardar Inspección (Offline)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
            ),
          ),
        ] else ...[
          // Modo online - botón normal
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: puedeRegistrar ? _registrarRevision : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: puedeRegistrar
                    ? Colors.blue
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                elevation: puedeRegistrar ? 2 : 0,
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Registrando...'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(puedeRegistrar ? Icons.save : Icons.block, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            puedeRegistrar
                                ? 'Registrar Inspección'
                                : 'Complete los campos requeridos',
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
