import 'package:flutter/material.dart';
import '../models/board.dart';
import '../models/hour_prediction.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/mac_address_formatter.dart';
import 'status_block.dart';

String boardDisplayName(Board board, [String? name]) {
  name ??= board.name;
  return (name != null && name.isNotEmpty) ? name : MacAddressFormatter.format(board.boardMac);
}

/// One place on the home list: name and status on one line, count and usual range under it.
class BoardCard extends StatefulWidget {
  final Board board;
  /// Null means offline.
  final double? current;
  final HourPrediction? prediction;
  final VoidCallback onTap;

  const BoardCard({
    super.key,
    required this.board,
    required this.current,
    required this.prediction,
    required this.onTap,
  });

  @override
  State<BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<BoardCard> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final offline = widget.current == null;
    final status = statusInfo(widget.current, widget.prediction);

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        boardDisplayName(widget.board),
                        style: heading(18).copyWith(color: offline ? Palette.muted : Palette.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusTag(info: status, offline: offline),
                  ],
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: ApiService.isAdmin,
                  builder: (context, isAdmin, _) {
                    final firmware = isAdmin ? widget.board.firmwareVersion : null;
                    if (status.captions.isEmpty && firmware == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(status.captions.join(', '), style: archivo(14, color: Palette.muted)),
                          ),
                          if (firmware != null) Text('v$firmware', style: archivo(12, color: Palette.muted)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
