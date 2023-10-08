import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerComponent extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerComponent({
    Key? key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor != null ? baseColor! : Theme.of(context).scaffoldBackgroundColor,
      highlightColor: highlightColor != null ? highlightColor! : Colors.grey.shade900,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: Colors.grey.shade800,
        ),
        child: child,
      ),
    );
  }
}
