import 'dart:math';
import 'package:flutter/material.dart';

class SnowfallWidget extends StatefulWidget {
  final int numberOfSnowflakes;
  final double minSpeed;
  final double maxSpeed;
  final double minSize;
  final double maxSize;
  final Color snowColor;
  final bool isEnabled;

  const SnowfallWidget({
    super.key,
    this.numberOfSnowflakes = 50,
    this.minSpeed = 1.0,
    this.maxSpeed = 3.0,
    this.minSize = 2.0,
    this.maxSize = 8.0,
    this.snowColor = Colors.white,
    this.isEnabled = true,
  });

  @override
  State<SnowfallWidget> createState() => _SnowfallWidgetState();
}

class _SnowfallWidgetState extends State<SnowfallWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Snowflake> _snowflakes;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _initializeSnowflakes();
    _controller.addListener(_updateSnowflakes);
  }

  void _initializeSnowflakes() {
    _snowflakes = List.generate(
      widget.numberOfSnowflakes,
          (index) => Snowflake(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: widget.minSize +
            _random.nextDouble() * (widget.maxSize - widget.minSize),
        speed: widget.minSpeed +
            _random.nextDouble() * (widget.maxSpeed - widget.minSpeed),
        swingAmplitude: 0.02 + _random.nextDouble() * 0.03,
        swingSpeed: 0.5 + _random.nextDouble() * 1.5,
      ),
    );
  }

  void _updateSnowflakes() {
    if (!widget.isEnabled) return;

    setState(() {
      for (var snowflake in _snowflakes) {
        // Update vertical position
        snowflake.y += snowflake.speed * 0.001;

        // Update horizontal swing
        snowflake.swingOffset += snowflake.swingSpeed * 0.01;
        snowflake.x += sin(snowflake.swingOffset) * snowflake.swingAmplitude * 0.01;

        // Reset snowflake if it falls off screen
        if (snowflake.y > 1.0) {
          snowflake.y = -0.1;
          snowflake.x = _random.nextDouble();
        }

        // Wrap horizontal position
        if (snowflake.x < 0) snowflake.x = 1.0;
        if (snowflake.x > 1.0) snowflake.x = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        painter: SnowfallPainter(
          snowflakes: _snowflakes,
          color: widget.snowColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class Snowflake {
  double x;
  double y;
  final double size;
  final double speed;
  final double swingAmplitude;
  final double swingSpeed;
  double swingOffset;

  Snowflake({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.swingAmplitude,
    required this.swingSpeed,
    this.swingOffset = 0.0,
  });
}

class SnowfallPainter extends CustomPainter {
  final List<Snowflake> snowflakes;
  final Color color;

  SnowfallPainter({
    required this.snowflakes,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var snowflake in snowflakes) {
      final x = snowflake.x * size.width;
      final y = snowflake.y * size.height;

      // Draw snowflake as a circle
      canvas.drawCircle(
        Offset(x, y),
        snowflake.size / 2,
        paint,
      );

      // Optional: Draw a more detailed snowflake shape
      if (snowflake.size > 4) {
        _drawSnowflakeShape(canvas, Offset(x, y), snowflake.size, paint);
      }
    }
  }

  void _drawSnowflakeShape(Canvas canvas, Offset center, double size, Paint paint) {
    final lineLength = size / 2;
    paint.strokeWidth = 1.0;
    paint.style = PaintingStyle.stroke;

    // Draw 6 lines radiating from center (snowflake pattern)
    for (int i = 0; i < 6; i++) {
      final angle = (i * pi / 3);
      final dx = cos(angle) * lineLength;
      final dy = sin(angle) * lineLength;
      canvas.drawLine(
        center,
        Offset(center.dx + dx, center.dy + dy),
        paint,
      );
    }

    paint.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(SnowfallPainter oldDelegate) => true;
}

/// ✅ Color schemes cho different backgrounds
enum SnowColorScheme {
  blueWhite,    // Cho background xám (blue + white)
  purpleWhite,  // Purple tones
  cyanWhite,    // Cyan tones
  pinkWhite,    // Pink tones
  goldWhite,    // Gold/yellow tones
  rainbow,      // Multicolor
  classic,      // Pure white
  redWhite,     // Christmas (red + white)
  christmasCustom, // ✅ Custom Christmas colors (red, green, beige)
}

/// AdvancedSnowfallWidget - Phiên bản nâng cao với nhiều loại hình tuyết
class AdvancedSnowfallWidget extends StatefulWidget {
  final int numberOfSnowflakes;
  final bool isEnabled;
  final SnowColorScheme colorScheme;

  const AdvancedSnowfallWidget({
    super.key,
    this.numberOfSnowflakes = 50,
    this.isEnabled = true,
    this.colorScheme = SnowColorScheme.christmasCustom, // ✅ Default: Red, Green, Beige
  });

  @override
  State<AdvancedSnowfallWidget> createState() => _AdvancedSnowfallWidgetState();
}

class _AdvancedSnowfallWidgetState extends State<AdvancedSnowfallWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<AdvancedSnowflake> _snowflakes;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _initializeSnowflakes();
    _controller.addListener(_updateSnowflakes);
  }

  void _initializeSnowflakes() {
    _snowflakes = List.generate(
      widget.numberOfSnowflakes,
          (index) {
        final shapes = [
          SnowflakeShape.circle,
          SnowflakeShape.star,
          SnowflakeShape.sparkle,
        ];
        return AdvancedSnowflake(
          x: _random.nextDouble(),
          y: _random.nextDouble() * 1.2 - 0.2,
          size: 2.0 + _random.nextDouble() * 6.0,
          speed: 1.0 + _random.nextDouble() * 2.0,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.02,
          shape: shapes[_random.nextInt(shapes.length)],
          opacity: 0.5 + _random.nextDouble() * 0.5,
          sizeMultiplier: 1.0 + _random.nextInt(6).toDouble(), // ✅ Random 1-6
        );
      },
    );
  }

  void _updateSnowflakes() {
    if (!widget.isEnabled) return;

    setState(() {
      for (var snowflake in _snowflakes) {
        snowflake.y += snowflake.speed * 0.001;
        snowflake.rotation += snowflake.rotationSpeed;

        if (snowflake.y > 1.1) {
          snowflake.y = -0.1;
          snowflake.x = _random.nextDouble();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        painter: AdvancedSnowfallPainter(
          snowflakes: _snowflakes,
          colorScheme: widget.colorScheme, // ✅ Pass color scheme
        ),
        size: Size.infinite,
      ),
    );
  }
}

enum SnowflakeShape { circle, star, sparkle }

class AdvancedSnowflake {
  double x;
  double y;
  final double size;
  final double speed;
  double rotation;
  final double rotationSpeed;
  final SnowflakeShape shape;
  final double opacity;
  final double sizeMultiplier; // ✅ Random từ 1-6

  AdvancedSnowflake({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.shape,
    required this.opacity,
    required this.sizeMultiplier,
  });
}

class AdvancedSnowfallPainter extends CustomPainter {
  final List<AdvancedSnowflake> snowflakes;
  final SnowColorScheme colorScheme;

  AdvancedSnowfallPainter({
    required this.snowflakes,
    required this.colorScheme,
  });

  /// ✅ Get colors based on color scheme
  List<Color> _getColors() {
    switch (colorScheme) {
      case SnowColorScheme.blueWhite:
        return [
          Colors.white,
          Colors.blue[50]!,
          Colors.cyan[50]!,
          Colors.lightBlue[100]!,
        ];
      case SnowColorScheme.purpleWhite:
        return [
          Colors.white,
          Colors.purple[50]!,
          Colors.pink[50]!,
          Colors.deepPurple[100]!,
        ];
      case SnowColorScheme.cyanWhite:
        return [
          Colors.white,
          Colors.cyan[50]!,
          Colors.teal[50]!,
          Colors.cyan[100]!,
        ];
      case SnowColorScheme.pinkWhite:
        return [
          Colors.white,
          Colors.pink[50]!,
          Colors.pink[100]!,
          Colors.pinkAccent[100]!,
        ];
      case SnowColorScheme.goldWhite:
        return [
          Colors.white,
          Colors.amber[50]!,
          Colors.yellow[50]!,
          Colors.amber[100]!,
        ];
      case SnowColorScheme.rainbow:
        return [
          Colors.red[100]!,
          Colors.orange[100]!,
          Colors.yellow[100]!,
          Colors.green[100]!,
          Colors.blue[100]!,
          Colors.purple[100]!,
        ];
      case SnowColorScheme.classic:
        return [
          Colors.white,
          Colors.white.withOpacity(0.9),
          Colors.white.withOpacity(0.8),
          Colors.white.withOpacity(0.7),
        ];
      case SnowColorScheme.redWhite:
        return [
          Colors.white,
          Colors.red[100]!,
          Colors.red[200]!,
          Colors.white,
        ];
      case SnowColorScheme.christmasCustom:
      // ✅ Custom colors from user: #8b181d, #325632, #e6be9a + white
        return [
          const Color(0xFF8b181d), // Red (Christmas red)
          const Color(0xFF325632), // Green (Christmas green)
          const Color(0xFFe6be9a), // Beige/Tan
          Colors.white,            // White for contrast
          const Color(0xFF8b181d), // Red again (more red snowflakes)
          Colors.white,            // White again (more white snowflakes)
        ];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final colorOptions = _getColors();

    for (var snowflake in snowflakes) {
      final x = snowflake.x * size.width;
      final y = snowflake.y * size.height;
      final center = Offset(x, y);

      // ✅ Select color based on size multiplier
      final colorIndex = snowflake.sizeMultiplier.toInt() % colorOptions.length;
      final paint = Paint()
        ..color = colorOptions[colorIndex].withOpacity(snowflake.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(snowflake.rotation);
      canvas.translate(-x, -y);

      // ✅ Apply size multiplier
      final finalSize = snowflake.size * snowflake.sizeMultiplier;

      switch (snowflake.shape) {
        case SnowflakeShape.circle:
          canvas.drawCircle(center, finalSize / 2, paint);
          break;
        case SnowflakeShape.star:
          _drawStar(canvas, center, finalSize, paint);
          break;
        case SnowflakeShape.sparkle:
          _drawSparkle(canvas, center, finalSize, paint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final radius = size / 2;

    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * pi / 5) - pi / 2;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      final innerAngle = angle + pi / 5;
      final innerRadius = radius * 0.4;
      final innerX = center.dx + cos(innerAngle) * innerRadius;
      final innerY = center.dy + sin(innerAngle) * innerRadius;
      path.lineTo(innerX, innerY);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint) {
    paint.strokeWidth = 1.5;
    paint.style = PaintingStyle.stroke;

    final length = size / 2;

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - length),
      Offset(center.dx, center.dy + length),
      paint,
    );

    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - length, center.dy),
      Offset(center.dx + length, center.dy),
      paint,
    );

    // Diagonal lines
    final diagonalLength = length * 0.7;
    canvas.drawLine(
      Offset(center.dx - diagonalLength, center.dy - diagonalLength),
      Offset(center.dx + diagonalLength, center.dy + diagonalLength),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - diagonalLength, center.dy + diagonalLength),
      Offset(center.dx + diagonalLength, center.dy - diagonalLength),
      paint,
    );

    paint.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(AdvancedSnowfallPainter oldDelegate) => true;
}