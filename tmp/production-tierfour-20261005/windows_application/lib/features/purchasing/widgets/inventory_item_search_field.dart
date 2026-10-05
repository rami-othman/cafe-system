import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _failed = false;
  bool _clearingSelection = false;
  bool _pointerInsideResults = false;
  int _highlighted = -1;
  final ScrollController _scrollController = ScrollController();
  static const double _resultHeight = 64;
  final Object _tapGroupId = Object();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selected?.name ?? '';
    _focusNode.addListener(_onFocusChanged);
    _focusNode.onKeyEvent = _onKeyEvent;
  }

  @override
  void didUpdateWidget(covariant InventoryItemSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected?.id != oldWidget.selected?.id) {
      if (!(_clearingSelection && widget.selected == null)) {
        _cancelSearch();
        _hideOverlay();
        _controller.text = widget.selected?.name ?? '';
      }
    }
    _clearingSelection = false;
  }

  @override
  void dispose() {
    _hideOverlay();
    _debouncer.dispose();
    _scrollController.dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && !_pointerInsideResults) {
      _dismiss();
    }
  }

  void _onChanged(String value) {
    if (widget.selected != null) {
      _clearingSelection = true;
      widget.onSelected(null);
    }
    _queueSearch(value);
  }

  void _cancelSearch() {
    _debouncer.cancel();
    _guard.next();
    _loading = false;
    _results = const <InventoryItem>[];
    _searched = false;
    _failed = false;
    _highlighted = -1;
  }

  void _dismiss() {
    _hideOverlay();
    setState(_cancelSearch);
  }

  void _queueSearch(String value) {
    _cancelSearch();
    _hideOverlay();
    final String query = value.trim();
    setState(() => _loading = query.isNotEmpty);
    if (query.isEmpty) {
      return;
    }
    final int token = _guard.next();
    _showOverlay();
    _debouncer.run(() => _search(query, token));
  }

  Future<void> _search(String query, int token) async {
    List<InventoryItem> results;
    bool failed = false;
    try {
      results = await widget.repository.items(search: query, activeOnly: true);
    } catch (_) {
      results = const <InventoryItem>[];
      failed = true;
    }
    if (!mounted || !_guard.isCurrent(token)) {
      return;
    }
    setState(() {
      _results = results;
      _loading = false;
      _searched = true;
      _failed = failed;
      _highlighted = -1;
    });
    _showOverlay();
  }

  void _select(InventoryItem item) {
    _pointerInsideResults = false;
    _cancelSearch();
    _controller.text = item.name;
    widget.onSelected(item);
    _hideOverlay();
    _focusNode.unfocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _dismiss();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _dismiss();
      return KeyEventResult.ignored;
    }
    if (_overlayEntry == null || _loading || _results.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _select(_results[_highlighted < 0 ? 0 : _highlighted]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      _highlighted = key == LogicalKeyboardKey.arrowDown
          ? (_highlighted + 1) % _results.length
          : (_highlighted <= 0 ? _results.length - 1 : _highlighted - 1);
      _overlayEntry?.markNeedsBuild();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          (_highlighted * _resultHeight).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _showOverlay() {
    _hideOverlay();
    if (!_focusNode.hasFocus) return;
    if (!_loading && _results.isEmpty && !_searched) {
      return;
    }
    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) => Positioned.fill(
        child: Stack(
          children: <Widget>[
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 4),
              child: TapRegion(
                groupId: _tapGroupId,
                child: Listener(
                  onPointerDown: (_) => _pointerInsideResults = true,
                  onPointerUp: (_) => _pointerInsideResults = false,
                  onPointerCancel: (_) => _pointerInsideResults = false,
                  child: SizedBox(
                    width: widget.width,
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
              ),
            ),
          ],
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
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('تعذّر البحث عن الأصناف. حاول مرة أخرى.'),
            TextButton(
              onPressed: () => _queueSearch(_controller.text),
              child: const Text('إعادة المحاولة'),
            ),
          ],
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
      controller: _scrollController,
      itemExtent: _resultHeight,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _results.length,
      itemBuilder: (BuildContext context, int index) {
        final InventoryItem item = _results[index];
        return ListTile(
          selected: index == _highlighted,
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
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        groupId: _tapGroupId,
        onTapOutside: (_) => _dismiss(),
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
            if (_searched || _loading) {
              _showOverlay();
            } else if (widget.selected == null &&
                _controller.text.trim().isNotEmpty) {
              _queueSearch(_controller.text);
            }
          },
        ),
      ),
    );
  }
}
