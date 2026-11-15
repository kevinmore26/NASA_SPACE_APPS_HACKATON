import 'package:field_nasa/field_nasa.dart';
import 'package:flutter/material.dart';

import 'field_strings.dart';
import 'period_picker.dart';
import 'workspace_widgets.dart';

class WeatherPanel extends StatefulWidget {
  final ClimateSeries report;
  final DateTime start, end;

  const WeatherPanel(
    this.report, {
    super.key,
    required this.start,
    required this.end,
  });

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> {
  static const _pageSize = 14;
  int _page = 0;

  @override
  void didUpdateWidget(covariant WeatherPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.report != oldWidget.report) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final days = report.days;
    final title = Theme.of(context).textTheme.titleMedium;
    if (days.isEmpty) {
      return Text(
        context.t(
          'NASA POWER returned no daily records for this period.',
          'NASA POWER no devolvió datos diarios para este período.',
        ),
      );
    }
    final from = DateTime.parse(days.first);
    final to = DateTime.parse(days.last);
    final matches =
        DateUtils.isSameDay(from, widget.start) &&
        DateUtils.isSameDay(to, widget.end);
    final rainfall = days
        .map((day) => report.value('PRECTOTCORR', day))
        .whereType<double>()
        .toList();
    final rainUnit = report.unitFor('PRECTOTCORR');
    final tableColumns = [
      (context.t('Rain', 'Lluvia'), 'PRECTOTCORR'),
      (context.t('Air temp.', 'Temp. aire'), 'T2M'),
      (context.t('Humidity', 'Humedad'), 'RH2M'),
      (context.t('Sunlight', 'Radiación'), 'ALLSKY_SFC_SW_DWN'),
    ];
    final pageDays = days.reversed.skip(_page * _pageSize).take(_pageSize);
    final pageCount = (days.length / _pageSize).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('Regional weather', 'Clima de la zona'), style: title),
        Text(
          periodLabel(context, from, to),
          style: const TextStyle(color: muted),
        ),
        if (!matches)
          Text(
            context.t(
              'This saved period differs from the current selection.',
              'El período guardado es distinto al seleccionado.',
            ),
          ),
        const SizedBox(height: 8),
        if (rainfall.isNotEmpty && rainUnit != null)
          Text(
            context.t(
              'Average rain on ${rainfall.length} days with data: ${context.number(rainfall.reduce((a, b) => a + b) / rainfall.length)} $rainUnit.',
              'Lluvia promedio en ${rainfall.length} días con datos: ${context.number(rainfall.reduce((a, b) => a + b) / rainfall.length)} $rainUnit.',
            ),
          ),
        Text(
          context.t(
            'NASA POWER covers the surrounding area. A rain gauge gives a reading for your field.',
            'NASA POWER cubre la zona. Un pluviómetro da una lectura de tu terreno.',
          ),
          style: const TextStyle(color: muted),
        ),
        ExpansionTile(
          key: const PageStorageKey('weather-daily-expansion'),
          tilePadding: EdgeInsets.zero,
          title: Text(context.t('Daily records', 'Datos por día')),
          subtitle: Text(
            context.t('${days.length} days · UTC', '${days.length} días · UTC'),
          ),
          children: [
            SingleChildScrollView(
              key: const PageStorageKey('weather-daily-horizontal-offset'),
              primary: false,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                horizontalMargin: 8,
                columns: [
                  DataColumn(label: Text(context.t('Date', 'Fecha'))),
                  for (final (label, code) in tableColumns)
                    DataColumn(
                      label: Text('$label\n${report.unitFor(code) ?? '–'}'),
                    ),
                ],
                rows: [
                  for (final day in pageDays)
                    DataRow(
                      cells: [
                        DataCell(Text(context.dateLabel(DateTime.parse(day)))),
                        for (final (_, code) in tableColumns)
                          DataCell(
                            Text(context.number(report.value(code, day))),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (pageCount > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: context.t('Newer days', 'Días más recientes'),
                    onPressed: _page > 0 ? () => setState(() => _page--) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${_page + 1} / $pageCount'),
                  IconButton(
                    tooltip: context.t('Earlier days', 'Días anteriores'),
                    onPressed: _page + 1 < pageCount
                        ? () => setState(() => _page++)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.t(
                  'Grid sizes: about 0.5° × 0.625° for weather and 1° × 1° for solar radiation.',
                  'Cuadrículas: aprox. 0,5° × 0,625° para clima y 1° × 1° para radiación solar.',
                ),
                style: const TextStyle(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
