import 'package:field_core/field_core.dart';
import 'package:field_rotations/field_rotations.dart';
import 'package:flutter/material.dart';

import '../application/field_controller.dart';
import 'crop_suitability_panel.dart';
import 'field_strings.dart';
import 'period_picker.dart';
import 'rotation_form.dart';
import 'workspace_widgets.dart';

class RotationPage extends StatefulWidget {
  final FieldController model;
  const RotationPage(this.model, {super.key});

  @override
  State<RotationPage> createState() => _RotationPageState();
}

class _RotationPageState extends State<RotationPage> {
  final _scroll = ScrollController();
  bool? _editing;
  FieldController get m => widget.model;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parcel = m.selected;
    final planting = parcel?.farm.planning;
    final edit = _editing ?? planting == null;
    return PageBody(
      'crop-planning',
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            context.t('Plan your next crop', 'Planea qué sembrar'),
            action: parcel != null && planting != null && !m.editing
                ? OutlinedButton.icon(
                    onPressed: m.isBusy
                        ? null
                        : () => setState(() => _editing = !edit),
                    icon: Icon(
                      edit ? Icons.close : Icons.edit_outlined,
                      size: 18,
                    ),
                    label: Text(
                      edit
                          ? context.t('Close editor', 'Cerrar edición')
                          : context.t(
                              'Edit field notes',
                              'Editar datos del terreno',
                            ),
                    ),
                  )
                : null,
          ),
          if (m.saved.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 425),
                child: ParcelPicker(m, FieldPage.rotations),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (m.editing || parcel == null)
            EmptyPanel(
              icon: Icons.eco_outlined,
              title: context.t(
                'Choose a saved field',
                'Elige un terreno guardado',
              ),
              detail: context.t(
                'Save a field boundary to start planning.',
                'Guarda los límites de un terreno para empezar a planear.',
              ),
              action: OutlinedButton(
                onPressed: m.editing
                    ? () => m.goTo(FieldPage.map)
                    : m.newParcel,
                child: Text(context.t('Go to map', 'Ir al mapa')),
              ),
            )
          else ...[
            if (m.cropSuitabilityClient != null) ...[
              CropSuitabilityPanel(model: m),
              const SizedBox(height: 16),
            ],
            Text(
              context.t(
                'This pilot covers irrigated yellow field corn on the coast of Lambayeque, Peru.',
                'El piloto cubre maíz amarillo duro bajo riego en la costa de Lambayeque, Perú.',
              ),
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            if (edit)
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: RotationForm(
                    record: parcel.farm,
                    busy: m.isBusy,
                    onSave: (farm) async {
                      if (await m.saveFarm(farm) && mounted) {
                        setState(() => _editing = false);
                        if (_scroll.hasClients) _scroll.jumpTo(0);
                      }
                    },
                  ),
                ),
              )
            else
              _Comparison(model: m, parcel: parcel),
          ],
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  final FieldController model;
  final Parcel parcel;
  const _Comparison({required this.model, required this.parcel});

  @override
  Widget build(BuildContext context) {
    final plan = const RotationEngine().compare(parcel);
    final profile = parcel.farm.planning!;
    final crop = context.currentCrop(parcel.farm);
    final regionOutside = plan.issues.contains(RotationIssue.unsupportedRegion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (regionOutside) ...[
          Notice(
            context.t(
              'Your field is outside the pilot area. You can keep your current plan and check field observations.',
              'Tu terreno está fuera de la zona piloto. Puedes guardar tu plan actual y consultar las observaciones del terreno.',
            ),
            warning: true,
          ),
          const SizedBox(height: 12),
        ] else if (plan.issues.isNotEmpty) ...[
          Notice(
            [
              context.t(
                'What to check before comparing more crops',
                'Qué revisar para comparar más cultivos',
              ),
              for (final issue in plan.issues) '• ${_issue(context, issue)}',
            ].join('\n'),
            warning: true,
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, size) {
            final columns =
                plan.alternatives.length == 2 && size.maxWidth >= 910
                ? 3
                : plan.alternatives.isNotEmpty && size.maxWidth >= 600
                ? 2
                : 1;
            final width = (size.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _Scenario(
                    title: context.t('Your current plan', 'Tu plan actual'),
                    sequence: [
                      if (crop.isNotEmpty) crop,
                      if (plan.currentPlan.isNotEmpty) plan.currentPlan,
                    ].join(' → '),
                    notes: [
                      if (plan.currentPlan.isEmpty)
                        context.t(
                          'Next crop not recorded yet.',
                          'Aún no registraste el siguiente cultivo.',
                        ),
                      if (plan.history.isNotEmpty)
                        context.t(
                          'Past crops: ${plan.history}',
                          'Cultivos anteriores: ${plan.history}',
                        ),
                    ],
                  ),
                ),
                for (final alternative in plan.alternatives)
                  SizedBox(
                    width: width,
                    child: _option(
                      context,
                      crop,
                      alternative,
                      profile.priority,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _Evidence(model, profile: profile),
      ],
    );
  }

  Widget _option(
    BuildContext context,
    String current,
    RotationAlternative option,
    FarmPriority? priority,
  ) {
    final cowpea = option.type == RotationCrop.cowpea;
    final label = context.t(
      cowpea ? 'INIA 432 cowpea' : 'Medium white bean',
      option.crop,
    );
    final season = context.t(
      cowpea ? 'October to March' : 'March to May',
      option.plantingWindow,
    );
    return _Scenario(
      title: label,
      sequence: '$current → $label',
      notes: [
        context.t('Planting window: $season', 'Época de siembra: $season'),
        context.t(
          cowpea
              ? 'Adds a legume between corn seasons.'
              : 'A break between corn crops may interrupt some pest cycles.',
          option.benefit,
        ),
        if (cowpea)
          context.t(
            'Needs sandy loam and a soil conductivity of up to 2 dS/m.',
            option.soilRequirement!,
          ),
        context.t(
          cowpea
              ? 'Check seed, irrigation, local buyers and pests.'
              : 'Check the variety, soil salts and past herbicide use.',
          option.risk,
        ),
        if (priority == FarmPriority.water)
          context.t(
            'For your water goal: check the irrigation schedule and cost.',
            'Para cuidar el agua, revisa los turnos y el costo de riego.',
          ),
        if (priority == FarmPriority.soil)
          context.t(
            'For your soil goal: confirm drainage and soil salts.',
            'Para cuidar el suelo, confirma el drenaje y la salinidad.',
          ),
        if (priority == FarmPriority.cost)
          context.t(
            'For your budget: check seed, irrigation and sale prices.',
            'Para cuidar el presupuesto, revisa semilla, riego y precio de venta.',
          ),
      ],
      source: option.source,
    );
  }

  String _issue(
    BuildContext context,
    RotationIssue issue,
  ) => context.t(switch (issue) {
    RotationIssue.missingCrop => 'Record what you grow now.',
    RotationIssue.unsupportedCrop => 'The pilot starts from yellow field corn.',
    RotationIssue.missingRegion => 'Choose the area where you grow.',
    RotationIssue.unsupportedRegion => 'The field is outside the pilot area.',
    RotationIssue.missingSowingMonth => 'Choose a planting month.',
    RotationIssue.missingDrainage => 'Tell us how water drains in your field.',
    RotationIssue.poorDrainage =>
      'Ask about drainage before planting these legumes.',
    RotationIssue.uncertainWater =>
      'Confirm that you will have water for this season.',
    RotationIssue.missingIrrigation =>
      'Choose the irrigation system you will use.',
    RotationIssue.restrictedBudget =>
      'Your budget currently covers the existing crop.',
    RotationIssue.cowpeaSeason =>
      'INIA 432 cowpea is planted from October to March.',
    RotationIssue.cowpeaSoil => 'Check for sandy loam and soil conductivity of up to 2 dS/m for INIA 432 cowpea.',
    RotationIssue.dryBeanSeason =>
      'Medium white bean is planted from March to May.',
  }, issue.message);
}

class _Scenario extends StatelessWidget {
  final String title, sequence;
  final List<String> notes;
  final RotationSource? source;
  const _Scenario({
    required this.title,
    required this.sequence,
    required this.notes,
    this.source,
  });

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (sequence.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            sequence,
            style: const TextStyle(fontWeight: FontWeight.w600, color: forest),
          ),
        ],
        for (final note in notes) ...[const SizedBox(height: 6), Text(note)],
        if (source != null)
          ExpansionTile(
            key: PageStorageKey(source!.url),
            tilePadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(context.t('Crop source', 'Fuente del cultivo')),
            children: [
              Text(source!.title),
              CopyValue(
                source!.url,
                label: context.t('Copy link', 'Copiar enlace'),
              ),
            ],
          ),
      ],
    ),
  );
}

