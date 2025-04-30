import 'package:flutter/material.dart';
import '../../../services/database_service.dart';

class AnalyticsPage extends StatefulWidget {
  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _databaseService = DatabaseService();
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Usage'),
              Tab(text: 'Stock'),
              Tab(text: 'Costs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsageAnalytics(),
            _buildStockAnalytics(),
            _buildCostAnalytics(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageAnalytics() {
    return FutureBuilder(
      future: _databaseService.getUsageAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Build usage analytics visualization
        return const Center(child: Text('Usage Analytics'));
      },
    );
  }

  Widget _buildStockAnalytics() {
    return FutureBuilder(
      future: _databaseService.getStockAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Build stock analytics visualization
        return const Center(child: Text('Stock Analytics'));
      },
    );
  }

  Widget _buildCostAnalytics() {
    return FutureBuilder(
      future: _databaseService.getCostAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Build cost analytics visualization
        return const Center(child: Text('Cost Analytics'));
      },
    );
  }
}
