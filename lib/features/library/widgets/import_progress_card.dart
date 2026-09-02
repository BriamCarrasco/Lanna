// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
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
        padding: const EdgeInsets.all(LannaSpacing.s5),
        decoration: BoxDecoration(
          color: LannaColors.surfaceHigh,
          borderRadius: LannaRadii.brLg,
          border: Border.all(color: LannaColors.border),
          boxShadow: LannaElevation.e3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: LannaType.lg.copyWith(color: LannaColors.textStrong),
                ),
                const Spacer(),
                Text(
                  '${progress.finished} de ${progress.total}',
                  style: LannaType.sm.copyWith(color: LannaColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: LannaSpacing.s3),
            ClipRRect(
              borderRadius: LannaRadii.brXs,
              child: LinearProgressIndicator(
                value: progress.total == 0
                    ? 0
                    : progress.finished / progress.total,
                minHeight: 3,
                backgroundColor: LannaColors.border,
              ),
            ),
            const SizedBox(height: LannaSpacing.s2),
            ...progress.items.map(_row),
            const SizedBox(height: LannaSpacing.s3),
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
      padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s2 - 1),
      child: Row(
        children: [
          _StatusIcon(item.status),
          const SizedBox(width: LannaSpacing.s3 - 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LannaType.sm.copyWith(fontWeight: FontWeight.w600),
                ),
                if (item.detail != null)
                  Text(
                    item.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LannaType.micro.copyWith(
                      color: item.status == ImportItemStatus.failed
                          ? LannaColors.danger
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
          color: LannaColors.danger,
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
            border: Border.all(color: LannaColors.border, width: 2),
          ),
        );
    }
  }
}