class _Evidence extends StatelessWidget {
  final FieldController model;
  final FarmPlanning profile;
  const _Evidence(this.model, {required this.profile});

  @override
  Widget build(BuildContext context) {
    final satellite = model.observations.latestUsable;
    final climate = model.weather;
    final days = climate?.days ?? const <String>[];
    final title = Theme.of(context).textTheme.titleMedium;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('What this plan uses', 'En qué se basa el plan'),
            style: title,
          ),
          const SizedBox(height: 7),
          Text(
            context.t(
              'Crop options use your field notes and crop guides. The saved images and weather help you check conditions.',
              'Las opciones usan tus datos y las fichas de cultivo. Las imágenes y el clima guardados ayudan a revisar las condiciones.',
            ),
          ),
          if (profile.priority != null) ...[
            const SizedBox(height: 6),
            Text(
              context.t(
                'Your priority: ${context.priorityLabel(profile.priority!)}',
                'Tu prioridad: ${context.priorityLabel(profile.priority!)}',
              ),
            ),
          ],
          if (satellite != null)
            Text(
              '${context.observationLabel(satellite.observation)} · ${context.dateLabel(satellite.acquired)}',
            ),
          if (days.isNotEmpty)
            Text(
              'NASA POWER · ${periodLabel(context, DateTime.parse(days.first), DateTime.parse(days.last))}',
            ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'Check the variety, water and planting dates with a local adviser before planting.',
              'Revisa con asesoría local la variedad, el agua y las fechas antes de sembrar.',
            ),
            style: const TextStyle(color: muted),
          ),
          ExpansionTile(
            key: const PageStorageKey('rotation-sources'),
            tilePadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(context.t('Rule sources', 'Fuentes de las reglas')),
            children: [
              for (final source in [
                RotationEngine.rotationGuide,
                RotationEngine.cowpeaGuide,
              ]) ...[
                Text(source.title),
                CopyValue(
                  source.url,
                  label: context.t('Copy link', 'Copiar enlace'),
                ),
                const SizedBox(height: 7),
              ],
            ],
          ),
          TextButton.icon(
            onPressed: () => model.viewObservations(),
            icon: const Icon(Icons.insights_outlined, size: 18),
            label: Text(context.t('Open observations', 'Abrir observaciones')),
          ),
        ],
      ),
    );
  }
}
