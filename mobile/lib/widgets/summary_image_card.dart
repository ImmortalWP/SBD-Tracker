import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SummaryImageGenerator {
  static Future<void> shareSummaryImage(BuildContext context, Map<String, dynamic> prs, int totalSessions) async {
    final screenshotController = ScreenshotController();
    
    final squat = prs['Squat'] ?? 0;
    final bench = prs['Bench'] ?? 0;
    final deadlift = prs['Deadlift'] ?? 0;
    final total = (squat + bench + deadlift).toDouble();
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final image = await screenshotController.captureFromWidget(
        Material(
          type: MaterialType.transparency,
          child: Container(
            width: 1080,
            height: 1920, // 9:16 aspect ratio for IG stories
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.bg950, AppTheme.bg850],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: const EdgeInsets.all(80),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.fitness_center, size: 120, color: AppColors.accentBlueLight),
                const SizedBox(height: 40),
                const Text(
                  'SBD TRACKER',
                  style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 8),
                ),
                const SizedBox(height: 120),
                _buildLiftRow('SQUAT', squat.toString()),
                const SizedBox(height: 60),
                _buildLiftRow('BENCH', bench.toString()),
                const SizedBox(height: 60),
                _buildLiftRow('DEADLIFT', deadlift.toString()),
                const SizedBox(height: 100),
                const Divider(color: AppColors.borderColor, thickness: 4),
                const SizedBox(height: 100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: AppColors.statYellow)),
                    Text('\${total.toString().replaceAll(".0", "")} KG', style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: AppColors.statYellow)),
                  ],
                ),
                const SizedBox(height: 160),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: AppColors.borderColor, width: 4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month, size: 60, color: AppColors.textSecondary),
                      const SizedBox(width: 40),
                      Text(
                        '\$totalSessions SESSIONS LOGGED',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 1.0,
      );

      final dir = await getTemporaryDirectory();
      final file = File('\${dir.path}/sbd_summary.png');
      await file.writeAsBytes(image);

      if (context.mounted) Navigator.pop(context); // Close loading

      await Share.shareXFiles([XFile(file.path)], text: 'Check out my powerlifting progress!');
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate image: \$e')));
      }
    }
  }

  static Widget _buildLiftRow(String label, String weight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 4)),
        Text('\${weight.replaceAll(".0", "")} KG', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: Colors.white)),
      ],

    );
  }
}
