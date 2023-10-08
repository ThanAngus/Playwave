import 'package:flutter/material.dart';
import 'package:playwave/utils/style.dart';

class DividerComponent extends StatelessWidget {
  const DividerComponent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.white.withOpacity(0.1),
    );
  }
}
