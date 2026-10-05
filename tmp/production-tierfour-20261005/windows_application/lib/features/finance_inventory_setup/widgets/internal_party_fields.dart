import 'package:flutter/material.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/controllers/auth_session_cubit.dart';
import '../../pos/models/branch.dart';
import '../repositories/finance_setup_repository.dart';
import '../../../core/network/dio_api_client.dart';

class InternalCustomerEditor extends StatelessWidget {
  const InternalCustomerEditor({super.key, required this.id, required this.internal, this.branchId, required this.onSaved});
  final int id; final bool internal; final int? branchId; final VoidCallback onSaved;
  @override
  Widget build(BuildContext context) {
    if (!serviceLocator.isRegistered<AuthSessionCubit>() || serviceLocator<AuthSessionCubit>().state.session?.user.role != 'owner') return const SizedBox.shrink();
    return TextButton(child: const Text('الطرف الداخلي'), onPressed: () async {
      bool selected = internal; int? branch = branchId; String? error; bool saving = false;
      final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(title: const Text('الطرف الداخلي'), content: Column(mainAxisSize: MainAxisSize.min, children: [InternalPartyFields(customer: true, initialInternal: internal, initialBranchId: branchId, onChanged: (value, id) { selected = value; branch = id; }), if (error != null) Text(error!)]), actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), FilledButton(onPressed: saving ? null : () async { update(() => saving = true); try { await serviceLocator<DioApiClient>().put('finance/customers/$id', data: {'isInternal': selected, 'internalBranchId': branch}); if (dialogContext.mounted) Navigator.pop(dialogContext, true); } catch (e) { if (dialogContext.mounted) update(() { error = '$e'; saving = false; }); } }, child: const Text('حفظ'))])));
      if (saved == true) onSaved();
    });
  }
}

class InternalPartyFields extends StatefulWidget {
  const InternalPartyFields({super.key, required this.customer, required this.initialInternal, this.initialBranchId, required this.onChanged});
  final bool customer;
  final bool initialInternal;
  final int? initialBranchId;
  final void Function(bool, int?) onChanged;
  @override
  State<InternalPartyFields> createState() => _InternalPartyFieldsState();
}
class _InternalPartyFieldsState extends State<InternalPartyFields> {
  late bool internal = widget.initialInternal;
  late int? branch = widget.initialBranchId;
  late final Future<List<Branch>> branches = serviceLocator<FinanceSetupRepository>().getBranches();
  @override
  Widget build(BuildContext context) {
    if (!serviceLocator.isRegistered<AuthSessionCubit>() || serviceLocator<AuthSessionCubit>().state.session?.user.role != 'owner') return const SizedBox.shrink();
    return Column(children: [
      SwitchListTile(title: const Text('طرف داخلي'), value: internal, onChanged: (value) { setState(() => internal = value); widget.onChanged(internal, branch); }),
      if (internal) FutureBuilder<List<Branch>>(future: branches, builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('تعذّر تحميل الفروع. أعد فتح النموذج للمحاولة.');
        final items = (snapshot.data ?? []).where((b) => b.branchType == (widget.customer ? 'cafe' : 'factory')).toList();
        return DropdownButtonFormField<int>(initialValue: items.any((b) => b.id == branch) ? branch : null, decoration: const InputDecoration(labelText: 'الفرع الذي يمثله الطرف'), items: items.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(), onChanged: (value) { setState(() => branch = value); widget.onChanged(internal, branch); });
      }),
    ]);
  }
}
