import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../utils/token_handler.dart';
import '../config/api_config.dart';

class AgregarBeneficiarioScreen extends StatefulWidget {
  const AgregarBeneficiarioScreen({super.key});

  @override
  State<AgregarBeneficiarioScreen> createState() => _AgregarBeneficiarioScreenState();
}

class _AgregarBeneficiarioScreenState extends State<AgregarBeneficiarioScreen> with TokenExpirationHandler {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isLoadingSectores = false;
  bool isLoadingColonias = false;
  
  // Controladores para los campos del beneficiario
  final _nombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _curpController = TextEditingController();
  final _rfcController = TextEditingController();
  
  // Controladores para los campos de dirección
  final _calleController = TextEditingController();
  final _numeroPredioController = TextEditingController();
  final _numeroInteriorController = TextEditingController();
  final _cruzamiento1Controller = TextEditingController();
  final _cruzamiento2Controller = TextEditingController();
  final _observacionesController = TextEditingController();

  // Datos para dropdowns
  List<Map<String, dynamic>> sectoresHabitacionales = [];
  List<Map<String, dynamic>> colonias = [];
  
  // Valores seleccionados
  int? selectedSectorId;
  int? selectedColoniaId;

  @override
  void initState() {
    super.initState();
    _loadSectoresHabitacionales();
  }

