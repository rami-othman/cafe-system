import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_journal_drawer.dart';
import '../widgets/finance_shell.dart';

const Map<String, String> _blockerLabels = <String, String>{
  'MISSING_ACTUAL_CASH_COUNT': 'لم يتم إدخال النقد الفعلي بعد',
  'MISSING_EXTERNAL_CLOSING_BALANCE': 'لم يتم إدخال الرصيد الختامي الخارجي بعد',
  'NON_ZERO_DIFFERENCE': 'يوجد فرق غير محسوم',
  'UNMATCHED_STATEMENT_LINES': 'توجد أسطر كشف غير مطابقة بالكامل',
  'UNMATCHED_SYSTEM_TRANSACTIONS': 'توجد حركات نظام غير مطابقة بالكامل',
};
const Map<String, String> _typeLabels = <String, String>{'cash': 'نقدي', 'bank': 'بنك', 'card': 'بطاقة'};

/// Cash / Bank / Card reconciliation workspace (`/finance/reconciliation/:id`).
/// Every balance, match, and readiness signal is backend truth — this screen
/// only decomposes a multi-select "Match" click into the real backend's
/// one-statement-line-to-one-journal-entry match() calls (repeated per
/// pairing for N:1/1:N groups); it never invents a bulk-match endpoint or
/// recomputes the completion decision itself.
class ReconciliationWorkspaceScreen extends StatefulWidget {
  const ReconciliationWorkspaceScreen({super.key, required this.reconciliationId});
  final int reconciliationId;

  @override
  State<ReconciliationWorkspaceScreen> createState() => _ReconciliationWorkspaceScreenState();
}

class _ReconciliationWorkspaceScreenState extends State<ReconciliationWorkspaceScreen> {
  ReconciliationSession? _session;
  List<ReconciliationSystemTransaction> _transactions = const <ReconciliationSystemTransaction>[];
  List<ReconciliationSuggestion> _suggestions = const <ReconciliationSuggestion>[];
  bool _loading = true;
  Object? _error;

  final Set<int> _selectedSystem = <int>{};
  final Set<int> _selectedStatement = <int>{};
  String? _matchError;
  bool _matching = false;

