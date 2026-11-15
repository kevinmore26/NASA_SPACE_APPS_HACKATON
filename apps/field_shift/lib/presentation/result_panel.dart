import 'dart:convert';
import 'dart:io';

import 'package:field_imagery/field_imagery.dart';
import 'package:flutter/material.dart';

import '../application/field_controller.dart';

String dateLabel(DateTime d) => d.toIso8601String().substring(0, 10);
String number(Object? n) => n is num ? n.toStringAsFixed(3) : 'Sin datos';

class ResultPanel extends StatelessWidget {
  final FieldController model;
  const ResultPanel({super.key, required this.model});
  @override
  Widget build(BuildContext context) {
    final r = model.result;
    if (r == null) return const SizedBox.shrink();
    final index =
        r.observation == Observation.ndvi || r.observation == Observation.ndmi;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!File(r.imagePath).existsSync())
              const Text(
                'La imagen ya no está en la caché. Las estadísticas siguen guardadas. Con internet, vuelve a procesar esta escena para recuperarla.',
              ),
            Text(
              r.observation.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${dateLabel(r.acquired)} · ${r.resolution.toStringAsFixed(0)} m · ${r.provider}',
            ),
            const SizedBox(height: 12),
            if (index || r.observation == Observation.temperature) ...[
              Container(
                height: 16,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 210, 95, 45),
                      Color.fromARGB(255, 120, 120, 65),
                      Color.fromARGB(255, 30, 145, 85),
                    ],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(index ? '−1 · menor señal' : '−10 °C'),
                  Text(index ? '0' : '25 °C'),
                  Text(index ? '+1 · mayor señal' : '60 °C'),
                ],
              ),
            ] else
              const Text(
                'Brillo fijo: reflectancia 0 → negro; 0,3 → brillo máximo. No es una clasificación agrícola.',
              ),
            const SizedBox(height: 8),
            const Text(
              '◻ Gris claro: nube · ◼ Violeta: sombra\nTransparente: fuera del terreno, inválido o sin datos.',
            ),
            const SizedBox(height: 8),
            Text(r.observation.caveat),
            const Divider(),
            Text(
              'Cobertura válida: ${number(r.statistics.validPercent)}% · ${r.statistics.validPixels} píxeles',
            ),
            if (index || r.observation == Observation.temperature)
              Text('Promedio: ${number(r.statistics.mean)} ${r.data['unit']}'),
            if ((r.data['warnings'] as List).isNotEmpty)
              Text(
                (r.data['warnings'] as List).join('\n'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            const Text(
              'Incertidumbre no cuantificada. Bordes mezclados y errores de máscara pueden afectar el resultado.',
            ),
            if (model.advanced) ...[
              const Divider(),
              Text('Método: ${r.data['method']}\n${r.observation.formula}'),
              Text(
                'Mín: ${number(r.statistics.min)} · Máx: ${number(r.statistics.max)}\nMediana: ${number(r.statistics.median)} · Desv. estándar: ${number(r.statistics.stdDev)}',
              ),
              Text(
                'Nubes: ${r.statistics.cloudPixels} · Sombras: ${r.statistics.shadowPixels} · Sin datos: ${r.statistics.missingPixels}',
              ),
              Text(
                'Bandas: ${(r.data['bands'] as List).join(', ')}\n${r.data['quality']}\n${r.data['resampling']}',
              ),
              Text(
                'Producto: ${r.data['collection']} · versión ${r.data['productVersion']}\n${r.sceneId}\nCRS: ${r.data['crs']}',
              ),
              const Text(
                'Toca el mapa para consultar los valores numéricos del píxel.',
              ),
              if (model.pixel != null)
                SelectableText('Píxel: ${jsonEncode(model.pixel?.toJson())}'),
            ],
            if (model.comparison != null) ...[
              const Divider(),
              Text('Comparación con ${dateLabel(model.comparison!.acquired)}'),
              Text(
                'Promedio anterior: ${number(model.comparison!.statistics.mean)}',
              ),
              Text(
                'Cobertura anterior: ${number(model.comparison!.statistics.validPercent)}%',
              ),
              const Text(
                'Misma geometría, cuadrícula y método. Diferencias de cobertura/nubes limitan la comparación. No equivale a un cambio causal del cultivo.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
