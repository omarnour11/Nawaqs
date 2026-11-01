import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/core/config.dart';
import 'package:nawakes_mobile/features/pharmacy/data/sales_ledger_models.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';
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
  final String? readOnlyNotice;

  const TicketThreadSection({
    super.key,
    required this.ticketId,
    required this.canReply,
    this.readOnlyNotice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadState = ref.watch(ticketMessagesProvider(ticketId));
    final replyCtrl = useTextEditingController();
    final sending = useState(false);

    Future<void> send() async {
      if (replyCtrl.text.trim().isEmpty) return;
      sending.value = true;
      try {
        final client = ref.read(apiClientProvider);
        await client.postTicketMessage(
            ticketId, PostMessageRequest(body: replyCtrl.text.trim()));
        replyCtrl.clear();
        ref.invalidate(ticketMessagesProvider(ticketId));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تعذر إرسال الرسالة — يرجى المحاولة مرة أخرى.')),
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
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            data: (messages) {
              if (messages.isEmpty) {
                return const Text('لا توجد رسائل سابقة في هذه التذكرة.',
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
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رد…',
                    ),
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
          ] else if (readOnlyNotice != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      readOnlyNotice!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'Admin';
        final bg = isAdmin ? AppColors.accentBlueBg : AppColors.card;

    return Container(
      width: double.infinity,
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isAdmin ? 14 : 4),
            bottomRight: Radius.circular(isAdmin ? 4 : 14),
          ),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${isAdmin ? "فريق الدعم" : "أنت"} · ${DateFormat('d MMM · HH:mm').format(createdAt.toLocal())}',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isAdmin ? AppColors.accentBlue : AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// Opens the thread as a sheet (used from patient support list).
Future<void> showTicketThreadSheet(BuildContext context, TicketDto ticket) {
  final isClosed = ticket.status == 'Closed' || ticket.status == 'Resolved';
  final isOpen = ticket.status == 'Open';
  final isInProgress = ticket.status == 'InProgress';

  final canReply = isInProgress;
  final readOnlyNotice = isClosed
      ? 'هذه التذكرة مغلقة — المحادثة للقراءة فقط.'
      : isOpen
          ? 'التذكرة قيد المراجعة — سيتم تفعيل المحادثة فور استلام المشرف للتذكرة.'
          : null;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticket.subject,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      'تاريخ الإنشاء: ${DateFormat('d MMMM · HH:mm').format(ticket.createdAt.toLocal())}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              StatusChip(
                ticket.status == 'Open'
                    ? 'قيد المراجعة'
                    : ticket.status == 'InProgress'
                        ? 'مفتوحة للنقاش'
                        : 'مغلقة',
                tone: ticket.status == 'Open'
                    ? ChipTone.warning
                    : ticket.status == 'InProgress'
                        ? ChipTone.neutral
                        : ChipTone.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // تفاصيل الشكوى
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نص الشكوى / البلاغ:',
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(ticket.description,
                    style: const TextStyle(fontSize: 13, height: 1.5)),
                if (ticket.attachmentUrl != null && ticket.attachmentUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('مرفق الإثبات:',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      ticket.attachmentUrl!.startsWith('http')
                          ? ticket.attachmentUrl!
                          : '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}${ticket.attachmentUrl}',
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          TicketThreadSection(
            ticketId: ticket.id,
            canReply: canReply,
            readOnlyNotice: readOnlyNotice,
          ),
        ],
      ),
    ),
  );
}
