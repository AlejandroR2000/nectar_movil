import 'package:flutter/material.dart';
import 'lista_beneficiarios_screen.dart';

class BeneficiariosScreen extends StatefulWidget {
  const BeneficiariosScreen({super.key});

  @override
  State<BeneficiariosScreen> createState() => _BeneficiariosScreenState();
}

class _BeneficiariosScreenState extends State<BeneficiariosScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beneficiarios'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 32,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Gestión de Beneficiarios',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'En esta sección podrás gestionar la información de los beneficiarios del programa.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Funcionalidades disponibles:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.search, color: Colors.green),
                title: const Text('Buscar Beneficiarios'),
                subtitle: const Text('Buscar beneficiarios por nombre o ID'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // TODO: Implementar búsqueda de beneficiarios
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Funcionalidad en desarrollo')),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.blue),
                title: const Text('Registrar Beneficiario'),
                subtitle: const Text('Agregar nuevo beneficiario al sistema'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // TODO: Implementar registro de beneficiarios
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Funcionalidad en desarrollo')),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.list, color: Colors.orange),
                title: const Text('Lista de Beneficiarios'),
                subtitle: const Text('Ver todos los beneficiarios registrados'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  print('Navegando a lista de beneficiarios');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ListaBeneficiariosScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
