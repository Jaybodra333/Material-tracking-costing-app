import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/material_model.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  int _selectedIndex = 0;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _updateConnectionStatus(result);
      if (_isOnline) {
        _syncData();
      }
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> _syncData() async {
    await _databaseService.syncMaterials();
    // Add more sync operations here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operator Dashboard'),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              color: _isOnline ? Colors.green : Colors.red,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _ScannerView(),
          _TasksView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  final DatabaseService _databaseService = DatabaseService();
  MaterialModel? _scannedMaterial;
  bool _isScanning = false;  // Changed to false by default
  MobileScannerController? _scannerController;

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _startScanning() {
    _scannerController = MobileScannerController();
    setState(() => _isScanning = true);
  }

  void _stopScanning() {
    _scannerController?.dispose();
    _scannerController = null;
    setState(() => _isScanning = false);
  }

  Widget _buildMaterialCard() {
    if (_scannedMaterial == null) return const SizedBox.shrink();

    final costs = _scannedMaterial!.calculateCosts(1); // Calculate for single unit

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _scannedMaterial!.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Barcode: ${_scannedMaterial!.barcode}'),
            Text('Unit Cost: \$${_scannedMaterial!.unitCost}'),
            Text('Quantity: ${_scannedMaterial!.quantity}'),
            Text('Unit: ${_scannedMaterial!.unit}'),
            Text('Category: ${_scannedMaterial!.category}'),
            const Divider(),
            Text(
              'Cost Breakdown (Per Unit):',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Raw Material Cost: \$${costs.rawMaterialCost.toStringAsFixed(2)}'),
            Text('Processing Cost: \$${costs.processingCost.toStringAsFixed(2)}'),
            Text('Manufacturing Cost: \$${costs.manufacturingCost.toStringAsFixed(2)}'),
            Text('Suggested Price: \$${costs.unitPrice.toStringAsFixed(2)}'),
            Text('Profit Margin: \$${costs.unitProfit.toStringAsFixed(2)} (${costs.profitPercentage.toStringAsFixed(1)}%)'),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _scannedMaterial = null;
                      _isScanning = true;
                    });
                  },
                  child: const Text('Scan Again'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _logUsage(context),
                  child: const Text('Log Usage'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isScanning && _scannedMaterial == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _startScanning,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Start Scanner'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
          ),
        if (_isScanning)
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      _stopScanning();
                      final code = barcodes.first.rawValue ?? '';
                      await _handleBarcode(code);
                    }
                  },
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: _stopScanning,
                    child: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        if (_scannedMaterial != null)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildMaterialCard(),
            ),
          ),
      ],
    );
  }

  Future<void> _handleBarcode(String code) async {
    print('Scanned barcode: $code'); // Debug log
    try {
      final material = await _databaseService.getMaterialByBarcode(code);
      if (material != null) {
        setState(() => _scannedMaterial = material);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Material not found with barcode: $code'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _startScanning(),
              ),
            ),
          );
          setState(() => _isScanning = true);
        }
      }
    } catch (e) {
      print('Error in barcode handling: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching material: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isScanning = true);
      }
    }
  }

  Future<void> _logUsage(BuildContext context) async {
    try {
      // Show dialog to input quantity
      final quantity = await showDialog<int>(
        context: context,
        builder: (context) => _UsageLogDialog(),
      );

      if (quantity != null && quantity > 0) {
        await _databaseService.logMaterialUsage(
          _scannedMaterial!.id,
          quantity,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usage logged successfully')),
          );
          setState(() {
            _scannedMaterial = null;
            _isScanning = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _UsageLogDialog extends StatefulWidget {
  @override
  State<_UsageLogDialog> createState() => _UsageLogDialogState();
}

class _UsageLogDialogState extends State<_UsageLogDialog> {
  final _quantityController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Material Usage'),
      content: TextField(
        controller: _quantityController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Quantity Used',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final quantity = int.tryParse(_quantityController.text);
            Navigator.pop(context, quantity);
          },
          child: const Text('Log'),
        ),
      ],
    );
  }
}

class _LogsView extends StatelessWidget {
  final DatabaseService _databaseService = DatabaseService();

  _LogsView();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _databaseService.getConsumptionHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final logs = snapshot.data ?? [];
        
        if (logs.isEmpty) {
          return const Center(child: Text('No usage logs found'));
        }

        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final date = DateTime.fromMillisecondsSinceEpoch(log['timestamp'] as int);
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: ListTile(
                title: Text(log['material_name'] ?? 'Unknown Material'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantity: ${log['quantity']} ${log['material_unit'] ?? ''}'),
                    Text('Date: ${date.toString().split('.')[0]}'),
                    if (log['product_name'] != null)
                      Text('Product: ${log['product_name']}'),
                    if (log['batch_number'] != null)
                      Text('Batch: ${log['batch_number']}'),
                  ],
                ),
                trailing: Icon(
                  log['is_synced'] == 1 ? Icons.cloud_done : Icons.cloud_queue,
                  color: log['is_synced'] == 1 ? Colors.green : Colors.grey,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TasksView extends StatelessWidget {
  const _TasksView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Assigned Tasks'),
    );
  }
}
