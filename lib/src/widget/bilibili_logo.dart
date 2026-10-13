import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BilibiliLogo extends StatelessWidget {
  const BilibiliLogo({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Bilibili',
      image: true,
      child: SizedBox(
          width: size,
          height: size,
          child: SvgPicture.asset('assets/branding/bilibili.svg',
              fit: BoxFit.contain, excludeFromSemantics: true)));
}
