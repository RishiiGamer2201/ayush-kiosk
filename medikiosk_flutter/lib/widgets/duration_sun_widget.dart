import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DurationOption {
  final String value;
  final String labelHi;
  final String labelEn;
  final String iconEmoji;
  final String serverValue;

  const DurationOption({
    required this.value,
    required this.labelHi,
    required this.labelEn,
    required this.iconEmoji,
    required this.serverValue,
  });
}

const List<DurationOption> durationOptions = [
  DurationOption(
    value: 'today',
    labelHi: 'आज से शुरू हुआ',
    labelEn: 'Started today',
    iconEmoji: '☀️',
    serverValue: 'today',
  ),
  DurationOption(
    value: 'few_days',
    labelHi: '2 - 3 दिन से',
    labelEn: '2 to 3 days',
    iconEmoji: '🌅',
    serverValue: 'three days',
  ),
  DurationOption(
    value: 'one_week',
    labelHi: 'लगभग 1 हफ़्ते से',
    labelEn: 'About 1 week',
    iconEmoji: '📅',
    serverValue: 'one week',
  ),
  DurationOption(
    value: 'one_month',
    labelHi: '1 महीने या ज़्यादा से',
    labelEn: 'Over a month',
    iconEmoji: '🌕',
    serverValue: 'one month',
  ),
];

class DurationSunWidget extends StatelessWidget {
  final String? selectedDuration;
  final ValueChanged<DurationOption> onSelected;

  const DurationSunWidget({
    super.key,
    this.selectedDuration,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isBounded = constraints.hasBoundedHeight;
        final bool canFit = !isBounded || constraints.maxHeight >= 340;

        Widget buildBody() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'यह परेशानी कब से है? (How long have you had this?)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: durationOptions.map((opt) {
                  final isSelected = selectedDuration == opt.value;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 145,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.warningLight
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected ? AppTheme.warningOrange : AppTheme.surfaceBorder,
                          width: isSelected ? 3.0 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.warningOrange.withAlpha(80),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : AppTheme.cardShadow,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            opt.iconEmoji,
                            style: const TextStyle(fontSize: 40),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            opt.labelHi,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            opt.labelEn,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }

        if (canFit) {
          return buildBody();
        } else {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: buildBody(),
          );
        }
      },
    );
  }
}
