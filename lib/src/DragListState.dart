import 'dart:async';
import 'dart:math';

import 'package:async/async.dart';
import 'package:drag_list/src/DragItem.dart';
import 'package:drag_list/src/DragItemStatus.dart';
import 'package:drag_list/src/DragList.dart';
import 'package:drag_list/src/DragOverlay.dart';
import 'package:flutter/material.dart';

class DragListState<T> extends State<DragList<T>>
    with SingleTickerProviderStateMixin {
  int _dragIndex;
  int _hoverIndex;
  bool _isDropping;
  bool _isDragging;
  double _totalDelta;
  double _dragDelta;
  double _localStart;
  double _itemStart;
  double _lastFrameDelta;
  double _touchScroll;
  Offset _startPoint;
  Offset _touchPoint;
  CancelableOperation _startDragJob;
  StreamSubscription _overdragSub;
  OverlayEntry _dragOverlay;
  ScrollController _scrollController;
  ScrollController _innerController;
  Map<int, GlobalKey> _itemKeys;

  AnimationController _animator;
  Animation<double> _baseAnim;
  Animation<double> _deltaAnim;
  Animation<double> _elevAnim;
  Animation<double> _transAnim;

  OverlayState get _overlay => Overlay.of(context);
  RenderBox get _listBox => context.findRenderObject();
  bool get _isDragSettled => _dragIndex == null;
  bool get _dragsForwards => _dragDelta > 0;
  double get _scrollOffset => _scrollController.offset;
  double get _listSize => widget.axisSize(_listBox.size);
  double get _itemStartExtent =>
      widget.itemExtent * (1 + widget.handleAlignment) / 2;
  WidgetBuilder get _handleBuilder =>
      widget.handleBuilder ?? _buildDefaultHandle;

  @override
  void didUpdateWidget(DragList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateScrollController();
  }

  @override
  void initState() {
    super.initState();
    _innerController = ScrollController();
    _updateScrollController();
    _clearState();
    _itemKeys = {};
    _animator = AnimationController(vsync: this, duration: widget.animDuration)
      ..addListener(_onAnimUpdate)
      ..addStatusListener(_onAnimStatus);
    _baseAnim = _animator.drive(CurveTween(curve: Curves.easeInOut));
    _elevAnim = _baseAnim.drive(Tween(begin: 0.0, end: 2.0));
    _dragOverlay = OverlayEntry(builder: _buildOverlay);
  }

  void _updateScrollController() {
    _scrollController = widget.controller ?? _innerController;
  }

  void _onAnimUpdate() {
    final toAdd = _deltaAnim.value - _lastFrameDelta;
    _lastFrameDelta = _deltaAnim.value;
    _onDeltaChanged(toAdd);
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
    _touchScroll = 0.0;
    _isDropping = false;
    _isDragging = false;
    _localStart = null;
    _itemStart = null;
    _dragIndex = null;
    _hoverIndex = null;
    _startDragJob = null;
    _startPoint = null;
    _touchPoint = null;
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
    _innerController.dispose();
    _animator.dispose();
    _clearDragJob();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: _isDragSettled ? widget.physics : NeverScrollableScrollPhysics(),
      padding: widget.padding,
      scrollDirection: widget.scrollDirection,
      shrinkWrap: widget.shrinkWrap,
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
      onDragTouch: (position) => _onItemDragTouch(itemIndex, position),
      onDragStop: (position) => _onItemDragStop(itemIndex, position),
      onDragUpdate: (delta) => _onItemDragUpdate(itemIndex, delta),
      extent: widget.itemExtent,
      animDuration: widget.animDuration,
      scrollDirection: widget.scrollDirection,
      status: DragItemStatus(dispIndex, _hoverIndex),
    );
  }

  void _onItemDragTouch(int index, Offset position) {
    if (_isDragSettled) {
      _touchPoint = position;
      _startPoint = position;
      _touchScroll = _scrollOffset;
      _scheduleDragStart(index);
    }
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
    _isDragging = true;
    _clearDragJob();
    _registerStartPoint(_touchPoint);
    _overlay.insert(_dragOverlay);
    setState(() {
      _dragIndex = index;
      _hoverIndex = index;
    });
    _runRaiseAnim();
  }

  void _registerStartPoint(Offset position) {
    final localPos = _listBox.globalToLocal(position);
    _localStart = widget.axisOffset(localPos) + _touchScroll - _scrollOffset;
    _itemStart = (_localStart + _scrollOffset) % widget.itemExtent;
  }

  void _runRaiseAnim() {
    _transAnim = _baseAnim.drive(Tween(begin: _calcTranslation(), end: 0.0));
    _deltaAnim = _baseAnim.drive(Tween(begin: 0.0, end: _calcRaiseDelta()));
    _animator.forward();
  }

  double _calcRaiseDelta() {
    final startDrag = widget.axisOffset(_startPoint - _touchPoint) +
        _scrollOffset -
        _touchScroll;
    return _itemStart - _itemStartExtent + startDrag;
  }

  void _onItemDragStop(int index, Offset position) {
    _isDragging = false;
    _clearDragJob();
    _stopOverdrag();
    if (!_isDragSettled && !_isDropping) {
      _totalDelta = _calcBoundedDelta(_totalDelta);
      final localPos = _listBox.globalToLocal(position);
      _runDropAnim(localPos);
    }
  }

  void _clearDragJob() {
    _startDragJob?.cancel();
    _startDragJob = null;
  }

  void _runDropAnim(Offset stopOffset) {
    _isDropping = true;
    final delta = _calcDropDelta(stopOffset);
    _lastFrameDelta += delta * (1 - _baseAnim.value);
    _deltaAnim = _baseAnim.drive(Tween(begin: delta, end: 0.0));
    final trans = _calcTranslation();
    _transAnim = _baseAnim.drive(Tween(
      begin: trans,
      end: trans * (1 - 1 / _baseAnim.value),
    ));
    _animator.reverse();
  }

  double _calcDropDelta(Offset stopOffset) {
    final rawPos = widget.axisOffset(stopOffset);
    final halfItemStart = widget.itemExtent * widget.handleAlignment / 2;
    final stopPos = rawPos.clamp(halfItemStart, _listSize + halfItemStart);
    final hoverStartPos = _hoverIndex * widget.itemExtent - _scrollOffset;
    return -(stopPos - hoverStartPos - _itemStartExtent);
  }

  double _calcTranslation() {
    final rawClip = _dragsForwards
        ? 1 - ((_scrollOffset + _listSize) / widget.itemExtent - _hoverIndex)
        : _scrollOffset / widget.itemExtent - _hoverIndex;
    final clip = max(rawClip - 0.5, 0.0) * (_dragsForwards ? 1 : -1);
    return clip * widget.itemExtent;
  }

  void _onItemDragUpdate(int index, Offset delta) {
    if (_startDragJob != null) {
      _startPoint += delta;
      final startDrag = widget.axisOffset(_startPoint - _touchPoint).abs();
      if (startDrag > widget.itemExtent / 2) {
        _clearDragJob();
      }
    }
    if (!_isDragSettled && !_isDropping) {
      _onDeltaChanged(widget.axisOffset(delta));
    }
  }

  void _onDeltaChanged(double delta) {
    _updateDelta(delta);
    _updateHoverIndex();
    _updateScrollIfBeyond();
  }

  void _updateScrollIfBeyond() {
    final localDragDelta = _localStart + _dragDelta;
    final isDraggedBeyond = localDragDelta < widget.itemExtent / 2 ||
        localDragDelta > _listSize - widget.itemExtent / 2;
    if (_isDragging && isDraggedBeyond) {
      _overdragSub ??= Stream.periodic(Duration(milliseconds: 50))
          .listen((_) => _onOverdragUpdate());
    } else if (!isDraggedBeyond && _overdragSub != null) {
      _stopOverdrag();
    }
  }

  void _onOverdragUpdate() {
    final canScrollMore = _dragsForwards
        ? _scrollOffset < widget.items.length * widget.itemExtent - _listSize
        : _scrollOffset > 0;
    if (canScrollMore) {
      final newOffset = _scrollOffset + 2.0 * (_dragsForwards ? 1 : -1);
      _scrollController.jumpTo(newOffset);
    } else {
      _stopOverdrag();
    }
  }

  void _stopOverdrag() {
    _overdragSub?.cancel();
    _overdragSub = null;
  }

  void _updateDelta(double delta) {
    _totalDelta += delta;
    _dragDelta = _calcBoundedDelta(_totalDelta);
    _overlay.setState(() {});
  }

  double _calcBoundedDelta(double delta) {
    final minDelta = -_localStart + _itemStart - widget.itemExtent / 2;
    final maxDelta = minDelta + _listSize;
    return delta.clamp(minDelta, maxDelta);
  }

  void _updateHoverIndex() {
    final halfExtent = widget.itemExtent / 2 * (_dragsForwards ? 1 : -1);
    final rawIndex =
        _dragIndex + (_dragDelta + halfExtent) ~/ widget.itemExtent;
    final index = rawIndex.clamp(0, widget.items.length - 1);
    if (_hoverIndex != index) {
      setState(() => _hoverIndex = index);
    }
  }

  Widget _buildDefaultHandle(_) {
    final size = 24.0;
    final padding = (widget.itemExtent - size).clamp(0.0, 8.0);
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Icon(Icons.drag_handle, size: size),
    );
  }
}