  FinanceSetupRepository get _repository => context.read<FinanceSetupCubit>().repository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getReconciliation(widget.reconciliationId),
        _repository.getReconciliationTransactions(widget.reconciliationId),
        _repository.getReconciliationSuggestions(widget.reconciliationId),
      ]);
      if (!mounted) return;
      setState(() {
        _session = results[0] as ReconciliationSession;
        _transactions = results[1] as List<ReconciliationSystemTransaction>;
        _suggestions = results[2] as List<ReconciliationSuggestion>;
        _selectedSystem.clear();
        _selectedStatement.clear();
        _matchError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: FinanceShell(
        currentSection: 'التسويات',
        title: 'التسويات',
        subtitle: 'ملف التسوية وحركاتها',
        showContext: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'العودة إلى التسويات',
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => context.go(AppRoutes.financeReconciliationCanonical),
          ),
        ],
        child: _buildBody(),
      ),
    ),
  );

  Widget _buildBody() {
    if (_loading) return const FinanceLoadingState(label: 'جارٍ تحميل التسوية…');
    if (_error != null) {
      return FinanceErrorState(message: 'تعذّر تحميل التسوية. $_error', onRetry: _load);
    }
    final ReconciliationSession? session = _session;
    if (session == null) return const FinanceErrorState(message: 'تعذّر إيجاد التسوية المطلوبة.');
    final bool completed = session.status == 'completed';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FinanceEntityHeader(
            title: session.account.name ?? session.account.financialAccountName,
            reference:
                '${_typeLabels[session.type] ?? session.type} · ${session.account.branchName ?? 'عام'} · ${session.periodFrom == session.periodTo ? session.periodFrom : '${session.periodFrom} → ${session.periodTo}'}',
            status: session.status,
          ),
          const SizedBox(height: FinanceSpace.lg),
          FinanceKpiGrid(
            items: <FinanceKpiData>[
              FinanceKpiData(label: 'الرصيد الافتتاحي (دفتر)', value: session.balances.bookOpening ?? '—'),
              FinanceKpiData(label: 'الرصيد الختامي (دفتر)', value: session.balances.bookClosing ?? '—'),
              FinanceKpiData(
                label: session.type == 'cash' ? 'النقد الفعلي' : 'الرصيد الفعلي/الكشف',
                value: (session.type == 'cash' ? session.balances.actualCash : session.balances.externalClosing) ?? '—',
              ),
              FinanceKpiData(
                label: 'الفرق',
                value: session.balances.difference ?? '—',
                tone: session.balances.differenceDirection == 'balanced'
                    ? FinanceTone.success
                    : FinanceTone.danger,
              ),
              FinanceKpiData(label: 'المطابق', value: session.summary.matchedAmount, tone: FinanceTone.success),
              FinanceKpiData(
                label: 'غير المطابق',
                value: session.type == 'cash'
                    ? session.summary.unmatchedSystemAmount
                    : session.summary.unmatchedStatementAmount,
                tone: FinanceTone.danger,
              ),
              FinanceKpiData(label: 'نسبة التقدم', value: '${session.summary.progressPercent.round()}%'),
            ],
          ),
          const SizedBox(height: FinanceSpace.lg),
          if (completed)
            FinanceAlertBanner(
              tone: FinanceTone.success,
              message:
                  'تم إنهاء هذه التسوية في ${session.completedAt ?? '—'} — الرصيد النهائي ${session.balances.bookClosing ?? '—'}، الفرق ${session.balances.difference ?? '—'}.',
            )
          else
            _ReadinessPanel(session: session),
          const SizedBox(height: FinanceSpace.lg),
          if (session.type == 'cash')
            _CashMovements(transactions: _transactions, onOpenJournal: _openJournalDrawer)
          else
            _BankCardWorkspace(
              session: session,
              transactions: _transactions,
              suggestions: _suggestions,
              selectedSystem: _selectedSystem,
              selectedStatement: _selectedStatement,
              matchError: _matchError,
              matching: _matching,
              readOnly: completed,
              onToggleSystem: _toggleSystem,
              onToggleStatement: _toggleStatement,
              onOpenJournal: _openJournalDrawer,
              onMatch: _performMatch,
              onAcceptSuggestion: _acceptSuggestion,
              onUnmatch: _unmatch,
              onAddLine: _openAddLineDialog,
              onDeleteLine: _deleteLine,
              onUpdateExternalBalance: () => _openBalanceDialog(actualCash: false),
            ),
          const SizedBox(height: FinanceSpace.lg),
          if (!completed) _OperationalBar(session: session, onComplete: _complete, onUpdateCash: session.type == 'cash' ? () => _openBalanceDialog(actualCash: true) : null),
        ],
      ),
    );
  }

  void _toggleSystem(int journalEntryId) => setState(() {
    if (!_selectedSystem.remove(journalEntryId)) _selectedSystem.add(journalEntryId);
    _matchError = null;
  });
  void _toggleStatement(int lineId) => setState(() {
    if (!_selectedStatement.remove(lineId)) _selectedStatement.add(lineId);
    _matchError = null;
  });

  double _systemRemaining(ReconciliationSystemTransaction t) => _amount(t.amount) - _amount(t.matchedAmount);

  Future<void> _performMatch() async {
    final ReconciliationSession? session = _session;
    if (session == null) return;
    final List<ReconciliationSystemTransaction> selectedSystem =
        _transactions.where((ReconciliationSystemTransaction t) => _selectedSystem.contains(t.journalEntryId)).toList();
    final List<ReconciliationStatementLine> selectedStatement = session.statementLines
        .where((ReconciliationStatementLine l) => _selectedStatement.contains(l.id))
        .toList();
    if (selectedSystem.isEmpty || selectedStatement.isEmpty) return;
    if (selectedSystem.length > 1 && selectedStatement.length > 1) {
      setState(() => _matchError = 'اختر عنصراً واحداً من أحد الجانبين عند مطابقة أكثر من عنصر بالجهة الأخرى.');
      return;
    }
    final double sysTotal = selectedSystem.fold<double>(0, (double s, ReconciliationSystemTransaction t) => s + _systemRemaining(t));
    final double stmtTotal = selectedStatement.fold<double>(0, (double s, ReconciliationStatementLine l) => s + _amount(l.remainingAmount));
    if ((sysTotal - stmtTotal).abs() > 0.0001) {
      setState(() => _matchError = 'إجمالي الحركات المحددة (${sysTotal.toStringAsFixed(2)}) لا يساوي إجمالي أسطر الكشف المحددة (${stmtTotal.toStringAsFixed(2)}).');
      return;
    }
    setState(() {
      _matching = true;
      _matchError = null;
    });
    try {
      final int stamp = DateTime.now().microsecondsSinceEpoch;
      if (selectedStatement.length > 1) {
        final ReconciliationSystemTransaction sys = selectedSystem.single;
        for (final ReconciliationStatementLine line in selectedStatement) {
          await _repository.matchReconciliation(widget.reconciliationId, <String, dynamic>{
            'statementLineId': line.id,
            'journalEntryId': sys.journalEntryId,
            'amount': line.remainingAmount,
            'idempotencyKey': 'reconciliation-match-${widget.reconciliationId}-${sys.journalEntryId}-${line.id}-$stamp',
          });
        }
      } else {
        final ReconciliationStatementLine line = selectedStatement.single;
        for (final ReconciliationSystemTransaction sys in selectedSystem) {
          await _repository.matchReconciliation(widget.reconciliationId, <String, dynamic>{
            'statementLineId': line.id,
            'journalEntryId': sys.journalEntryId,
            'amount': _systemRemaining(sys).toStringAsFixed(2),
            'idempotencyKey': 'reconciliation-match-${widget.reconciliationId}-${sys.journalEntryId}-${line.id}-$stamp',
          });
        }
      }
      await _load();
      if (mounted) setState(() => _matching = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _matchError = '$error';
          _matching = false;
        });
      }
      await _load();
    }
  }

  Future<void> _acceptSuggestion(int statementLineId, ReconciliationSystemTransaction candidate) async {
    try {
      await _repository.matchReconciliation(widget.reconciliationId, <String, dynamic>{
        'statementLineId': statementLineId,
        'journalEntryId': candidate.journalEntryId,
        'amount': candidate.amount,
        'idempotencyKey': 'reconciliation-suggestion-${widget.reconciliationId}-${candidate.journalEntryId}-$statementLineId',
      });
      await _load();
    } catch (error) {
      if (mounted) _showError('تعذّر قبول الاقتراح: $error');
    }
  }

  Future<void> _unmatch(ReconciliationMatchRecord match) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('إلغاء المطابقة'),
        content: const Text('سيتم فصل هذه المطابقة وإعادة المبلغ إلى غير المطابق. هل تريد المتابعة؟'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
            child: const Text('إلغاء المطابقة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.unmatchReconciliation(widget.reconciliationId, match.id);
      await _load();
    } catch (error) {
      if (mounted) _showError('تعذّر إلغاء المطابقة: $error');
    }
  }

  Future<void> _deleteLine(ReconciliationStatementLine line) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('حذف سطر الكشف'),
        content: Text('سيتم حذف السطر «${line.description}». هل تريد المتابعة؟'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.danger, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteReconciliationStatementLine(widget.reconciliationId, line.id);
      await _load();
    } catch (error) {
      if (mounted) _showError('تعذّر حذف السطر: $error');
    }
  }

  Future<void> _openAddLineDialog() async {
    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialog) => const _AddStatementLineDialog(),
    );
    if (result == null) return;
    try {
      await _repository.addReconciliationStatementLine(widget.reconciliationId, result);
      await _load();
    } catch (error) {
      if (mounted) _showError('تعذّر إضافة السطر: $error');
    }
  }

  Future<void> _openBalanceDialog({required bool actualCash}) async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) => _BalanceDialog(label: actualCash ? 'النقد الفعلي' : 'الرصيد الختامي الخارجي'),
    );
    if (value == null) return;
    try {
      await _repository.updateReconciliation(widget.reconciliationId, <String, dynamic>{
        actualCash ? 'actualCashCount' : 'externalClosingBalance': value,
      });
      await _load();
    } catch (error) {
      if (mounted) _showError('تعذّر تحديث الرصيد: $error');
    }
  }

  Future<void> _complete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('إنهاء التسوية'),
        content: const Text('بعد الإنهاء تصبح التسوية للقراءة فقط ولا يمكن التراجع عن هذا الإجراء.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
            child: const Text('إنهاء التسوية'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.completeReconciliation(widget.reconciliationId);
      await _load();
    } catch (error) {
      if (mounted) _showError('تعذّر إنهاء التسوية: $error');
    }
  }

  void _openJournalDrawer(int journalEntryId) {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'إغلاق',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (BuildContext dialogContext, _, _) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FinanceJournalDrawer(
          child: FinanceJournalDrawerBody(
            loader: () => _repository.getFinanceMap('finance/transactions/$journalEntryId'),
            onNavigate: (String path) {
              Navigator.of(dialogContext).pop();
              context.go(path);
            },
          ),
        ),
      ),
      transitionBuilder: (BuildContext context, Animation<double> animation, _, Widget child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.session});
  final ReconciliationSession session;

  @override
  Widget build(BuildContext context) {
    final bool ready = session.canComplete;
    final tone = ready ? FinanceTone.success : FinanceTone.danger;
    final colors = financeTone(tone);
    return Container(
      padding: const EdgeInsets.all(FinanceSpace.lg),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            ready ? 'جاهزة للإنهاء' : 'محظورة عن الإنهاء',
            style: FinanceText.body.copyWith(fontWeight: FontWeight.w700, color: colors.foreground),
          ),
          if (!ready) ...<Widget>[
            const SizedBox(height: FinanceSpace.xs),
            ...session.blockingReasons.map(
              (String code) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• ${_blockerLabels[code] ?? code}', style: FinanceText.small.copyWith(color: colors.foreground)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OperationalBar extends StatelessWidget {
  const _OperationalBar({required this.session, required this.onComplete, this.onUpdateCash});
  final ReconciliationSession session;
  final VoidCallback onComplete;
  final VoidCallback? onUpdateCash;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: FinanceSpace.sm,
    runSpacing: FinanceSpace.sm,
    children: <Widget>[
      if (onUpdateCash != null)
        OutlinedButton(onPressed: onUpdateCash, child: const Text('تحديث النقد الفعلي')),
      ElevatedButton(
        onPressed: session.canComplete ? onComplete : null,
        style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
        child: const Text('إكمال التسوية'),
      ),
    ],
  );
}

class _CashMovements extends StatelessWidget {
  const _CashMovements({required this.transactions, required this.onOpenJournal});
  final List<ReconciliationSystemTransaction> transactions;
  final ValueChanged<int> onOpenJournal;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const FinanceEmptyState(message: 'لا توجد حركات نقدية ضمن فترة التسوية');
    }
    return FinanceTable(
      minWidth: 900,
      headers: const <String>['التاريخ', 'المرجع', 'الوصف', 'الاتجاه', 'المبلغ'],
      onRowTap: (int index) => onOpenJournal(transactions[index].journalEntryId),
      rows: transactions
          .map(
            (ReconciliationSystemTransaction t) => <Widget>[
              Text(t.date, style: FinanceText.body),
              FinanceReference(reference: t.reference),
              Text(t.description, style: FinanceText.body),
              Text(t.direction == 'inflow' ? 'وارد' : 'صادر', style: FinanceText.body),
              FinanceAmount(value: t.amount),
            ],
          )
          .toList(),
    );
  }
}

