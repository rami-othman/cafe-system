import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/shift_models.dart';
import 'shift_design.dart';
import 'shift_format.dart';
import 'shift_primitives.dart';
import 'shift_strings.dart';

ShiftTone _toneFor(BarCountStatus status) => switch (status) {
  BarCountStatus.uncounted => ShiftTone.neutral,
  BarCountStatus.match => ShiftTone.success,
  BarCountStatus.shortage => ShiftTone.warning,
  BarCountStatus.surplus => ShiftTone.surplus,
};

String _labelFor(BarCountStatus status) => switch (status) {
  BarCountStatus.uncounted => ShiftStrings.statusUncounted,
  BarCountStatus.match => ShiftStrings.statusMatch,
  BarCountStatus.shortage => ShiftStrings.statusShortage,
  BarCountStatus.surplus => ShiftStrings.statusSurplus,
};

/// One material row in the desktop bar-count table.
///
/// Negative theoretical stock is shown as informational only — never as a
/// blocker — per the domain rule that negative inventory is normal and must
/// never stop a count.
class BarCountRow extends StatefulWidget {
  const BarCountRow({
    super.key,
    required this.line,
    required this.onCountedChanged,
    required this.onNoteChanged,
    required this.onFillTheoretical,
    required this.onClear,
    required this.onSubmitNext,
  });

  final BarCountLine line;
  final ValueChanged<String> onCountedChanged;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onFillTheoretical;
  final VoidCallback onClear;
  final VoidCallback onSubmitNext;

  @override
  State<BarCountRow> createState() => _BarCountRowState();
}

class _BarCountRowState extends State<BarCountRow> {
  late final TextEditingController _countedController = TextEditingController(
    text: widget.line.counted == null
        ? ''
        : ShiftFormat.quantity(widget.line.counted!, widget.line.decimals),
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.line.note,
  );

