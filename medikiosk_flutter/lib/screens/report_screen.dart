import 'package:flutter/material.dart';
import '../l10n.dart';
import '../models/models.dart';
import '../widgets/tactile_button.dart';

class ReportScreen extends StatelessWidget {
  final Map<String, dynamic>? reportData;
  final PatientProfile profile;
  final List<ClinicalAnswerRecord> clinicalAnswers;
  final List<String> extractedDocumentLines;
  final VoidCallback onNewPatient;
  final VoidCallback? onPrintSlip;
  final VoidCallback? onEdit;
  /// The language the patient chose. The slip is what they carry to the doctor, so its labels
  /// are written in the language the rest of the session was conducted in.
  final String language;

  const ReportScreen({
    super.key,
    this.reportData,
    this.language = 'en',
    required this.profile,
    required this.clinicalAnswers,
    required this.extractedDocumentLines,
    required this.onNewPatient,
    this.onPrintSlip,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final queueEntry = reportData?['queue_entry'] as Map?;
    final routing = reportData?['routing'] as Map<String, dynamic>? ?? {};
    final queue = queueEntry?['specialty'] as String? ?? routing['queue'] as String? ?? 'General Medicine OPD';
    final token = queueEntry?['number'] != null ? '${queueEntry!['number']}' : routing['token'] as String? ?? 'A-42';
    final room = routing['room'] as String? ?? '14';
    final prakriti = reportData?['prakriti'] as Map<String, dynamic>?;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 650;
        final isBounded = constraints.hasBoundedHeight;

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tr('checkup_complete', language),
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Patient Identity Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_rounded, color: Color(0xFF0D9488), size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      profile.name.isEmpty ? tr('not_recorded', language) : profile.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (profile.age != null)
                    Text(
                      '${profile.age} Y • ${profile.gender}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                  const Spacer(),
                  Text(
                    profile.maskedAbha,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Main Split: Wide (Left + Right) vs Narrow (Stacked Compact)
            if (isBounded)
              Expanded(child: isWide ? _buildWideSplit(context, queue, token, room, prakriti) : _buildNarrowView(context, queue, token, room, prakriti))
            else
              SizedBox(height: 300, child: isWide ? _buildWideSplit(context, queue, token, room, prakriti) : _buildNarrowView(context, queue, token, room, prakriti)),

            const SizedBox(height: 6),

            // Giant Glowing Green Print Button
            TactileButton(
              onPressed: onPrintSlip ?? onNewPatient,
              height: 56,
              isSuccess: true,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.print_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    tr('download_slip', language),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return content;
      },
    );
  }

  Widget _buildWideSplit(
    BuildContext context,
    String queue,
    String token,
    String room,
    Map<String, dynamic>? prakriti,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT: 3 Summary Cards
        Expanded(
          flex: 5,
          child: Column(
            children: [
              // These read the intake. They used to be literals, so every slip printed the
              // same complaint, duration and severity whatever the patient had said.
              Expanded(child: _buildSummaryTile(
                icon: Icons.personal_injury_rounded,
                title: tr('chief_complaint', language),
                value: _complaintText(),
                onEdit: onEdit,
              )),
              const SizedBox(height: 6),
              Expanded(child: _buildSummaryTile(
                icon: Icons.access_time_filled_rounded,
                title: tr('duration', language),
                value: _durationText(),
                onEdit: onEdit,
              )),
              const SizedBox(height: 6),
              Expanded(child: prakriti != null
                ? _buildSummaryTile(
                    icon: Icons.spa_rounded,
                    title: tr('prakriti_title', language),
                    value: prakriti['complete'] == false
                        ? tr('prakriti_incomplete', language)
                        : '${prakriti['prakriti'] ?? 'Provisional'} (${_formatMarks(prakriti['marks'])})',
                    onEdit: onEdit,
                  )
                : _buildSummaryTile(
                    icon: Icons.sentiment_very_dissatisfied_rounded,
                    title: tr('severity', language),
                    value: _severityText(),
                    onEdit: onEdit,
                  ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // RIGHT: Thermal Hospital Ticket Slip
        Expanded(
          flex: 4,
          child: _buildThermalSlip(queue, token, room),
        ),
      ],
    );
  }

  Widget _buildNarrowView(
    BuildContext context,
    String queue,
    String token,
    String room,
    Map<String, dynamic>? prakriti,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool canFlex = constraints.hasBoundedHeight && constraints.maxHeight >= 220;

        Widget buildTiles({required bool useFlex}) {
          final tile1 = _buildSummaryTile(
            icon: Icons.personal_injury_rounded,
            title: tr('chief_complaint', language),
            value: _complaintText(),
            onEdit: onEdit,
          );
          final tile2 = prakriti != null && prakriti['prakriti'] != null
              ? _buildSummaryTile(
                  icon: Icons.spa_rounded,
                  title: tr('prakriti_title', language),
                  value: '${prakriti['prakriti']} (${_formatMarks(prakriti['marks'])})',
                  onEdit: onEdit,
                )
              : _buildSummaryTile(
                  icon: Icons.sentiment_very_dissatisfied_rounded,
                  title: tr('severity', language),
                  value: _severityText(),
                  onEdit: onEdit,
                );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact Token Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF5EEAD4), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Token $token', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0D9488))),
                        Text('$queue - ${tr('room', language)} $room', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const Icon(Icons.qr_code_2_rounded, size: 38, color: Color(0xFF0D9488)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (useFlex) Expanded(child: tile1) else SizedBox(height: 64, child: tile1),
              const SizedBox(height: 6),
              if (useFlex) Expanded(child: tile2) else SizedBox(height: 64, child: tile2),
            ],
          );
        }

        if (canFlex) {
          return buildTiles(useFlex: true);
        } else {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: buildTiles(useFlex: false),
          );
        }
      },
    );
  }

  Widget _buildThermalSlip(String queue, String token, String room) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('AIIMS / सरकारी अस्पताल', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              Text(tr('token_slip', language), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const Divider(color: Color(0xFFE2E8F0), thickness: 1, height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Token $token',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D9488), letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 3),
              Text(queue, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1),
              Text('${tr('room', language)} $room', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0D9488))),
            ],
          ),
          const Icon(Icons.qr_code_2_rounded, size: 36, color: Color(0xFF334155)),
        ],
      ),
    );
  }

  Map<String, dynamic> get _clinical =>
      (reportData?['clinical'] as Map?)?.cast<String, dynamic>() ?? const {};

  String _complaintText() {
    if (clinicalAnswers.isNotEmpty) {
      return clinicalAnswers.map((a) => a.answerText).join(', ');
    }
    final complaint = '${_clinical['complaint'] ?? ''}'.trim();
    return complaint.isEmpty ? tr('not_recorded', language) : complaint;
  }

  String _durationText() {
    final duration = _clinical['duration'];
    if (duration == null || '$duration'.trim().isEmpty) return tr('not_recorded', language);
    // A bare number is a count of days; anything else is the patient's own wording.
    final days = duration is num ? duration : num.tryParse('$duration'.trim());
    return days == null ? '$duration' : '$days ${tr('days', language)}';
  }

  String _severityText() {
    final severity = _clinical['severity'];
    if (severity == null) return tr('not_recorded', language);
    return '$severity / 10';
  }

  String _formatMarks(dynamic marks) {
    if (marks is Map) {
      return marks.entries
          .map((e) {
            final k = e.key.toString();
            final cap = k.isNotEmpty ? '${k[0].toUpperCase()}${k.substring(1)}' : k;
            return '$cap ${e.value}';
          })
          .join(', ');
    }
    return '';
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0D9488), size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Color(0xFF0D9488), size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}
