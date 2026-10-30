import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/help_content.dart';
import '../domain/help_models.dart';

/// The text for the app's language. Ships with the app: these pages work offline.
final helpContentProvider = Provider<HelpContent>((ref) {
  return ref.watch(localeControllerProvider).languageCode == 'bn' ? helpContentBn : helpContentEn;
});

/// Opens a URL in another app (dialer, WhatsApp, browser); false when nothing
/// could. A provider so tests can stand in for the platform.
final externalLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Opens a phone call, WhatsApp chat or web page outside the app. When
/// nothing can open it, [fallbackCopy] (a phone number) is copied instead.
Future<void> openExternal(BuildContext context, WidgetRef ref, String url, {String? fallbackCopy}) async {
  var opened = false;
  try {
    opened = await ref.read(externalLauncherProvider)(Uri.parse(url));
  } catch (_) {}
  if (opened || !context.mounted) return;
  if (fallbackCopy != null) await Clipboard.setData(ClipboardData(text: fallbackCopy));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(stringsProvider).couldNotOpenLink)));
}

class PrivacyTermsScreen extends ConsumerWidget {
  const PrivacyTermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(helpContentProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(c.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final section in c.privacySections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.heading, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final line in section.lines) _Bullet(line),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(helpContentProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(c.supportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(c.contactHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final contact in supportContacts) _ContactCard(contact: contact, content: c),
          const SizedBox(height: 20),
          Text(c.howToHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final h in c.howTo)
            Card(
              child: ExpansionTile(
                title: Text(h.heading),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < h.lines.length; i++) _Bullet(h.lines[i], marker: '${i + 1}.'),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(c.faqHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final f in c.faq)
            Card(
              child: ExpansionTile(
                title: Text(f.question),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedAlignment: Alignment.centerLeft,
                children: [Text(f.answer)],
              ),
            ),
        ],
      ),
    );
  }
}

/// A button label that never wraps: it shrinks to fit instead.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, softWrap: false));
}

/// A number with Call, WhatsApp and Copy.
class _ContactCard extends ConsumerWidget {
  const _ContactCard({required this.contact, required this.content});

  final SupportContact contact;
  final HelpContent content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact.display, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Call on its own full-width row (still the filled, main button);
            // WhatsApp and Copy share the row below, equal widths. Labels stay
            // on one line and shrink a little on a small phone.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => openExternal(context, ref, contact.tel, fallbackCopy: contact.display),
                icon: const Icon(Icons.call_outlined),
                label: _OneLine(content.callLabel),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openExternal(context, ref, contact.whatsapp, fallbackCopy: contact.display),
                    icon: const Icon(Icons.chat_outlined),
                    label: _OneLine(content.whatsappLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: contact.display));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(content.copiedLabel)));
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: _OneLine(content.copyLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AboutUsScreen extends ConsumerWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(helpContentProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(c.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Statement(label: c.missionLabel, text: c.mission),
          _Statement(label: c.visionLabel, text: c.vision),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.goalsHeading, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final g in c.goals) _Bullet(g),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(c.teamHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          // Two columns; one on narrow phones.
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [for (final m in c.team) _TeamCard(member: m, facebookLabel: c.facebookLabel)];
              if (constraints.maxWidth < 360) return Column(children: cards);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final card in cards) Expanded(child: card)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Statement extends StatelessWidget {
  const _Statement({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.palette.muted)),
            const SizedBox(height: 4),
            Text(text, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _TeamCard extends ConsumerWidget {
  const _TeamCard({required this.member, required this.facebookLabel});

  final HelpTeamMember member;
  final String facebookLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: AssetImage('assets/images/team/${member.photo}'),
            ),
            const SizedBox(height: 10),
            Text(member.name, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(member.field, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(member.university, textAlign: TextAlign.center, style: TextStyle(color: context.palette.muted, fontSize: 13)),
            TextButton(
              onPressed: () => openExternal(context, ref, member.facebook),
              child: Text(facebookLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {this.marker = '•'});

  final String text;
  final String marker;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 22, child: Text(marker)),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
