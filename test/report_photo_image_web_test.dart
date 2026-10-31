import 'package:blue_track/features/report_submit/presentation/widgets/report_photo_image_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('web photos load from the picker blob URL through the network',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: reportPhotoImage(
          path: 'blob:http://localhost/photo-1',
          errorBuilder: (context, error, stackTrace) =>
              const Text('gagal dimuat'),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      'blob:http://localhost/photo-1',
    );
  });
}
