import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';

part 'widgets.g.dart';

/// Live unread-notifications count for the bell badge; 0 on failure.
@Riverpod(keepAlive: true)
class UnreadNotificationsCount extends _$UnreadNotificationsCount {
  @override
  Future<int> build() async {
    try {
      final res = await ref.read(apiClientProvider).getUnreadCount();
      return res.count;
    } catch (_) {
      return 0;
    }
  }
}

/// ─── Shared widgets from the Nawaqs design spec ─────────────────────────────
/// Top app bar, section labels, stat cards, status chips, queue rows, steppers.
/// Every screen composes these; no bespoke card shapes.

/// Top app bar: teal rounded app mark + eyebrow/H1 stack + bell with a real
/// unread-count dot (hidden when zero). Detail screens pass `back: true`
/// to swap the mark for a chevron.
class NawaqsTopBar extends ConsumerWidget {
  final String eyebrow;
  final String title;
  final bool back;
  final bool showBell;
  final VoidCallback? onBell;
  final List<Widget> extraActions;

  const NawaqsTopBar({
    super.key,
    required this.eyebrow,
    required this.title,
    this.back = false,
    this.showBell = true,
    this.onBell,
    this.extraActions = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          if (back)
            IconButton(
              onPressed: () {
                // Pop if there is something to pop, otherwise fall back home by module.
                if (context.canPop()) {
                  context.pop();
                } else {
                  final loc = GoRouterState.of(context).matchedLocation;
                  if (loc.startsWith('/admin')) {
                    context.go('/admin');
                  } else if (loc.startsWith('/pharmacy')) {
                    context.go('/pharmacy');
                  } else {
                    context.go('/home');
                  }
                }
              },
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.brand900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.monitor_heart_outlined,
                  color: Colors.white, size: 20),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                        height: 1.1)),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25)),
              ],
            ),
          ),
          ...extraActions,
          if (showBell)
            Stack(
              children: [
                IconButton(
                  onPressed: onBell ?? () {},
                  icon: const Icon(Icons.notifications_none_rounded, size: 23),
                  padding: const EdgeInsets.all(6),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                if (unread > 0)
                  PositionedDirectional(
                    top: 5,
                    end: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 15),
                      height: 15,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.dangerIcon,
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: AppColors.page, width: 1.4),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Screen subtitle under the top bar.
class ScreenSubtitle extends StatelessWidget {
  final String text;
  const ScreenSubtitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
    );
  }
}

/// Uppercase micro-label above every card/section — a real recurring component.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textMuted));
  }
}

/// Semantic chip: success / warning / danger / neutral(blue).
class StatusChip extends StatelessWidget {
  final String label;
  final ChipTone tone;
  final IconData? icon;

  const StatusChip(this.label,
      {super.key, this.tone = ChipTone.neutral, this.icon});

  static const Map<ChipTone, (Color, Color)> _colors = {
    ChipTone.success: (AppColors.successBg, AppColors.successText),
    ChipTone.warning: (AppColors.warningBg, AppColors.warningText),
    ChipTone.danger: (AppColors.dangerBg, AppColors.dangerText),
    ChipTone.neutral: (AppColors.accentBlueBg, AppColors.accentBlue),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors[tone]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

enum ChipTone { success, warning, danger, neutral }

/// Stat card — big number + uppercase label; whole card tinted by state.
class StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final ChipTone tone;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.tone,
  });

  static (Color, Color, Color) _visual(ChipTone tone) => switch (tone) {
        ChipTone.success => (
            AppColors.successBg,
            AppColors.successText,
            AppColors.successIcon
          ),
        ChipTone.warning => (
            AppColors.warningBg,
            AppColors.warningText,
            AppColors.warningIcon
          ),
        ChipTone.danger => (AppColors.dangerBg, AppColors.dangerText, AppColors.dangerIcon),
        ChipTone.neutral => (AppColors.card, AppColors.textPrimary, AppColors.textMuted),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, ic) = _visual(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: tone == ChipTone.neutral
            ? Border.all(color: AppColors.hairline)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.topStart,
            child: Icon(icon, size: 16, color: ic),
          ),
          const SizedBox(height: 10),
          Text('$value',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: fg, height: 1.1)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: fg.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

/// Queue/list row — icon tile + title/meta + trailing. Flat, hairline-bordered.
class QueueRow extends StatelessWidget {
  final IconData leadingIcon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String meta;
  final String? trailingMeta;
  final VoidCallback? onTap;

  const QueueRow({
    super.key,
    required this.leadingIcon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.meta,
    this.trailingMeta,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(leadingIcon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(meta,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (trailingMeta != null) ...[
                const SizedBox(width: 8),
                Text(trailingMeta!,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-step (or more) vertical status tracker from the pass screen.
class NawaqsStepper extends StatelessWidget {
  final List<StepperStep> steps;

  const NawaqsStepper({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    _StepDot(step: steps[i]),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.hairline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].title,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(steps[i].subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final StepperStep step;
  const _StepDot({required this.step});

  @override
  Widget build(BuildContext context) {
    final done = step.done;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done ? AppColors.successIcon : AppColors.accentBlueBg,
        shape: BoxShape.circle,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : step.pendingIcon != null
              ? Icon(step.pendingIcon, size: 14, color: AppColors.accentBlue)
              : Center(
                  child: Text(step.indexLabel ?? '?',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentBlue))),
    );
  }
}

class StepperStep {
  final String title;
  final String subtitle;
  final bool done;
  final IconData? pendingIcon;
  final String? indexLabel;

  StepperStep.done(this.title, this.subtitle)
      : done = true,
        pendingIcon = null,
        indexLabel = null;

  StepperStep.pending(this.title, this.subtitle,
      {this.pendingIcon, this.indexLabel})
      : done = false;
}

/// Info cell used in two-column grids (pickup time, medication name...).
class InfoCell extends StatelessWidget {
  final String label;
  final String value;
  const InfoCell({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 3),
          Text(value,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Icon tile used in list rows.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;
  const IconTile(this.icon, {super.key, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Alias used by pass screens.
class StepperWidget extends StatelessWidget {
  final List<StepperStep> steps;
  const StepperWidget({super.key, required this.steps});

  @override
  Widget build(BuildContext context) => NawaqsStepperInternal(steps: steps);
}

class NawaqsStepperInternal extends StatelessWidget {
  final List<StepperStep> steps;
  const NawaqsStepperInternal({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    _StepDot(step: steps[i]),
                    if (i < steps.length - 1)
                      Expanded(child: Container(width: 2, color: AppColors.hairline)),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].title,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(steps[i].subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
