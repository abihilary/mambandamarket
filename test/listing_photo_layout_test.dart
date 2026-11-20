import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/Components/ItemCard.dart';
import 'package:mambandamarket/Components/listing_photo.dart';

/// A real PNG of [w]×[h], so the photo is sized from a decoded image the way
/// it is in the app.
Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.teal);
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            size: const Size(400, 800), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    );

Future<double> _photoHeight(WidgetTester tester, ImageProvider image,
    {PhotoShape shape = PhotoShape.feed}) async {
  await tester.pumpWidget(_app(Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 200,
      child: ListingPhoto(key: UniqueKey(), image: image, shape: shape),
    ),
  )));
  // Decoding happens off the fake clock.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pump();
  return tester.getSize(find.byType(ListingPhoto)).height;
}

void main() {
  setUp(PhotoRatios.clear);

  // A phone: 400×800 logical pixels.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('photo height follows the image, cut at the shape limits',
      (tester) async {
    final portrait = MemoryImage(await tester.runAsync(() => _png(400, 500)) as Uint8List);
    final tall = MemoryImage(await tester.runAsync(() => _png(300, 1200)) as Uint8List);
    final wide = MemoryImage(await tester.runAsync(() => _png(1200, 300)) as Uint8List);

    // 4:5 is inside the feed's range: drawn at its own proportions.
    expect(await _photoHeight(tester, portrait), closeTo(250, 0.5));
    // 1:4 is taller than 2:3: the box stops at 2:3 and the bottom is cut.
    expect(await _photoHeight(tester, tall), closeTo(300, 0.5));
    // 4:1 is wider than 4:3: the box stops at 4:3.
    expect(await _photoHeight(tester, wide), closeTo(150, 0.5));
    // A rail stops tall photos earlier, at 4:5.
    expect(await _photoHeight(tester, tall, shape: PhotoShape.rail),
        closeTo(250, 0.5));

    final cut = tester.widget<Image>(find.byType(Image));
    expect(cut.fit, BoxFit.cover);
    expect(cut.alignment, Alignment.topCenter);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a photo seen before is the right height on its first frame',
      (tester) async {
    final tall = MemoryImage(await tester.runAsync(() => _png(400, 600)) as Uint8List);
    await _photoHeight(tester, tall);

    await tester.pumpWidget(_app(Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
          width: 200, child: ListingPhoto(key: UniqueKey(), image: tall)),
    )));
    expect(tester.getSize(find.byType(ListingPhoto)).height, closeTo(300, 0.5));
  });

  testWidgets('an unloadable photo falls back to a square, no exceptions',
      (tester) async {
    final h = await _photoHeight(tester, const NetworkImage('http://invalid.test/x.jpg'));
    expect(h, closeTo(200, 0.5));
    expect(tester.takeException(), isNull);
  });

  ItemCard card(int i, {bool compact = false, PhotoShape? shape}) => ItemCard(
        key: ValueKey(i),
        imageUrl: 'http://invalid.test/$i.jpg',
        title: 'Samsung Galaxy A54 128 Go, très bon état, chargeur inclus $i',
        price: '3.500.000 FCFA',
        priceTail: 'nég.',
        specLine: compact ? null : 'Batt. 88 % · Occasion · Noir',
        badge: i.isEven ? 'Service' : null,
        location: 'Cité des Palmiers, Douala',
        distanceMeters: 2300,
        isCompact: compact,
        photoShape: shape,
        onFavoriteToggle: compact ? null : () {},
      );

  // Cards get real photos of five different shapes, keyed by their URL.
  final shapes = [(400, 500), (300, 1200), (1200, 300), (600, 600), (900, 600)];
  final photos = <String, MemoryImage>{};
  setUpAll(() {
    ItemCard.imageFor = (url) => photos[url]!;
  });
  Future<void> paintPhotos(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      final (w, h) = shapes[i % shapes.length];
      photos['http://invalid.test/$i.jpg'] ??=
          MemoryImage(await tester.runAsync(() => _png(w, h)) as Uint8List);
    }
  }

  for (final scale in [1.0, 1.6]) {
    testWidgets('home layout lays out at text scale $scale', (tester) async {
      phone(tester);
      await paintPhotos(tester);
      await tester.pumpWidget(_app(
        textScale: scale,
        CustomScrollView(slivers: [
          // The carousel: a Row of top-aligned compact cards.
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 8; i++)
                    card(i, compact: true, shape: PhotoShape.rail),
                ],
              ),
            ),
          ),
          // The feed: masonry.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: ItemCard.columnsFor(368),
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childCount: 40,
              itemBuilder: (_, i) => card(i, shape: PhotoShape.feed),
            ),
          ),
        ]),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);

      // Cards share a width; heights follow their photos.
      final feed = find.descendant(
          of: find.byType(SliverMasonryGrid), matching: find.byType(ListingPhoto));
      final sizes = [
        for (final e in feed.evaluate()) (e.renderObject! as RenderBox).size
      ];
      expect(sizes.map((s) => s.width).toSet().length, 1);
      expect(sizes.map((s) => s.height.round()).toSet().length, greaterThan(2));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fixed grids still fit a square card at text scale $scale',
        (tester) async {
      phone(tester);
      await paintPhotos(tester);
      await tester.pumpWidget(_app(
        textScale: scale,
        LayoutBuilder(
          builder: (context, box) => GridView.builder(
            gridDelegate: ItemCard.gridDelegate(
                box.maxWidth, MediaQuery.textScalerOf(context)),
            itemCount: 12,
            itemBuilder: (_, i) => card(i),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
