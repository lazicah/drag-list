import 'package:drag_list/src/DragItem.dart';
import 'package:flutter/material.dart';

typedef Widget DragItemBuilder<T>(BuildContext context, T item, Widget handle);
typedef void ItemReorderCallback(int from, int to);

class DragList<T> extends StatefulWidget {
  const DragList({
    @required this.items,
    @required this.handleBuilder,
    @required this.builder,
    @required this.itemExtent,
    @required this.onItemReorder,
  });

  final List<T> items;
  final WidgetBuilder handleBuilder;
  final DragItemBuilder<T> builder;
  final double itemExtent;
  final ItemReorderCallback onItemReorder;

  @override
  _DragListState<T> createState() => _DragListState<T>();
}

class _DragListState<T> extends State<DragList<T>>
    with SingleTickerProviderStateMixin {
  int _dragIndex;
  int _hoverIndex;
  double _totalDelta;
  double _delta;
  double _globalStart;
  double _localStart;
  double _itemStart;
  double _lastAnimDelta;
  OverlayEntry _dragOverlay;
  ScrollController _scrollController;

  AnimationController _animator;
  Animation<double> _deltaAnim;
  Animation<double> _elevAnim;

  OverlayState get _overlay => Overlay.of(context);
  double get _itemHalfExtent => widget.itemExtent / 2;
  RenderBox get _listBox => context.findRenderObject();

  @override
  void initState() {
    super.initState();
    _clearState();
    _scrollController = ScrollController();
    _animator = _createAnimator(Duration(milliseconds: 300));
    _elevAnim = _animator.drive(Tween(begin: 0.0, end: 4.0));
    _dragOverlay = OverlayEntry(builder: _buildOverlay);
  }

  AnimationController _createAnimator(Duration duration) {
    return AnimationController(vsync: this, duration: duration)
      ..addListener(_onAnimDelta)
      ..addStatusListener(_onDragAnimEnd);
  }

  void _onAnimDelta() {
    final toAdd = _deltaAnim.value - _lastAnimDelta;
    _lastAnimDelta = _deltaAnim.value;
    _updateDelta(toAdd);
  }

  Widget _buildOverlay(BuildContext context) {
    final dragWidget = widget.builder(
      context,
      widget.items[_dragIndex],
      widget.handleBuilder(context),
    );
    return Positioned(
      left: 0.0,
      top: _globalStart - _itemStart + _delta,
      right: 0.0,
      child: Material(elevation: _elevAnim.value, child: dragWidget),
    );
  }

  void _clearState() {
    _lastAnimDelta = 0.0;
    _totalDelta = 0.0;
    _delta = 0.0;
    _globalStart = null;
    _localStart = null;
    _itemStart = null;
    _dragIndex = null;
    _hoverIndex = null;
  }

  void _updateDelta(double delta) {
    final oldDelta = _delta;
    _totalDelta += delta;
    _delta = _calcBoundedDelta(_totalDelta);
    if (oldDelta.toInt() != _delta.toInt()) {
      _overlay.setState(() {});
    }
  }

  double _calcBoundedDelta(double delta) {
    final minDelta = -_localStart + _itemHalfExtent;
    final maxDelta = _listBox.size.height - _localStart - _itemHalfExtent;
    return delta < minDelta ? minDelta : delta > maxDelta ? maxDelta : delta;
  }

  void _onDragAnimEnd(AnimationStatus status) {
    _lastAnimDelta = 0.0;
    if (_animator.isDismissed) {
      _dragOverlay.remove();
      if (_dragIndex != _hoverIndex) {
        widget.onItemReorder(_dragIndex, _hoverIndex);
      }
      setState(_clearState);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemExtent: widget.itemExtent,
        controller: _scrollController,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final itemIndex = _calcItemIndex(index);
          final itemWidget = _buildDragItem(context, itemIndex);
          return index == _hoverIndex
              ? Container(
                  color: Colors.grey,
                  child: AbsorbPointer(child: itemWidget),
                )
              : itemWidget;
        });
  }

  int _calcItemIndex(int index) {
    if (_dragIndex == _hoverIndex) {
      return index;
    }
    if (index > _hoverIndex && index <= _dragIndex) {
      return index - 1;
    }
    if (index < _hoverIndex && index >= _dragIndex) {
      return index + 1;
    }
    return index;
  }

  Widget _buildDragItem(BuildContext context, int index) {
    return DragItem(
      handle: widget.handleBuilder(context),
      builder: (context, handle) =>
          widget.builder(context, widget.items[index], handle),
      onDragStart: () => _onItemDragStart(index),
      onDragStop: () => _onItemDragStop(index),
      onDragUpdate: (details) => _onItemDragUpdate(index, details),
      onDragTouch: (event) => _onItemDragTouch(index, event),
    );
  }

  void _onItemDragStart(int index) {
    if (_dragIndex == null) {
      _overlay.insert(_dragOverlay);
      _runStartAnim();
      setState(() {
        _dragIndex = index;
        _hoverIndex = index;
      });
    }
  }

  void _runStartAnim() {
    final end = _itemStart - _itemHalfExtent;
    _deltaAnim = _animator.drive(Tween(begin: 0.0, end: end));
    _animator.forward();
  }

  void _onItemDragStop(int index) {
    if (_dragIndex != null) {
      _runStopAnim();
    }
  }

  void _runStopAnim() {
    final begin = (_hoverIndex - _dragIndex) * widget.itemExtent - _delta;
    _deltaAnim = _animator.drive(Tween(begin: begin, end: 0.0));
    _animator.reverse();
  }

  void _onItemDragUpdate(int index, PointerMoveEvent details) {
    _updateDelta(details.delta.dy);
    _updateHoverIndex();
  }

  void _updateHoverIndex() {
    if (_dragIndex != null) {
      final halfExtent = _delta > 0 ? _itemHalfExtent : -_itemHalfExtent;
      final index = _dragIndex + (_delta + halfExtent) ~/ widget.itemExtent;
      if (_hoverIndex != index) {
        setState(() => _hoverIndex = index);
      }
    }
  }

  void _onItemDragTouch(int index, PointerDownEvent event) {
    _globalStart = event.position.dy;
    _localStart = _listBox.globalToLocal(event.position).dy;
    _itemStart = (_localStart + _scrollController.offset) % widget.itemExtent;
  }
}
