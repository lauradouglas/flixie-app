import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_detail_sections_controller.dart';

void main() {
  test('late refresh and old viewer results never overwrite current sections',
      () async {
    String? viewer = 'alice';
    final controller = MovieDetailSectionsController(viewerId: () => viewer);
    addTearDown(controller.dispose);
    final old = Completer<int>();
    final values = <int>[];
    controller.begin(clearLoaded: true);
    final oldRequest = controller.load('reviews', () => old.future, values.add);
    controller.begin(clearLoaded: false);
    await controller.load('reviews', () async => 2, values.add);
    old.complete(1);
    await oldRequest;
    expect(values, [2]);
    final previousViewer = Completer<int>();
    final request =
        controller.load('rating', () => previousViewer.future, values.add);
    viewer = 'bob';
    previousViewer.complete(3);
    await request;
    expect(values, [2]);
  });

  test('a failed section retries independently and keeps resolved sections',
      () async {
    final controller = MovieDetailSectionsController(viewerId: () => null);
    addTearDown(controller.dispose);
    controller.begin(clearLoaded: true);
    await controller.load('images', () async => 1, (_) {});
    var attempts = 0;
    int? value;
    await controller.load('credits', () async {
      if (++attempts == 1) throw StateError('fixture');
      return 2;
    }, (result) => value = result);
    expect(controller.states['credits'], 'error');
    expect(controller.loaded, contains('images'));
    await controller.retries['credits']!();
    expect(value, 2);
    expect(controller.states['credits'], isNull);
    controller.begin(clearLoaded: false);
    expect(controller.loaded, containsAll(['images', 'credits']));
    controller.begin(clearLoaded: true);
    expect(controller.loaded, isEmpty);
  });

  test('dispose prevents late application and notification', () async {
    final controller = MovieDetailSectionsController(viewerId: () => null);
    final pending = Completer<int>();
    var applied = false;
    var notifications = 0;
    controller.addListener(() => notifications++);
    final request =
        controller.load('images', () => pending.future, (_) => applied = true);
    controller.dispose();
    pending.complete(1);
    await request;
    expect(applied, false);
    expect(notifications, 1);
  });
}
