import 'package:flutter/material.dart';

class PaymentJarWidget extends StatefulWidget {
  final List<Widget> balls;
  final double width;
  final double height;

  const PaymentJarWidget({
    super.key,
    required this.balls,
    this.width = 200,
    this.height = 300,
  });

  @override
  State<PaymentJarWidget> createState() => _PaymentJarWidgetState();
}

class _PaymentJarWidgetState extends State<PaymentJarWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    _animationControllers = List.generate(
      widget.balls.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 800 + (index * 200)),
        vsync: this,
      ),
    );

    _scaleAnimations =
        _animationControllers
            .map(
              (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: controller, curve: Curves.elasticOut),
              ),
            )
            .toList();

    _slideAnimations =
        _animationControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Tween<Offset>(
            begin: Offset(0, -2.0 - (index * 0.3)),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: controller, curve: Curves.bounceOut),
          );
        }).toList();
  }

  void _startAnimations() {
    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _animationControllers[i].forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(PaymentJarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balls.length != widget.balls.length) {
      _disposeAnimations();
      _initAnimations();
      _startAnimations();
    }
  }

  void _disposeAnimations() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Offset> positions = [
      const Offset(0.50, 0.82), // 1. Giữa đáy
      const Offset(0.32, 0.78), // 2. Trái đáy
      const Offset(0.68, 0.78), // 3. Phải đáy
      const Offset(0.22, 0.68), // 4. Trái giữa thấp
      const Offset(0.78, 0.68), // 5. Phải giữa thấp
      const Offset(0.38, 0.58), // 6. Trái giữa cao
      const Offset(0.62, 0.58), // 7. Phải giữa cao
      const Offset(0.50, 0.48), // 8. Giữa cao
      const Offset(0.28, 0.42), // 9. Trái rất cao
      const Offset(0.72, 0.42), // 10. Phải rất cao
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration:
          isDark
              ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              )
              : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Hình ảnh lọ làm nền
            Positioned.fill(
              child: Image.asset(
                'lib/assets/image.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                color: isDark ? Colors.white.withOpacity(0.8) : null,
                colorBlendMode: isDark ? BlendMode.modulate : null,
              ),
            ),
            // Các quả bóng nằm trong lọ với hiệu ứng animation
            ...List.generate(widget.balls.length, (i) {
              if (i >= positions.length || i >= _animationControllers.length) {
                return const SizedBox.shrink();
              }
              final pos = positions[i];
              return AnimatedBuilder(
                animation: _animationControllers[i],
                builder: (context, child) {
                  return Positioned(
                    left: pos.dx * widget.width - 30,
                    top: pos.dy * widget.height - 30,
                    child: SlideTransition(
                      position: _slideAnimations[i],
                      child: ScaleTransition(
                        scale: _scaleAnimations[i],
                        child: Transform.scale(
                          scale: 1.2,
                          child: widget.balls[i],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
