// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'liquid_glass.dart';

class LiquidGlassStyle {
  const LiquidGlassStyle({
    required this.tint,
    this.contrast = 0,
    this.blur = 2.5,
    this.haze = 0,
    this.hazeBlur = 0,
    this.refraction = 60,
    this.bevel = 20,
    this.saturation = 1.5,
    this.brightness = 1,
    this.rim = 0.6,
    this.rimWidth = 1.3,
    this.rimTail = 0,
    this.rimFocus = 0,
    this.rimAdded = 0,
    this.endShade = 0,
    this.dispersion = 0,
    this.rimBlur = 0,
    this.hairline = 0,
    this.hairlineSide,
  });

  factory LiquidGlassStyle.regular(ColorScheme colorScheme) {
    final dark = colorScheme.brightness == Brightness.dark;
    return dark
        ? LiquidGlassStyle(
            tint: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
            contrast: -0.4,
            saturation: 2.84,
            rim: 0.28,
            rimWidth: 1.2,
            rimTail: 0.17,
            rimFocus: 1,
            rimAdded: 0.38,
            hairlineSide: 0.75,
          )
        : const LiquidGlassStyle(
            tint: Color(0x8AFDFDFD),
            contrast: 0.4,
            saturation: 2.08,
            rim: 0.28,
            rimWidth: 1.2,
            rimTail: 0.17,
            rimFocus: 1,
            rimAdded: 0.38,
            hairline: 0.25,
            hairlineSide: 0.75,
          );
  }

  factory LiquidGlassStyle.pill(ColorScheme colorScheme) {
    final dark = colorScheme.brightness == Brightness.dark;
    return dark
        ? LiquidGlassStyle(
            tint: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
            contrast: -0.4,
            blur: 0,
            haze: 0.72,
            hazeBlur: 15.6,
            saturation: 1.925,
            rim: 0.35,
          )
        : const LiquidGlassStyle(
            tint: Color(0x93F4F4F4),
            contrast: 0.4,
            blur: 0,
            haze: 0.72,
            hazeBlur: 15.6,
            saturation: 2.1,
            hairline: 0.35,
          );
  }

  /// Thicker than [LiquidGlassStyle.regular], for rows over anything; it takes a [LiquidGlassRim].
  factory LiquidGlassStyle.menu(ColorScheme colorScheme) {
    final dark = colorScheme.brightness == Brightness.dark;
    return dark
        ? LiquidGlassStyle(
            tint: colorScheme.surfaceContainerHighest.withValues(alpha: 0.63),
            contrast: -0.53,
            blur: 12,
            saturation: 1.75,
            brightness: 1.8,
            rim: 0,
          )
        : LiquidGlassStyle(
            tint: colorScheme.surfaceBright.withValues(alpha: 0.55),
            blur: 12,
            saturation: 2,
            brightness: 1.1,
            rim: 0,
          );
  }

  factory LiquidGlassStyle.alert(ColorScheme colorScheme) =>
      LiquidGlassStyle.menu(colorScheme).copyWith(blur: 16);

  factory LiquidGlassStyle.tinted(ColorScheme colorScheme, Color color) {
    final dark = colorScheme.brightness == Brightness.dark;
    return LiquidGlassStyle(
      tint: color.withValues(alpha: 0.82),
      saturation: 1.2,
      rim: dark ? 0.14 : 0.2,
      rimWidth: 1.2,
      rimTail: 0.17,
      rimFocus: 1,
      rimAdded: 0.38,
      hairline: dark ? 0 : 0.34,
      hairlineSide: dark ? 0.73 : 0.5,
    );
  }

  factory LiquidGlassStyle.lens(ColorScheme colorScheme) {
    final dark = colorScheme.brightness == Brightness.dark;
    return LiquidGlassStyle(
      tint: Colors.transparent,
      blur: 0,
      refraction: -4.3,
      bevel: 5.5,
      saturation: 1,
      brightness: dark ? 1.33 : 1,
      rim: dark ? 0.3 : 0.6,
      rimWidth: 1.1,
      endShade: 0.045,
      dispersion: 6.5,
      rimBlur: 1.5,
      hairline: 0.42,
    );
  }

