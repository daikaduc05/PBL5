import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ScreenContainer extends StatelessWidget {
  final Widget child;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final EdgeInsetsGeometry padding;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  const ScreenContainer({
    super.key,
    required this.child,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.appBar,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
