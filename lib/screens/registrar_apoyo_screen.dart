import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class RegistrarApoyoScreen extends StatefulWidget {
  const RegistrarApoyoScreen({super.key});

  @override
  State<RegistrarApoyoScreen> createState() => _RegistrarApoyoScreenState();
}

class _RegistrarApoyoScreenState extends State<RegistrarApoyoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _beneficiarioController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _montoController = TextEditingController();

  bool _isLoading = false;
  bool _isBeneficiarioLoading = false;
  List<Map<String, dynamic>> _beneficiarios = [];
  List<Map<String, dynamic>> _tiposApoyo = [];
  Map<String, dynamic>? _beneficiarioSeleccionado;
  Map<String, dynamic>? _tipoApoyoSeleccionado;
  Map<String, dynamic>? _saldoApoyo;
  bool _isSaldoLoading = false;
  double _saldoRestante = 0.0;
  bool _excedeSaldo = false;

  @override
  void initState() {
    super.initState();
    _cargarTiposApoyo();
    _cargarSaldoApoyo();
    
    // Listener para actualizar saldo en tiempo real
    _montoController.addListener(_actualizarSaldoRestante);
  }

  @override
  void dispose() {
    _beneficiarioController.dispose();
    _observacionesController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _cargarTiposApoyo() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.obtenerTipoApoyoUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tiposApoyo = List<Map<String, dynamic>>.from(data);
        });
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _mostrarMensaje(
          'Error del servidor al cargar tipos de apoyo',
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      _mostrarMensaje(
        'Error de conexión al cargar tipos de apoyo',
        Colors.red,
        Icons.error,
      );
    }
  }

  Future<void> _cargarSaldoApoyo() async {
    setState(() {
      _isSaldoLoading = true;
    });

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();
      
      if (token == null || userId == null) {
        throw Exception('Token o ID de usuario no disponible');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.obtenerSaldoApoyoUrl}?id=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _saldoApoyo = data;
          _isSaldoLoading = false;
        });
        _actualizarSaldoRestante(); // Actualizar saldo restante después de cargar
      } else if (response.statusCode == 404) {
        setState(() {
          _saldoApoyo = null;
          _isSaldoLoading = false;
        });
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        throw Exception('Error al obtener saldo: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isSaldoLoading = false;
      });
      _mostrarMensaje(
        'Error al cargar saldo disponible',
        Colors.red,
        Icons.error,
      );
    }
  }

  void _actualizarSaldoRestante() {
    if (_saldoApoyo == null) return;
    
    final montoIngresado = double.tryParse(_montoController.text) ?? 0.0;
    final saldoDisponible = (_saldoApoyo!['cantidadDisponible'] ?? 0).toDouble();
    
    setState(() {
      _saldoRestante = saldoDisponible - montoIngresado;
      _excedeSaldo = montoIngresado > saldoDisponible;
    });
  }

  Future<void> _buscarBeneficiarios(String query) async {
    if (query.length < 2) {
      setState(() {
        _beneficiarios = [];
      });
      return;
    }

    setState(() {
      _isBeneficiarioLoading = true;
    });

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.obtenerBeneficiariosUrl}?pageNumber=1&pageSize=20&search=$query&searchField=nombre',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _beneficiarios = List<Map<String, dynamic>>.from(
            data['beneficiarios'] ?? [],
          );
        });
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _beneficiarios = [];
        });
      }
    } catch (e) {
      setState(() {
        _beneficiarios = [];
      });
    } finally {
      setState(() {
        _isBeneficiarioLoading = false;
      });
    }
  }

  Future<void> _registrarApoyo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_beneficiarioSeleccionado == null) {
      _mostrarMensaje(
        'Debe seleccionar un beneficiario',
        Colors.red,
        Icons.error,
      );
      return;
    }

    if (_tipoApoyoSeleccionado == null) {
      _mostrarMensaje(
        'Debe seleccionar un tipo de apoyo',
        Colors.red,
        Icons.error,
      );
      return;
    }

    // Validar saldo disponible
    final montoApoyo = double.tryParse(_montoController.text) ?? 0;
    final saldoDisponible = (_saldoApoyo?['cantidadDisponible'] ?? 0).toDouble();
    
    if (_saldoApoyo == null) {
      _mostrarMensaje(
        'No se pudo verificar el saldo disponible. Intente nuevamente.',
        Colors.red,
        Icons.error,
      );
      return;
    }

    if (montoApoyo > saldoDisponible) {
      _mostrarMensaje(
        'El monto del apoyo (\$${montoApoyo.toStringAsFixed(2)}) excede el saldo disponible (\$${saldoDisponible.toStringAsFixed(2)})',
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

      final apoyo = {
        'idApoyo': 0,
        'idBeneficiario': _beneficiarioSeleccionado!['idBeneficiario'],
        'beneficiario':
            '${_beneficiarioSeleccionado!['nombre'] ?? ''} ${_beneficiarioSeleccionado!['apellidoPaterno'] ?? ''} ${_beneficiarioSeleccionado!['apellidoMaterno'] ?? ''}'
                .trim(),
        'curp': _beneficiarioSeleccionado!['curp'] ?? '',
        'rfc': _beneficiarioSeleccionado!['rfc'] ?? '',
        'idTipoApoyo': _tipoApoyoSeleccionado!['id'],
        'tipoApoyo': _tipoApoyoSeleccionado!['descripcion'],
        'monto': double.tryParse(_montoController.text) ?? 0,
        'comentario': _observacionesController.text.trim(),
        'folio': '',
        'fechaPago': DateTime.now().toIso8601String(),
        'fechaRegistro': DateTime.now().toIso8601String(),
        'idUsuarioCreacion': int.parse(userId),
        'fechaActualizacion': DateTime.now().toIso8601String(),
        'idUsuarioUltiAct': int.parse(userId),
        'atributo': 0,
        'idDireccion': _beneficiarioSeleccionado!['idDireccion'] ?? 0,
        'direccion': null,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.agregarApoyoUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(apoyo),
      );

      if (response.statusCode == 200) {
        _mostrarMensaje(
          'Apoyo registrado exitosamente',
          Colors.green,
          Icons.check,
        );

        // Limpiar formulario
        setState(() {
          _beneficiarioSeleccionado = null;
          _tipoApoyoSeleccionado = null;
          _beneficiarios = [];
          _saldoRestante = 0.0;
          _excedeSaldo = false;
        });
        _beneficiarioController.clear();
        _observacionesController.clear();
        _montoController.clear();
        _formKey.currentState!.reset();

        // Regresar a la pantalla anterior inmediatamente
        Navigator.pop(context);
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _mostrarMensaje('Error al registrar apoyo', Colors.red, Icons.error);
      }
    } catch (e) {
      _mostrarMensaje(
        'Error de conexión al registrar apoyo',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Apoyo'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                          Icon(Icons.add_box, size: 32, color: Colors.green),
                          const SizedBox(width: 12),
                          const Text(
                            'Nuevo Apoyo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Complete los datos para registrar un nuevo apoyo.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Campo de búsqueda de beneficiario
              const Text(
                'Beneficiario *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _beneficiarioController,
                decoration: InputDecoration(
                  labelText: 'Buscar beneficiario por nombre',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isBeneficiarioLoading
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
                onChanged: _buscarBeneficiarios,
                validator: (value) {
                  if (_beneficiarioSeleccionado == null) {
                    return 'Debe seleccionar un beneficiario';
                  }
                  return null;
                },
              ),

              // Lista de beneficiarios encontrados
              if (_beneficiarios.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _beneficiarios.length,
                    itemBuilder: (context, index) {
                      final beneficiario = _beneficiarios[index];
                      final nombreCompleto =
                          '${beneficiario['nombre'] ?? ''} ${beneficiario['apellidoPaterno'] ?? ''} ${beneficiario['apellidoMaterno'] ?? ''}'
                              .trim();
                      final colonia =
                          beneficiario['direccion']?['colonia'] ??
                          'No especificada';

                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(nombreCompleto),
                        subtitle: Text(
                          'CURP: ${beneficiario['curp'] ?? ''}\n'
                          'Colonia: $colonia',
                        ),
                        onTap: () {
                          setState(() {
                            _beneficiarioSeleccionado = beneficiario;
                            _beneficiarioController.text = nombreCompleto;
                            _beneficiarios = [];
                          });
                        },
                      );
                    },
                  ),
                ),
              ],

              // Mostrar mensaje si no hay beneficiarios encontrados (pero solo si no hay uno seleccionado)
              if (_beneficiarios.isEmpty &&
                  _beneficiarioController.text.length >= 2 &&
                  !_isBeneficiarioLoading &&
                  _beneficiarioSeleccionado == null) ...[
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
                        'Beneficiario no existe',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Información del beneficiario seleccionado
              if (_beneficiarioSeleccionado != null) ...[
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
                              'Beneficiario seleccionado:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nombre: ${_beneficiarioSeleccionado!['nombre']} ${_beneficiarioSeleccionado!['apellidoPaterno'] ?? ''} ${_beneficiarioSeleccionado!['apellidoMaterno'] ?? ''}',
                        ),
                        Text('CURP: ${_beneficiarioSeleccionado!['curp']}'),
                        Text(
                          'Colonia: ${_beneficiarioSeleccionado!['direccion']?['colonia'] ?? 'No especificada'}',
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _beneficiarioSeleccionado = null;
                              _beneficiarioController.clear();
                            });
                          },
                          child: const Text('Cambiar beneficiario'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Dropdown de tipo de apoyo
              const Text(
                'Tipo de Apoyo *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _tipoApoyoSeleccionado,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.support),
                ),
                hint: const Text('Seleccionar tipo de apoyo'),
                items: _tiposApoyo.map((tipo) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: tipo,
                    child: Text(
                      tipo['descripcion'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _tipoApoyoSeleccionado = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Debe seleccionar un tipo de apoyo';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Campo de monto
              const Text(
                'Monto *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Monto del apoyo',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _excedeSaldo ? Colors.red : Colors.grey,
                      width: _excedeSaldo ? 2 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _excedeSaldo ? Colors.red : Colors.grey,
                      width: _excedeSaldo ? 2 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _excedeSaldo ? Colors.red : Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: _excedeSaldo ? Colors.red : null,
                  ),
                  prefixText: '\$ ',
                  labelStyle: TextStyle(
                    color: _excedeSaldo ? Colors.red : null,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El monto es requerido';
                  }
                  final monto = double.tryParse(value);
                  if (monto == null || monto <= 0) {
                    return 'Ingrese un monto válido mayor a 0';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Información del saldo disponible
              if (_saldoApoyo != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _excedeSaldo ? Colors.red.shade50 : Colors.blue.shade50,
                    border: Border.all(
                      color: _excedeSaldo ? Colors.red.shade300 : Colors.blue.shade300,
                      width: _excedeSaldo ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _excedeSaldo ? Icons.error : Icons.check_circle,
                        color: _excedeSaldo ? Colors.red.shade700 : Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _excedeSaldo 
                            ? 'Excede el saldo por: \$${(-_saldoRestante).toStringAsFixed(2)}'
                            : 'Saldo disponible: \$${_saldoRestante.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _excedeSaldo ? Colors.red.shade700 : Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Campo de observaciones
              const Text(
                'Observaciones',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _observacionesController,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
                maxLength: 500,
              ),

              const SizedBox(height: 32),

              // Botón de registro
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registrarApoyo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text('Registrar Apoyo'),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
