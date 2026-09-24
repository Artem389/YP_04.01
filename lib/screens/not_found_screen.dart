import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundScreen extends StatelessWidget {
  final String location;
  const NotFoundScreen({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('404')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off,
                  size: 72,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Страница не найдена',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  location,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: const Text('На главную'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}