class _BankCardWorkspace extends StatelessWidget {
  const _BankCardWorkspace({
    required this.session,
    required this.transactions,
    required this.suggestions,
    required this.selectedSystem,
    required this.selectedStatement,
    required this.matchError,
    required this.matching,
    required this.readOnly,
    required this.onToggleSystem,
    required this.onToggleStatement,
    required this.onOpenJournal,
    required this.onMatch,
    required this.onAcceptSuggestion,
    required this.onUnmatch,
    required this.onAddLine,
    required this.onDeleteLine,
    required this.onUpdateExternalBalance,
  });
  final ReconciliationSession session;
  final List<ReconciliationSystemTransaction> transactions;
  final List<ReconciliationSuggestion> suggestions;
  final Set<int> selectedSystem;
  final Set<int> selectedStatement;
  final String? matchError;
  final bool matching;
  final bool readOnly;
  final ValueChanged<int> onToggleSystem;
  final ValueChanged<int> onToggleStatement;
  final ValueChanged<int> onOpenJournal;
  final VoidCallback onMatch;
  final void Function(int statementLineId, ReconciliationSystemTransaction candidate) onAcceptSuggestion;
  final ValueChanged<ReconciliationMatchRecord> onUnmatch;
  final VoidCallback onAddLine;
  final ValueChanged<ReconciliationStatementLine> onDeleteLine;
  final VoidCallback onUpdateExternalBalance;

