import 'package:drag_list/src/DragItemStatus.dart';
import 'package:flutter/material.dart';

typedef Widget DragWidgetBuilder(BuildContext context, Widget handle);

class DragItem extends StatefulWidget {
  DragItem({
    @required Key key,
    @required this.builder,
    @required this.handle,
    @required this.onDragStart,
    @required this.onDragStop,
    @required this.onDragUpdate,
    @required this.onDragTouch,
    @required this.extent,
    @required this.status,
    @required this.animDuration,
  }) : super(key: key);

  final DragWidgetBuilder builder;
  final Widget handle;
  final VoidCallback onDragStart;
  final VoidCallback onDragStop;
  final PointerMoveEventListener onDragUpdate;
  final PointerDownEventListener onDragTouch;
  final double extent;
  final DragItemStatus status;
  final Duration animDuration;

  @override
  DragItemState createState() => DragItemState();
}

class DragItemState extends State<DragItem>
    with SingleTickerProviderStateMixin {
  AnimationController _animator;
  Animation<double> _transAnim;
  DragItemStatus _status;
  DragItemStatus _prevStatus;

  @override
  void initState() {
    super.initState();
    _status = DragItemStatus.SETTLED;
    _animator = AnimationController(
      vsync: this,
      value: 1.0,
      duration: widget.animDuration,
    );
    _transAnim = _animator.drive(Tween(begin: 0.0, end: 0.0));
  }

  @override
  void dispose() {
    _animator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateStatus();
    if (_hasBeenHovered) {
      _updateTransAnim();
    }
    return _buildWidget();
  }

  void _updateStatus() {
    _prevStatus = _status;
    _status = widget.status;
  }

  bool get _hasBeenHovered =>
      (_prevStatus == DragItemStatus.BELOW &&
          _status == DragItemStatus.ABOVE) ||
      (_prevStatus == DragItemStatus.ABOVE && _status == DragItemStatus.BELOW);

  void _updateTransAnim() {
    final trans = widget.extent * (_status == DragItemStatus.ABOVE ? 1 : -1);
    _transAnim = _animator.drive(Tween(begin: trans, end: 0.0));
    _animator.forward(from: 1 - _animator.value);
  }

  Widget _buildWidget() {
    final handle = _wrapHandle();
    final item = widget.builder(context, handle);
    return _wrapItem(item);
  }

  Widget _wrapHandle() {
    return Listener(
      child: Listener(
        onPointerCancel: (_) => widget.onDragStop(),
        onPointerUp: (_) => widget.onDragStop(),
        onPointerDown: widget.onDragTouch,
        onPointerMove: widget.onDragUpdate,
        child: GestureDetector(
          onLongPress: widget.onDragStart,
          child: widget.handle,
        ),
      ),
    );
  }

  Widget _wrapItem(Widget itemWidget) {
    return Opacity(
      opacity: _status == DragItemStatus.HOVER ? 0.0 : 1.0,
      child: AbsorbPointer(
        absorbing: _status == DragItemStatus.HOVER,
        child: AnimatedBuilder(
          animation: _transAnim,
          child: itemWidget,
          builder: (_, child) => Transform.translate(
                offset: Offset(0.0, _transAnim.value),
                child: child,
              ),
        ),
      ),
    );
  }
}
