import 'package:field_core/field_core.dart';
import 'package:flutter/material.dart';

import 'field_strings.dart';
import 'workspace_widgets.dart';

Map<FarmRegion, String> regions(BuildContext context) => {
  FarmRegion.lambayequeCoast: context.t(
    'Coastal Lambayeque (0–500 m)',
    'Costa de Lambayeque (0–500 m)',
  ),
  FarmRegion.other: context.t('Another area', 'Otra zona'),
};
Map<SoilTexture, String> textures(BuildContext context) => {
  SoilTexture.sandyLoam: context.t('Sandy loam', 'Franco arenoso'),
  SoilTexture.loam: context.t('Loam', 'Franco'),
  SoilTexture.clay: context.t('Clay', 'Arcilloso'),
  SoilTexture.other: context.t('Other soil', 'Otro tipo de suelo'),
};
Map<SoilDrainage, String> drainageLabels(BuildContext context) => {
  SoilDrainage.good: context.t('Drains well', 'Drena bien'),
  SoilDrainage.poor: context.t('Water pools', 'Se encharca'),
};
Map<FarmWater, String> availability(BuildContext context) => {
  FarmWater.secured: context.t(
    'Confirmed for the next season',
    'Confirmada para la próxima campaña',
  ),
  FarmWater.limited: context.t('Limited or unreliable', 'Limitada o irregular'),
  FarmWater.unavailable: context.t('No water available', 'Sin agua disponible'),
};
Map<IrrigationMethod, String> irrigationLabels(BuildContext context) => {
  IrrigationMethod.gravity: context.t('Gravity or furrow', 'Gravedad o surcos'),
  IrrigationMethod.sprinkler: context.t('Sprinkler', 'Aspersión'),
  IrrigationMethod.drip: context.t('Drip', 'Goteo'),
  IrrigationMethod.none: context.t(
    'No irrigation system',
    'Sin sistema de riego',
  ),
};
Map<FarmBudget, String> budgets(BuildContext context) => {
  FarmBudget.canEvaluate: context.t(
    'I can try another crop',
    'Puedo probar otro cultivo',
  ),
  FarmBudget.currentCropOnly: context.t(
    'Only covers the current crop',
    'Solo alcanza para el cultivo actual',
  ),
};

class RotationForm extends StatefulWidget {
  final FarmRecord record;
  final bool busy;
  final ValueChanged<FarmRecord> onSave;

  const RotationForm({
    super.key,
    required this.record,
    required this.busy,
    required this.onSave,
  });

  @override
  State<RotationForm> createState() => _RotationFormState();
}