  double _amt(String v) => double.tryParse(v.replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final double sysTotal = transactions
        .where((ReconciliationSystemTransaction t) => selectedSystem.contains(t.journalEntryId))
        .fold<double>(0, (double s, ReconciliationSystemTransaction t) => s + _amt(t.amount) - _amt(t.matchedAmount));
    final double stmtTotal = session.statementLines
        .where((ReconciliationStatementLine l) => selectedStatement.contains(l.id))
        .fold<double>(0, (double s, ReconciliationStatementLine l) => s + _amt(l.remainingAmount));
    final double diff = sysTotal - stmtTotal;
    final bool canMatch = !readOnly && selectedSystem.isNotEmpty && selectedStatement.isNotEmpty && diff.abs() < 0.0001 && !matching;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!readOnly)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: FinanceSpace.sm,
              children: <Widget>[
                OutlinedButton.icon(onPressed: onAddLine, icon: const Icon(Icons.add, size: 18), label: const Text('إضافة سطر كشف')),
                OutlinedButton.icon(
                  onPressed: onUpdateExternalBalance,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تحديث الرصيد الخارجي'),
                ),
              ],
            ),
          ),
        const SizedBox(height: FinanceSpace.md),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stack = constraints.maxWidth < 900;
            final Widget left = _SystemPanel(
              transactions: transactions,
              selected: selectedSystem,
              readOnly: readOnly,
              onToggle: onToggleSystem,
              onOpenJournal: onOpenJournal,
            );
            final Widget right = _StatementPanel(
              lines: session.statementLines,
              selected: selectedStatement,
              readOnly: readOnly,
              onToggle: onToggleStatement,
              onDelete: onDeleteLine,
            );
            if (stack) {
              return Column(children: <Widget>[left, const SizedBox(height: FinanceSpace.md), right]);
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: left),
                  const SizedBox(width: FinanceSpace.md),
                  Expanded(child: right),
                ],
              ),
            );
          },
        ),
        if (!readOnly) ...<Widget>[
          const SizedBox(height: FinanceSpace.md),
          Container(
            padding: const EdgeInsets.all(FinanceSpace.md),
            decoration: BoxDecoration(
              color: FinanceColors.card,
              border: Border.all(color: FinanceColors.border),
              borderRadius: BorderRadius.circular(FinanceRadius.card),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: FinanceSpace.lg,
              runSpacing: FinanceSpace.sm,
              children: <Widget>[
                Text('إجمالي النظام: ${sysTotal.toStringAsFixed(2)}', style: FinanceText.body),
                Text('إجمالي الكشف: ${stmtTotal.toStringAsFixed(2)}', style: FinanceText.body),
                Text(
                  'الفرق: ${diff.toStringAsFixed(2)}',
                  style: FinanceText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: diff.abs() < 0.0001 ? FinanceColors.success : FinanceColors.danger,
                  ),
                ),
                ElevatedButton(
                  onPressed: canMatch ? onMatch : null,
                  style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
                  child: matching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('مطابقة'),
                ),
              ],
            ),
          ),
          if (matchError != null) ...<Widget>[
            const SizedBox(height: FinanceSpace.sm),
            Text(matchError!, style: const TextStyle(color: FinanceColors.danger)),
          ],
        ],
        if (suggestions.isNotEmpty && !readOnly) ...<Widget>[
          const SizedBox(height: FinanceSpace.lg),
          Text('اقتراحات المطابقة', style: FinanceText.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: FinanceSpace.sm),
          ...suggestions.map(
            (ReconciliationSuggestion suggestion) => Container(
              margin: const EdgeInsets.only(bottom: FinanceSpace.sm),
              padding: const EdgeInsets.all(FinanceSpace.md),
              decoration: BoxDecoration(
                color: FinanceColors.card,
                border: Border.all(color: FinanceColors.border),
                borderRadius: BorderRadius.circular(FinanceRadius.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: suggestion.candidates
                    .map(
                      (ReconciliationSystemTransaction candidate) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text('${candidate.reference} — ${candidate.amount}', style: FinanceText.body),
                            ),
                            TextButton(
                              onPressed: () => onAcceptSuggestion(suggestion.statementLineId, candidate),
                              child: const Text('قبول الاقتراح'),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
        if (session.matches.isNotEmpty) ...<Widget>[
          const SizedBox(height: FinanceSpace.lg),
          Text('مطابقات مسجلة', style: FinanceText.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: FinanceSpace.sm),
          FinanceTable(
            minWidth: 700,
            headers: const <String>['الحركة', 'سطر الكشف', 'المبلغ', ''],
            rows: session.matches.map((ReconciliationMatchRecord match) {
              final ReconciliationStatementLine? line = session.statementLines
                  .where((ReconciliationStatementLine l) => l.id == match.statementLineId)
                  .firstOrNull;
              return <Widget>[
                FinanceReference(reference: match.journalReference),
                Text(line?.reference ?? '#${match.statementLineId}', style: FinanceText.body),
                FinanceAmount(value: match.amount),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: readOnly
                      ? const SizedBox.shrink()
                      : TextButton(onPressed: () => onUnmatch(match), child: const Text('إلغاء المطابقة')),
                ),
              ];
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _SystemPanel extends StatelessWidget {
  const _SystemPanel({
    required this.transactions,
    required this.selected,
    required this.readOnly,
    required this.onToggle,
    required this.onOpenJournal,
  });
  final List<ReconciliationSystemTransaction> transactions;
  final Set<int> selected;
  final bool readOnly;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onOpenJournal;

  double _amt(String v) => double.tryParse(v.replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.md),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('حركات النظام', style: FinanceText.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: FinanceSpace.sm),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: FinanceSpace.lg),
            child: FinanceEmptyState(message: 'لا توجد حركات نظام ضمن فترة التسوية'),
          )
        else
          ...transactions.map((ReconciliationSystemTransaction t) {
            final double remaining = _amt(t.amount) - _amt(t.matchedAmount);
            final bool matched = remaining <= 0.0001;
            final bool isSelected = selected.contains(t.journalEntryId);
            return Container(
              margin: const EdgeInsets.only(bottom: FinanceSpace.xs),
              padding: const EdgeInsets.symmetric(horizontal: FinanceSpace.sm, vertical: FinanceSpace.xs),
              decoration: BoxDecoration(
                color: isSelected ? FinanceColors.workspace : Colors.transparent,
                borderRadius: BorderRadius.circular(FinanceRadius.control),
              ),
              child: Row(
                children: <Widget>[
                  if (!readOnly && !matched)
                    Checkbox(value: isSelected, onChanged: (_) => onToggle(t.journalEntryId))
                  else if (matched)
                    const Padding(
                      padding: EdgeInsets.all(FinanceSpace.xs),
                      child: Icon(Icons.check_circle, size: 18, color: FinanceColors.success),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(t.description, style: FinanceText.body),
                        Text('${t.reference} · ${t.date}', style: FinanceText.small.copyWith(color: FinanceColors.supporting)),
                      ],
                    ),
                  ),
                  FinanceAmount(value: t.amount),
                  IconButton(
                    tooltip: 'عرض القيد',
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    onPressed: () => onOpenJournal(t.journalEntryId),
                  ),
                ],
              ),
            );
          }),
      ],
    ),
  );
}

class _StatementPanel extends StatelessWidget {
  const _StatementPanel({
    required this.lines,
    required this.selected,
    required this.readOnly,
    required this.onToggle,
    required this.onDelete,
  });
  final List<ReconciliationStatementLine> lines;
  final Set<int> selected;
  final bool readOnly;
  final ValueChanged<int> onToggle;
  final ValueChanged<ReconciliationStatementLine> onDelete;

  double _amt(String v) => double.tryParse(v.replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.md),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('سطور الكشف', style: FinanceText.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: FinanceSpace.sm),
        if (lines.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: FinanceSpace.lg),
            child: FinanceEmptyState(message: 'لا توجد أسطر كشف بعد'),
          )
        else
          ...lines.map((ReconciliationStatementLine line) {
            final bool matched = _amt(line.remainingAmount) <= 0.0001;
            final bool isSelected = selected.contains(line.id);
            return Container(
              margin: const EdgeInsets.only(bottom: FinanceSpace.xs),
              padding: const EdgeInsets.symmetric(horizontal: FinanceSpace.sm, vertical: FinanceSpace.xs),
              decoration: BoxDecoration(
                color: isSelected ? FinanceColors.workspace : Colors.transparent,
                borderRadius: BorderRadius.circular(FinanceRadius.control),
              ),
              child: Row(
                children: <Widget>[
                  if (!readOnly && !matched)
                    Checkbox(value: isSelected, onChanged: (_) => onToggle(line.id))
                  else if (matched)
                    const Padding(
                      padding: EdgeInsets.all(FinanceSpace.xs),
                      child: Icon(Icons.check_circle, size: 18, color: FinanceColors.success),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(line.description, style: FinanceText.body),
                        Text('${line.reference} · ${line.transactionDate}', style: FinanceText.small.copyWith(color: FinanceColors.supporting)),
                      ],
                    ),
                  ),
                  FinanceAmount(value: line.amount),
                  if (!readOnly && _amt(line.matchedAmount) <= 0.0001)
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => onDelete(line),
                    ),
                ],
              ),
            );
          }),
      ],
    ),
  );
}

