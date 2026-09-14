part of 'entry.dart';

/// The shipped license is read from the same root LICENSE that governs the
/// source tree, not a short summary that could silently diverge from it.
final class _OpenSourcePage extends StatelessWidget {
  const _OpenSourcePage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = SourceProvenance.exactSource;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          l10n.openSourceTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(l10n.openSourceIntro),
        const SizedBox(height: 10),
        Text(l10n.openSourceCopyright),
        const SizedBox(height: 10),
        Text(l10n.openSourceNoWarranty),
        const SizedBox(height: 10),
        Text(l10n.openSourceRights),
        const SizedBox(height: 10),
        Text(
          SourceProvenance.modifiedDate.isEmpty
              ? l10n.openSourceModifiedUnknown
              : l10n.openSourceModifiedOn(SourceProvenance.modifiedDate),
        ),
        const SizedBox(height: 18),
        ListTile(
          leading: const Icon(Icons.source_outlined),
          title: Text(l10n.openSourceOriginal),
          subtitle: const Text(SourceProvenance.upstream),
          onTap: () => SourceProvenance.upstream.launchUrl(),
        ),
        ListTile(
          leading: const Icon(Icons.code_outlined),
          title: Text(l10n.openSourceModifiedSource),
          subtitle: Text(source ?? l10n.openSourceUnverified),
          onTap: source == null ? null : () => source.launchUrl(),
        ),
        ListTile(
          leading: const Icon(Icons.library_books_outlined),
          title: Text(l10n.openSourceThirdParty),
          onTap: () => showLicensePage(context: context),
        ),
        const SizedBox(height: 10),
        ExpansionTile(
          leading: const Icon(Icons.travel_explore_outlined),
          title: Text(l10n.openSourceReferences),
          subtitle: Text(l10n.openSourceReferencesTip),
          children: [
            for (final reference in SourceProvenance.networkReferences)
              ListTile(
                title: Text(reference.name),
                subtitle: Text('${reference.license} · ${reference.purpose}'),
                onTap: () => reference.url.launchUrl(),
              ),
          ],
        ),
        const SizedBox(height: 14),
        ExpansionTile(
          title: Text(l10n.openSourceLicense),
          children: [
            FutureBuilder<String>(
              future: rootBundle.loadString('LICENSE'),
              builder: (context, snapshot) => Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  snapshot.data ??
                      (snapshot.hasError ? l10n.openSourceLicenseError : ''),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
