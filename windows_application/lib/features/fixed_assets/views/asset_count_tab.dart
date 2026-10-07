import 'package:flutter/material.dart';

import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../data/fa_api.dart';
import '../widgets/fa_widgets.dart';
import 'asset_dialogs.dart';

/// الجرد الفعلي للأصول: جلسة جرد تُلتقط من السجل، يُمسح كل أصل بالكود أو الباركود،
/// وعند الإغلاق يصبح غير الممسوح «مفقودًا». لا أثر محاسبي.
class AssetCountTab extends StatefulWidget {
  const AssetCountTab({super.key, required this.refs});

  final FaRefs refs;

  @override
  State<AssetCountTab> createState() => _AssetCountTabState();
}

class _AssetCountTabState extends State<AssetCountTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  final TextEditingController _scan = TextEditingController();
  final FocusNode _scanFocus = FocusNode();
  List<Json> _counts = const <Json>[];
  Json? _open;
  String? _branch;
  bool _busy = false;
  String? _error;
  String? _scanMessage;
  bool _scanOk = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _scan.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    try {
      final List<Json> list = await _api.counts();
      if (mounted) setState(() => _counts = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _openCount(int id) async {
    try {
      final Json c = await _api.count(id);
      if (mounted) {
        setState(() {
          _open = c;
          _scanMessage = null;
        });
        _scanFocus.requestFocus();
      }
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Json c = await _api.startCount(<String, dynamic>{'branchId': _branch == null || _branch == kCompanyBranch ? null : int.tryParse(_branch!)});
      if (!mounted) return;
      setState(() => _open = c);
      await _loadList();
      _scanFocus.requestFocus();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doScan(String code) async {
    final String value = code.trim();
    final Json? c = _open;
    if (value.isEmpty || c == null) return;
    try {
      final Json r = await _api.scanCount(intOf(c['id'])!, value);
      final String result = str(r['result']);
      final Json line = asJson(r['line']);
      if (!mounted) return;
      setState(() {
        _scanOk = result != 'already';
        _scanMessage = switch (result) {
          'already' => 'سبق مسح ${line['code']} — ${line['name']}',
          'extra' => '${line['code']} — ${line['name']}: أصل من خارج نطاق الجرد (أُضيف كزائد)',
          _ => '✓ ${line['code']} — ${line['name']}',
        };
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanOk = false;
          _scanMessage = '$e';
        });
      }
    }
    _scan.clear();
    await _refreshOpen();
    _scanFocus.requestFocus();
  }

  Future<void> _refreshOpen() async {
    final Json? c = _open;
    if (c == null) return;
    try {
      final Json fresh = await _api.count(intOf(c['id'])!);
      if (mounted) setState(() => _open = fresh);
    } catch (_) {}
  }

  Future<void> _setLine(Json line, String status) async {
    try {
      await _api.setCountLine(intOf(_open!['id'])!, intOf(line['id'])!, <String, dynamic>{'status': status});
      await _refreshOpen();
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    }
  }

  Future<void> _close() async {
    final Json c = _open!;
    final int pending = intOf(asJson(c['summary'])['pending']) ?? 0;
    if (!await confirmFa(context, 'إغلاق الجرد', pending > 0 ? 'يوجد $pending أصل لم يُمسح وسيُعتبر مفقودًا. إغلاق الجرد؟' : 'إغلاق الجرد؟', confirm: 'إغلاق')) return;
    try {
      final Json closed = await _api.closeCount(intOf(c['id'])!);
      if (!mounted) return;
      setState(() => _open = closed);
      showFaMessage(context, 'تم إغلاق الجرد.');
      await _loadList();
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    }
  }

  Future<void> _cancel() async {
    final Json c = _open!;
    if (!await confirmFa(context, 'إلغاء الجرد', 'إلغاء هذا الجرد؟ لا يمكن متابعته بعد ذلك.', confirm: 'إلغاء الجرد')) return;
    try {
      await _api.cancelCount(intOf(c['id'])!);
      if (!mounted) return;
      setState(() => _open = null);
      await _loadList();
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    }
  }

  static String _statusLabel(String s) => switch (s) {
    'found' => 'موجود',
    'missing' => 'مفقود',
    'extra' => 'زائد',
    'cancelled' => 'ملغى',
    'closed' => 'مغلق',
    'open' => 'مفتوح',
    _ => 'لم يُمسح',
  };

  static String _pillStatus(String s) => switch (s) {
    'found' || 'closed' => 'posted',
    'missing' || 'cancelled' => 'reversed',
    'pending' || 'open' => 'draft',
    _ => 'neutral',
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Json? c = _open;
    return ListView(
      children: <Widget>[
        FaSection(
          title: 'جرد جديد',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: FinanceSpace.md,
                runSpacing: FinanceSpace.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  FaBranchDropdown(
                    branches: widget.refs.branches,
                    value: _branch,
                    includeCompany: false,
                    includeAll: true,
                    onChanged: (String? v) => setState(() => _branch = v),
                  ),
                  FaBusyButton(label: 'بدء الجرد', icon: Icons.fact_check_outlined, busy: _busy, onPressed: _start),
                ],
              ),
              FaErrorText(_error),
            ],
          ),
        ),
        if (c != null) ...<Widget>[
          const SizedBox(height: FinanceSpace.md),
          FaSection(
            title: 'جرد ${c['number']}${c['branchName'] == null ? '' : ' — ${c['branchName']}'}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: FinanceSpace.md,
                  runSpacing: FinanceSpace.md,
                  children: <Widget>[
                    FaStat(label: 'الإجمالي', value: '${asJson(c['summary'])['total']}'),
                    FaStat(label: 'موجود', value: '${asJson(c['summary'])['found']}', color: FinanceColors.success),
                    FaStat(label: 'لم يُمسح', value: '${asJson(c['summary'])['pending']}', color: FinanceColors.primary),
                    FaStat(label: 'مفقود', value: '${asJson(c['summary'])['missing']}', color: FinanceColors.danger),
                    FaStat(label: 'زائد', value: '${asJson(c['summary'])['extra']}'),
                  ],
                ),
                const SizedBox(height: FinanceSpace.md),
                if (c['status'] == 'open') ...<Widget>[
                  Wrap(
                    spacing: FinanceSpace.md,
                    runSpacing: FinanceSpace.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _scan,
                          focusNode: _scanFocus,
                          autofocus: true,
                          onSubmitted: _doScan,
                          decoration: const InputDecoration(
                            labelText: 'امسح الباركود أو اكتب كود الأصل ثم Enter',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.qr_code_scanner, size: 18),
                          ),
                        ),
                      ),
                      FilledButton(onPressed: _close, child: const Text('إغلاق الجرد')),
                      TextButton(onPressed: _cancel, child: const Text('إلغاء الجرد')),
                    ],
                  ),
                  if (_scanMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: FinanceSpace.sm),
                      child: Text(_scanMessage!, style: FinanceText.body.copyWith(color: _scanOk ? FinanceColors.success : FinanceColors.danger)),
                    ),
                  const SizedBox(height: FinanceSpace.md),
                ],
                FaTable(
                  minWidth: 800,
                  columns: const <String>['الكود', 'الأصل', 'الحالة', 'ملاحظة', ''],
                  flex: const <int>[2, 4, 2, 3, 3],
                  emptyMessage: 'لا توجد أسطر.',
                  rows: asJsonList(c['lines'])
                      .map((Json l) => <Widget>[
                            faCell(str(l['code']), ltr: true, bold: true),
                            faCell(str(l['name'])),
                            FaStatusPill(status: _pillStatus(str(l['status'])), label: _statusLabel(str(l['status']))),
                            faCell(str(l['note'])),
                            c['status'] == 'open' && l['status'] != 'extra'
                                ? Wrap(children: <Widget>[
                                    TextButton(onPressed: l['status'] == 'found' ? null : () => _setLine(l, 'found'), child: const Text('موجود')),
                                    TextButton(onPressed: l['status'] == 'missing' ? null : () => _setLine(l, 'missing'), child: const Text('مفقود')),
                                  ])
                                : const SizedBox.shrink(),
                          ])
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'الجردات السابقة',
          child: FaTable(
            minWidth: 800,
            columns: const <String>['الرقم', 'التاريخ', 'الفرع', 'موجود / الإجمالي', 'الحالة', ''],
            flex: const <int>[2, 2, 2, 2, 2, 1],
            emptyMessage: 'لا توجد جردات.',
            rows: _counts
                .map((Json k) => <Widget>[
                      faCell(str(k['number']), ltr: true, bold: true),
                      faCell(str(k['countDate']), ltr: true),
                      faCell(str(k['branchName'], 'كل الفروع')),
                      faCell('${asJson(k['summary'])['found']} / ${asJson(k['summary'])['total']}', ltr: true),
                      FaStatusPill(status: _pillStatus(str(k['status'])), label: _statusLabel(str(k['status']))),
                      TextButton(onPressed: () => _openCount(intOf(k['id'])!), child: const Text('فتح')),
                    ])
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}
