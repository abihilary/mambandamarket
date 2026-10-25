// The item page's blocks (§6.7 of the category-native listings spec) and the
// desktop share menu (§6.7.8): what each shows, and what it leaves out when
// the data cannot back it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/Components/ItemCard.dart';
import 'package:mambandamarket/Components/ItemDetailScreen.dart';
import 'package:mambandamarket/Components/listing_details.dart';
import 'package:mambandamarket/Components/share_menu.dart';
import 'package:mambandamarket/api/listing_guide.dart';
import 'package:mambandamarket/api/models.dart';
import 'package:mambandamarket/api/share_links.dart';
import 'package:mambandamarket/l10n/gen/app_localizations.dart';
import 'package:mambandamarket/theme/app_tokens.dart';

const _fr = Locale('fr');

/// A French page around [child], scrollable so nothing overflows the test
/// window.
Widget _page(Widget child) => MaterialApp(
  locale: _fr,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(extensions: [AppTokens.light]),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

Listing _listing({
  String kind = 'product',
  String? condition,
  Map<String, dynamic> attributes = const {},
  bool hasGuarantee = false,
  int quantity = 1,
  String? storeId,
  String? sellerRole,
  double? ratingAvg,
  int ratingCount = 0,
  DateTime? sellerCreatedAt,
  int? activeListings,
}) => Listing(
  id: '3f2a9c1d-0000-4000-8000-000000000001',
  sellerId: 'seller-1',
  title: 'Apple iPhone 13 Pro',
  priceCents: 300000,
  categorySlug: 'phones',
  kind: kind,
  condition: condition,
  attributes: attributes,
  hasGuarantee: hasGuarantee,
  quantity: quantity,
  storeId: storeId,
  sellerName: 'Raswar',
  sellerRole: sellerRole,
  storeName: storeId == null ? null : 'Raswar',
  storeRatingAvg: ratingAvg,
  storeRatingCount: ratingCount,
  sellerCity: 'Akwa, Douala',
  sellerCreatedAt: sellerCreatedAt,
  sellerActiveListings: activeListings,
);

Map<String, dynamic> _o(String v, String en, [String? fr]) =>
    {'value': v, 'label_en': en, 'label_fr': fr ?? en};

/// Phones as 0066 has them, cut down: leaf fields, then the group's colour.
final _phoneFields = attributeFieldsFor([
  Category.fromJson({'slug': 'elektronik', 'label': 'Électronique', 'attribute_schema': [
    {'key': 'colour', 'type': 'single', 'label_en': 'Colour', 'label_fr': 'Couleur',
     'options': [_o('black', 'Black', 'Noir'), _o('blue', 'Blue', 'Bleu')]},
  ]}),
  Category.fromJson({'slug': 'phones', 'label': 'Téléphones', 'parent_slug': 'elektronik', 'attribute_schema': [
    {'key': 'brand', 'type': 'single', 'label_en': 'Brand', 'label_fr': 'Marque',
     'options': [_o('apple', 'Apple'), _o('samsung', 'Samsung')]},
    {'key': 'storage_gb', 'type': 'single', 'label_en': 'Storage', 'label_fr': 'Stockage', 'card': 1,
     'options': [_o('128', '128 GB', '128 Go'), _o('256', '256 GB', '256 Go')]},
    {'key': 'battery_health', 'type': 'number', 'label_en': 'Battery health',
     'label_fr': 'État de la batterie', 'unit_en': '%', 'unit_fr': '%',
     'short_en': 'Batt. {}', 'short_fr': 'Batt. {}', 'card': 2},
    {'key': 'accounts_removed', 'type': 'bool', 'label_en': 'Signed out of iCloud / Google',
     'label_fr': "Déconnecté d'iCloud / Google"},
    {'key': 'swap_ok', 'type': 'bool', 'label_en': 'Swap considered', 'label_fr': 'Échange possible'},
    {'key': 'in_box', 'type': 'multi', 'label_en': 'In the box', 'label_fr': 'Dans la boîte',
     'display': 'checklist',
     'options': [_o('box', 'Box', 'Boîte'), _o('charger', 'Charger', 'Chargeur'), _o('invoice', 'Invoice', 'Facture')]},
  ]}),
], 'phones');

Future<AppLocalizations> _l10n() => AppLocalizations.delegate.load(_fr);

void main() {
  group('ListingDetails', () {
    test('rows, highlights and checklists come only from answers', () async {
      final l10n = await _l10n();
      final d = ListingDetails.of(
        _listing(
          condition: 'Like New',
          hasGuarantee: true,
          quantity: 3,
          attributes: {
            'brand': 'apple',
            'battery_health': 88,
            'colour': 'blue',
            'accounts_removed': true,
            'swap_ok': false,
            'in_box': ['charger', 'box'],
          },
        ),
        _phoneFields,
        ListingGuide.empty,
        l10n,
        _fr,
      );
      expect([for (final r in d.rows) (r.label, r.value)], [
        ('État', 'Comme neuf'),
        ('Marque', 'Apple'),
        ('État de la batterie', '88 %'),
        ('Couleur', 'Bleu'),
        ('Garantie vendeur', 'Oui'),
        (null, 'En stock : 3'),
      ]);
      // A false bool is never said; a true one is a highlight, not a row.
      expect(d.highlights, ["Déconnecté d'iCloud / Google"]);
      expect(d.checklists.single.label, 'Dans la boîte');
      expect(d.checklists.single.items, ['Boîte', 'Chargeur']);
    });

    test('a guide can switch condition and warranty off', () async {
      final l10n = await _l10n();
      final d = ListingDetails.of(
        _listing(condition: 'New', hasGuarantee: true),
        const [],
        ListingGuide.fromJson({'condition': false, 'warranty': false}),
        l10n,
        _fr,
      );
      expect(d.isEmpty, isTrue);
    });

    test('a service has no condition and no stock', () async {
      final l10n = await _l10n();
      final d = ListingDetails.of(
        _listing(kind: 'service', condition: 'New', quantity: 5),
        const [],
        ListingGuide.empty,
        l10n,
        _fr,
      );
      expect(d.rows, isEmpty);
    });
  });

  group('KeyFactsCard', () {
    testWidgets('says only what it was given', (tester) async {
      await tester.pumpWidget(_page(KeyFactsCard(
        title: 'Studio moderne',
        price: (main: '75.000 FCFA / mois', tail: null, negotiableChip: true),
        priceLabel: 'Loyer',
        city: 'Bonamoussadi, Douala',
        onCityTap: () {},
        facts: const ['1 ch.', 'Meublé'],
        categoryLabel: 'Location',
        posted: 'Il y a 6 j',
      )));
      expect(find.text('Loyer'), findsOneWidget);
      expect(find.text('75.000 FCFA / mois'), findsOneWidget);
      expect(find.text('Négociable'), findsOneWidget);
      expect(find.text('Meublé'), findsOneWidget);
      expect(find.text(' · Il y a 6 j'), findsOneWidget);
      // No delivery row without somewhere for it to go, and no views below 10.
      expect(find.text('Livraison : demandez un devis Mambanda'), findsNothing);
      expect(find.textContaining('vues'), findsNothing);
    });

    testWidgets('the delivery row opens the ship flow', (tester) async {
      var shipped = 0;
      await tester.pumpWidget(_page(KeyFactsCard(
        title: 'Frigo',
        price: (main: '120.000 FCFA', tail: null, negotiableChip: false),
        onDeliveryTap: () => shipped++,
      )));
      await tester.tap(find.text('Livraison : demandez un devis Mambanda'));
      expect(shipped, 1);
      expect(find.text('Négociable'), findsNothing);
    });
  });

  group('ItemCard grid', () {
    test('columns from the width, at least two', () {
      int columns(double w) =>
          (ItemCard.gridDelegate(w, TextScaler.noScaling)
                  as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount;
      expect(columns(328), 2);
      expect(columns(568), 3);
      expect(columns(1216), 7);
    });

    testWidgets('a full card fits its row at text size 1.3', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AppTokens.light]),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CustomScrollView(slivers: [
                SliverLayoutBuilder(
                  builder: (context, c) => SliverGrid(
                    gridDelegate: ItemCard.gridDelegate(
                        c.crossAxisExtent, MediaQuery.textScalerOf(context)),
                    delegate: SliverChildBuilderDelegate(
                      (_, _) => const ItemCard(
                        imageUrl: 'https://example.invalid/x.png',
                        title: 'Apple iPhone 13 Pro Max 256 Go bleu alpin',
                        specLine: 'Batt. 88 % · Comme neuf',
                        price: '3.500.000 FCFA',
                        priceTail: 'nég.',
                        badge: 'Service',
                        location: 'Bonamoussadi, Douala',
                      ),
                      childCount: 4,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Batt. 88 % · Comme neuf'), findsNWidgets(4));
    });
  });

  group('DetailsTable', () {
    final nine = ListingDetails(rows: [
      for (var i = 1; i <= 9; i++) DetailRow(label: 'Champ $i', value: 'Valeur $i'),
    ]);

    testWidgets('nine rows fold to six and a "show all"', (tester) async {
      await tester.pumpWidget(_page(DetailsTable(details: nine)));
      await tester.pumpAndSettle();
      expect(find.text('Détails'), findsOneWidget);
      expect(find.text('Valeur 6'), findsOneWidget);
      expect(find.text('Valeur 7'), findsNothing);
      expect(find.text('Voir les 9 détails'), findsOneWidget);

      await tester.tap(find.text('Voir les 9 détails'));
      await tester.pumpAndSettle();
      expect(find.text('Valeur 9'), findsOneWidget);
      expect(find.text('Voir moins'), findsOneWidget);
    });

    testWidgets('eight rows do not fold', (tester) async {
      await tester.pumpWidget(_page(DetailsTable(
        details: ListingDetails(rows: nine.rows.take(8).toList()),
      )));
      expect(find.text('Valeur 8'), findsOneWidget);
      expect(find.textContaining('Voir les'), findsNothing);
    });

    testWidgets('nothing to list draws nothing at all', (tester) async {
      await tester.pumpWidget(_page(const DetailsTable(details: ListingDetails.empty)));
      expect(find.text('Détails'), findsNothing);
      expect(find.text('Détails fournis par le vendeur.'), findsNothing);
      final box = tester.widget<SizedBox>(find.descendant(
          of: find.byType(DetailsTable), matching: find.byType(SizedBox)));
      expect((box.width, box.height), (0.0, 0.0));
    });

    testWidgets('closes with the seller footnote, highlights and checklists',
        (tester) async {
      await tester.pumpWidget(_page(const DetailsTable(
        details: ListingDetails(
          rows: [DetailRow(label: 'Marque', value: 'Apple')],
          highlights: ["Déconnecté d'iCloud / Google"],
          checklists: [
            DetailChecklist(label: 'Dans la boîte', items: ['Boîte', 'Chargeur']),
          ],
        ),
      )));
      expect(find.text('Détails fournis par le vendeur.'), findsOneWidget);
      expect(find.text('Points forts'), findsOneWidget);
      expect(find.text("Déconnecté d'iCloud / Google"), findsOneWidget);
      expect(find.text('Dans la boîte'), findsOneWidget);
      expect(find.text('Chargeur'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(3));
    });

    testWidgets('two columns put two rows on a line', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_page(DetailsTable(
        details: ListingDetails(rows: nine.rows.take(4).toList()),
        columns: 2,
      )));
      final a = tester.getTopLeft(find.text('Valeur 1'));
      final b = tester.getTopLeft(find.text('Valeur 2'));
      expect(a.dy, b.dy);
      expect(b.dx, greaterThan(a.dx));
    });
  });

  group('CollapsibleDescription', () {
    String lines(int n) => [for (var i = 1; i <= n; i++) 'Ligne $i'].join('\n');

    testWidgets('three lines show whole, with no "show more"', (tester) async {
      await tester.pumpWidget(_page(CollapsibleDescription(text: lines(3))));
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Voir plus'), findsNothing);
    });

    testWidgets('twelve lines fold, and unfold on tap', (tester) async {
      await tester.pumpWidget(_page(CollapsibleDescription(text: lines(12))));
      expect(find.text('Voir plus'), findsOneWidget);
      await tester.tap(find.text('Voir plus'));
      await tester.pump();
      expect(find.text('Voir moins'), findsOneWidget);
    });

    testWidgets('empty says so, unless the details already say plenty',
        (tester) async {
      await tester.pumpWidget(_page(const CollapsibleDescription(text: '  ')));
      expect(find.text("Le vendeur n'a pas ajouté de description."), findsOneWidget);
      await tester.pumpWidget(
          _page(const CollapsibleDescription(text: '', hideWhenEmpty: true)));
      expect(find.text('Description'), findsNothing);
    });
  });

  group('SellerCard', () {
    final now = DateTime(2026, 10, 25);

    testWidgets('no rating below three reviews', (tester) async {
      await tester.pumpWidget(_page(SellerCard(
        listing: _listing(storeId: 's1', ratingAvg: 4.6, ratingCount: 2),
        now: now,
      )));
      expect(find.textContaining('avis'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('a rating at three reviews, always with the count',
        (tester) async {
      await tester.pumpWidget(_page(SellerCard(
        listing: _listing(storeId: 's1', ratingAvg: 4.6, ratingCount: 3),
        now: now,
      )));
      expect(find.text('4,6 · 3 avis'), findsOneWidget);
    });

    testWidgets('new under 30 days, a month and year after', (tester) async {
      await tester.pumpWidget(_page(SellerCard(
        listing: _listing(sellerCreatedAt: now.subtract(const Duration(days: 12))),
        now: now,
      )));
      expect(find.text('Nouveau sur Mambanda'), findsOneWidget);

      await tester.pumpWidget(_page(SellerCard(
        listing: _listing(sellerCreatedAt: DateTime(2025, 3, 14), activeListings: 6),
        now: now,
      )));
      expect(find.text('Membre depuis mars 2025'), findsOneWidget);
      expect(find.text('6 annonces'), findsOneWidget);
    });

    testWidgets('the type line follows what was actually verified',
        (tester) async {
      Future<void> show(Listing x) =>
          tester.pumpWidget(_page(SellerCard(listing: x, now: now)));

      await show(_listing());
      expect(find.text('Particulier · Akwa, Douala'), findsOneWidget);
      expect(find.text('Voir le vendeur'), findsOneWidget);

      await show(_listing(storeId: 's1'));
      expect(find.text('Boutique · Akwa, Douala'), findsOneWidget);
      expect(find.text('Voir la boutique'), findsOneWidget);

      await show(_listing(sellerRole: 'company'));
      expect(find.text('Entreprise vérifiée · Akwa, Douala'), findsOneWidget);
      // No count from the server is not "0 annonces".
      expect(find.textContaining('annonce'), findsNothing);
    });
  });

  group('BuyerTipsCard', () {
    test('the guide first, the general three for a product without', () async {
      final l10n = await _l10n();
      final guide = ListingGuide.fromJson({
        'buyer_tips': [
          {'en': 'Visit first.', 'fr': "Visitez d'abord."},
        ],
      });
      expect(BuyerTipsCard.tipsFor(_listing(), guide, l10n, _fr), ["Visitez d'abord."]);
      expect(BuyerTipsCard.tipsFor(_listing(), ListingGuide.empty, l10n, _fr),
          [l10n.tipDefault1, l10n.tipDefault2, l10n.tipDefault3]);
      expect(BuyerTipsCard.tipsFor(_listing(kind: 'job'), ListingGuide.empty, l10n, _fr),
          isEmpty);
      expect(
          BuyerTipsCard.tipsFor(_listing(), ListingGuide.empty, l10n, _fr,
              protected: true).first,
          l10n.tipProtected);
    });

    testWidgets('one tip showing, the rest behind a tap', (tester) async {
      await tester.pumpWidget(_page(const BuyerTipsCard(tips: ['Un.', 'Deux.', 'Trois.'])));
      expect(find.text('Avant de payer'), findsOneWidget);
      expect(find.text('Un.'), findsOneWidget);
      expect(find.text('Deux.'), findsNothing);
      await tester.tap(find.text('Voir les conseils (3)'));
      await tester.pump();
      expect(find.text('Trois.'), findsOneWidget);
    });
  });

  group('share menu', () {
    const id = '3f2a9c1d-0000-4000-8000-000000000001';
    final link = ShareLinks.listing(id).toString();

    Future<List<String>> openMenu(WidgetTester tester) async {
      final copied = <String>[];
      await tester.pumpWidget(_page(Builder(
        builder: (context) => TextButton(
          onPressed: () => showShareMenu(
            context,
            anchor: context,
            title: 'Apple iPhone 13 Pro',
            priceText: '300.000 FCFA',
            link: link,
            canShare: false,
            copy: (text) async {
              copied.add(text);
              return true;
            },
          ),
          child: const Text('partager'),
        ),
      )));
      await tester.tap(find.text('partager'));
      await tester.pumpAndSettle();
      return copied;
    }

    testWidgets('copies the bare link and nothing else', (tester) async {
      final copied = await openMenu(tester);
      expect(find.text("Partager l'annonce"), findsOneWidget);
      expect(find.text('mambandamarket.com/l/$id'), findsOneWidget);

      await tester.tap(find.text('Copier le lien'));
      await tester.pump();
      expect(copied, ['https://mambandamarket.com/l/$id']);

      // Confirmed in place, and the menu stays open for the next choice.
      expect(find.text('Lien copié'), findsOneWidget);
      expect(find.text('Envoyer sur WhatsApp'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Lien copié'), findsNothing);
      expect(find.text("Partager l'annonce"), findsOneWidget);
    });

    testWidgets('"More options" only where the browser can share',
        (tester) async {
      await openMenu(tester);
      expect(find.text('Partager sur Facebook'), findsOneWidget);
      expect(find.text("Plus d'options…"), findsNothing);
    });
  });

  group('item page', () {
    // No id, so nothing is fetched: the page draws from the listing it was
    // handed, the way it does while the full one loads.
    Future<void> show(WidgetTester tester, Size size, Listing x) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        locale: _fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: [AppTokens.light]),
        home: ItemDetailScreen(
          title: x.title,
          price: x.displayPrice,
          imageUrl: '',
          listing: x,
        ),
      ));
      await tester.pump();
    }

    final full = Listing(
      id: '3f2a9c1d-0000-4000-8000-000000000002',
      sellerId: 'seller-1',
      title: 'Apple iPhone 13 Pro · 256 Go',
      description: [for (var i = 1; i <= 14; i++) 'Ligne $i'].join('\n'),
      priceCents: 300000,
      priceMode: 'negotiable',
      categorySlug: 'phones',
      condition: 'Like New',
      hasGuarantee: true,
      quantity: 2,
      city: 'Bonamoussadi, Douala',
      viewCount: 4,
      sellerName: 'Raswar',
      storeId: 's1',
      storeName: 'Raswar',
      sellerCity: 'Akwa, Douala',
      sellerCreatedAt: DateTime(2025, 3, 1),
      sellerActiveListings: 6,
    );

    for (final (name, size) in [
      ('phone', const Size(360, 800)),
      ('desktop', const Size(1280, 900)),
      ('large desktop', const Size(1440, 900)),
    ]) {
      testWidgets('lays out on a $name', (tester) async {
        await show(tester, size, full);
        expect(tester.takeException(), isNull);
        expect(find.text('Apple iPhone 13 Pro · 256 Go'), findsWidgets);
        expect(find.text('300.000 FCFA'), findsOneWidget);
        expect(find.text('Négociable'), findsOneWidget);
        // The condition comes from the data, translated; the old "Retrait
        // sur place" fallback is gone, and four views are not worth saying.
        expect(find.text('Comme neuf'), findsWidgets);
        expect(find.text('Retrait sur place'), findsNothing);
        expect(find.textContaining('vues'), findsNothing);
        expect(find.text('Garantie vendeur'), findsWidgets);
        expect(find.text('Voir plus'), findsOneWidget);
        expect(find.text('Boutique · Akwa, Douala'), findsOneWidget);
        expect(find.text('Avant de payer'), findsOneWidget);
        // No guide cta: the usual button.
        expect(find.text('Écrire'), findsOneWidget);
      });
    }

    testWidgets('a bare listing shows no empty blocks', (tester) async {
      await show(
        tester,
        const Size(360, 800),
        const Listing(
          id: '3f2a9c1d-0000-4000-8000-000000000003',
          sellerId: '',
          title: 'Cours de maths',
          priceCents: 0,
          priceMode: 'on_request',
          kind: 'service',
          categorySlug: 'tutoring',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Sur demande'), findsOneWidget);
      expect(find.text('Détails'), findsNothing);
      expect(find.text('Avant de payer'), findsNothing);
      expect(find.text('Livraison : demandez un devis Mambanda'), findsNothing);
    });
  });
}
