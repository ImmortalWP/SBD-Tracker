import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class PRCelebrationModal extends StatefulWidget {
  final String exercise;
  final double weight;
  final int reps;

  const PRCelebrationModal({
    super.key,
    required this.exercise,
    required this.weight,
    required this.reps,
  });

  static void show(BuildContext context, {required String exercise, required double weight, required int reps}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return PRCelebrationModal(exercise: exercise, weight: weight, reps: reps);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.elasticOut.transform(anim1.value) - 1.0;
        return Transform.scale(
          scale: anim1.value > 0 ? 1.0 + (curvedValue * 0.2) : 0.0,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<PRCelebrationModal> createState() => _PRCelebrationModalState();
}

class _PRCelebrationModalState extends State<PRCelebrationModal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.heavyImpact());

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.statYellow.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.statYellow.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) {
                    return Transform.rotate(
                      angle: _controller.value * 2 * pi,
                      child: const Icon(Icons.star, size: 80, color: AppColors.statYellow),
                    );
                  },
                ),
                const Icon(Icons.star, size: 40, color: Colors.white),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'NEW PR!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.statYellow,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.exercise.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.weight.toString().replaceAll('.0', ''),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    ' kg',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('×', style: TextStyle(fontSize: 24, color: AppColors.textMuted)),
                  ),
                  Text(
                    widget.reps.toString(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statYellow,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'AWESOME',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
