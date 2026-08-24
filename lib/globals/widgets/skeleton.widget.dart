import 'package:flutter/material.dart';

/// Color de relleno de un hueco que todavía no tiene contenido.
///
/// Sale de la superficie del tema y no de un gris fijo para que el esqueleto
/// se vea igual de discreto en claro que en oscuro.
Color skeletonBaseColor(ThemeData theme) {
  final colors = theme.colorScheme;
  final velo = theme.brightness == Brightness.dark
      ? Colors.white.withOpacity(0.07)
      : Colors.black.withOpacity(0.07);
  return Color.alphaBlend(velo, colors.surface);
}

Color _skeletonHighlightColor(ThemeData theme) {
  final colors = theme.colorScheme;
  final velo = theme.brightness == Brightness.dark
      ? Colors.white.withOpacity(0.15)
      : Colors.black.withOpacity(0.02);
  return Color.alphaBlend(velo, colors.surface);
}

/// Recuadro gris que ocupa el lugar de un texto o una imagen en camino.
///
/// Pensado para usarse dentro de un [SkeletonShimmer], que es quien le da el
/// brillo. Suelto también funciona: se queda quieto.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  const SkeletonBox.circular(double diametro, {super.key})
      : width = diametro,
        height = diametro,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Opaco a propósito: el barrido del shimmer pinta sobre el alfa del
        // hijo, y con cajas semitransparentes el brillo casi no se nota.
        color: skeletonBaseColor(Theme.of(context)),
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Pasa un brillo por encima de todo su subárbol.
///
/// Sin paquetes externos y con un solo [AnimationController] para todo el
/// bloque: una tanda de esqueletos cuesta una animación, no una por caja.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  bool _animacionesReducidas = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se consulta aquí y no en `build` porque un controller repitiendo pide un
    // frame nuevo cada 16 ms aunque nadie lo mire.
    final reducidas = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducidas == _animacionesReducidas && _controller.isAnimating) return;
    _animacionesReducidas = reducidas;
    if (reducidas) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animacionesReducidas) return widget.child;

    final theme = Theme.of(context);
    final base = skeletonBaseColor(theme);
    final brillo = _skeletonHighlightColor(theme);

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // De -0.3 a 1.3 para que el brillo entre y salga fuera de cuadro.
        final avance = _controller.value * 1.6 - 0.3;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, brillo, base],
            stops: [
              (avance - 0.25).clamp(0.0, 1.0),
              avance.clamp(0.0, 1.0),
              (avance + 0.25).clamp(0.0, 1.0),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
