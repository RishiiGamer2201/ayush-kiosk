import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme/app_theme.dart';

class FaceScore {
  final int score;
  final String labelEn;
  /// The same label in each language the kiosk offers, keyed by code. English is labelEn.
  final Map<String, String> labels;
  final Color color;
  final String emoji;

  const FaceScore({
    required this.score,
    required this.labelEn,
    required this.labels,
    required this.color,
    required this.emoji,
  });

  String labelFor(String language) => labels[language] ?? labelEn;
}

const List<FaceScore> wongBakerFaces = [
  FaceScore(
    score: 0,
    labels: {'hi': 'कोई दर्द नहीं', 'bn': 'কোনো ব্যথা নেই', 'mr': 'वेदना नाही', 'te': 'నొప్పి లేదు', 'ta': 'வலி இல்லை', 'gu': 'દુખાવો નથી', 'kn': 'ನೋವು ಇಲ್ಲ', 'pa': 'ਕੋਈ ਦਰਦ ਨਹੀਂ'},
    labelEn: 'No Hurt',
    color: Color(0xFF2EA043),
    emoji: '😊',
  ),
  FaceScore(
    score: 2,
    labels: {'hi': 'हल्का दर्द', 'bn': 'সামান্য ব্যথা', 'mr': 'थोडी वेदना', 'te': 'కొద్దిగా నొప్పి', 'ta': 'சிறிது வலி', 'gu': 'થોડો દુખાવો', 'kn': 'ಸ್ವಲ್ಪ ನೋವು', 'pa': 'ਹਲਕਾ ਦਰਦ'},
    labelEn: 'Hurts Little Bit',
    color: Color(0xFF7EE787),
    emoji: '🙂',
  ),
  FaceScore(
    score: 4,
    labels: {'hi': 'थोड़ा ज़्यादा दर्द', 'bn': 'আরেকটু বেশি ব্যথা', 'mr': 'थोडी जास्त वेदना', 'te': 'కొంచెం ఎక్కువ నొప్పి', 'ta': 'இன்னும் கொஞ்சம் வலி', 'gu': 'થોડો વધુ દુખાવો', 'kn': 'ಸ್ವಲ್ಪ ಹೆಚ್ಚು ನೋವು', 'pa': 'ਥੋੜ੍ਹਾ ਵੱਧ ਦਰਦ'},
    labelEn: 'Hurts Little More',
    color: Color(0xFFD29922),
    emoji: '😐',
  ),
  FaceScore(
    score: 6,
    labels: {'hi': 'काफ़ी दर्द', 'bn': 'বেশ ব্যথা', 'mr': 'बरीच वेदना', 'te': 'చాలా నొప్పి', 'ta': 'அதிக வலி', 'gu': 'ઘણો દુખાવો', 'kn': 'ಸಾಕಷ್ಟು ನೋವು', 'pa': 'ਕਾਫ਼ੀ ਦਰਦ'},
    labelEn: 'Hurts Even More',
    color: Color(0xFFFA8E3D),
    emoji: '😟',
  ),
  FaceScore(
    score: 8,
    labels: {'hi': 'बहुत तेज़ दर्द', 'bn': 'খুব তীব্র ব্যথা', 'mr': 'खूप तीव्र वेदना', 'te': 'చాలా తీవ్రమైన నొప్పి', 'ta': 'மிகக் கடுமையான வலி', 'gu': 'ખૂબ તીવ્ર દુખાવો', 'kn': 'ತುಂಬಾ ತೀವ್ರ ನೋವು', 'pa': 'ਬਹੁਤ ਤੇਜ਼ ਦਰਦ'},
    labelEn: 'Hurts Whole Lot',
    color: Color(0xFFF85149),
    emoji: '😢',
  ),
  FaceScore(
    score: 10,
    labels: {'hi': 'असहनीय भयंकर दर्द', 'bn': 'অসহনীয় ভয়ানক ব্যথা', 'mr': 'असह्य भयंकर वेदना', 'te': 'భరించలేని నొప్పి', 'ta': 'தாங்க முடியாத வலி', 'gu': 'અસહ્ય ભયંકર દુખાવો', 'kn': 'ಸಹಿಸಲಾಗದ ನೋವು', 'pa': 'ਅਸਹਿ ਭਿਆਨਕ ਦਰਦ'},
    labelEn: 'Worst Hurt Possible',
    color: Color(0xFFDA3633),
    emoji: '😭',
  ),
];

class FacesSeverityWidget extends StatelessWidget {
  final int? selectedScore;
  final ValueChanged<int> onScoreSelected;
  final String language;

  const FacesSeverityWidget({
    super.key,
    this.selectedScore,
    required this.onScoreSelected,
    this.language = 'hi',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isBounded = constraints.hasBoundedHeight;
        final bool canFit = !isBounded || constraints.maxHeight >= 420;

        Widget buildBody() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                tr('pain_prompt', language),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Grid of 6 FACES
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: wongBakerFaces.map((face) {
                  final isSelected = selectedScore == face.score;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onScoreSelected(face.score),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 140,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? face.color.withAlpha(30)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? face.color : AppTheme.surfaceBorder,
                    width: isSelected ? 3.0 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: face.color.withAlpha(60),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : AppTheme.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Big Emoji Face
                    Text(
                      face.emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 6),

                    // Number Score badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: face.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${face.score}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Hindi Text
                    Text(
                      face.labelFor(language),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),

                    // English Subtext
                    Text(
                      '',
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

        const SizedBox(height: 16),

        if (selectedScore != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentCyan),
            ),
            child: Text(
              'चयनित दर्द स्कोर (Selected): $selectedScore / 10',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentCyan,
              ),
            ),
          ),
        ],
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
