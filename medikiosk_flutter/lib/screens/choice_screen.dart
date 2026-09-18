import 'package:flutter/material.dart';
import '../widgets/option_icon.dart';
import '../widgets/tactile_button.dart';

class ChoiceScreen extends StatefulWidget {
  const ChoiceScreen({
    super.key,
    required this.headline,
    required this.options,
    required this.onChoose,
    this.progress,
    this.onBack,
    this.onRepeat,
    this.selectedValue,
  });

  final String headline;
  final List<Map<String, dynamic>> options;
  final void Function(String value) onChoose;
  final List<int>? progress;
  final VoidCallback? onBack;
  final VoidCallback? onRepeat;
  final String? selectedValue;

  @override
  State<ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<ChoiceScreen> {
  final TextEditingController _typed = TextEditingController();
  final bool _typing = false;
  String? _typeError;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _submitTyped() {
    final entry = _typed.text.trim().toLowerCase();
    if (entry.isEmpty) return;

    final index = int.tryParse(entry);
    if (index != null && index >= 1 && index <= widget.options.length) {
      _choose(widget.options[index - 1]);
      return;
    }

    for (final option in widget.options) {
      final label = (option['label'] as String? ?? '').toLowerCase();
      final value = (option['value'] as String? ?? '').toLowerCase();
      if (label == entry || value == entry || label.startsWith(entry)) {
        _choose(option);
        return;
      }
    }

    setState(() => _typeError = 'विकल्पों में से कोई एक चुनें (Choose an option above)');
  }

  void _choose(Map<String, dynamic> option) {
    widget.onChoose(option['value'] as String? ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.options.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Question Headline Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Row(
                children: [
                  if (widget.progress != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.progress![0]}/${widget.progress![1]}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.headline,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onRepeat != null)
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF0284C7)),
                      onPressed: widget.onRepeat,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Clamped Options Grid (Strictly zero scrolling)
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final crossCount = (box.maxWidth > 550 && count > 2) ? 2 : 1;
                  final rows = (count / crossCount).ceil();
                  final double spacing = 10.0;
                  final double itemHeight = (box.maxHeight - (rows - 1) * spacing) / rows;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      mainAxisExtent: itemHeight > 55 ? itemHeight : 65,
                    ),
                    itemCount: count,
                    itemBuilder: (context, idx) {
                      final opt = widget.options[idx];
                      final val = '${opt['value']}';
                      final isSelected = widget.selectedValue == val;

                      return TactileButton(
                        onPressed: () => _choose(opt),
                        isSelected: isSelected,
                        height: itemHeight > 55 ? itemHeight : 65,
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          children: [
                            if (opt['icon'] is String && (opt['icon'] as String).isNotEmpty) ...[
                              OptionIcon(name: opt['icon'] as String, index: idx),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                '${idx + 1}. ${opt['label'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Typed entry expander
            if (_typing) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _typed,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'विकल्प नंबर या नाम लिखें (Type number or text)',
                        errorText: _typeError,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (_) => _submitTyped(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TactileButton(
                    onPressed: _submitTyped,
                    height: 48,
                    borderRadius: BorderRadius.circular(12),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
