// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../import_controller.dart';

class ImportProgressCard extends StatelessWidget {
  const ImportProgressCard({
    super.key,
    required this.progress,
    required this.onDismiss,
  });

  final ImportProgress progress;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final running = progress.isRunning;
    final title = running
        ? 'Importando ${progress.total} '
              '${progress.total == 1 ? 'libro' : 'libros'}'
        : 'Importación completada';

    return Center(
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1E24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF322F39)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${progress.finished} de ${progress.total}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: LannaColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.total == 0
                    ? 0
                    : progress.finished / progress.total,
                minHeight: 3,
                backgroundColor: const Color(0xFF322F39),
              ),
            ),
            const SizedBox(height: 8),
            ...progress.items.map(_row),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onDismiss,
                child: Text(running ? 'Ocultar' : 'Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ImportItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _StatusIcon(item.status),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.detail != null)
                  Text(
                    item.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: item.status == ImportItemStatus.failed
                          ? const Color(0xFFE5686B)
                          : LannaColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.status);

  final ImportItemStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ImportItemStatus.added:
        return const Icon(Icons.check, size: 17, color: LannaColors.success);
      case ImportItemStatus.skipped:
        return const Icon(
          Icons.remove_circle_outline,
          size: 17,
          color: LannaColors.textMuted,
        );
      case ImportItemStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 17,
          color: Color(0xFFE5686B),
        );
      case ImportItemStatus.processing:
        return const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ImportItemStatus.queued:
        return Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF3A3742), width: 2),
          ),
        );
    }
  }
}
