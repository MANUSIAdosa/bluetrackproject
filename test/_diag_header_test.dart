import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blue_track/core/localization/app_localizations.dart';
import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/core/theme/app_theme.dart';

void main() {
  testWidgets('measure header parts at 288 width scale 1.5', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('id'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) {
                final header = Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('p01.interests.title'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: context.tr('p01.interests.info.button'),
                      child: TextButton.icon(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.ocean,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.info_outline, size: 20),
                        label: Text(
                          context.tr('p01.interests.info.labelShort'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 200, width: double.infinity, child: header),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('Pilih Minatmu'));
    final label = tester.getRect(find.text('Info Detail'));
    final button = tester.getRect(find.byType(TextButton));
    // ignore: avoid_print
    print('title=$title');
    // ignore: avoid_print
    print('label=$label');
    // ignore: avoid_print
    print('button=$button');
  });
}
