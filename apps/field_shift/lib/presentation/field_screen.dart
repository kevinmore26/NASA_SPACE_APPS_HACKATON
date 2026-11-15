import 'package:field_core/field_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../application/field_controller.dart';
import 'dashboard_page.dart';
import 'farm_dialog.dart';
import 'field_navigation.dart';
import 'field_strings.dart';
import 'map_workspace.dart';
import 'parcels_page.dart';
import 'rotation_page.dart';
import 'settings_page.dart';
import 'workspace_widgets.dart';

class FieldScreen extends StatefulWidget {
  final FieldController model;
  final http.Client tiles;
  final String dataDirectory;
  const FieldScreen({
    super.key,
    required this.model,
    required this.tiles,
    required this.dataDirectory,
  });

  @override
  State<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends State<FieldScreen> {
  FieldController get m => widget.model;
  var _mapVisited = false;
  var _analyzing = false;

  Future<void> _saveDetails() async {
    final error = FieldGeometry.validationIssue(m.vertices);
    if (error != null) {
      m.feedback(context.geometryIssue(error), error: true);
      return;
    }
    final data = await showDialog<({String name, FarmRecord farm})>(
      context: context,
      builder: (_) => FarmDialog(parcel: m.selected),
    );
    if (data != null && mounted) await m.save(data.name, data.farm);
  }

  Future<void> _delete(Parcel? parcel) async {
    if (parcel == null || m.isBusy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('Remove this field?', '¿Eliminar este terreno?')),
        content: Text(
          context.t(
            'The boundary and notes for ${parcel.name} will be removed from this device. Saved observations stay archived.',
            'Se eliminarán los límites y las notas de ${parcel.name} de este equipo. Las observaciones seguirán archivadas.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('Keep field', 'Conservar terreno')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('Remove field', 'Eliminar terreno')),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await m.select(parcel, destination: FieldPage.parcels);
    if (m.selected?.id == parcel.id) await m.deleteSelected();
  }

  Future<void> _parcelAction(Parcel parcel, ParcelAction action) async {
    if (m.isBusy) return;
    if (action == ParcelAction.delete) {
      await _delete(parcel);
      return;
    }
    final page = switch (action) {
      ParcelAction.analysis => FieldPage.analysis,
      ParcelAction.rotate => FieldPage.rotations,
      ParcelAction.details => FieldPage.parcels,
      _ => FieldPage.map,
    };
    if (action == ParcelAction.analysis) m.showingWeather = false;
    await m.select(parcel, destination: page);
    if (!mounted) return;
    if (action == ParcelAction.details) await _saveDetails();
    if (action == ParcelAction.limits) m.edit();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: m,
    builder: (context, _) {
      final mapVisible =
          m.page == FieldPage.map || m.page == FieldPage.analysis;
      if (mapVisible) {
        _mapVisited = true;
        _analyzing = m.page == FieldPage.analysis;
      }
      return LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 950;
          return Scaffold(
            appBar: compact ? FieldAppBar(m) : null,
            bottomNavigationBar: compact ? FieldBottomNavigation(m) : null,
            body: SafeArea(
              child: Row(
                children: [
                  SizedBox(
                    width: compact ? 0 : 214,
                    child: compact ? null : FieldSidebar(m),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        if (m.isBusy)
                          _Activity(m)
                        else if (m.message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: Semantics(
                              liveRegion: true,
                              child: Notice(
                                m.message,
                                warning: m.hasError,
                                icon: m.hasError
                                    ? Icons.info_outline
                                    : Icons.check_circle_outline,
                                onDismiss: () => m.feedback(''),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_mapVisited)
                                Offstage(
                                  offstage: !mapVisible,
                                  child: ExcludeFocus(
                                    excluding: !mapVisible,
                                    child: TickerMode(
                                      enabled: mapVisible,
                                      child: MapWorkspace(
                                        model: m,
                                        tiles: widget.tiles,
                                        analyzing: _analyzing,
                                        save: _saveDetails,
                                        delete: () => _delete(m.selected),
                                      ),
                                    ),
                                  ),
                                ),
                              if (!mapVisible)
                                switch (m.page) {
                                  FieldPage.home => DashboardPage(m),
                                  FieldPage.parcels => ParcelsPage(
                                    m,
                                    onAction: _parcelAction,
                                  ),
                                  FieldPage.rotations => RotationPage(
                                    m,
                                    key: ValueKey(m.selected?.id),
                                  ),
                                  FieldPage.settings => SettingsPage(
                                    m,
                                    dataDirectory: widget.dataDirectory,
                                  ),
                                  _ => const SizedBox.shrink(),
                                },
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _Activity extends StatelessWidget {
  final FieldController model;
  const _Activity(this.model);

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      children: [
        const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(model.busy)),
              if (model.canCancel)
                TextButton(
                  onPressed: model.cancel,
                  child: Text(context.t('Cancel', 'Cancelar')),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
