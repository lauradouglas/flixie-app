import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import '../../models/chat_share_media.dart';
import '../media_share_session.dart';
import 'package:flixie_app/models/group.dart';

class GroupShareComposer extends StatefulWidget {
  const GroupShareComposer(
      {super.key,
      required this.movie,
      required this.groups,
      required this.session});
  final ChatShareMedia movie;
  final List<Group> groups;
  final MediaShareSession session;
  @override
  State<GroupShareComposer> createState() => _GroupShareComposerState();
}

class _GroupShareComposerState extends State<GroupShareComposer> {
  late String selectedGroupId = widget.groups.first.id!;
  final messageController =
      TextEditingController(text: 'Has anyone ever seen this?');
  bool sending = false;
  ChatShareMedia get movie => widget.movie;
  List<Group> get groups => widget.groups;
  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        if (!widget.session.isCurrent) {
          return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Account changed. Close this sheet to continue.'));
        }
        final selectedGroup = groups.firstWhere(
          (group) => group.id == selectedGroupId,
          orElse: () => groups.first,
        );

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.medium.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Share to group chat',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title,
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose a group',
                style: TextStyle(
                  color: context.colors.medium,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 228),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final group = groups[index];
                    final isSelected = group.id == selectedGroupId;
                    return InkWell(
                      onTap: sending || group.id == null
                          ? null
                          : () => setState(() => selectedGroupId = group.id!),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? FlixieColors.primary.withValues(alpha: 0.14)
                              : context.colors.tabBarBackgroundFocused,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? FlixieColors.primary.withValues(alpha: 0.45)
                                : context.colors.tabBarBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? FlixieColors.primary
                                        .withValues(alpha: 0.22)
                                    : context.colors.surfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                (group.abbreviation?.isNotEmpty == true
                                        ? group.abbreviation!
                                        : group.name)
                                    .trim()
                                    .characters
                                    .take(2)
                                    .toString()
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: isSelected
                                      ? FlixieColors.primary
                                      : context.colors.light,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: TextStyle(
                                      color: context.colors.light,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (group.abbreviation?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      group.abbreviation!.toUpperCase(),
                                      style: TextStyle(
                                        color: context.colors.medium,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: FlixieColors.primary,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: context.colors.medium,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                minLines: 2,
                maxLines: 3,
                enabled: !sending,
                style: TextStyle(color: context.colors.light),
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Has anyone ever seen this?',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          if (!widget.session.isCurrent) return;
                          setState(() => sending = true);
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final customMessage = messageController.text.trim();

                          try {
                            await widget.session.shareGroup(
                              movie: movie,
                              group: selectedGroup,
                              message: customMessage,
                            );
                            if (!mounted ||
                                !context.mounted ||
                                !widget.session.isCurrent ||
                                ModalRoute.of(context)?.isCurrent != true) {
                              return;
                            }
                            navigator.pop();
                            messenger.showFlixieToast(
                              FlixieToast(
                                type: FlixieToastType.success,
                                content: Text(
                                    'Shared to ${selectedGroup.name} chat'),
                              ),
                            );
                          } catch (_) {
                            if (!mounted ||
                                !context.mounted ||
                                !widget.session.isCurrent ||
                                ModalRoute.of(context)?.isCurrent != true) {
                              return;
                            }
                            setState(() => sending = false);
                            messenger.showFlixieToast(
                              FlixieToast(
                                type: FlixieToastType.error,
                                content: const Text(
                                    'Could not share to that group yet'),
                              ),
                            );
                          }
                        },
                  icon: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(sending ? 'Sharing...' : 'Share in group chat'),
                ),
              ),
            ],
          ),
        );
      });
}