  factory LiquidGlassStyle.lensContent(ColorScheme colorScheme) {
    final dark = colorScheme.brightness == Brightness.dark;
    return LiquidGlassStyle(
      tint: Colors.transparent,
      blur: 0,
      refraction: 14,
      bevel: 11.2,
      saturation: 1,
      brightness: dark ? 1.33 : 1,
      rim: 0,
      dispersion: 3.6,
      rimBlur: 2.5,
    );
  }

  final Color tint;

  final double contrast;
  final double blur;

  final double haze;
  final double hazeBlur;

  final double refraction;
  final double bevel;
  final double saturation;
  final double brightness;

  final double rim;
  final double rimWidth;

  final double rimTail;

  final double rimFocus;

  final double rimAdded;

  final double endShade;
  final double dispersion;

  final double rimBlur;
  final double hairline;
  final double? hairlineSide;

  /// Eases in from bare air, as glass materializes by bending, not fading.
  LiquidGlassStyle scale(double t) {
    final amount = t.clamp(0.0, 1.0);
    return LiquidGlassStyle(
      tint: tint.withValues(alpha: tint.a * amount),
      contrast: contrast * amount,
      blur: blur * amount,
      haze: haze * amount,
      hazeBlur: hazeBlur,
      refraction: refraction * amount,
      bevel: bevel,
      saturation: 1 + (saturation - 1) * amount,
      brightness: 1 + (brightness - 1) * amount,
      rim: rim * amount,
      rimWidth: rimWidth,
      rimTail: rimTail,
      rimFocus: rimFocus,
      rimAdded: rimAdded,
      endShade: endShade * amount,
      dispersion: dispersion * amount,
      rimBlur: rimBlur * amount,
      hairline: hairline * amount,
      hairlineSide: hairlineSide == null ? null : hairlineSide! * amount,
    );
  }

  LiquidGlassStyle copyWith({double? blur}) => LiquidGlassStyle(
    tint: tint,
    contrast: contrast,
    blur: blur ?? this.blur,
    haze: haze,
    hazeBlur: hazeBlur,
    refraction: refraction,
    bevel: bevel,
    saturation: saturation,
    brightness: brightness,
    rim: rim,
    rimWidth: rimWidth,
    rimTail: rimTail,
    rimFocus: rimFocus,
    rimAdded: rimAdded,
    endShade: endShade,
    dispersion: dispersion,
    rimBlur: rimBlur,
    hairline: hairline,
    hairlineSide: hairlineSide,
  );

