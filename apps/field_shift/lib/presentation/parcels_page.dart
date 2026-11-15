import 'package:field_core/field_core.dart';
import 'package:flutter/material.dart';

import '../application/field_controller.dart';
import 'field_boundary_preview.dart';
import 'field_strings.dart';
import 'workspace_widgets.dart';

enum ParcelAction {
  view('Open map', 'Ver parcela', Icons.map_outlined),
  details('Edit information', 'Editar información', Icons.edit_note),
  limits('Edit boundary', 'Corregir límites', Icons.edit_location_alt_outlined),
  analysis('View observations', 'Consultar análisis', Icons.insights_outlined),
  rotate('Plan crops', 'Planificar rotaciones', Icons.eco_outlined),
  delete('Remove field', 'Eliminar terreno', Icons.delete_outline);

  const ParcelAction(this.english, this.spanish, this.icon);
  final String english, spanish;
  final IconData icon;
}

class ParcelsPage extends StatelessWidget {
  final FieldController model;
  final void Function(Parcel, ParcelAction) onAction;
  const ParcelsPage(this.model, {super.key, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final create = model.isBusy ? null : model.newParcel;
    final parcels = [...model.saved]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return PageBody(
      'terrenos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            context.t('My fields', 'Mis terrenos'),
            subtitle: context.t(
              'Boundaries and notes are saved on this device.',
              'Límites y registros disponibles sin internet.',
            ),
            action: FilledButton.icon(
              onPressed: create,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(context.t('Add field', 'Nuevo terreno')),
            ),
          ),
          if (parcels.isEmpty)
            EmptyPanel(
              icon: Icons.landscape_outlined,
              title: context.t(
                'No fields saved yet',
                'Aún no hay terrenos guardados',
              ),
              detail: context.t(
                'Mark a boundary on the map to see observations for your field.',
                'Marca el contorno de tu parcela para guardar sus límites y consultar observaciones.',
              ),
              action: OutlinedButton(
                onPressed: create,
                child: Text(
                  context.t('Mark a field', 'Marcar terreno en el mapa'),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 3
                    : constraints.maxWidth >= 650
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - 14 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final parcel in parcels)
                      SizedBox(width: width, child: _card(context, parcel)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Parcel parcel) {
    final observations = model.observationsFor(parcel);
    final count = observations.rasters.length;
    final active = parcel.id == model.selected?.id;
    final crop = context.currentCrop(parcel.farm);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FieldBoundaryPreview(parcel.geometry),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parcel.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${context.number(parcel.geometry.hectares)} ha',
                      style: const TextStyle(color: muted),
                    ),
                    if (active) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.t('Active', 'Activo'),
                        style: const TextStyle(
                          color: forest,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<ParcelAction>(
                tooltip: context.t(
                  'Options for ${parcel.name}',
                  'Opciones de ${parcel.name}',
                ),
                enabled: !model.isBusy,
                onSelected: (action) => onAction(parcel, action),
                itemBuilder: (context) => [
                  for (final action in ParcelAction.values)
                    PopupMenuItem(
                      value: action,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(action.icon, size: 20),
                        title: Text(context.t(action.english, action.spanish)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 23),
          Text(
            coordinatesLabel(parcel.geometry.bounds.center),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            crop.isEmpty
                ? context.t('Crop not recorded', 'Cultivo por registrar')
                : crop,
          ),
          Text(
            context.t(
              'Edited ${context.dateLabel(parcel.updatedAt.toLocal())}',
              'Editado el ${context.dateLabel(parcel.updatedAt.toLocal())}',
            ),
            style: const TextStyle(color: muted),
          ),
          Text(
            observations.incomplete
                ? context.t(
                    'Some history unavailable',
                    'Historial disponible parcialmente',
                  )
                : count == 0
                ? context.t('No saved observations', 'Sin análisis guardados')
                : (count == 1
                      ? context.t(
                          '1 saved observation',
                          '1 observación guardada',
                        )
                      : context.t(
                          '$count saved observations',
                          '$count observaciones guardadas',
                        )),
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonal(
                onPressed: model.isBusy
                    ? null
                    : () => onAction(parcel, ParcelAction.view),
                child: Text(context.t('Open map', 'Ver parcela')),
              ),
              TextButton(
                onPressed: model.isBusy
                    ? null
                    : () => onAction(parcel, ParcelAction.analysis),
                child: Text(
                  context.t('View observations', 'Consultar análisis'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
