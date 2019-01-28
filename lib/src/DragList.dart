import 'dart:math';

import 'package:drag_list/src/DragItem.dart';
import 'package:flutter/material.dart';

typedef Widget DragItemBuilder<T>(BuildContext context, T item, Widget handle);
typedef void ItemReorderCallback(int from, int to);

class DragList<T> extends StatefulWidget {
  DragList({
    @required this.items,
    @required this.itemExtent,
    @required this.handleBuilder,
    @required this.builder,
    this.handleAlignment = 0.0,
    this.onItemReorder,
  }) : assert(handleAlignment >= -1.0 && handleAlignment <= 1.0,
            'Handle alignment has to be in bounds (-1, 1) inclusive. Passed value was: $handleAlignment.');

  final List<T> items;
  final double itemExtent;
  final double handleAlignment;
  final WidgetBuilder handleBuilder;
  final DragItemBuilder<T> builder;
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
  Animation<double> _transAnim;

  OverlayState get _overlay => Overlay.of(context);
  RenderBox get _listBox => context.findRenderObject();
  bool get _isDragging => _dragIndex != null;
  double get _scrollOffset => _scrollController.offset;
  bool get _dragsUpwards => _delta < 0;

  @override
  void initState() {
    super.initState();
    _clearState();
    _scrollController = ScrollController();
    _animator = _createAnimator(Duration(milliseconds: 1000));
    _elevAnim = _animator.drive(Tween(begin: 0.0, end: 2.0));
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

  void _onDragAnimEnd(AnimationStatus status) {
    if (!_animator.isAnimating) {
      _lastAnimDelta = 0.0;
      if (_animator.isDismissed) {
        _onDragSettled();
      }
    }
    setState(() {});
  }

  void _onDragSettled() {
    _dragOverlay.remove();
    if (_dragIndex != _hoverIndex) {
      (widget.onItemReorder ?? _defaultOnItemReorder)
          .call(_dragIndex, _hoverIndex);
    }
    _clearState();
  }

  void _defaultOnItemReorder(int from, int to) =>
      widget.items.insert(to, widget.items.removeAt(from));

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

  Widget _buildOverlay(BuildContext context) {
    final top = _listBox.localToGlobal(Offset.zero).dy;
    return Positioned(
      top: top,
      height: _listBox.size.height,
      left: 0.0,
      right: 0.0,
      child: ClipRect(
        child: Stack(children: [
          Positioned(
            top: _globalStart + _delta - _itemStart - top,
            height: widget.itemExtent,
            left: _listBox.localToGlobal(Offset.zero).dx,
            width: _listBox.size.width,
            child: Transform.translate(
              offset: Offset(0.0, _transAnim.value),
              child: Material(
                elevation: _elevAnim.value,
                child: widget.builder(
                  context,
                  widget.items[_dragIndex],
                  widget.handleBuilder(context),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
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
        physics: _animator.isAnimating ? NeverScrollableScrollPhysics() : null,
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
    if (!_isDragging) {
      _overlay.insert(_dragOverlay);
      _runStartAnim();
      setState(() {
        _dragIndex = index;
        _hoverIndex = index;
      });
    }
  }

  void _runStartAnim() {
    final transEnd = 0.0;
    _transAnim = _animator.drive(Tween(begin: 0.0, end: transEnd));
    final deltaEnd = _itemStart - _calcItemTopExtent();
    _deltaAnim = _animator.drive(Tween(begin: 0.0, end: deltaEnd));
    _animator.forward();
  }

  double _calcItemTopExtent() =>
      widget.itemExtent * (1 + widget.handleAlignment) / 2;

  void _onItemDragStop(int index) {
    if (_isDragging) {
      _runStopAnim();
    }
  }

  void _runStopAnim() {
    final transBegin =
        _calcHoverItemClip() * widget.itemExtent * (_dragsUpwards ? -1 : 1);
    _transAnim = _animator.drive(Tween(begin: transBegin, end: 0.0));
    final deltaBegin = (_hoverIndex - _dragIndex) * widget.itemExtent - _delta;
    _deltaAnim = _animator.drive(Tween(begin: deltaBegin, end: 0.0));
    _animator.reverse();
  }

  double _calcHoverItemClip() {
    final toClip = _dragsUpwards
        ? _scrollOffset / widget.itemExtent - _hoverIndex
        : 1 -
            ((_scrollOffset + _listBox.size.height) / widget.itemExtent -
                _hoverIndex);
    return max(toClip, 0.0);
  }

  void _onItemDragUpdate(int index, PointerMoveEvent details) {
    if (_isDragging) {
      _updateDelta(details.delta.dy);
      _updateHoverIndex();
    }
  }

  void _updateDelta(double delta) {
    _totalDelta += delta;
    _delta = _calcBoundedDelta(_totalDelta);
    _overlay.setState(() {});
  }

  double _calcBoundedDelta(double delta) {
    final minDelta = _itemStart - _localStart;
    final maxDelta = minDelta + _listBox.size.height - widget.itemExtent;
    return delta < minDelta ? minDelta : delta > maxDelta ? maxDelta : delta;
  }

  void _updateHoverIndex() {
    final halfExtent = widget.itemExtent / 2;
    final itemExtent = _dragsUpwards ? -halfExtent : halfExtent;
    final index = _dragIndex + (_delta + itemExtent) ~/ widget.itemExtent;
    if (_hoverIndex != index) {
      setState(() => _hoverIndex = index);
    }
  }

  void _onItemDragTouch(int index, PointerDownEvent event) {
    _globalStart = event.position.dy;
    _localStart = _listBox.globalToLocal(event.position).dy;
    _itemStart = (_localStart + _scrollOffset) % widget.itemExtent;
  }
}
