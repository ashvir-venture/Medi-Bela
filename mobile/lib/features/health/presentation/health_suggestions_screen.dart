import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../widgets/state_views.dart';
import '../domain/health_models.dart';
import 'health_controller.dart';

/// Shows the current user's published, pharmacist-reviewed AI health
/// suggestions (tests to ask about, food, lifestyle, warning signs,
/// etc. — open-ended categories, see `HealthSuggestionItem`). Draft
/// suggestions never reach the app; the backend endpoint only ever
/// returns PUBLISHED rows.
class HealthSuggestionsScreen extends ConsumerWidget {
  const HealthSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final languageCode = ref.watch(localeControllerProvider).languageCode;
    final suggestionsAsync = ref.watch(mySuggestionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.aiHealthSuggestions)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mySuggestionsProvider),
        child: suggestionsAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorView(
                message: friendlyErrorMessage(error),
                retryLabel: strings.retry,
                onRetry: () => ref.invalidate(mySuggestionsProvider),
              ),
            ],
          ),
          data: (suggestions) {
            if (suggestions.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyView(
                    message: strings.noHealthSuggestionsYet,
                    icon: Icons.tips_and_updates_outlined,
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      strings.notMedicalAdviceDisclaimer,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final suggestion in suggestions)
                  _SuggestionCard(suggestion: suggestion, languageCode: languageCode),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.languageCode});

  final HealthSuggestionModel suggestion;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final items = suggestion.itemsFor(languageCode);
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items) _SuggestionItemTile(item: item),
          ],
        ),
      ),
    );
  }
}

class _SuggestionItemTile extends StatelessWidget {
  const _SuggestionItemTile({required this.item});

  final HealthSuggestionItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 2),
                Text(item.text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
