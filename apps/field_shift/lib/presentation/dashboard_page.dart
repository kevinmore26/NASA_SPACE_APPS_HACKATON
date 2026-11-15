import 'package:field_core/field_core.dart';
import 'package:flutter/material.dart';

import '../application/field_controller.dart';
import 'field_strings.dart';
import 'workspace_widgets.dart';

class DashboardPage extends StatelessWidget {
  final FieldController model;

  const DashboardPage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final parcel = model.selected;
    final satellite = model.observations.latestUsable;
    final climateDay = model.weather?.days.lastOrNull;
    final climateDate = climateDay == null
        ? null
        : DateTime.tryParse(climateDay);

    return PageBody(
      'home',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            context.t('Home', 'Inicio'),
            action: FilledButton.icon(
              onPressed: model.isBusy ? null : model.newParcel,
              icon: const Icon(Icons.add, size: 20),
              label: Text(context.t('Add field', 'Añadir terreno')),
            ),
          ),
          _FieldCover(model, parcel: parcel),
          if (parcel != null) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, bounds) {
                final width = bounds.maxWidth >= 620
                    ? (bounds.maxWidth - 12) / 2
                    : bounds.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _FieldUpdate(
                        icon: Icons.satellite_alt_outlined,
                        tint: const Color(0xffecf2df),
                        label: context.t('Satellite image', 'Imagen satelital'),
                        value: satellite == null
                            ? context.t(
                                'No image analyzed yet',
                                'Aún no hay una imagen analizada',
                              )
                            : '${context.dateLabel(satellite.acquired)} · ${context.observationLabel(satellite.observation)}',
                        onTap: () {
                          model.viewObservations();
                          if (satellite != null && !model.isBusy) {
                            model.openResult(satellite);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _FieldUpdate(
                        icon: Icons.water_drop_outlined,
                        tint: const Color(0xffe9eff0),
                        label: context.t(
                          'Regional weather',
                          'Clima de la zona',
                        ),
                        value: climateDate == null
                            ? context.t(
                                'No weather history saved',
                                'Aún no hay datos del clima guardados',
                              )
                            : context.t(
                                'Saved through ${context.dateLabel(climateDate)}',
                                'Guardado hasta el ${context.dateLabel(climateDate)}',
                              ),
                        onTap: () => model.viewObservations(weather: true),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (model.saved.length > 1) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => model.goTo(FieldPage.parcels),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(
                    context.t(
                      'View your other fields',
                      'Ver tus otros terrenos',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FieldCover extends StatelessWidget {
  final FieldController model;
  final Parcel? parcel;

  const _FieldCover(this.model, {required this.parcel});

  @override
  Widget build(BuildContext context) {
    final field = parcel;
    final crop = field == null ? '' : context.currentCrop(field.farm);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: pine,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final narrow = bounds.maxWidth < 600;
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/punjab-fields.jpg',
                    fit: BoxFit.cover,
                    alignment: narrow
                        ? const Alignment(0.28, -0.7)
                        : const Alignment(0.3, 0),
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const ColoredBox(color: pine),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: narrow
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x25142f26),
                                Color(0xe3142f26),
                                pine,
                              ],
                              stops: [0, 0.45, 1],
                            )
                          : const LinearGradient(
                              colors: [
                                pine,
                                Color(0xf2142f26),
                                Color(0x21142f26),
                              ],
                              stops: [0, 0.39, 1],
                            ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: narrow ? 268 : 292,
                    maxWidth: narrow ? bounds.maxWidth : bounds.maxWidth * 0.65,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 17 : 28,
                        narrow ? 64 : 27,
                        narrow ? 17 : 24,
                        narrow ? 41 : 37,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (field != null) ...[
                            Text(
                              context.t('Active field', 'Terreno activo'),
                              style: const TextStyle(
                                color: leaf,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 7),
                          ],
                          Text(
                            field?.name ??
                                context.t(
                                  'Mark your first field',
                                  'Marca tu primer terreno',
                                ),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: narrow ? 25 : 35,
                                ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            field == null
                                ? context.t(
                                    'Find it on the map and click around its boundary. You can then check images and plan what to plant next.',
                                    'Encuéntralo en el mapa y marca sus límites. Luego podrás consultar imágenes y planear qué sembrar.',
                                  )
                                : [
                                    '${context.number(field.geometry.hectares)} ha',
                                    if (crop.isNotEmpty) crop,
                                  ].join(' · '),
                            style: const TextStyle(color: Color(0xfff0f4e9)),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => model.goTo(FieldPage.map),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0x35ffffff),
                                  side: const BorderSide(
                                    color: Color(0xa9ebf1e4),
                                  ),
                                ),
                                icon: const Icon(Icons.map_outlined, size: 19),
                                label: Text(
                                  context.t('Open map', 'Abrir mapa'),
                                ),
                              ),
                              if (field != null)
                                FilledButton.icon(
                                  onPressed: () =>
                                      model.goTo(FieldPage.rotations),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: leaf,
                                    foregroundColor: pine,
                                  ),
                                  icon: const Icon(
                                    Icons.eco_outlined,
                                    size: 19,
                                  ),
                                  label: Text(
                                    context.t(
                                      'Plan next crop',
                                      'Planear qué sembrar',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: Tooltip(
                    message: context.t(
                      'Aerial photo of Punjab, India',
                      'Fotografía aérea de Punjab, India',
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xd2142f26),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        child: Text(
                          context.t(
                            'Reference photo · Punjab',
                            'Foto de referencia · Punjab',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FieldUpdate extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label, value;
  final VoidCallback onTap;

  const _FieldUpdate({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Surface(
    padding: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(11),
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: forest, size: 20),
        ),
      ),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(value, style: const TextStyle(color: muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: forest, size: 21),
      onTap: onTap,
    ),
  );
}