  static LiquidGlassStyle lerp(
    LiquidGlassStyle a,
    LiquidGlassStyle b,
    double t,
  ) {
    double between(double a, double b) => ui.lerpDouble(a, b, t)!;
    return LiquidGlassStyle(
      tint: Color.lerp(a.tint, b.tint, t)!,
      contrast: between(a.contrast, b.contrast),
      blur: between(a.blur, b.blur),
      haze: between(a.haze, b.haze),
      hazeBlur: between(a.hazeBlur, b.hazeBlur),
      refraction: between(a.refraction, b.refraction),
      bevel: between(a.bevel, b.bevel),
      saturation: between(a.saturation, b.saturation),
      brightness: between(a.brightness, b.brightness),
      rim: between(a.rim, b.rim),
      rimWidth: between(a.rimWidth, b.rimWidth),
      rimTail: between(a.rimTail, b.rimTail),
      rimFocus: between(a.rimFocus, b.rimFocus),
      rimAdded: between(a.rimAdded, b.rimAdded),
      endShade: between(a.endShade, b.endShade),
      dispersion: between(a.dispersion, b.dispersion),
      rimBlur: between(a.rimBlur, b.rimBlur),
      hairline: between(a.hairline, b.hairline),
      hairlineSide: between(a._hairlineSide, b._hairlineSide),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassStyle &&
      other.tint == tint &&
      other.contrast == contrast &&
      other.blur == blur &&
      other.haze == haze &&
      other.hazeBlur == hazeBlur &&
      other.refraction == refraction &&
      other.bevel == bevel &&
      other.saturation == saturation &&
      other.brightness == brightness &&
      other.rim == rim &&
      other.rimWidth == rimWidth &&
      other.rimTail == rimTail &&
      other.rimFocus == rimFocus &&
      other.rimAdded == rimAdded &&
      other.endShade == endShade &&
      other.dispersion == dispersion &&
      other.rimBlur == rimBlur &&
      other.hairline == hairline &&
      other.hairlineSide == hairlineSide;

  @override
  int get hashCode => Object.hash(
    tint,
    contrast,
    blur,
    haze,
    hazeBlur,
    refraction,
    bevel,
    saturation,
    brightness,
    rim,
    rimWidth,
    rimTail,
    rimFocus,
    rimAdded,
    endShade,
    dispersion,
    rimBlur,
    hairline,
    hairlineSide,
  );

  double get _hairlineSide => hairlineSide ?? hairline;

  /// The standard tier's: no colors parted, and a haze for the whole frost.
  LiquidGlassStyle get _standard {
    if (haze == 0 && dispersion == 0) {
      return this;
    }
    return LiquidGlassStyle(
      tint: tint,
      contrast: contrast,
      blur: haze > 0 ? hazeBlur : blur,
      refraction: refraction,
      bevel: bevel,
      saturation: saturation,
      brightness: brightness,
      rim: rim,
      rimWidth: rimWidth,
      rimTail: rimTail,
      rimFocus: rimFocus,
      rimAdded: rimAdded,
      endShade: endShade,
      rimBlur: rimBlur,
      hairline: hairline,
      hairlineSide: hairlineSide,
    );
  }
}

/// An iOS 27 menu's or alert's, measured over white.
List<BoxShadow> glassMenuShadows(ColorScheme colorScheme, [double depth = 1]) {
  final strength = colorScheme.brightness == Brightness.dark ? 1.5 : 1.0;
  final alpha = strength * depth;
  return [
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.09 * alpha),
      blurRadius: 16.5,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.045 * alpha),
      blurRadius: 42,
      offset: const Offset(0, 8),
    ),
  ];
}

Color glassFillOf(ColorScheme colorScheme) =>
    (colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)
        .withValues(alpha: 0.13);

/// iOS 27's rim around a menu's or an alert's glass (.agents/architecture.md).
@immutable
class LiquidGlassRim {
  const LiquidGlassRim({
    required this.side,
    required this.corner,
    required this.flat,
    required this.shine,
  });

  factory LiquidGlassRim.alert(ColorScheme colorScheme) =>
      colorScheme.brightness == Brightness.dark
      ? const LiquidGlassRim(side: 0.75, corner: 0.1, flat: 0.03, shine: 0.22)
      : const LiquidGlassRim(side: 0.35, corner: 0.22, flat: 0.12, shine: 0.16);

  factory LiquidGlassRim.menu(ColorScheme colorScheme) =>
      colorScheme.brightness == Brightness.dark
      ? const LiquidGlassRim(side: 0.27, corner: 0.1, flat: 0.02, shine: 0.22)
      : const LiquidGlassRim(side: 0.25, corner: 0.15, flat: 0.09, shine: 0.16);

  final double side;
  final double corner;
  final double flat;

  /// Added light, not white laid over: iOS lifts dark and light panes alike.
  final double shine;

  LiquidGlassRim scale(double t) {
    final amount = t.clamp(0.0, 1.0);
    return LiquidGlassRim(
      side: side * amount,
      corner: corner * amount,
      flat: flat * amount,
      shine: shine * amount,
    );
  }

