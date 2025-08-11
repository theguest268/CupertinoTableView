import 'package:flutter/cupertino.dart';

class CupertinoTableViewCell extends StatefulWidget {
  const CupertinoTableViewCell({
    super.key,
    required this.builder,
    this.pressedOpacity,
    this.hitBehavior,
    this.onTap,
    this.pressedColor = const Color(0x00000000),
  });

  final WidgetBuilder builder;
  final HitTestBehavior? hitBehavior;
  final VoidCallback? onTap;
  final double? pressedOpacity;
  final Color pressedColor;

  @override
  State<CupertinoTableViewCell> createState() => _CupertinoTableViewCellState();
}

class _CupertinoTableViewCellState extends State<CupertinoTableViewCell> with TickerProviderStateMixin {
  static const Duration _fadeOutDuration = Duration(milliseconds: 120);
  static const Duration _fadeInDuration = Duration(milliseconds: 180);

  final Tween<double> _opacityTween = Tween<double>(begin: 1.0);

  AnimationController? _opacityController;
  Animation<double>? _opacityAnimation;

  AnimationController? _colorController;
  Animation<Color?>? _colorAnimation;

  bool _cellHeldDown = false;
  bool _enablePressedAnimation = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void didUpdateWidget(covariant CupertinoTableViewCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onTap != widget.onTap) {
      _initAnimations();
    }
  }

  void _initAnimations() {
    final pressedOpacity = widget.pressedOpacity ?? 0.0;
    _enablePressedAnimation = widget.onTap != null && (pressedOpacity) < 1 && (pressedOpacity) > 0;

    if (_enablePressedAnimation) {
      _opacityTween.end = pressedOpacity;
      if (_opacityController == null) {
        _opacityController = AnimationController(
          duration: const Duration(milliseconds: 200),
          value: 0.0,
          vsync: this,
        );
        _opacityAnimation = _opacityController!.drive(CurveTween(curve: Curves.decelerate)).drive(_opacityTween);
      }

      if (_colorController == null) {
        _colorController = AnimationController(
          duration: const Duration(milliseconds: 150),
          vsync: this,
        );
        _colorAnimation = ColorTween(
          begin: const Color(0x00000000),
          end: widget.pressedColor,
        ).animate(_colorController!);
      }
    }
  }

  void _handleTapDown(TapDownDetails _) {
    if (!_cellHeldDown) {
      _cellHeldDown = true;
      _animateOpacity();
      _animateColor();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_cellHeldDown) {
      _cellHeldDown = false;
      _animateOpacity();
      _animateColor();
    }
  }

  void _handleTapCancel() {
    if (_cellHeldDown) {
      _cellHeldDown = false;
      _animateOpacity();
      _animateColor();
    }
  }

  void _animateOpacity() {
    if ((_opacityController?.isAnimating ?? true) || !_enablePressedAnimation) return;
    final wasHeldDown = _cellHeldDown;
    final TickerFuture ticker = _cellHeldDown
        ? _opacityController!.animateTo(1.0, duration: _fadeOutDuration, curve: Curves.easeInOutCubicEmphasized)
        : _opacityController!.animateTo(0.0, duration: _fadeInDuration, curve: Curves.easeOutCubic);
    ticker.then<void>((_) {
      if (mounted && wasHeldDown != _cellHeldDown) {
        _animateOpacity();
      }
    });
  }

  void _animateColor() {
    if (_colorController == null || !_enablePressedAnimation) return;
    if (_cellHeldDown) {
      _colorController!.forward();
    } else {
      _colorController!.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) {
      return widget.builder(context);
    }
    return GestureDetector(
      behavior: widget.hitBehavior ?? HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: _enablePressedAnimation ? _handleTapDown : null,
      onTapUp: _enablePressedAnimation ? _handleTapUp : null,
      onTapCancel: _enablePressedAnimation ? _handleTapCancel : null,
      child: _enablePressedAnimation && _opacityAnimation != null
          ? AnimatedBuilder(
              animation: Listenable.merge([_colorAnimation, _opacityAnimation]),
              builder: (_, child) => Container(
                color: _colorAnimation?.value,
                child: Opacity(opacity: _opacityAnimation!.value, child: child),
              ),
              child: widget.builder(context),
            )
          : widget.builder(context),
    );
  }

  @override
  void dispose() {
    _opacityController?.dispose();
    _colorController?.dispose();
    super.dispose();
  }
}