  @override
  void didUpdateWidget(covariant BarCountRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.counted != widget.line.counted &&
        !_countedController.value.selection.isValid) {
      _countedController.text = widget.line.counted == null
          ? ''
          : ShiftFormat.quantity(widget.line.counted!, widget.line.decimals);
    }
  }

  @override
  void dispose() {
    _countedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BarCountLine line = widget.line;
    final ShiftTone tone = _toneFor(line.status);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 16,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            line.name,
                            style: ShiftText.bodyStrong,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: <Widget>[
                              ShiftValue(
                                line.sku,
                                style: ShiftText.label,
                              ),
                              const SizedBox(width: 6),
                              Text('· ${line.category}', style: ShiftText.label),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 6,
                child: Text(line.unit, style: ShiftText.tableCell),
              ),
              Expanded(
                flex: 9,
                child: Align(
                  alignment: Alignment.center,
                  child: ShiftValue(
                    ShiftFormat.quantity(line.theoretical, line.decimals),
                    style: ShiftText.tableCell,
                    color: line.hasNegativeTheoretical
                        ? ShiftColors.shortageInk
                        : ShiftColors.ink,
                  ),
                ),
              ),
              Expanded(
                flex: 10,
                child: Center(
                  child: SizedBox(
                    width: ShiftLayout.countFieldWidth,
                    child: ShiftNumberField(
                      fieldKey: Key('bar-count-field-${line.id}'),
                      controller: _countedController,
                      allowDecimal: line.decimals > 0,
                      textAlign: TextAlign.center,
                      hintText: '—',
                      onChanged: widget.onCountedChanged,
                      onSubmitted: (_) => widget.onSubmitNext(),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 8,
                child: Center(
                  child: ShiftValue(
                    line.difference == null
                        ? '—'
                        : ShiftFormat.signedQuantity(line.difference!, line.decimals),
                    style: ShiftText.bodyStrong,
                    color: line.difference == null ? ShiftColors.inkMuted : tone.ink,
                  ),
                ),
              ),
              Expanded(
                flex: 9,
                child: Center(
                  child: ShiftBadge(label: _labelFor(line.status), tone: tone, dense: true),
                ),
              ),
            ],
          ),
          if (line.hasNegativeTheoretical) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                const Icon(Icons.info_outline, size: 13, color: ShiftColors.shortageInk),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ShiftStrings.negativeTheoretical,
                    style: ShiftText.label.copyWith(color: ShiftColors.shortageInk),
                  ),
                ),
              ],
            ),
          ],
          if (line.hasDifference) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _noteController,
                    onChanged: widget.onNoteChanged,
                    style: ShiftText.body,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: ShiftStrings.noteHint,
                      hintStyle: ShiftText.label,
                      filled: true,
                      fillColor: ShiftColors.subtleFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.control,
                        borderSide: const BorderSide(color: ShiftColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (line.differenceValue != null)
                  ShiftValue(
                    '${ShiftStrings.estimatedDifferenceValue}: '
                    '${ShiftFormat.signedMoney(line.differenceValue!)}',
                    style: ShiftText.label,
                    color: tone.ink,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: widget.onFillTheoretical,
                child: Text(
                  ShiftStrings.fillWithTheoretical,
                  style: ShiftText.label.copyWith(color: ShiftColors.accent),
                ),
              ),
              if (line.isCounted)
                TextButton(
                  onPressed: widget.onClear,
                  child: Text(
                    ShiftStrings.clearValue,
                    style: ShiftText.label.copyWith(color: ShiftColors.blockerInk),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The same row, as a self-contained card for tablet/mobile bar counting.
class BarCountCard extends StatefulWidget {
  const BarCountCard({
    super.key,
    required this.line,
    required this.onCountedChanged,
    required this.onNoteChanged,
    required this.onFillTheoretical,
    required this.onClear,
  });

  final BarCountLine line;
  final ValueChanged<String> onCountedChanged;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onFillTheoretical;
  final VoidCallback onClear;

  @override
  State<BarCountCard> createState() => _BarCountCardState();
}

class _BarCountCardState extends State<BarCountCard> {
  late final TextEditingController _countedController = TextEditingController(
    text: widget.line.counted == null
        ? ''
        : ShiftFormat.quantity(widget.line.counted!, widget.line.decimals),
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.line.note,
  );

  @override
  void dispose() {
    _countedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BarCountLine line = widget.line;
    final ShiftTone tone = _toneFor(line.status);

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(line.name, style: ShiftText.cardTitle),
                    Text(
                      '${line.sku} · ${line.category} · ${line.unit}',
                      style: ShiftText.label,
                    ),
                  ],
                ),
              ),
              ShiftBadge(label: _labelFor(line.status), tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: ShiftFactTile(
                  label: ShiftStrings.theoreticalQty,
                  value: ShiftFormat.quantity(line.theoretical, line.decimals),
                  valueColor: line.hasNegativeTheoretical
                      ? ShiftColors.shortageInk
                      : null,
                ),
              ),
              Expanded(
                child: ShiftField(
                  label: ShiftStrings.actualQty,
                  child: ShiftNumberField(
                    fieldKey: Key('bar-count-card-field-${line.id}'),
                    controller: _countedController,
                    allowDecimal: line.decimals > 0,
                    hintText: '—',
                    onChanged: widget.onCountedChanged,
                  ),
                ),
              ),
            ],
          ),
          if (line.hasNegativeTheoretical) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ShiftNotice(
              tone: ShiftTone.warning,
              message: ShiftStrings.negativeTheoretical,
              detail: ShiftStrings.negativeTheoreticalDetail,
            ),
          ],
          if (line.difference != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ShiftKeyValueRow(
              label: ShiftStrings.difference,
              value: ShiftFormat.signedQuantity(line.difference!, line.decimals),
              valueColor: tone.ink,
            ),
          ],
          if (line.hasDifference) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ShiftTextArea(
              controller: _noteController,
              onChanged: widget.onNoteChanged,
              hintText: ShiftStrings.noteHint,
              minLines: 1,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: widget.onFillTheoretical,
                child: Text(
                  ShiftStrings.fillWithTheoretical,
                  style: ShiftText.label.copyWith(color: ShiftColors.accent),
                ),
              ),
              if (line.isCounted)
                TextButton(
                  onPressed: widget.onClear,
                  child: Text(
                    ShiftStrings.clearValue,
                    style: ShiftText.label.copyWith(color: ShiftColors.blockerInk),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
