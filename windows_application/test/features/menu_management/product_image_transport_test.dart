import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/products/controllers/product_editor_cubit.dart';
import 'package:windows_application/features/menu_management/products/models/selected_product_image.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  final SelectedProductImage image = SelectedProductImage(
    bytes: Uint8List.fromList(<int>[137, 80, 78, 71]),
    filename: 'latte.png',
    mimeType: 'image/png',
  );

  test('image transport preserves selected bytes filename and MIME type', () {
    expect(image.bytes, Uint8List.fromList(<int>[137, 80, 78, 71]));
    expect(image.filename, 'latte.png');
    expect(image.mimeType, 'image/png');
  });

  test(
    'editor uploads the bytes transport and keeps a memory-preview state',
    () async {
      final _ImageRepository repository = _ImageRepository();
      final ProductEditorCubit cubit = ProductEditorCubit(
        repository: repository,
      );
      addTearDown(cubit.close);

      await cubit.uploadImage(image);

      expect(repository.lastImage, same(image));
      expect(cubit.state.draft.imageUrl, 'https://images.example/latte.png');
      expect(cubit.state.isUploadingImage, isFalse);
    },
  );

  test('a receive timeout gives a non-retry-safe image error', () async {
    final ProductEditorCubit cubit = ProductEditorCubit(
      repository: _ImageRepository(
        error: const ApiException(
          message:
              'The server response timed out. The operation may have completed; check before retrying.',
          type: ApiErrorType.receiveTimeout,
        ),
      ),
    );
    addTearDown(cubit.close);

    await cubit.uploadImage(image);

    expect(cubit.state.draft.imageUrl, isEmpty);
    expect(cubit.state.imageUploadError, contains('may have completed'));
  });
}

class _ImageRepository extends MenuCatalogRepository {
  _ImageRepository({this.error});

  final Object? error;
  SelectedProductImage? lastImage;

  @override
  Future<String> uploadProductImage(SelectedProductImage image) async {
    lastImage = image;
    if (error != null) throw error!;
    return 'https://images.example/latte.png';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
