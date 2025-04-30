import 'package:flutter/material.dart';
import '../../../models/material_model.dart';
import '../../../services/database_service.dart';

class MaterialListPage extends StatefulWidget {
  @override
  _MaterialListPageState createState() => _MaterialListPageState();
}

class _MaterialListPageState extends State<MaterialListPage> {
  final _databaseService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Materials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showMaterialForm(context),
          ),
        ],
      ),
      body: FutureBuilder<List<MaterialModel>>(
        future: _databaseService.getMaterials(forceOnline: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final materials = snapshot.data ?? [];
          return ListView.builder(
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final material = materials[index];
              return ListTile(
                title: Text(material.name),
                subtitle: Text('Quantity: ${material.quantity} ${material.unit}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showMaterialForm(context, material),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteMaterial(material),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showMaterialForm(BuildContext context, [MaterialModel? material]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => MaterialFormDialog(material: material),
    );

    if (result != null) {
      // Handle save
    }
  }

  Future<void> _deleteMaterial(MaterialModel material) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Are you sure you want to delete ${material.name}?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Handle delete
    }
  }
}
