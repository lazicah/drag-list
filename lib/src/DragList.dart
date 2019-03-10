import 'dart:math';

import 'package:async/async.dart';
import 'package:drag_list/src/AxisDimen.dart';
import 'package:drag_list/src/DragItem.dart';
import 'package:drag_list/src/DragItemStatus.dart';
import 'package:drag_list/src/DragOverlay.dart';
import 'package:flutter/material.dart';

typedef Widget DragItemBuilder<T>(BuildContext context, T item, Widget handle);
typedef void ItemReorderCallback(int from, int to);

class DragList<T> extends StatefulWidget with AxisDimen {
  final List<T> items;
  final double itemExtent;
  final double handleAlignment;
  final Duration animDuration;
  final Duration dragDelay;
  final WidgetBuilder handleBuilder;
  final DragItemBuilder<T> builder;
  final ItemReorderCallback onItemReorder;
  final Axis scrollDirection;

  DragList({
    @required this.items,
    @required this.itemExtent,
    @required this.builder,
    Duration animDuration,
    Duration dragDelay,
    double handleAlignment,
    Axis scrollDirection,
    this.handleBuilder,
    this.onItemReorder,
  })  : this.animDuration = animDuration ?? Duration(milliseconds: 300),
        this.dragDelay = dragDelay ?? Duration(milliseconds: 500),
        this.handleAlignment = handleAlignment ?? 0.0,
        this.scrollDirection = scrollDirection ?? Axis.vertical {
    assert(this.handleAlignment >= -1.0 && this.handleAlignment <= 1.0,
        'Handle alignment has to be in bounds (-1, 1) inclusive. Passed value was: $handleAlignment.');
  }

  DragList.handleless({
    @required List<T> items,
    @required double itemExtent,
    Widget Function(BuildContext, T) builder,
    Duration animDuration,
    Duration dragDelay,
    double handleAlignment,
    Axis scrollDirection,
    ItemReorderCallback onItemReorder,
  }) : this(
          items: items,
          itemExtent: itemExtent,
          handleAlignment: handleAlignment,
          scrollDirection: scrollDirection,
          animDuration: animDuration,
          dragDelay: dragDelay,
          onItemReorder: onItemReorder,
          handleBuilder: (_) => Container(),
          builder: (context, item, handle) {
            return Stack(children: [
              builder(context, item),
              Positioned.fill(child: handle),
            ]);
          },
        );

  @override
  _DragListState<T> createState() => _DragListState<T>();

  @override
  Axis get axis => scrollDirection;
}

