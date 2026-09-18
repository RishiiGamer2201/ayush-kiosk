import 'package:flutter/material.dart';

/// Tactile 3D Push Button inspired by physical arcade/kiosk buttons.
/// Provides physical depression animation (translateY + reduced shadow),
/// high contrast colors, tactile feel, and STRICT zero-overflow guarantees via FittedBox.
class TactileButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? label;
  final String? subtitle;
  final Widget? icon;
  final String? imageAsset;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double height;
  final double? width;
  final bool isSelected;
  final bool isDestructive;
  final bool isSuccess;
  final BorderRadius? borderRadius;

  const TactileButton({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.subtitle,
    this.icon,
    this.imageAsset,
    this.backgroundColor = Colors.white,
    this.foregroundColor = const Color(0xFF0F172A),
    this.borderColor = const Color(0xFFCBD5E1),
    this.shadowColor = const Color(0xFF94A3B8),
    this.height = 76,
    this.width,
    this.isSelected = false,
    this.isDestructive = false,
    this.isSuccess = false,
    this.borderRadius,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final r = widget.borderRadius ?? BorderRadius.circular(20);

    Color bg = widget.backgroundColor;
    Color fg = widget.foregroundColor;
    Color border = widget.borderColor;
    Color shadow = widget.shadowColor;

    if (!enabled) {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF94A3B8);
      border = const Color(0xFFE2E8F0);
      shadow = const Color(0xFFCBD5E1);
    } else if (widget.isSelected) {
      bg = const Color(0xFF0D9488); // Lovable Primary Teal
      fg = Colors.white;
      border = const Color(0xFF0F766E);
      shadow = const Color(0xFF115E59);
    } else if (widget.isSuccess) {
      bg = const Color(0xFF16A34A);
      fg = Colors.white;
      border = const Color(0xFF15803D);
      shadow = const Color(0xFF166534);
    } else if (widget.isDestructive) {
      bg = const Color(0xFFDC2626);
      fg = Colors.white;
      border = const Color(0xFFB91C1C);
      shadow = const Color(0xFF991B1B);
    }

    final double offsetY = _isPressed ? 4.0 : 0.0;
    final double shadowHeight = _isPressed ? 1.0 : 5.0;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: offsetY, bottom: 4.0 - offsetY),
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: r,
          border: Border.all(color: border, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: shadow,
              offset: Offset(0, shadowHeight),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: widget.child ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.imageAsset != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          widget.imageAsset!,
                          width: (widget.height - 24) * 0.75,
                          height: (widget.height - 24) * 0.75,
                          fit: BoxFit.contain,
                          cacheWidth: 160,
                          cacheHeight: 160,
                          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ] else if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 10),
                    ],
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.label != null)
                          Text(
                            widget.label!,
                            style: TextStyle(
                              fontSize: widget.height > 80 ? 20 : 16,
                              fontWeight: FontWeight.w800,
                              color: fg,
                              letterSpacing: -0.2,
                            ),
                            textAlign: TextAlign.center,
                            // The FittedBox above already guarantees the label cannot overflow:
                            // it shrinks to fit. Ellipsis on top of that only threw the text
                            // away - "Measure heart rate" reached the tablet as "measure hea..."
                            // in every language whose word for it is long.
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                          ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: fg.withAlpha(200),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ],
                    ),
                    if (widget.isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                    ],
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
