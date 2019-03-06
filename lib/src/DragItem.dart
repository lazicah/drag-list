import 'package:drag_list/src/DragItemStatus.dart';
import 'package:flutter/material.dart';

typedef Widget DragWidgetBuilder(BuildContext context, Widget handle);

class DragItem extends StatefulWidget {
  DragItem({
    @required Key key,
    @required this.builder,
    @required this.handle,
    @required this.onDragStop,
    @required this.onDragUpdate,
    @required this.onDragTouch,
    @required this.extent,
    @required this.status,
    @required this.animDuration,
    @required this.scrollDirection,
  }) : super(key: key);

  final DragWidgetBuilder builder;
  final Widget handle;
  final VoidCallback onDragStop;
  final PointerMoveEventListener onDragUpdate;
  final PointerDownEventListener onDragTouch;
  final double extent;
  final DragItemStatus status;
  final Duration animDuration;
  final Axis scrollDirection;

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
      (_prevStatus == DragItemStatus.AFTER &&
          _status == DragItemStatus.BEFORE) ||
      (_prevStatus == DragItemStatus.BEFORE && _status == DragItemStatus.AFTER);

  void _updateTransAnim() {
    final trans = widget.extent * (_status == DragItemStatus.BEFORE ? 1 : -1);
    _transAnim = Tween(begin: trans, end: 0.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_animator);
    _animator.forward(from: 1 - _animator.value);
  }

  Widget _buildWidget() {
    return Opacity(
      opacity: _status == DragItemStatus.HOVER ? 0.0 : 1.0,
      child: AbsorbPointer(
        absorbing: _status == DragItemStatus.HOVER,
        child: AnimatedBuilder(
          animation: _transAnim,
          child: widget.builder(context, _wrapHandle()),
          builder: (_, child) => Transform.translate(
                offset: widget.scrollDirection == Axis.vertical
                    ? Offset(0.0, _transAnim.value)
                    : Offset(_transAnim.value, 0.0),
                child: child,
              ),
        ),
      ),
    );
  }

  Widget _wrapHandle() {
    return Listener(
      onPointerCancel: (_) => widget.onDragStop(),
      onPointerUp: (_) => widget.onDragStop(),
      onPointerDown: widget.onDragTouch,
      onPointerMove: widget.onDragUpdate,
      child: widget.handle,
    );
  }
}
