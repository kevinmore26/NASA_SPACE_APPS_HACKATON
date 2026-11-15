import 'package:field_core/field_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/field_controller.dart';
import 'field_strings.dart';

const pine = Color(0xff142f26);
const forest = Color(0xff23523a);
const leaf = Color(0xffd9ecae);
const muted = Color(0xff536056);
const border = Color(0xffdedfd3);
const paper = Color(0xfffffefa);
const canvas = Color(0xfff2f1eb);

String coordinatesLabel(GeoPoint point) =>
    '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';

String connectionLabel(BuildContext context, FieldController model) {
  if (model.offline) return context.t('Offline mode', 'Modo sin conexión');
  return switch (model.networkStatus) {
    NetworkStatus.unverified => context.t(
      'Connection unchecked',
      'Conexión por verificar',
    ),
    NetworkStatus.reachable => context.t(
      'Last request connected',
      'Última consulta en línea',
    ),
    NetworkStatus.failed => context.t(
      'Service did not respond',
      'Servicio sin respuesta',
    ),
  };
}

String pageLabel(BuildContext context, FieldPage page) => switch (page) {
  FieldPage.home => context.t('Home', 'Inicio'),
  FieldPage.parcels => context.t('My fields', 'Mis terrenos'),
  FieldPage.map => context.t('Map', 'Mapa'),
  FieldPage.analysis => context.t('Observations', 'Observaciones'),
  FieldPage.rotations => context.t('Crop planning', 'Planificador'),
  FieldPage.settings => context.t('Settings', 'Configuración'),
};

class PageBody extends StatelessWidget {
  final Widget child;
  final String storageKey;
  final ScrollController? controller;
  const PageBody(
    this.storageKey, {
    super.key,
    required this.child,
    this.controller,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: PageStorageKey(storageKey),
    controller: controller,
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const PageHeading(this.title, {super.key, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 21),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: const TextStyle(color: muted)),
            ],
          ],
        ),
        ?action,
      ],
    ),
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = paper,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    elevation: 1,
    shadowColor: const Color(0x3a172e26),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title, detail;
  final Widget? action;
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: forest, size: 30),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(detail, style: const TextStyle(color: muted)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warning;
  final VoidCallback? onDismiss;
  const Notice(
    this.text, {
    super.key,
    this.icon = Icons.info_outline,
    this.warning = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: warning ? const Color(0xffffefd6) : const Color(0xffe9f1e6),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: warning ? const Color(0xff754607) : forest,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
          if (onDismiss != null)
            IconButton(
              tooltip: context.t('Dismiss notice', 'Cerrar aviso'),
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 17),
              constraints: const BoxConstraints.tightFor(width: 27, height: 24),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    ),
  );
}

class ParcelPicker extends StatelessWidget {
  final FieldController model;
  final FieldPage destination;
  const ParcelPicker(this.model, this.destination, {super.key});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey('parcel-${model.selected?.id}'),
    initialValue: model.selected?.id,
    isExpanded: true,
    hint: Text(context.t('Choose a field', 'Elige un terreno')),
    decoration: InputDecoration(labelText: context.t('Field', 'Terreno')),
    items: [
      for (final parcel in model.saved)
        DropdownMenuItem(
          value: parcel.id,
          child: Text(parcel.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: model.isBusy || model.editing || model.saved.isEmpty
        ? null
        : (id) {
            final parcel = model.saved.firstWhere((p) => p.id == id);
            model.select(parcel, destination: destination);
          },
  );
}

/// Keeps long provider values readable and copyable inside a scrolling panel.
class CopyValue extends StatelessWidget {
  final String value;
  final String label;

  const CopyValue(this.value, {super.key, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: const TextStyle(color: muted)),
      TextButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.t('Copied to clipboard', 'Copiado al portapapeles'),
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.copy_outlined, size: 16),
        label: Text(label),
      ),
    ],
  );
}