  /// The line, outside the pane; the pane given this rim draws the highlight.
  void paintLine(Canvas canvas, Rect rect, double radius) {
    if (rect.isEmpty) {
      return;
    }
    final round = _roundOf(rect.size, radius);
    final shape = AppRadius.all(round).toRSuperellipse(rect);
    final across = math.min(round / rect.width, 0.4);
    Color dark(double alpha) => Colors.black.withValues(alpha: alpha);
    canvas.drawRSuperellipse(
      shape.inflate(_hairlineWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _hairlineWidth
        ..shader = LinearGradient(
          colors: [
            dark(side),
            dark(corner),
            dark(flat),
            dark(flat),
            dark(corner),
            dark(side),
          ],
          stops: [0, across / 4, across, 1 - across, 1 - across / 4, 1],
        ).createShader(rect),
    );
  }

  static double _roundOf(Size size, double radius) =>
      math.min(math.max(0.0, radius), size.shortestSide / 2);

  List<double> _uniforms(Size size, double radius) {
    final turns = _turns(size, _roundOf(size, radius));
    final ends = [for (final band in _shineBands) band.depth + band.width];
    return [
      for (final (turn, _) in turns) turn,
      for (final (_, lit) in turns) shine * lit,
      for (var index = 0; index < _shineSlots; index++)
        ends[math.min(index, ends.length - 1)],
      for (var index = 0; index < _shineSlots; index++)
        index < _shineBands.length ? _shineBands[index].lit : 0.0,
    ];
  }

  void _paintShine(Canvas canvas, Rect rect, double radius) {
    final round = _roundOf(rect.size, radius);
    final shape = AppRadius.all(round).toRSuperellipse(rect);
    final around = _sweepStops(rect.size, round);
    final stops = [for (final (stop, _) in around) stop];
    for (final band in _shineBands) {
      final alpha = shine * band.lit;
      // A ring, not a stroke: Impeller widens a stroke thinner than a pixel.
      canvas.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRSuperellipse(shape.deflate(band.depth))
          ..addRSuperellipse(shape.deflate(band.depth + band.width)),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = SweepGradient(
            colors: [
              for (final (_, lit) in around)
                Colors.white.withValues(alpha: math.min(alpha * lit, 1)),
            ],
            stops: stops,
          ).createShader(rect),
      );
    }
  }

  static List<(double, double)> _turns(Size size, double round) {
    final halfWidth = size.width / 2;
    final halfHeight = size.height / 2;
    final turns = [(0.0, 1.0)];
    for (final (:along, :down, :lit) in _shineAround) {
      final turn = math.atan2(
        halfWidth - math.min(along * round, halfWidth),
        halfHeight - math.min(down * round, halfHeight),
      );
      turns.add((math.max(turns.last.$1, turn), lit));
    }
    turns.add((math.pi / 2, 0));
    return turns;
  }

  static List<(double, double)> _sweepStops(Size size, double round) {
    final turns = _turns(size, round);
    const full = 2 * math.pi;
    return [
      for (final (turn, lit) in turns.reversed)
        ((math.pi / 2 - turn) / full, lit),
      for (final (turn, lit) in turns.skip(1))
        ((math.pi / 2 + turn) / full, lit),
      for (final (turn, lit) in turns.reversed.skip(1))
        ((math.pi * 1.5 - turn) / full, lit),
      for (final (turn, lit) in turns.skip(1))
        ((math.pi * 1.5 + turn) / full, lit),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassRim &&
      other.side == side &&
      other.corner == corner &&
      other.flat == flat &&
      other.shine == shine;

  @override
  int get hashCode => Object.hash(side, corner, flat, shine);
}

/// Light a press casts on a pane: [strength] at [center], falling off to [wash] over [reach].
@immutable
class LiquidGlassGlow {
  const LiquidGlassGlow({
    required this.center,
    required this.reach,
    required this.strength,
    this.wash = 0,
  });

  static const none = LiquidGlassGlow(
    center: Offset.zero,
    reach: 1,
    strength: 0,
  );

  final Offset center;
  final double reach;
  final double strength;
  final double wash;

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassGlow &&
      other.center == center &&
      other.reach == reach &&
      other.strength == strength &&
      other.wash == wash;

  @override
  int get hashCode => Object.hash(center, reach, strength, wash);
}
