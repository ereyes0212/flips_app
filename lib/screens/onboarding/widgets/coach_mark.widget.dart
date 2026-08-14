import 'package:flutter/material.dart';

/// Forma del recorte que deja ver el elemento resaltado.
enum CoachMarkShape { circle, rounded }

/// Un paso del tour guiado.
///
/// Si [targetKey] es `null` (o el widget no está montado) el paso se muestra
/// como tarjeta centrada, sin recorte: útil para el mensaje de cierre.
class CoachMarkStep {
  const CoachMarkStep({
    required this.title,
    required this.description,
    this.icon,
    this.targetKey,
    this.focusResolver,
    this.shape = CoachMarkShape.circle,
    this.spotlightPadding = 10,
    this.bullets = const <String>[],
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final String title;
  final String description;
  final IconData? icon;

  /// Widget real de la interfaz que se va a resaltar.
  final GlobalKey? targetKey;

  /// Ajusta el área a resaltar a partir del rectángulo del [targetKey].
  ///
  /// Sirve para apuntar a una porción de un widget que no expone claves
  /// individuales (por ejemplo, un ícono dentro de la barra inferior).
  final Rect Function(Rect anchor)? focusResolver;

  final CoachMarkShape shape;
  final double spotlightPadding;

  /// Viñetas opcionales para pasos con más contexto (ej. beneficios del plan).
  final List<String> bullets;

  /// Acción destacada del paso. Al ejecutarla se cierra el tour.
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
}

/// Muestra el tour guiado sobre la pantalla actual.
///
/// Devuelve cuando el usuario termina o salta el recorrido.
Future<void> showCoachMarks(
  BuildContext context,
  List<CoachMarkStep> steps,
) {
  if (steps.isEmpty) return Future<void>.value();

  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: animation,
        child: _CoachMarkView(steps: steps),
      ),
    ),
  );
}

class _CoachMarkView extends StatefulWidget {
  const _CoachMarkView({required this.steps});

  final List<CoachMarkStep> steps;

  @override
  State<_CoachMarkView> createState() => _CoachMarkViewState();
}

class _CoachMarkViewState extends State<_CoachMarkView> {
  static const double _cardMargin = 16;
  static const double _caretSize = 12;
  static const double _gap = 14;

  int _index = 0;

  CoachMarkStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  void _next() {
    if (_isLast) {
      _close();
      return;
    }
    setState(() => _index++);
  }

  void _close() => Navigator.of(context).maybePop();

  void _runPrimaryAction() {
    final action = _step.onPrimaryAction;
    _close();
    action?.call();
  }

  /// Rectángulo global del elemento resaltado, o `null` si no está disponible.
  Rect? _resolveTargetRect() {
    final key = _step.targetKey;
    if (key == null) return null;

    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final offset = renderObject.localToGlobal(Offset.zero);
    final anchor = offset & renderObject.size;
    final focus = _step.focusResolver?.call(anchor) ?? anchor;

    final padded = focus.inflate(_step.spotlightPadding);
    if (_step.shape != CoachMarkShape.circle) return padded;

    // Un recorte circular se ve mejor sobre un área cuadrada.
    final side = padded.longestSide;
    return Rect.fromCenter(center: padded.center, width: side, height: side);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final screen = media.size;
    final target = _resolveTargetRect();

    // La tarjeta se coloca del lado con más espacio libre para no tapar el
    // elemento que se está explicando.
    final placeBelow = target == null || target.center.dy < screen.height / 2;

    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: '${_step.title}. ${_step.description}',
        // El foco se desplaza suavemente entre pasos. Cuando el paso no tiene
        // objetivo se dibuja directo: interpolar hacia "sin recorte" haría
        // encoger el foco hacia la esquina superior izquierda.
        child: target == null
            ? _buildStack(context, theme, media, screen, null, placeBelow)
            : TweenAnimationBuilder<Rect?>(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                tween: RectTween(begin: target, end: target),
                builder: (context, animatedRect, _) => _buildStack(
                  context,
                  theme,
                  media,
                  screen,
                  animatedRect ?? target,
                  placeBelow,
                ),
              ),
      ),
    );
  }

  Widget _buildStack(
    BuildContext context,
    ThemeData theme,
    MediaQueryData media,
    Size screen,
    Rect? hole,
    bool placeBelow,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _next,
            child: CustomPaint(
              painter: _SpotlightPainter(
                hole: hole,
                shape: _step.shape,
                scrimColor: const Color(0xFF06132B).withOpacity(0.86),
                ringColor: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
        if (hole != null)
          Positioned(
            left: hole.center.dx - _caretSize,
            top: placeBelow
                ? hole.bottom + _gap - _caretSize + 1
                : hole.top - _gap - 1,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(_caretSize * 2, _caretSize),
                painter: _CaretPainter(
                  color: theme.colorScheme.surface,
                  pointsUp: placeBelow,
                ),
              ),
            ),
          ),
        if (hole == null)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _cardMargin),
              child: Center(child: _buildCard(context, media)),
            ),
          )
        else
          Positioned(
            left: _cardMargin,
            right: _cardMargin,
            top: placeBelow ? hole.bottom + _gap : null,
            bottom: placeBelow ? null : screen.height - hole.top + _gap,
            child: _buildCard(context, media),
          ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, MediaQueryData media) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.6),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        elevation: 8,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_step.icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _step.icon,
                        size: 20,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _step.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${_index + 1} de ${widget.steps.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _step.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withOpacity(0.82),
                  height: 1.35,
                ),
              ),
              if (_step.bullets.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._step.bullets.map(
                  (bullet) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: colors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bullet,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  _StepDots(count: widget.steps.length, current: _index),
                  const Spacer(),
                  if (!_isLast)
                    TextButton(
                      onPressed: _close,
                      child: const Text('Saltar'),
                    ),
                  const SizedBox(width: 4),
                  if (_step.primaryActionLabel != null)
                    ElevatedButton(
                      onPressed: _runPrimaryAction,
                      child: Text(_step.primaryActionLabel!),
                    )
                  else
                    ElevatedButton(
                      onPressed: _next,
                      child: Text(_isLast ? 'Entendido' : 'Siguiente'),
                    ),
                ],
              ),
              if (_isLast && _step.primaryActionLabel != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _close,
                    child: const Text('Finalizar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final active = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          height: 6,
          width: active ? 18 : 6,
          decoration: BoxDecoration(
            color: active ? colors.primary : colors.outlineVariant,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.hole,
    required this.shape,
    required this.scrimColor,
    required this.ringColor,
  });

  final Rect? hole;
  final CoachMarkShape shape;
  final Color scrimColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    final target = hole;

    if (target == null) {
      canvas.drawPath(scrim, Paint()..color = scrimColor);
      return;
    }

    final radius = shape == CoachMarkShape.circle
        ? target.shortestSide / 2
        : 16.0;
    final holeRRect = RRect.fromRectAndRadius(target, Radius.circular(radius));

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        scrim,
        Path()..addRRect(holeRRect),
      ),
      Paint()..color = scrimColor,
    );

    canvas.drawRRect(
      holeRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ringColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.shape != shape ||
      oldDelegate.scrimColor != scrimColor ||
      oldDelegate.ringColor != ringColor;
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter({required this.color, required this.pointsUp});

  final Color color;
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..lineTo(0, 0);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointsUp != pointsUp;
}
