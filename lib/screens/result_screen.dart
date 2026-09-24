import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../logic/calculator.dart';
import '../logic/currency.dart';

class ResultScreen extends StatelessWidget {
  final String title;
  final String expression;
  final Map<String, String> rawQuery;
  final String backPath;

  const ResultScreen({
    super.key,
    required this.title,
    required this.expression,
    required this.rawQuery,
    required this.backPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isCalculator = rawQuery.containsKey('op');

    if (isCalculator) {
      final result = calculate(rawQuery['a'], rawQuery['op'], rawQuery['b']);
      switch (result) {
        case CalcSuccess(:final value):
          return _success(context, 'Результат', formatNumber(value));
        case CalcFailure(:final message):
          return _failure(context, message);
      }
    } else {
      final result = convert(
        rawQuery['amount'],
        rawQuery['from'],
        rawQuery['to'],
      );
      switch (result) {
        case ConvertSuccess(:final value):
          return _success(context, 'Результат', formatNumber(value));
        case ConvertFailure(:final message):
          return _failure(context, message);
      }
    }
  }

  Widget _success(BuildContext context, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          expression,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.go(backPath),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Вернуться к форме'),
        ),
      ],
    );
  }

  Widget _failure(BuildContext context, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          expression,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.go(backPath),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Вернуться к форме'),
        ),
      ],
    );
  }
}