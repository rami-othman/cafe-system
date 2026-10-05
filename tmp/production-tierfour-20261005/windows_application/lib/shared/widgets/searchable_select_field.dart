import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Local-list searchable picker, mirroring the purchase invoice's item
/// search field (`InventoryItemSearchField`) but filtering an already-loaded
/// `items` list client-side instead of querying a repository — for forms
/// (e.g. sales invoice lines) whose catalog is preloaded in full at bootstrap.
class SearchableSelectField<T> extends StatefulWidget {
  const SearchableSelectField({
    super.key,
    required this.items,
    required this.selected,
    required this.itemLabel,
    required this.onSelected,
    this.itemSubtitle,
    this.label = 'الصنف',
    this.width = 260,
  });

  final List<T> items;
  final T? selected;
  final String Function(T) itemLabel;
  final String Function(T)? itemSubtitle;
  final ValueChanged<T?> onSelected;
  final String label;
  final double width;

  @override
  State<SearchableSelectField<T>> createState() =>
      _SearchableSelectFieldState<T>();
}

class _SearchableSelectFieldState<T> extends State<SearchableSelectField<T>> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<T> _results = <T>[];
  bool _clearingSelection = false;
  bool _pointerInsideResults = false;
  int _highlighted = -1;
  final ScrollController _scrollController = ScrollController();
  static const double _resultHeight = 64;
  final Object _tapGroupId = Object();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selected == null
        ? ''
        : widget.itemLabel(widget.selected as T);
    _focusNode.addListener(_onFocusChanged);
    _focusNode.onKeyEvent = _onKeyEvent;
  }

  @override
  void didUpdateWidget(covariant SearchableSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (!(_clearingSelection && widget.selected == null)) {
        _hideOverlay();
        _controller.text = widget.selected == null
            ? ''
            : widget.itemLabel(widget.selected as T);
      }
    }
    _clearingSelection = false;
  }

  @override
  void dispose() {
    _hideOverlay();
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
    _filter(value);
  }

  bool _matches(T item, String query) {
    final String label = widget.itemLabel(item).toLowerCase();
    final String? subtitle = widget.itemSubtitle?.call(item).toLowerCase();
    return label.contains(query) || (subtitle?.contains(query) ?? false);
  }

  void _filter(String value) {
    final String query = value.trim().toLowerCase();
    if (query.isEmpty) {
      _dismiss();
      return;
    }
    setState(() {
      _results = widget.items.where((T item) => _matches(item, query)).toList();
      _highlighted = -1;
    });
    _showOverlay();
  }

  void _dismiss() {
    _hideOverlay();
    setState(() {
      _results = <T>[];
      _highlighted = -1;
    });
  }

  void _select(T item) {
    _pointerInsideResults = false;
    _controller.text = widget.itemLabel(item);
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
    if (_overlayEntry == null || _results.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _select(_results[_highlighted < 0 ? 0 : _highlighted]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlighted = key == LogicalKeyboardKey.arrowDown
            ? (_highlighted + 1) % _results.length
            : (_highlighted <= 0 ? _results.length - 1 : _highlighted - 1);
      });
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
        final T item = _results[index];
        final String? subtitle = widget.itemSubtitle?.call(item);
        return ListTile(
          selected: index == _highlighted,
          dense: true,
          title: Text(widget.itemLabel(item), overflow: TextOverflow.ellipsis),
          subtitle: (subtitle == null || subtitle.isEmpty)
              ? null
              : Text(subtitle),
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
            labelText: widget.label,
            isDense: true,
            hintText: 'ابحث بالاسم...',
            suffixIcon: widget.selected != null
                ? const Icon(Icons.check_circle, size: 18, color: Colors.green)
                : null,
          ),
          onChanged: _onChanged,
          onTap: () => _filter(_controller.text),
        ),
      ),
    );
  }
}
