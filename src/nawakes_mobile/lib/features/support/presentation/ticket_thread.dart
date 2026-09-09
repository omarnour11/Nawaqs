import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/pharmacy/data/sales_ledger_models.dart';
import 'package:intl/intl.dart' show DateFormat;

part 'ticket_thread.g.dart';

@riverpod
Future<List<TicketMessageDto>> ticketMessages(Ref ref, String ticketId) async {
  return ref.read(apiClientProvider).getTicketMessages(ticketId);
}

/// محادثة التذكرة — read + reply, shared by admin detail and patient support.
class TicketThreadSection extends HookConsumerWidget {
  final String ticketId;
  final bool canReply;

  const TicketThreadSection(
      {super.key, required this.ticketId, required this.canReply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadState = ref.watch(ticketMessagesProvider(ticketId));
    final replyCtrl = useTextEditingController();
    final sending = useState(false);

    Future<void> send() async {
      if (replyCtrl.text.trim().isEmpty) return;
      sending.value = true;
      try {
        final client = ProviderScope.containerOf(context).read(apiClientProvider);
        await client.postTicketMessage(
            ticketId, PostMessageRequest(body: replyCtrl.text.trim()));
        replyCtrl.clear();
        ref.invalidate(ticketMessagesProvider(ticketId));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر إرسال الرسالة — حاول تاني.')),
          );
        }
      } finally {
        sending.value = false;
      }
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('المحادثة'),
          const SizedBox(height: 10),
          threadState.when(
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )),
            error: (e, _) => const Text('تعذر تحميل المحادثة',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            data: (messages) {
              if (messages.isEmpty) {
                return const Text('مفيش رسائل — ابدأ المحادثة.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary));
              }
              return Column(
                children: [
                  for (final m in messages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MessageBubble(
                          role: m.senderRole,
                          body: m.body,
                          createdAt: m.createdAt),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (canReply) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: replyCtrl,
                    maxLines: 2,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sending.value ? null : send(),
                    decoration: const InputDecoration(
                        hintText: 'اكتب رد…'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending.value ? null : send,
                  icon: sending.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String role;
  final String body;
  final DateTime createdAt;

  const _MessageBubble(
      {required this.role, required this.body, required this.createdAt});

  bool get _isAdmin => role == 'Admin';

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _isAdmin
        ? (AppColors.accentBlueBg, AppColors.accentBlue, 'الدعم')
        : (AppColors.fieldBg, AppColors.textPrimary, 'أنت');

    return Align(
      alignment: _isAdmin
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(_isAdmin ? 14 : 4),
            bottomRight: Radius.circular(_isAdmin ? 4 : 14),
          ),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$role · ${DateFormat('d MMM · HH:mm').format(createdAt.toLocal())}',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _isAdmin ? AppColors.accentBlue : AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(body,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// Opens the thread as a sheet (used from patient support list).
Future<void> showTicketThreadSheet(
    BuildContext context, String ticketId, String subject) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('محادثة التذكرة',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: TicketThreadSection(ticketId: ticketId, canReply: true),
          ),
        ],
      ),
    ),
  );
}