class _RotationFormState extends State<RotationForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _history,
      _nextCrop,
      _conductivity,
      _otherCrop;
  FarmCrop? _crop;
  FarmRegion? _region;
  int? _sowingMonth;
  SoilTexture? _texture;
  SoilDrainage? _drainage;
  FarmWater? _water;
  IrrigationMethod? _irrigation;
  FarmBudget? _budget;
  FarmPriority? _priority;

  @override
  void initState() {
    super.initState();
    final p = widget.record.planning ?? const FarmPlanning();
    _crop = p.crop;
    _region = p.region;
    _sowingMonth = p.sowingMonth;
    _texture = p.texture;
    _drainage = p.drainage;
    _water = p.water;
    _irrigation = p.irrigation;
    _budget = p.budget;
    _priority = p.priority;
    _history = TextEditingController(text: widget.record.history);
    _nextCrop = TextEditingController(text: p.referenceNextCrop);
    _conductivity = TextEditingController(
      text: p.soilConductivity?.toString() ?? '',
    );
    _otherCrop = TextEditingController(text: widget.record.crop);
  }

  @override
  void dispose() {
    _history.dispose();
    _nextCrop.dispose();
    _conductivity.dispose();
    _otherCrop.dispose();
    super.dispose();
  }

  double? _parseConductivity(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _save() {
    if (!_key.currentState!.validate()) return;
    final p = FarmPlanning(
      crop: _crop,
      region: _region,
      sowingMonth: _sowingMonth,
      texture: _texture,
      drainage: _drainage,
      soilConductivity: _parseConductivity(_conductivity.text),
      water: _water,
      irrigation: _irrigation,
      budget: _budget,
      priority: _priority,
      referenceNextCrop: _nextCrop.text.trim(),
    );
    final old = widget.record;
    widget.onSave(
      FarmRecord(
        crop: _crop == FarmCrop.other ? _otherCrop.text.trim() : old.crop,
        history: _history.text,
        soil: old.soil,
        water: old.water,
        irrigation: old.irrigation,
        budget: old.budget,
        priorities: old.priorities,
        planning: p,
      ),
    );
  }

  Widget _choice<T>(
    String label,
    T? value,
    Map<T, String> options,
    ValueChanged<T?> onChanged,
  ) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    hint: Text(context.t('Unknown', 'No sé')),
    items: [
      DropdownMenuItem(child: Text(context.t('Unknown', 'No sé'))),
      for (final entry in options.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: widget.busy ? null : onChanged,
  );

  Widget _text(
    String label,
    TextEditingController controller, {
    String? hint,
    int? lines,
  }) => TextFormField(
    controller: controller,
    enabled: !widget.busy,
    maxLines: lines ?? 1,
    decoration: InputDecoration(labelText: label, hintText: hint),
  );

  Widget _group(BuildContext context, String title, List<Widget> fields) =>
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            for (final field in fields) ...[const SizedBox(height: 12), field],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _group(
          context,
          context.t('Next growing season', 'Cultivo y próxima campaña'),
          [
            _choice(
              context.t('Current crop', 'Tipo de cultivo actual'),
              _crop,
              {for (final c in FarmCrop.values) c: context.cropLabel(c)},
              (v) => setState(() => _crop = v),
            ),
            if (_crop == FarmCrop.other)
              _text(
                context.t('Name of your crop', 'Nombre de tu cultivo'),
                _otherCrop,
              )
            else if (_crop == null && widget.record.crop.isNotEmpty)
              Text(
                context.t(
                  'Previously recorded: ${widget.record.crop}',
                  'Cultivo en tu registro previo: ${widget.record.crop}',
                ),
                style: const TextStyle(color: muted),
              ),
            _text(
              context.t(
                'What you planned to plant next (optional)',
                'Siguiente cultivo en tu plan actual (opcional)',
              ),
              _nextCrop,
            ),
            _text(
              context.t(
                'Past crops (optional)',
                'Historial de cultivos (opcional)',
              ),
              _history,
              hint: context.t(
                'Crops and seasons',
                'Cultivos y campañas anteriores',
              ),
              lines: 2,
            ),
            _choice(
              context.t('Where is your field?', 'Zona y altitud de la parcela'),
              _region,
              regions(context),
              (v) => _region = v,
            ),
            _choice(
              context.t('Planting month', 'Mes disponible para sembrar'),
              _sowingMonth,
              {
                for (var month = 1; month <= 12; month++)
                  month: context.monthLabel(month),
              },
              (v) => _sowingMonth = v,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _group(context, context.t('Soil', 'Suelo'), [
          _choice(
            context.t('What kind of soil is it?', 'Textura del suelo'),
            _texture,
            textures(context),
            (v) => _texture = v,
          ),
          _choice(
            context.t('How does water drain?', 'Drenaje del suelo'),
            _drainage,
            drainageLabels(context),
            (v) => _drainage = v,
          ),
          TextFormField(
            controller: _conductivity,
            enabled: !widget.busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.t(
                'Salt level on your soil test (dS/m)',
                'Conductividad del suelo (dS/m)',
              ),
              hintText: context.t(
                'Leave blank if you have no soil test',
                'Deja vacío si no tienes un análisis de suelo',
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final n = _parseConductivity(value);
              return n == null || !n.isFinite || n < 0
                  ? context.t(
                      'Enter a valid soil test value.',
                      'Escribe un valor de conductividad válido.',
                    )
                  : null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ]),
        const SizedBox(height: 12),
        _group(
          context,
          context.t('Water and budget', 'Agua, presupuesto y prioridad'),
          [
            _choice(
              context.t('Water available', 'Agua disponible'),
              _water,
              availability(context),
              (v) => _water = v,
            ),
            _choice(
              context.t('How do you irrigate?', 'Sistema de riego'),
              _irrigation,
              irrigationLabels(context),
              (v) => _irrigation = v,
            ),
            _choice(
              context.t('Budget', 'Restricción económica'),
              _budget,
              budgets(context),
              (v) => _budget = v,
            ),
            _choice(
              context.t('What matters most?', 'Qué quieres priorizar'),
              _priority,
              {
                for (final item in FarmPriority.values)
                  item: context.priorityLabel(item),
              },
              (v) => _priority = v,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: widget.busy ? null : _save,
            icon: const Icon(Icons.compare_arrows_outlined),
            label: Text(context.t('Save and compare', 'Guardar y comparar')),
          ),
        ),
      ],
    ),
  );
}
