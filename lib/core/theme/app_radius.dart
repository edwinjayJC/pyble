import 'package:flutter/material.dart';

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;

  static const Radius circularSm = Radius.circular(sm);
  static const Radius circularMd = Radius.circular(md);
  static const Radius circularLg = Radius.circular(lg);

  static const BorderRadius allSm = BorderRadius.all(circularSm);
  static const BorderRadius allMd = BorderRadius.all(circularMd);
  static const BorderRadius allLg = BorderRadius.all(circularLg);
}
