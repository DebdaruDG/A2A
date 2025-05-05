import 'package:flutter/material.dart';

class DancingDots extends StatefulWidget {
  const DancingDots({super.key});

  @override
  State<DancingDots> createState() => _DancingDotsState();
}

class _DancingDotsState extends State<DancingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _animations = [
      Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
        ),
      ),
      Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
        ),
      ),
      Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '.',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