class _DragListState<T> extends State<DragList<T>>
    with SingleTickerProviderStateMixin {
  int _dragIndex;
  int _hoverIndex;
  bool _isDropping;
  double _totalDelta;
  double _dragDelta;
  double _localStart;
  double _itemStart;
  double _lastFrameDelta;
  CancelableOperation _startDragJob;
  OverlayEntry _dragOverlay;
  ScrollController _scrollController;
  Map<int, GlobalKey> _itemKeys;

  AnimationController _animator;
  Animation<double> _baseAnim;
  Animation<double> _deltaAnim;
  Animation<double> _elevAnim;
  Animation<double> _transAnim;

  OverlayState get _overlay => Overlay.of(context);
  RenderBox get _listBox => context.findRenderObject();
  bool get _isDragging => _dragIndex != null;
  bool get _dragsForwards => _dragDelta > 0;
  double get _scrollOffset => _scrollController.offset;
  double get _listMainSize => widget.axisSize(_listBox.size);
  WidgetBuilder get _handleBuilder =>
      widget.handleBuilder ?? _buildDefaultHandle;

  @override
  void initState() {
    super.initState();
    _clearState();
    _itemKeys = {};
    _scrollController = ScrollController();
    _animator = AnimationController(vsync: this, duration: widget.animDuration)
      ..addListener(_onAnimUpdate)
      ..addStatusListener(_onAnimStatus);
    _baseAnim = _animator.drive(CurveTween(curve: Curves.easeInOut));
    _elevAnim = _baseAnim.drive(Tween(begin: 0.0, end: 2.0));
    _dragOverlay = OverlayEntry(builder: _buildOverlay);
  }

  void _onAnimUpdate() {
    final toAdd = _deltaAnim.value - _lastFrameDelta;
    _lastFrameDelta = _deltaAnim.value;
    _updateDelta(toAdd);
  }

  void _onAnimStatus(AnimationStatus status) {
    if (!_animator.isAnimating) {
      _lastFrameDelta = 0.0;
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
      _swapItemKeys(_dragIndex, _hoverIndex);
    }
    _clearState();
    // Jump to current offset to make sure _drag in ScrollableState has been disposed.
    // Happened every time when list view was touched after an item had been dragged.
    _scrollController.jumpTo(_scrollOffset);
  }

  void _swapItemKeys(int from, int to) {
    final sign = from < to ? 1 : -1;
    final temp = _itemKeys[from];
    List.generate((to - from).abs(), (it) => from + it * sign)
        .forEach((it) => _itemKeys[it] = _itemKeys[it + sign]);
    _itemKeys[to] = temp;
  }

  void _defaultOnItemReorder(int from, int to) =>
      widget.items.insert(to, widget.items.removeAt(from));

  void _clearState() {
    _lastFrameDelta = 0.0;
    _totalDelta = 0.0;
    _dragDelta = 0.0;
    _isDropping = false;
    _localStart = null;
    _itemStart = null;
    _dragIndex = null;
    _hoverIndex = null;
    _startDragJob = null;
  }

  Widget _buildOverlay(BuildContext context) {
    return DragOverlay(
      scrollDirection: widget.scrollDirection,
      itemStart: _localStart - _itemStart + _dragDelta,
      listBox: _listBox,
      itemExtent: widget.itemExtent,
      translation: _transAnim.value,
      elevation: _elevAnim.value,
      child: widget.builder(
        context,
        widget.items[_dragIndex],
        _handleBuilder(context),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animator.dispose();
    _clearDragJob();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: _animator.isAnimating ? NeverScrollableScrollPhysics() : null,
      scrollDirection: widget.scrollDirection,
      itemExtent: widget.itemExtent,
      controller: _scrollController,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final itemIndex = _calcItemIndex(index);
        return _buildDragItem(context, itemIndex, index);
      },
    );
  }

  int _calcItemIndex(int index) {
    if (_dragIndex == _hoverIndex) {
      return index;
    }
    if (index == _hoverIndex) {
      return _dragIndex;
    }
    if (index > _hoverIndex && index <= _dragIndex) {
      return index - 1;
    }
    if (index < _hoverIndex && index >= _dragIndex) {
      return index + 1;
    }
    return index;
  }

  Widget _buildDragItem(BuildContext context, int itemIndex, int dispIndex) {
    return DragItem(
      key: _itemKeys.putIfAbsent(itemIndex, () => GlobalKey()),
      handle: _handleBuilder(context),
      builder: (context, handle) =>
          widget.builder(context, widget.items[itemIndex], handle),
      onDragTouch: (event) => _onItemDragTouch(itemIndex, event),
      onDragStop: () => _onItemDragStop(itemIndex),
      onDragUpdate: (details) => _onItemDragUpdate(itemIndex, details),
      extent: widget.itemExtent,
      animDuration: widget.animDuration,
      scrollDirection: widget.scrollDirection,
      status: DragItemStatus(dispIndex, _hoverIndex),
    );
  }

  void _onItemDragTouch(int index, PointerDownEvent event) {
    if (!_isDragging) {
      _registerStartPoint(event.position);
      _scheduleDragStart(index);
    }
  }

  void _registerStartPoint(Offset position) {
    final localPos = _listBox.globalToLocal(position);
    _localStart = widget.axisOffset(localPos);
    _itemStart = (_localStart + _scrollOffset) % widget.itemExtent;
  }

  void _scheduleDragStart(int index) {
    _clearDragJob();
    var cancelled = false;
    final startDrag = Future.delayed(widget.dragDelay, () {
      if (!cancelled) _onItemDragStart(index);
    });
    _startDragJob = CancelableOperation.fromFuture(startDrag,
        onCancel: () => cancelled = true);
  }

  void _onItemDragStart(int index) {
    _clearDragJob();
    _overlay.insert(_dragOverlay);
    setState(() {
      _dragIndex = index;
      _hoverIndex = index;
    });
    _runRaiseAnim();
  }

  void _runRaiseAnim() {
    _transAnim = _baseAnim.drive(Tween(begin: _calcTranslation(), end: 0.0));
    _deltaAnim = _baseAnim.drive(Tween(begin: 0.0, end: _calcRaiseDelta()));
    _animator.forward();
  }

  double _calcRaiseDelta() {
    final itemStartExtent =
        widget.itemExtent * (1 + widget.handleAlignment) / 2;
    return _itemStart - itemStartExtent;
  }

  void _onItemDragStop(int index) {
    _clearDragJob();
    if (_isDragging && !_isDropping) {
      _totalDelta = _calcBoundedDelta(_totalDelta);
      _runDropAnim();
    }
  }

  void _clearDragJob() {
    _startDragJob?.cancel();
    _startDragJob = null;
  }

  void _runDropAnim() {
    _isDropping = true;
    final delta = _calcDropDelta();
    _lastFrameDelta += delta * (1 - _baseAnim.value);
    _deltaAnim = _baseAnim.drive(Tween(begin: delta, end: 0.0));
    final trans = _calcTranslation();
    _transAnim = _baseAnim.drive(Tween(
      begin: trans,
      end: trans * (1 - 1 / _baseAnim.value),
    ));
    _animator.reverse();
  }

  double _calcDropDelta() {
    final rawDelta = (_hoverIndex - _dragIndex) * widget.itemExtent;
    final totalDropDelta =
        _calcBoundedDelta(rawDelta) - (_dragDelta - _lastFrameDelta);
    return totalDropDelta / _baseAnim.value;
  }

  double _calcTranslation() {
    final rawClip = _dragsForwards
        ? 1 -
            ((_scrollOffset + _listMainSize) / widget.itemExtent - _hoverIndex)
        : _scrollOffset / widget.itemExtent - _hoverIndex;
    final clip = max(rawClip - 0.5, 0.0) * (_dragsForwards ? 1 : -1);
    return clip * widget.itemExtent;
  }

  void _onItemDragUpdate(int index, PointerMoveEvent event) {
    if (_startDragJob != null) {
      _registerStartPoint(event.position);
    }
    if (_isDragging && !_isDropping) {
      final delta = widget.axisOffset(event.delta);
      _updateDelta(delta);
      _updateHoverIndex();
    }
  }

  void _updateDelta(double delta) {
    _totalDelta += delta;
    _dragDelta = _calcBoundedDelta(_totalDelta);
    _overlay.setState(() {});
  }

  double _calcBoundedDelta(double delta) {
    final minDelta = -_localStart + _itemStart - widget.itemExtent / 2;
    final maxDelta = minDelta + _listMainSize;
    return min(max(delta, minDelta), maxDelta);
  }

  void _updateHoverIndex() {
    final halfExtent = widget.itemExtent / 2 * (_dragsForwards ? 1 : -1);
    final rawIndex =
        _dragIndex + (_dragDelta + halfExtent) ~/ widget.itemExtent;
    final index = min(max(rawIndex, 0), widget.items.length - 1);
    if (_hoverIndex != index) {
      setState(() => _hoverIndex = index);
    }
  }

  Widget _buildDefaultHandle(_) {
    final size = 24.0;
    final padding = min(max((widget.itemExtent - size) / 2, 0.0), 8.0);
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Icon(Icons.drag_handle, size: size),
    );
  }
}
