import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';

/// Мои покупки. Для роли `client` сервер сам фильтрует по customerId.
class MySalesScreen extends StatefulWidget {
  const MySalesScreen({super.key});

  @override
  State<MySalesScreen> createState() => _MySalesScreenState();
}

class _MySalesScreenState extends State<MySalesScreen> {
  List<Map<String, dynamic>> _sales = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = context.read<Dio>();
      final response = await dio.get('/sales', queryParameters: {'size': 100});
      final data = response.data as Map<String, dynamic>;
      _sales = (data['items'] as List).cast<Map<String, dynamic>>();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои покупки')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_sales.isEmpty) {
      return const Center(child: Text('Покупок пока нет'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _sales.length,
      itemBuilder: (_, i) {
        final s = _sales[i];
        final product = s['product'] as Map<String, dynamic>?;
        final soldAt = s['soldAt'] as String?;
        return Card(
          child: ListTile(
            title: Text(product?['name'] as String? ?? '—'),
            subtitle: Text('Количество: ${s['quantity']} • $soldAt'),
            trailing: Chip(label: Text('${s['status']}')),
          ),
        );
      },
    );
  }
}