import 'package:field_core/field_core.dart';
import 'package:flutter/material.dart';

class FarmDialog extends StatefulWidget {
  final Parcel? parcel;
  const FarmDialog({super.key, this.parcel});
  @override
  State<FarmDialog> createState() => _FarmDialogState();
}

class _FarmDialogState extends State<FarmDialog> {
  late final List<TextEditingController> fields;
  final form = GlobalKey<FormState>();
  static const labels = [
    'Nombre del terreno',
    'Cultivo actual',
    'Historial de cultivos (cultivo y fechas)',
    'Tipo de suelo (si lo conoces)',
    'Agua disponible',
    'Sistema de riego',
    'Restricciones económicas',
    'Qué es más importante para ti',
  ];
  @override
  void initState() {
    super.initState();
    final p = widget.parcel;
    final f = p?.farm ?? const FarmRecord();
    fields = [
      p?.name ?? '',
      f.crop,
      f.history,
      f.soil,
      f.water,
      f.irrigation,
      f.budget,
      f.priorities,
    ].map((t) => TextEditingController(text: t)).toList();
  }

  @override
  void dispose() {
    for (final c in fields) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Guardar mi terreno'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Estos datos los registras tú. No son mediciones satelitales.',
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < fields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: fields[i],
                    decoration: InputDecoration(labelText: labels[i]),
                    maxLength: i == 0 ? 80 : 500,
                    validator: i == 0
                        ? (v) => v == null || v.trim().isEmpty
                              ? 'Escribe un nombre'
                              : null
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Volver'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, (
              name: fields[0].text,
              farm: FarmRecord(
                crop: fields[1].text,
                history: fields[2].text,
                soil: fields[3].text,
                water: fields[4].text,
                irrigation: fields[5].text,
                budget: fields[6].text,
                priorities: fields[7].text,
              ),
            ));
          }
        },
        child: const Text('Guardar terreno'),
      ),
    ],
  );
}
