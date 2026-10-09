import 'package:flutter/material.dart';

/// Описание одного поля формы.
class FormFieldSpec {
  final String key; // 'name', 'email'
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;

  const FormFieldSpec({
    required this.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.maxLines,
    this.enabled = true,
  });
}

/// Общий виджет формы: разметка + обработка отправки.
/// Специфичные поля передаются как список [FormFieldSpec]
/// или как [extraFields] — произвольные виджеты (дропдауны, чипы).
class EntityForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final String title;
  final List<FormFieldSpec> fields;
  final List<Widget> extraFields;
  final Future<void> Function() onSubmit;
  final VoidCallback onCancel;
  final String submitLabel;
  final double maxWidth;

  const EntityForm({
    super.key,
    required this.formKey,
    required this.title,
    required this.fields,
    required this.onSubmit,
    required this.onCancel,
    this.extraFields = const [],
    this.submitLabel = 'Сохранить',
    this.maxWidth = 720,
  });

  @override
  State<EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<EntityForm> {
  bool _submitting = false;

  Future<void> _handleSubmit() async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmit();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: widget.formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final f in widget.fields) ...[
                    TextFormField(
                      controller: f.controller,
                      enabled: f.enabled,
                      keyboardType: f.keyboardType,
                      maxLines: f.maxLines,
                      decoration: InputDecoration(
                        labelText: f.label,
                        border: const OutlineInputBorder(),
                      ),
                      validator: f.validator,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...widget.extraFields,
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _handleSubmit,
                    child: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.submitLabel),
                  ),
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
