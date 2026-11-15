import 'package:flutter/material.dart';

import '../application/field_controller.dart';
import '../application/field_language.dart';
import 'field_strings.dart';
import 'map_workspace.dart' show MapLayers;
import 'workspace_widgets.dart';

class SettingsPage extends StatelessWidget {
  final FieldController model;
  final String? dataDirectory;
  const SettingsPage(this.model, {super.key, required this.dataDirectory});

  @override
  Widget build(BuildContext context) => PageBody(
    'settings',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(context.t('Settings', 'Configuración')),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 255),
                child: DropdownButtonFormField<FieldLanguage>(
                  key: ValueKey(model.language.value),
                  isExpanded: true,
                  initialValue: model.language.value,
                  decoration: InputDecoration(
                    labelText: context.t('Language', 'Idioma'),
                  ),
                  items: [
                    for (final locale in FieldLanguage.values)
                      DropdownMenuItem(
                        value: locale,
                        child: Text(locale.label),
                      ),
                  ],
                  onChanged: model.isBusy
                      ? null
                      : (value) {
                          if (value != null) model.setLanguage(value);
                        },
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('Work offline', 'Trabajar sin internet')),
                subtitle: Text(
                  dataDirectory == null
                      ? context.t(
                          'Use saved fields and observations in the open tab.',
                          'Usa terrenos y observaciones guardados en esta pestaña.',
                        )
                      : context.t(
                          'Use saved fields, map tiles, and observations.',
                          'Usa terrenos, mapas y observaciones guardados.',
                        ),
                ),
                value: model.offline,
                onChanged: model.isBusy
                    ? null
                    : (value) {
                        model.offline = value;
                        model.networkStatus = NetworkStatus.unverified;
                        model.emit();
                        model.preferences();
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.t('Advanced tools', 'Herramientas avanzadas'),
                ),
                subtitle: Text(
                  context.t(
                    'Choose Landsat, set a cloud limit, or inspect a pixel.',
                    'Elige Landsat, fija un límite de nubes o inspecciona un píxel.',
                  ),
                ),
                value: model.advanced,
                onChanged: (value) {
                  model.advanced = value;
                  model.emit();
                  model.preferences();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Surface(child: MapLayers(model)),
        const SizedBox(height: 12),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('Local storage', 'Almacenamiento local'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 7),
              Text(
                dataDirectory == null
                    ? context.t(
                        'Fields and observations are saved in this browser.',
                        'Los terrenos y las observaciones se guardan en este navegador.',
                      )
                    : context.t(
                        'Map cache: 128 MB. Image cache: 512 MB. Saved measurements stay in the field history.',
                        'Caché de mapas: 128 MB. Caché de imágenes: 512 MB. Las mediciones siguen guardadas en el historial.',
                      ),
              ),
              if (dataDirectory case final path?) ...[
                const SizedBox(height: 8),
                CopyValue(
                  path,
                  label: context.t(
                    'Copy data folder path',
                    'Copiar ruta de datos',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('About Field Shift', 'Acerca de Field Shift'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 7),
              Text(
                context.t(
                  'Sources: NASA POWER, NASA GIBS, ESA/Copernicus Sentinel-2, USGS/NASA Landsat and OpenStreetMap.',
                  'Fuentes: NASA POWER, NASA GIBS, Sentinel-2 ESA/Copernicus, Landsat USGS/NASA y OpenStreetMap.',
                ),
              ),
              TextButton.icon(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'NASA Field Shift',
                  applicationVersion: '0.2.1',
                ),
                icon: const Icon(Icons.info_outline),
                label: Text(
                  context.t('Software licenses', 'Licencias de software'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
