import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isSecondary;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController;

  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isInteractive => !widget.isLoading;
  bool get _isActive => _isInteractive && (_isHovered || _isPressed);

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_isInteractive) {
      _isHovered = false;
      _isPressed = false;
    }

    _syncShine();
  }

  void _syncShine() {
    if (_isActive) {
      if (!_shineController.isAnimating) {
        _shineController.repeat();
      }
      return;
    }

    if (_shineController.isAnimating) {
      _shineController.stop();
    }

    if (_shineController.value != 0) {
      _shineController.value = 0;
    }
  }

  void _setHovered(bool value) {
    if (_isHovered == value) {
      return;
    }

    setState(() {
      _isHovered = value;
    });
    _syncShine();
  }

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }

    setState(() {
      _isPressed = value;
    });
    _syncShine();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeStrength = _isPressed
        ? 1.0
        : _isHovered
        ? 0.65
        : 0.0;
    final borderRadius = BorderRadius.circular(12);
    final backgroundColor = widget.isSecondary
        ? Color.lerp(
            AppColors.surface,
            AppColors.primary.withValues(alpha: 0.22),
            activeStrength * 0.65,
          )!
        : Color.lerp(
            AppColors.primary,
            Colors.white,
            0.08 + (activeStrength * 0.16),
          )!;
    final textColor = widget.isSecondary
        ? AppColors.primary
        : AppColors.background;
    final glowColor = widget.isSecondary
        ? AppColors.primary.withValues(alpha: 0.16 + (0.18 * activeStrength))
        : AppColors.primary.withValues(alpha: 0.36 + (0.36 * activeStrength));

    return MouseRegion(
      cursor: _isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _isInteractive ? (_) => _setHovered(true) : null,
      onExit: _isInteractive ? (_) => _setHovered(false) : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 280.0;
          return AnimatedBuilder(
            animation: _shineController,
            builder: (context, child) {
              final shineOffset =
                  (buttonWidth * 2.2 * _shineController.value) -
                  (buttonWidth * 0.8);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: backgroundColor,
                  border: Border.all(
                    color: widget.isSecondary
                        ? AppColors.primary.withValues(
                            alpha: 0.65 + (0.2 * activeStrength),
                          )
                        : Colors.white.withValues(
                            alpha: 0.12 + (0.18 * activeStrength),
                          ),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 14 + (16 * activeStrength),
                      spreadRadius: 1 + (2 * activeStrength),
                      offset: Offset(0, 4 - activeStrength),
                    ),
                    if (!widget.isSecondary)
                      BoxShadow(
                        color: Colors.white.withValues(
                          alpha: 0.04 + (0.08 * activeStrength),
                        ),
                        blurRadius: 22,
                        spreadRadius: activeStrength,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    children: [
                      if (!widget.isSecondary)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: 0.1 + (0.1 * activeStrength),
                                  ),
                                  AppColors.primary.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _isActive ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(
                                            alpha:
                                                0.16 + (0.1 * activeStrength),
                                          ),
                                          Colors.transparent,
                                          AppColors.primary.withValues(
                                            alpha: 0.14 * activeStrength,
                                          ),
                                        ],
                                        stops: const [0.0, 0.35, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: shineOffset - (buttonWidth * 0.18),
                                  top: -18,
                                  bottom: -18,
                                  child: Transform.rotate(
                                    angle: -0.28,
                                    child: Container(
                                      width: buttonWidth * 0.18,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(
                                              alpha:
                                                  0.28 +
                                                  (0.12 * activeStrength),
                                            ),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.25, 0.55, 1.0],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(
                                                  alpha:
                                                      0.24 +
                                                      (0.14 * activeStrength),
                                                ),
                                            blurRadius: 18,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: borderRadius,
                          onTap: _isInteractive ? widget.onPressed : null,
                          onHighlightChanged:
                              _isInteractive ? _setPressed : null,
                          splashColor: AppColors.background.withValues(
                            alpha: widget.isSecondary ? 0.04 : 0.08,
                          ),
                          highlightColor: AppColors.background.withValues(
                            alpha: widget.isSecondary ? 0.02 : 0.06,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            child: Center(
                              child: widget.isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              textColor,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      widget.text.toUpperCase(),
                                      style: AppTypography.buttonText.copyWith(
                                        color: textColor,
                                        shadows: _isActive
                                            ? [
                                                Shadow(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.35),
                                                  blurRadius: 14,
                                                ),
                                              ]
                                            : null,
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
            },
          );
        },
      ),
    );
  }
}
