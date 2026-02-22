import 'package:flutter/material.dart';
import '../models/routing_decision.dart';

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isExpanded ? 320 : 120,
      decoration: BoxDecoration(
        color: const Color(0xDD1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Colors.amber.withValues(alpha: 0.4), width: 1),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.terminal, color: Colors.amber.shade400, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'DEBUG CONSOLE',
                    style: TextStyle(
                      color: Colors.amber.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.amber.shade400,
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
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                        fontSize: 12,
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
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: '[${entry.formattedTime}] ',
                                style: TextStyle(color: Colors.grey.shade500),
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
    );
  }

  Color _colorForSeverity(ConsoleSeverity severity) {
    return switch (severity) {
      ConsoleSeverity.info => const Color(0xFFB0BEC5),
      ConsoleSeverity.success => const Color(0xFF66BB6A),
      ConsoleSeverity.warning => const Color(0xFFFFCA28),
      ConsoleSeverity.error => const Color(0xFFEF5350),
    };
  }
}