  @override
  void dispose() {
    // Limpiar controladores
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _curpController.dispose();
    _rfcController.dispose();
    _calleController.dispose();
    _numeroPredioController.dispose();
    _numeroInteriorController.dispose();
    _cruzamiento1Controller.dispose();
    _cruzamiento2Controller.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _loadSectoresHabitacionales() async {
    setState(() {
      isLoadingSectores = true;
    });

    try {
      // Verificar token válido
      final isTokenValid = await checkTokenValidity();
      if (!isTokenValid) return;

      // Obtener headers con autenticación
      final headers = await AuthService.getAuthHeaders();

      final response = await http.get(
        Uri.parse(ApiConfig.obtenerSectorHabitacionalApoyosUrl),
        headers: headers,
      );


      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            sectoresHabitacionales = data.cast<Map<String, dynamic>>();
            isLoadingSectores = false;
          });
        }
      } else if (response.statusCode == 401) {
        handleTokenExpiration();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al cargar sectores: $e');
      if (mounted) {
        setState(() {
          isLoadingSectores = false;
        });
      }
    }
  }

  Future<void> _loadColonias(int sectorId) async {
    setState(() {
      isLoadingColonias = true;
      colonias.clear();
      selectedColoniaId = null;
    });

    try {
      // Verificar token válido
      final isTokenValid = await checkTokenValidity();
      if (!isTokenValid) return;

      // Obtener headers con autenticación
      final headers = await AuthService.getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.obtenerColoniasApoyoUrl}?idSectorHabitacional=$sectorId'),
        headers: headers,
      );



      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            colonias = data.cast<Map<String, dynamic>>();
            isLoadingColonias = false;
          });
        }
      } else if (response.statusCode == 401) {
        handleTokenExpiration();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al cargar colonias: $e');
      if (mounted) {
        setState(() {
          isLoadingColonias = false;
        });
      }
    }
  }

  Future<void> _agregarBeneficiario() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Verificar token válido
      final isTokenValid = await checkTokenValidity();
      if (!isTokenValid) return;

      // Obtener ID del usuario actual
      final userId = await AuthService.getUserId();
      if (userId == null) {
        throw Exception('No se pudo obtener el ID del usuario');
      }

      // Preparar datos para enviar
      final now = DateTime.now().toIso8601String();
      final requestBody = {
        "idBeneficiario": 0,
        "idDireccion": 0,
        "nombre": _nombreController.text.trim(),
        "apellidoPaterno": _apellidoPaternoController.text.trim(),
        "apellidoMaterno": _apellidoMaternoController.text.trim(),
        "curp": _curpController.text.trim(),
        "rfc": _rfcController.text.trim(),
        "fechaRegistro": now,
        "idUsuarioCreacion": int.parse(userId),
        "fechaActualizacion": now,
        "idUsuarioUltiAct": int.parse(userId),
        "atributo": 0,
        "direccion": {
          "id": 0,
          "idSectorHabitacional": selectedSectorId ?? 0,
          "sectorHabitacional": _getSectorDescripcion(selectedSectorId),
          "idColonia": selectedColoniaId ?? 0,
          "colonia": _getColoniaDescripcion(selectedColoniaId),
          "calle": _calleController.text.trim(),
          "numeroPredio": _numeroPredioController.text.trim(),
          "numeroInterior": _numeroInteriorController.text.trim(),
          "cruzamiento1": _cruzamiento1Controller.text.trim(),
          "cruzamiento2": _cruzamiento2Controller.text.trim(),
          "observaciones": _observacionesController.text.trim(),
          "fechaRegistro": now,
          "idUsuarioCreacion": 0,
          "fechaActualizacion": now,
          "idUsuarioUltiAct": int.parse(userId),
          "atributo": 0
        }
      };


      // Obtener headers con autenticación
      final headers = await AuthService.getAuthHeaders();

      final response = await http.post(
        Uri.parse(ApiConfig.agregarBeneficiarioUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Beneficiario registrado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Regresar con resultado exitoso
        }
      } else if (response.statusCode == 401) {
        handleTokenExpiration();
      } else {
        throw Exception('Error del servidor: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar beneficiario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _getSectorDescripcion(int? sectorId) {
    if (sectorId == null) return '';
    final sector = sectoresHabitacionales.firstWhere(
      (sector) => sector['id'] == sectorId,
      orElse: () => {'descripcion': ''},
    );
    return sector['descripcion'] ?? '';
  }

  String _getColoniaDescripcion(int? coloniaId) {
    if (coloniaId == null) return '';
    final colonia = colonias.firstWhere(
      (colonia) => colonia['id'] == coloniaId,
      orElse: () => {'descripcion': ''},
    );
    return colonia['descripcion'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Beneficiario'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información Personal
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
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Información Personal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _apellidoPaternoController,
                        decoration: const InputDecoration(
                          labelText: 'Apellido Paterno *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El apellido paterno es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _apellidoMaternoController,
                        decoration: const InputDecoration(
                          labelText: 'Apellido Materno',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _curpController,
                        decoration: const InputDecoration(
                          labelText: 'CURP *',
                          border: OutlineInputBorder(),
                          hintText: 'Ej. MAMA820505HYNLRS00',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La CURP es obligatoria';
                          }
                          if (value.trim().length != 18) {
                            return 'La CURP debe tener 18 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _rfcController,
                        decoration: const InputDecoration(
                          labelText: 'RFC',
                          border: OutlineInputBorder(),
                          hintText: 'Ej. MAMA820505ABC',
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Información de Dirección
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
                            Icons.location_on,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Información de Dirección',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (isLoadingSectores)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Cargando sectores habitacionales...'),
                              ],
                            ),
                          ),
                        ),
                      
                      DropdownButtonFormField<int>(
                        value: selectedSectorId,
                        decoration: const InputDecoration(
                          labelText: 'Sector Habitacional *',
                          border: OutlineInputBorder(),
                        ),
                        items: isLoadingSectores
                            ? []
                            : sectoresHabitacionales.map((sector) {
                                return DropdownMenuItem<int>(
                                  value: sector['id'],
                                  child: Text(sector['descripcion']),
                                );
                              }).toList(),
                        onChanged: isLoadingSectores ? null : (int? newValue) {
                          setState(() {
                            selectedSectorId = newValue;
                            selectedColoniaId = null;
                            colonias.clear();
                          });
                          if (newValue != null) {
                            _loadColonias(newValue);
                          }
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'El sector habitacional es obligatorio';
                          }
                          return null;
                        },
                        hint: isLoadingSectores 
                            ? const Text('Cargando sectores...')
                            : const Text('Seleccione un sector'),
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<int>(
                        value: selectedColoniaId,
                        decoration: const InputDecoration(
                          labelText: 'Colonia *',
                          border: OutlineInputBorder(),
                        ),
                        items: isLoadingColonias
                            ? []
                            : colonias.map((colonia) {
                                return DropdownMenuItem<int>(
                                  value: colonia['id'],
                                  child: Text(colonia['descripcion']),
                                );
                              }).toList(),
                        onChanged: selectedSectorId == null || isLoadingColonias 
                            ? null 
                            : (int? newValue) {
                                setState(() {
                                  selectedColoniaId = newValue;
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'La colonia es obligatoria';
                          }
                          return null;
                        },
                        hint: selectedSectorId == null
                            ? const Text('Primero seleccione un sector')
                            : isLoadingColonias
                                ? const Text('Cargando colonias...')
                                : const Text('Seleccione una colonia'),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _calleController,
                              decoration: const InputDecoration(
                                labelText: 'Calle *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'La calle es obligatoria';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _numeroPredioController,
                              decoration: const InputDecoration(
                                labelText: 'Número',
                                border: OutlineInputBorder(),
                                hintText: 'SN',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _numeroInteriorController,
                        decoration: const InputDecoration(
                          labelText: 'Número Interior',
                          border: OutlineInputBorder(),
                          hintText: 'Opcional',
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cruzamiento1Controller,
                              decoration: const InputDecoration(
                                labelText: 'Cruzamiento 1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cruzamiento2Controller,
                              decoration: const InputDecoration(
                                labelText: 'Cruzamiento 2',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _observacionesController,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones',
                          border: OutlineInputBorder(),
                          hintText: 'Información adicional',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _agregarBeneficiario,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Registrar'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                '* Campos obligatorios',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
