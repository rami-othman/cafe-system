import 'package:flutter/material.dart';

import '../../../core/utils/search_debouncer.dart';
import '../../inventory/models/inventory_models.dart';
import '../../inventory/repositories/inventory_repository.dart';

/// Server-side searchable inventory item picker for purchase invoice lines.
///
/// Replaces a plain dropdown backed by a single capped page (100 items) with
/// live, debounced, full-catalog search — an item beyond page 1 must still
/// be reachable by typing its name, code, or barcode.
class InventoryItemSearchField extends StatefulWidget {
  const InventoryItemSearchField({
    super.key,
    required this.repository,
    required this.selected,
    required this.onSelected,
    this.width = 240,
  });

  final InventoryRepository repository;
  final InventoryItem? selected;
  final ValueChanged<InventoryItem?> onSelected;
  final double width;

  @override
  State<InventoryItemSearchField> createState() =>
      _InventoryItemSearchFieldState();
}

class _InventoryItemSearchFieldState extends State<InventoryItemSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final SearchDebouncer _debouncer = SearchDebouncer();
  final LatestRequestGuard _guard = LatestRequestGuard();
  OverlayEntry? _overlayEntry;
  List<InventoryItem> _results = const <InventoryItem>[];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selected?.name ?? '';
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant InventoryItemSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected?.id != oldWidget.selected?.id) {
      _controller.text = widget.selected?.name ?? '';
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _debouncer.dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onChanged(String value) {
    if (widget.selected != null) {
      widget.onSelected(null);
    }
    final String query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <InventoryItem>[];
        _loading = false;
        _searched = false;
      });
      _hideOverlay();
      return;
    }
    _debouncer.run(() => _search(query));
  }

  Future<void> _search(String query) async {
    final int token = _guard.next();
    setState(() => _loading = true);
    List<InventoryItem> results;
    try {
      results = await widget.repository.items(search: query, activeOnly: true);
    } catch (_) {
      results = const <InventoryItem>[];
    }
    if (!mounted || !_guard.isCurrent(token)) {
      return;
    }
    setState(() {
      _results = results;
      _loading = false;
      _searched = true;
    });
    _showOverlay();
  }

  void _select(InventoryItem item) {
    _controller.text = item.name;
    widget.onSelected(item);
    _hideOverlay();
    _focusNode.unfocus();
  }

  void _showOverlay() {
    _hideOverlay();
    if (!_loading && _results.isEmpty && !_searched) {
      return;
    }
    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        width: widget.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: _buildOverlayContent(),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlayContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('لا توجد نتائج مطابقة للبحث'),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _results.length,
      itemBuilder: (BuildContext context, int index) {
        final InventoryItem item = _results[index];
        return ListTile(
          dense: true,
          title: Text(item.name, overflow: TextOverflow.ellipsis),
          subtitle: item.sku.isEmpty ? null : Text(item.sku),
          onTap: () => _select(item),
        );
      },
    );
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        onTapOutside: (_) => _hideOverlay(),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'الصنف',
            isDense: true,
            hintText: 'ابحث بالاسم أو الكود أو الباركود...',
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (widget.selected != null
                      ? const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Colors.green,
                        )
                      : null),
          ),
          onChanged: _onChanged,
          onTap: () {
            if (_results.isNotEmpty || _loading) {
              _showOverlay();
            }
          },
        ),
      ),
    );
  }
}
