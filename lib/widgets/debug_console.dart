import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/routing_decision.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A semi-transparent debug console overlay that displays real-time
/// routing decisions and system logs with color-coded entries.
class DebugConsole extends StatelessWidget {
  final List<ConsoleEntry> entries;
  final ScrollController scrollController;
  final bool isExpanded;
  final VoidCallback onToggle;

  const DebugConsole({
    super.key,
    required this.entries,
    required this.scrollController,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: isExpanded ? 320 : 120,
          decoration: BoxDecoration(
            color: const Color(
              0x771A1A2E,
            ), // Glassmorphism translucent background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: const Border(
              top: BorderSide(color: AppColors.primary, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle + title
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.terminal, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'DEBUG CONSOLE',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0x33FFFFFF)),
              // Log entries
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          'Awaiting input…',
                          style: AppTypography.consoleText.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: RichText(
                              text: TextSpan(
                                style: AppTypography.consoleText,
                                children: [
                                  TextSpan(
                                    text: '[${entry.formattedTime}] ',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  TextSpan(
                                    text: entry.message,
                                    style: TextStyle(
                                      color: _colorForSeverity(entry.severity),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForSeverity(ConsoleSeverity severity) {
    return switch (severity) {
      ConsoleSeverity.info => AppColors.textSecondary,
      ConsoleSeverity.success => AppColors.success,
      ConsoleSeverity.warning => AppColors.warning,
      ConsoleSeverity.error => AppColors.error,
    };
  }
}
