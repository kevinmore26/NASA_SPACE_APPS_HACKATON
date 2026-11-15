import 'package:field_core/field_core.dart';
import 'package:flutter/material.dart';

import 'field_strings.dart';

class FarmDialog extends StatefulWidget {
  final Parcel? parcel;
  const FarmDialog({super.key, this.parcel});

  @override
  State<FarmDialog> createState() => _FarmDialogState();
}

class _FarmDialogState extends State<FarmDialog> {
  late final List<TextEditingController> _fields;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final parcel = widget.parcel;
    final farm = parcel?.farm ?? const FarmRecord();
    _fields = [
      parcel?.name ?? '',
      farm.crop,
      farm.history,
      farm.soil,
      farm.water,
      farm.irrigation,
      farm.budget,
      farm.priorities,
    ].map((text) => TextEditingController(text: text)).toList();
  }

  @override
  void dispose() {
    for (final controller in _fields) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (
      name: _fields[0].text.trim(),
      farm: FarmRecord(
        crop: _fields[1].text,
        history: _fields[2].text,
        soil: _fields[3].text,
        water: _fields[4].text,
        irrigation: _fields[5].text,
        budget: _fields[6].text,
        priorities: _fields[7].text,
        planning: widget.parcel?.farm.planning,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final planning = widget.parcel?.farm.planning;
    final details = [
      context.t('Past crops', 'Cultivos anteriores'),
      context.t('Soil', 'Suelo'),
      context.t('Water available', 'Agua disponible'),
      context.t('Irrigation', 'Riego'),
      context.t('Budget', 'Presupuesto'),
      context.t('Priorities', 'Prioridades'),
    ];
    return AlertDialog(
      title: Text(context.t('Field information', 'Información del terreno')),
      content: SizedBox(
        width: 424,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(0, context.t('Field name', 'Nombre del terreno')),
                const SizedBox(height: 10),
                _field(
                  1,
                  planning == null
                      ? context.t(
                          'Current crop (optional)',
                          'Cultivo actual (opcional)',
                        )
                      : context.t(
                          'Crop notes (optional)',
                          'Notas del cultivo (opcional)',
                        ),
                ),
                if (planning != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.t(
                      'Edit the inputs for comparisons in Crop planning.',
                      'Edita los datos para comparar cultivos en el Planificador.',
                    ),
                  ),
                ],
                ExpansionTile(
                  key: const PageStorageKey('field-notes'),
                  tilePadding: EdgeInsets.zero,
                  maintainState: true,
                  title: Text(
                    context.t(
                      'Other notes (optional)',
                      'Otras notas (opcional)',
                    ),
                  ),
                  children: [
                    for (var index = 0; index < details.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _field(index + 2, details[index]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('Cancel', 'Cancelar')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.t('Save information', 'Guardar información')),
        ),
      ],
    );
  }

  Widget _field(int index, String label) => TextFormField(
    key: PageStorageKey('field-information-input-$index'),
    controller: _fields[index],
    autofocus: index == 0,
    maxLength: index == 0 ? 80 : 500,
    decoration: InputDecoration(labelText: label, counterText: ''),
    validator: index == 0
        ? (value) => value == null || value.trim().isEmpty
              ? context.t('Enter a name.', 'Escribe un nombre.')
              : null
        : null,
  );
}
