import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paintroid/tool/tool.dart';

import '../state/canvas_dirty_state.dart';
import '../state/canvas_state_notifier.dart';
import '../state/workspace_state_notifier.dart';
import 'canvas_painter.dart';

class DrawingCanvas extends ConsumerStatefulWidget {
  const DrawingCanvas({Key? key}) : super(key: key);

  @override
  ConsumerState<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends ConsumerState<DrawingCanvas> {
  final _transformationController = TransformationController();
  var _pointersOnScreen = 0;
  var _isZooming = false;

  void _resetCanvasScale({bool fitToScreen = false}) {
    final box = context.findRenderObject() as RenderBox;
    final widgetCenterOffset = Alignment.center.alongSize(box.size);
    final scale = fitToScreen ? 1.0 : 0.85;
    final scaledMatrix = _transformationController.value.clone()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale);
    _transformationController.value = scaledMatrix;
    final scaleAdjustedCenterOffset =
        _transformationController.toScene(widgetCenterOffset) -
            widgetCenterOffset;
    final centeredMatrix = _transformationController.value.clone()
      ..translate(scaleAdjustedCenterOffset.dx, scaleAdjustedCenterOffset.dy);
    _transformationController.value = centeredMatrix;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetCanvasScale());
  }

  @override
  void didUpdateWidget(covariant DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetCanvasScale();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      WorkspaceState.provider.select((value) => value.isFullscreen),
      (wasFullscreen, isFullscreen) {
        _resetCanvasScale(fitToScreen: isFullscreen);
      },
    );
    final toolStateNotifier = ref.watch(ToolState.provider.notifier);
    final canvasStateNotifier = ref.watch(CanvasState.provider.notifier);
    final canvasDirtyNotifier = ref.watch(CanvasDirtyState.provider.notifier);
    final canvasSize = ref.watch(CanvasState.provider).size;
    final panningMargin = (canvasSize - const Offset(5, 5)) as Size;
    return Listener(
      onPointerDown: (_) {
        _pointersOnScreen++;
        if (_pointersOnScreen >= 2) {
          _isZooming = true;
          toolStateNotifier.didSwitchToZooming();
        }
      },
      onPointerUp: (_) {
        _pointersOnScreen--;
        if ( _isZooming && _pointersOnScreen == 0) _isZooming = false;
      },
      child: InteractiveViewer(
        clipBehavior: Clip.none,
        transformationController: _transformationController,
        boundaryMargin: EdgeInsets.symmetric(
          horizontal: panningMargin.width,
          vertical: panningMargin.height,
        ),
        minScale: 0.2,
        maxScale: 6.9,
        panEnabled: false,
        onInteractionStart: (details) {
          if (!_isZooming) {
            final transformedLocalPoint = _transformationController.toScene(
              details.localFocalPoint,
            );
            toolStateNotifier.didTapDown(transformedLocalPoint);
          }
        },
        onInteractionUpdate: (details) {
          if (!_isZooming) {
            final transformedLocalPoint = _transformationController.toScene(
              details.localFocalPoint,
            );
            toolStateNotifier.didDrag(transformedLocalPoint);
            canvasDirtyNotifier.repaint();
          }
        },
        onInteractionEnd: (details) {
          if (!_isZooming) {
            toolStateNotifier.didTapUp();
            canvasStateNotifier.updateCachedImage();
          }
        },
        child: SizedBox.fromSize(
          size: canvasSize,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(BorderSide(width: 0.5)),
            ),
            position: DecorationPosition.foreground,
            child: CanvasPainter(),
          ),
        ),
      ),
    );
  }
}
