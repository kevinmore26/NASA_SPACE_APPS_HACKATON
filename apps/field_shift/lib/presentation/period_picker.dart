import 'package:flutter/material.dart';

import 'field_strings.dart';

Future<DateTimeRange?> choosePeriod(
  BuildContext context, {
  required DateTime from,
  required DateTime to,
}) => showDialog<DateTimeRange>(
  context: context,
  builder: (_) => _PeriodDialog(from: from, to: to),
);

String periodLabel(BuildContext context, DateTime from, DateTime to) {
  if (from.year == to.year &&
      from.month == to.month &&
      from.day == 1 &&
      to.day == DateUtils.getDaysInMonth(to.year, to.month)) {
    return context.t(
      '${context.monthLabel(to.month)} ${to.year}',
      '${context.monthLabel(to.month)} de ${to.year}',
    );
  }
  return '${context.dateLabel(from)} – ${context.dateLabel(to)}';
}

enum _PeriodMode { month, recent, custom }

class _PeriodDialog extends StatefulWidget {
  final DateTime from, to;
  const _PeriodDialog({required this.from, required this.to});

  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<_PeriodDialog> {
  final _form = GlobalKey<FormState>();
  final _today = DateUtils.dateOnly(DateTime.now());
  final _earliest = DateTime(2013);
  late int _year, _month;
  late DateTime _from, _to;
  _PeriodMode _mode = _PeriodMode.month;
  int _days = 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    _to = DateUtils.dateOnly(widget.to);
    _from = DateUtils.dateOnly(widget.from);
    _year = _to.year;
    _month = _to.month;
  }

  bool _monthAvailable(int month) =>
      _year < _today.year || month <= _today.month;

  void _apply() {
    DateTime start, end;
    switch (_mode) {
      case _PeriodMode.month:
        start = DateTime(_year, _month);
        final last = DateTime(_year, _month + 1, 0);
        end = last.isAfter(_today) ? _today : last;
      case _PeriodMode.recent:
        start = DateTime(_today.year, _today.month, _today.day - _days + 1);
        end = _today;
      case _PeriodMode.custom:
        if (!_form.currentState!.validate()) return;
        _form.currentState!.save();
        start = _from;
        end = _to;
    }
    if (end.isBefore(start)) {
      setState(
        () => _error = context.t(
          'Choose an end date on or after the start date.',
          'La fecha final debe ser igual o posterior a la inicial.',
        ),
      );
      return;
    }
    Navigator.pop(context, DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.t('Choose a period', 'Elige un período')),
    content: SizedBox(
      width: 392,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 7,
              runSpacing: 4,
              children: [
                for (final (mode, label) in [
                  (_PeriodMode.month, context.t('By month', 'Por mes')),
                  (_PeriodMode.recent, context.t('Recent', 'Reciente')),
                  (
                    _PeriodMode.custom,
                    context.t('Custom dates', 'Fechas personalizadas'),
                  ),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _mode == mode,
                    onSelected: (_) => setState(() {
                      _mode = mode;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            switch (_mode) {
              _PeriodMode.month => _monthAndYear(context),
              _PeriodMode.recent => Wrap(
                spacing: 8,
                children: [
                  for (final days in [30, 90])
                    ChoiceChip(
                      label: Text(
                        context.t('Last $days days', 'Últimos $days días'),
                      ),
                      selected: _days == days,
                      onSelected: (_) => setState(() => _days = days),
                    ),
                ],
              ),
              _PeriodMode.custom => Form(
                key: _form,
                child: Column(
                  children: [
                    InputDatePickerFormField(
                      initialDate: _from,
                      firstDate: _earliest,
                      lastDate: _today,
                      fieldLabelText: context.t('Start date', 'Fecha inicial'),
                      onDateSaved: (value) => _from = value,
                    ),
                    const SizedBox(height: 12),
                    InputDatePickerFormField(
                      initialDate: _to,
                      firstDate: _earliest,
                      lastDate: _today,
                      fieldLabelText: context.t('End date', 'Fecha final'),
                      onDateSaved: (value) => _to = value,
                    ),
                  ],
                ),
              ),
            },
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t('Cancel', 'Cancelar')),
      ),
      FilledButton(
        onPressed: _apply,
        child: Text(context.t('Use period', 'Usar período')),
      ),
    ],
  );

  Widget _monthAndYear(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      DropdownButtonFormField<int>(
        initialValue: _year,
        isExpanded: true,
        decoration: InputDecoration(labelText: context.t('Year', 'Año')),
        items: [
          for (var year = _today.year; year >= _earliest.year; year--)
            DropdownMenuItem(value: year, child: Text('$year')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _year = value;
            if (!_monthAvailable(_month)) _month = _today.month;
          });
        },
      ),
      const SizedBox(height: 12),
      Text(
        context.t('Month', 'Mes'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 7,
        runSpacing: 5,
        children: [
          for (var month = 1; month <= 12; month++)
            ChoiceChip(
              label: Text(context.monthLabel(month)),
              selected: month == _month,
              onSelected: _monthAvailable(month)
                  ? (_) => setState(() => _month = month)
                  : null,
            ),
        ],
      ),
    ],
  );
}
