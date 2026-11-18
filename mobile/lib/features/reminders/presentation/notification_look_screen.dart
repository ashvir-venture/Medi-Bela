import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../notifications/notification_look.dart';
import '../../../providers/core_providers.dart';

/// Round 14: "What notifications look like" (the demo's notification page).
/// Which alerts take over the screen and which are normal notifications, with
/// a sample of the neutral lock-screen text (never medicine names).
class NotificationLookScreen extends ConsumerStatefulWidget {
  const NotificationLookScreen({super.key});

  @override
  ConsumerState<NotificationLookScreen> createState() => _NotificationLookScreenState();
}

class _NotificationLookScreenState extends ConsumerState<NotificationLookScreen> {
  Future<void> _changed() async {
    // Re-register the reminders with the new look (photo, vibration, names).
    ref.read(notificationSchedulerProvider).timingChanged();
    if (mounted) setState(() {});
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null) return;
    await NotificationLook.setPhoto(file.path);
    await _changed();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r14;
    final r18 = strings.r18;
    final look = NotificationLook.current;
    final p = context.palette;
    final theme = Theme.of(context);

    Widget item(IconData icon, Color bg, Color fg, String title, String body, {required bool fullPage}) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: fullPage ? p.primaryContainer : p.surface2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          fullPage ? s.npFullPage : s.npNormal,
                          style: TextStyle(
                            fontSize: AppType.small,
                            fontWeight: FontWeight.w700,
                            color: fullPage ? p.onPrimaryContainer : p.muted2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(body, style: TextStyle(color: p.muted2, fontSize: AppType.body)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.notifLookTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.notifLookIntro, style: TextStyle(color: p.muted, fontSize: AppType.body)),
          const SizedBox(height: 14),
          // Round 18 (client points 9, 13): what the user can change.
          Text(r18.yourChoices, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: [
                Row(children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: p.primaryContainer,
                    backgroundImage: look.photoPath == null ? null : FileImage(File(look.photoPath!)),
                    child: look.photoPath == null ? Icon(Icons.person_outline_rounded, color: p.onPrimaryContainer) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r18.reminderPhoto, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(r18.reminderPhotoSub, style: TextStyle(color: p.muted, fontSize: AppType.small)),
                    ]),
                  ),
                ]),
                Row(children: [
                  TextButton(key: const ValueKey('notif-photo'), onPressed: _pickPhoto, child: Text(r18.choosePhoto)),
                  if (look.photoPath != null)
                    TextButton(
                      onPressed: () async {
                        await NotificationLook.setPhoto(null);
                        await _changed();
                      },
                      child: Text(r18.removePhoto),
                    ),
                ]),
                SwitchListTile(
                  key: const ValueKey('notif-vibrate'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(r18.vibrate),
                  value: look.vibrate,
                  onChanged: (v) async {
                    await NotificationLook.setVibrate(v);
                    await _changed();
                  },
                ),
                SwitchListTile(
                  key: const ValueKey('notif-names'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(r18.showNamesLock),
                  subtitle: Text(r18.showNamesLockSub),
                  value: look.showNames,
                  onChanged: (v) async {
                    await NotificationLook.setShowNames(v);
                    await _changed();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(strings.reminderSoundLabel),
                  subtitle: Text(strings.reminderSoundHelp),
                  onTap: () => ref.read(reminderStatusServiceProvider).openReminderSoundSettings(),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(r18.alarmIconNote, style: TextStyle(color: p.muted, fontSize: AppType.small)),
          const SizedBox(height: 16),
          // A lock screen with the neutral reminder text.
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
              decoration: BoxDecoration(color: const Color(0xFF16263B), borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('8:00',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: const Border(left: BorderSide(color: Color(0xFF2F7A3A), width: 4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medi-Bela · ${s.npMedicineTitle}',
                            style: const TextStyle(color: Color(0xFF0F2137), fontWeight: FontWeight.w700)),
                        Text(s.npMedicineSample, style: const TextStyle(color: Color(0xFF0F2137))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          item(Icons.medication_outlined, p.primaryContainer, p.onPrimaryContainer, s.npMedicineTitle, s.npMedicineBody,
              fullPage: true),
          item(Icons.biotech_outlined, p.violetContainer, p.violet, s.npTestTitle, s.npTestBody, fullPage: true),
          item(Icons.inventory_2_outlined, p.warnContainer, p.onWarnContainer, s.npBoxTitle, s.npBoxBody,
              fullPage: true),
          item(Icons.groups_outlined, p.errorContainer, p.onErrorContainer, s.npMissedTitle, s.npMissedBody,
              fullPage: false),
          // Round 18: the urgent reading and the caregiver's changes.
          item(Icons.warning_amber_rounded, p.errorContainer, p.onErrorContainer, r18.urgentTitle, r18.urgentBody, fullPage: true),
          item(Icons.edit_note_rounded, p.navyContainer, p.onNavyContainer, r18.changesTitle, r18.changesBody, fullPage: false),
          item(Icons.notifications_outlined, p.navyContainer, p.onNavyContainer, s.npOtherTitle, s.npOtherBody,
              fullPage: false),
        ],
      ),
    );
  }
}
