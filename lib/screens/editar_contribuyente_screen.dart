import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class EditarContribuyenteScreen extends StatefulWidget {
  final int? idContribuyente;
  final bool esNuevo;

  const EditarContribuyenteScreen({
    super.key,
    required this.idContribuyente,
    this.esNuevo = false,
  });

  @override
  State<EditarContribuyenteScreen> createState() =>
      _EditarContribuyenteScreenState();
}

class _EditarContribuyenteScreenState extends State<EditarContribuyenteScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers para los campos
  final _nombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _rfcController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _calleController = TextEditingController();
  final _numeroPredioController = TextEditingController();
  final _numeroInteriorController = TextEditingController();
  final _cruzamiento1Controller = TextEditingController();
  final _cruzamiento2Controller = TextEditingController();

  // Estados de carga
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSectoresLoading = true;
  bool _isColoniasLoading = false;

  // Datos del contribuyente
  Map<String, dynamic>? _contribuyenteData;

  // Listas para dropdowns
  List<Map<String, dynamic>> _sectoresHabitacionales = [];
  List<Map<String, dynamic>> _colonias = [];

  // Selecciones
  Map<String, dynamic>? _sectorSeleccionado;
  Map<String, dynamic>? _coloniaSeleccionada;

  @override
  void initState() {
    super.initState();
    if (!widget.esNuevo) {
      _cargarDatos();
    } else {
      _cargarSectoresHabitacionales().then((_) {
        setState(() {
          _isLoading = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _rfcController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _calleController.dispose();
    _numeroPredioController.dispose();
    _numeroInteriorController.dispose();
    _cruzamiento1Controller.dispose();
    _cruzamiento2Controller.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await Future.wait([
      _cargarContribuyente(),
      _cargarSectoresHabitacionales(),
    ]);

    // Después de cargar todo, intentar pre-seleccionar sector y colonia
    await _preseleccionarSectorYColonia();
  }

  Future<void> _preseleccionarSectorYColonia() async {
    if (_contribuyenteData == null ||
        _contribuyenteData!['direccion'] == null ||
        _contribuyenteData!['direccion']['idColonia'] == null) {
      return;
    }

    final idColonia = _contribuyenteData!['direccion']['idColonia'];
    

    try {
      // Usar la nueva API para obtener la información de la colonia directamente
      final coloniaInfo = await _obtenerInfoColonia(idColonia);
      
      if (coloniaInfo != null) {
        final idSectorHabitacional = coloniaInfo['idSectorHabitacional'];
        
        // Buscar el sector en la lista cargada
        final sectorEncontrado = _sectoresHabitacionales.firstWhere(
          (sector) => sector['id'] == idSectorHabitacional,
          orElse: () => <String, dynamic>{},
        );

        if (sectorEncontrado.isNotEmpty) {
          setState(() {
            _sectorSeleccionado = sectorEncontrado;
          });

          // Cargar todas las colonias de ese sector
          await _cargarColonias(idSectorHabitacional);

          // Buscar y seleccionar la colonia específica
          final coloniaEncontrada = _colonias.firstWhere(
            (colonia) => colonia['id'] == idColonia,
            orElse: () => <String, dynamic>{},
          );

          if (coloniaEncontrada.isNotEmpty) {
            setState(() {
              _coloniaSeleccionada = coloniaEncontrada;
            });
          }
        }
      }
    } catch (e) {
      // Si falla la nueva API, usar el método de fallback (buscar en todos los sectores)
      await _preseleccionarSectorYColoniaFallback(idColonia);
    }
  }

  Future<Map<String, dynamic>?> _obtenerInfoColonia(int idColonia) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConfig.obtenerColoniasUrl}?idColonia=$idColonia'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return data.first; // Retorna el primer elemento de la lista
        }
      }
    } catch (e) {
      print('Error al obtener info de colonia: $e');
    }
    return null;
  }

  Future<void> _preseleccionarSectorYColoniaFallback(int idColonia) async {
    // Método original como fallback
    for (final sector in _sectoresHabitacionales) {
      await _cargarColonias(sector['id']);

      final coloniaEncontrada = _colonias.firstWhere(
        (colonia) => colonia['id'] == idColonia,
        orElse: () => <String, dynamic>{},
      );

      if (coloniaEncontrada.isNotEmpty) {
        setState(() {
          _sectorSeleccionado = sector;
          _coloniaSeleccionada = coloniaEncontrada;
        });
        break;
      }
    }
  }

  Future<void> _cargarContribuyente() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.obtenerContribuyenteUrl}?idContribuyente=${widget.idContribuyente}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _contribuyenteData = data;
          _llenarFormulario(data);
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        throw Exception('Error al cargar contribuyente');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarMensaje(
        'Error al cargar datos del contribuyente: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  Future<void> _cargarSectoresHabitacionales() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConfig.obtenerSectoresHabitacionalesUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _sectoresHabitacionales = List<Map<String, dynamic>>.from(data);
          _isSectoresLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSectoresLoading = false;
      });
      _mostrarMensaje(
        'Error al cargar sectores habitacionales: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  Future<void> _cargarColonias(int idSectorHabitacional) async {
    setState(() {
      _isColoniasLoading = true;
      _colonias = [];
      _coloniaSeleccionada = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.obtenerColoniasUrl}?idSectorHabitacional=$idSectorHabitacional',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _colonias = List<Map<String, dynamic>>.from(data);
          _isColoniasLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isColoniasLoading = false;
      });
      _mostrarMensaje('Error al cargar colonias: $e', Colors.red, Icons.error);
    }
  }

  void _llenarFormulario(Map<String, dynamic> data) {
    _nombreController.text = data['nombre'] ?? '';
    _apellidoPaternoController.text = data['apellidoPaterno'] ?? '';
    _apellidoMaternoController.text = data['apellidoMaterno'] ?? '';
    _rfcController.text = data['rfc'] ?? '';
    _telefonoController.text = data['telefono'] ?? '';
    _emailController.text = data['email'] ?? '';

    final direccion = data['direccion'];
    if (direccion != null) {
      _calleController.text = direccion['calle'] ?? '';
      _numeroPredioController.text = direccion['numeroPredio'] ?? '';
      _numeroInteriorController.text = direccion['numeroInterior'] ?? '';
      _cruzamiento1Controller.text = direccion['cruzamiento1'] ?? '';
      _cruzamiento2Controller.text = direccion['cruzamiento2'] ?? '';
    }
  }

  Future<void> _guardarCambios() async {
    setState(() {
      _isSaving = true;
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

      // Construir el objeto de dirección
      final direccion = {
        "idEstado": 1,
        "idMunicipio": "8",
        "idSectorHabitacional": _sectorSeleccionado?['id'],
        "idColonia": _coloniaSeleccionada?['id'],
        "calle": _calleController.text.trim(),
        "numeroPredio": _numeroPredioController.text.trim(),
        "numeroInterior": _numeroInteriorController.text.trim(),
        "cruzamiento1": _cruzamiento1Controller.text.trim(),
        "cruzamiento2": _cruzamiento2Controller.text.trim(),
        "observaciones": "",
        "fechaRegistro": DateTime.now().toIso8601String(),
        "fechaActualizacion": DateTime.now().toIso8601String(),
        "idUsuarioUltiAct": userId.toString(),
      };

      if (widget.esNuevo) {
        // --- AGREGAR CONTRIBUYENTE ---
        final requestData = {
          "nombre": _nombreController.text.trim(),
          "apellidoPaterno": _apellidoPaternoController.text.trim(),
          "apellidoMaterno": _apellidoMaternoController.text.trim(),
          "rfc": _rfcController.text.trim(),
          "telefono": _telefonoController.text.trim(),
          "email": _emailController.text.trim(),
          "observaciones": "",
          "Atributo": "0",
          "direccion": direccion,
          "idUsuarioCreacion": userId.toString(),
          "idUsuarioUltiAct": userId.toString(),
          "fechaRegistro": DateTime.now().toIso8601String(),
          "fechaActualizacion": DateTime.now().toIso8601String(),
        };

        final response = await http.post(
          Uri.parse(ApiConfig.agregarContribuyenteUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestData),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          _mostrarMensaje(
            'Contribuyente agregado exitosamente',
            Colors.green,
            Icons.check,
          );
          Navigator.pop(context, data);
        } else if (response.statusCode == 401) {
          await AuthService.logout();
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          throw Exception('Error al agregar contribuyente: ${response.body}');
        }
      } else {
        // --- EDITAR CONTRIBUYENTE (lo que ya tienes) ---
        final requestData = {
          'idContribuyente': _contribuyenteData!['idContribuyente'],
          'idDireccion': _contribuyenteData!['idDireccion'],
          'rmc': _contribuyenteData!['rmc'],
          'nombre': _nombreController.text.trim(),
          'apellidoPaterno': _apellidoPaternoController.text.trim(),
          'apellidoMaterno': _apellidoMaternoController.text.trim(),
          'rfc': _rfcController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'email': _emailController.text.trim(),
          'observaciones': _contribuyenteData!['observaciones'] ?? '',
          'fechaRegistro': _contribuyenteData!['fechaRegistro'],
          'idUsuarioCreacion': _contribuyenteData!['idUsuarioCreacion'],
          'fechaActualizacion': DateTime.now().toIso8601String(),
          'idUsuarioUltiAct': int.parse(userId),
          'atributo': _contribuyenteData!['atributo'],
          'direccion': {
            'id': _contribuyenteData!['direccion']['id'],
            'idColonia': _coloniaSeleccionada!['id'],
            'idMunicipio': 1,
            'calle': _calleController.text.trim(),
            'numeroPredio': _numeroPredioController.text.trim(),
            'numeroInterior': _numeroInteriorController.text.trim(),
            'cruzamiento1': _cruzamiento1Controller.text.trim(),
            'cruzamiento2': _cruzamiento2Controller.text.trim(),
            'fechaRegistro': _contribuyenteData!['direccion']['fechaRegistro'],
            'idUsuarioCreacion':
                _contribuyenteData!['direccion']['idUsuarioCreacion'],
            'fechaActualizacion': DateTime.now().toIso8601String(),
            'idUsuarioUltiAct': int.parse(userId),
            'atributo': _contribuyenteData!['direccion']['atributo'],
            'Colonia': _coloniaSeleccionada!['descripcion'],
            'Municipio': 'Valladolid',
            'observaciones':
                _contribuyenteData!['direccion']['observaciones'] ?? '',
          },
        };

        final response = await http.patch(
          Uri.parse(ApiConfig.modificarContribuyenteUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestData),
        );

        if (response.statusCode == 200) {
          _mostrarMensaje(
            'Contribuyente actualizado exitosamente',
            Colors.green,
            Icons.check,
          );
          Navigator.pop(context, true);
        } else if (response.statusCode == 401) {
          await AuthService.logout();
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          throw Exception('Error al actualizar contribuyente');
        }
      }
    } catch (e) {
      _mostrarMensaje(
        widget.esNuevo
            ? 'Error al agregar contribuyente: $e'
            : 'Error al actualizar contribuyente: $e',
        Colors.red,
        Icons.error,
      );
    } finally {
      setState(() {
        _isSaving = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.esNuevo ? 'Agregar Contribuyente' : 'Editar Contribuyente',
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!_isSaving)
            IconButton(
              onPressed: _guardarCambios,
              icon: const Icon(Icons.save),
              tooltip: 'Guardar cambios',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información personal
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 20),

                    // Información de contacto
                    _buildContactInfoSection(),
                    const SizedBox(height: 20),

                    // Información de dirección
                    _buildAddressSection(),
                    const SizedBox(height: 32),

                    // Botón guardar
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información Personal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apellidoPaternoController,
              decoration: const InputDecoration(
                labelText: 'Apellido Paterno',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apellidoMaternoController,
              decoration: const InputDecoration(
                labelText: 'Apellido Materno',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rfcController,
              decoration: const InputDecoration(
                labelText: 'RFC',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información de Contacto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefonoController,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información de Dirección',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),

            // Sector Habitacional
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _sectorSeleccionado,
              isExpanded:
                  true, // Esto permite que el dropdown use todo el ancho disponible
              decoration: const InputDecoration(
                labelText: 'Sector Habitacional',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
              hint: _isSectoresLoading
                  ? const Text('Cargando sectores...')
                  : const Text('Seleccionar sector'),
              items: _sectoresHabitacionales.map((sector) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: sector,
                  child: Text(
                    sector['descripcion'] ?? '',
                    overflow: TextOverflow
                        .ellipsis, // Trunca el texto si es muy largo
                    maxLines: 1, // Limita a una línea
                  ),
                );
              }).toList(),
              onChanged: _isSectoresLoading
                  ? null
                  : (value) {
                      setState(() {
                        _sectorSeleccionado = value;
                        _coloniaSeleccionada = null;
                      });
                      if (value != null) {
                        _cargarColonias(value['id']);
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Colonia
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _coloniaSeleccionada,
              isExpanded:
                  true, // Esto permite que el dropdown use todo el ancho disponible
              decoration: const InputDecoration(
                labelText: 'Colonia',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              hint: _isColoniasLoading
                  ? const Text('Cargando colonias...')
                  : _sectorSeleccionado == null
                  ? const Text('Primero seleccione un sector')
                  : const Text('Seleccionar colonia'),
              items: _colonias.map((colonia) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: colonia,
                  child: Text(
                    colonia['descripcion'] ?? '',
                    overflow: TextOverflow
                        .ellipsis, // Trunca el texto si es muy largo
                    maxLines: 1, // Limita a una línea
                  ),
                );
              }).toList(),
              onChanged: _isColoniasLoading || _sectorSeleccionado == null
                  ? null
                  : (value) {
                      setState(() {
                        _coloniaSeleccionada = value;
                      });
                    },
            ),
            const SizedBox(height: 16),

            // Calle
            TextFormField(
              controller: _calleController,
              decoration: const InputDecoration(
                labelText: 'Calle',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            // Número de predio
            TextFormField(
              controller: _numeroPredioController,
              decoration: const InputDecoration(
                labelText: 'Número de Predio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 16),

            // Número interior
            TextFormField(
              controller: _numeroInteriorController,
              decoration: const InputDecoration(
                labelText: 'Número Interior',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.door_front_door),
              ),
            ),
            const SizedBox(height: 16),

            // Cruzamientos
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cruzamiento1Controller,
                    decoration: const InputDecoration(
                      labelText: 'Cruzamiento 1',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alt_route),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cruzamiento2Controller,
                    decoration: const InputDecoration(
                      labelText: 'Cruzamiento 2',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alt_route),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _guardarCambios,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        child: _isSaving
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
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text('Guardar Cambios'),
                ],
              ),
      ),
    );
  }
}
