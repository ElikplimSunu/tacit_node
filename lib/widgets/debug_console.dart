import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/routing_decision.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A semi-transparent debug console overlay that displays real-time
/// routing decisions and system logs with color-coded entries.
class DebugConsole extends StatefulWidget {
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
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  ConsoleSeverity? _filter;

  void _toggleEntryExpansion(int index) {
    setState(() {
      widget.entries[index].isExpanded = !widget.entries[index].isExpanded;
    });
  }

  void _updateFilter(String label) {
    setState(() {
      if (label == 'All') {
        _filter = null;
      } else if (label == 'Routing') {
        _filter = ConsoleSeverity.success;
      } else if (label == 'Warnings') {
        _filter = ConsoleSeverity.warning;
      } else if (label == 'Errors') {
        _filter = ConsoleSeverity.error;
      }
    });
  }

  List<ConsoleEntry> get _filteredEntries {
    if (_filter == null) return widget.entries;
    return widget.entries.where((e) => e.severity == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: widget.isExpanded
              ? 336
              : 136, // +16px to compensate for upward offset
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
                onTap: widget.onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.terminal,
                        color: AppColors.primary,
                        size: 16,
                      ),
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
                        widget.isExpanded
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

              // Filter chips
              if (widget.isExpanded) _buildFilterChips(),

              // Log entries
              Expanded(
                child: _filteredEntries.isEmpty
                    ? Center(
                        child: Text(
                          'Awaiting input…',
                          style: AppTypography.consoleText.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        itemCount: _filteredEntries.length,
                        itemBuilder: (context, index) {
                          final entry = _filteredEntries[index];
                          final originalIndex = widget.entries.indexOf(entry);
                          return _buildConsoleEntry(entry, originalIndex);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          _buildFilterChip('All', _filter == null),
          _buildFilterChip('Routing', _filter == ConsoleSeverity.success),
          _buildFilterChip('Warnings', _filter == ConsoleSeverity.warning),
          _buildFilterChip('Errors', _filter == ConsoleSeverity.error),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: isSelected ? AppColors.primary : AppColors.textMuted,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) => _updateFilter(label),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withOpacity(0.2),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : AppColors.textMuted.withOpacity(0.3),
      ),
    );
  }

  Widget _buildConsoleEntry(ConsoleEntry entry, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: entry.hasMetadata ? () => _toggleEntryExpansion(index) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            color: entry.isExpanded
                ? AppColors.primary.withOpacity(0.1)
                : Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.hasMetadata)
                  Icon(
                    entry.isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTypography.consoleText,
                      children: [
                        TextSpan(
                          text: '[${entry.formattedTime}] ',
                          style: const TextStyle(color: AppColors.textMuted),
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
                ),
              ],
            ),
          ),
        ),
        if (entry.isExpanded && entry.hasMetadata) _buildJsonViewer(entry),
      ],
    );
  }

  Widget _buildJsonViewer(ConsoleEntry entry) {
    final formattedJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(entry.metadata);

    return Container(
      margin: const EdgeInsets.only(left: 20, top: 4, bottom: 4, right: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: SelectableText(
        formattedJson,
        style: AppTypography.consoleText.copyWith(
          fontSize: 11,
          height: 1.5,
          fontFamily: 'monospace',
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
