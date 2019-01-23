import 'package:flutter/material.dart';

typedef Widget DragWidgetBuilder(BuildContext context, Widget handle);

class DragItem extends StatelessWidget {
  const DragItem({
    @required this.builder,
    @required this.handle,
    @required this.onDragStart,
    @required this.onDragStop,
    @required this.onDragUpdate,
    @required this.onDragTouch,
  });

  final DragWidgetBuilder builder;
  final Widget handle;
  final VoidCallback onDragStart;
  final VoidCallback onDragStop;
  final PointerMoveEventListener onDragUpdate;
  final PointerDownEventListener onDragTouch;

  @override
  Widget build(BuildContext context) {
    final wrappedHandle = Listener(
      child: Listener(
        onPointerCancel: (_) => onDragStop(),
        onPointerUp: (_) => onDragStop(),
        onPointerDown: onDragTouch,
        onPointerMove: onDragUpdate,
        child: GestureDetector(
          onLongPress: onDragStart,
          child: handle,
        ),
      ),
    );
    return builder(context, wrappedHandle);
  }
}