class _AddStatementLineDialog extends StatefulWidget {
  const _AddStatementLineDialog();
  @override
  State<_AddStatementLineDialog> createState() => _AddStatementLineDialogState();
}

class _AddStatementLineDialogState extends State<_AddStatementLineDialog> {
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  String _direction = 'inflow';
  String? _error;

  @override
  void dispose() {
    _reference.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked.toIso8601String().substring(0, 10));
  }

  void _submit() {
    if (_description.text.trim().isEmpty || !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(_amount.text.trim())) {
      setState(() => _error = 'أدخل وصفاً ومبلغاً صالحاً.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'transactionDate': _date,
      if (_reference.text.trim().isNotEmpty) 'reference': _reference.text.trim(),
      'description': _description.text.trim(),
      'amount': _amount.text.trim(),
      'direction': _direction,
    });
  }

  @override
  Widget build(BuildContext context) => FinanceDialogShell(
    title: 'إضافة سطر كشف',
    actions: <Widget>[
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
        child: const Text('إضافة'),
      ),
    ],
    child: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(decoration: const InputDecoration(labelText: 'التاريخ'), child: Text(_date)),
          ),
          const SizedBox(height: FinanceSpace.md),
          TextField(controller: _reference, decoration: const InputDecoration(labelText: 'المرجع (اختياري)')),
          const SizedBox(height: FinanceSpace.md),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'الوصف')),
          const SizedBox(height: FinanceSpace.md),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ'),
          ),
          const SizedBox(height: FinanceSpace.md),
          DropdownButtonFormField<String>(
            initialValue: _direction,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الاتجاه'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'inflow', child: Text('وارد')),
              DropdownMenuItem<String>(value: 'outflow', child: Text('صادر')),
            ],
            onChanged: (String? v) => setState(() => _direction = v!),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: FinanceSpace.sm),
            Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
          ],
        ],
      ),
    ),
  );
}

class _BalanceDialog extends StatefulWidget {
  const _BalanceDialog({required this.label});
  final String label;
  @override
  State<_BalanceDialog> createState() => _BalanceDialogState();
}

class _BalanceDialogState extends State<_BalanceDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(_controller.text.trim())) {
      setState(() => _error = 'أدخل مبلغاً صالحاً.');
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => FinanceDialogShell(
    title: widget.label,
    actions: <Widget>[
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
        child: const Text('حفظ'),
      ),
    ],
    child: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: widget.label),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: FinanceSpace.sm),
            Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
          ],
        ],
      ),
    ),
  );
}

double _amount(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
