import 'dart:async';
import 'dart:convert';

import 'package:comicslate/flutter/styles.dart' as app_styles;
import 'package:comicslate/models/comicslate_client.dart';
import 'package:comicslate/models/storage.dart';
import 'package:comicslate/view/comic_list.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_sentry/flutter_sentry.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

void main() {
  FlutterSentry.wrap(() {
    final client = ComicslateClient(
      language: 'ru',
      offlineStorage: FlutterCachingAPIClient<dynamic>(
        cache: CacheManager(Config('comicslate-client-json-v1')),
        responseParser: (js) => json.decode(utf8.decode(js)),
      ),
      prefetchCache: FlutterCachingAPIClient(
        cache: CacheManager(Config('comicslate-client-images')),
        responseParser: (bytes) => bytes,
      ),
    );

    runApp(Provider.value(
      value: client,
      child: MyApp(),
    ));
  }, dsn: 'https://b150cab29afe42278804731d11f2af9b@o336071.ingest.sentry.io/5230711');
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Comicslate',
        theme: ThemeData(
          fontFamily: app_styles.kFontFamily,
          primaryColorDark: app_styles.kPrimaryColorDark,
          primaryColor: app_styles.kPrimaryColor,
          accentColor: app_styles.kAccentColor,
          primaryColorLight: app_styles.kPrimaryColorLight,
          dividerColor: app_styles.kDividerColor,
          textTheme: Theme.of(context).textTheme.apply(
                fontFamily: app_styles.kFontFamily,
                displayColor: app_styles.kPrimaryText,
                decorationColor: app_styles.kSecondaryText,
              ),
        ),
        home: ComicList(),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          AppLocalizationsDelegate(),
        ],
        supportedLocales: const [
          // This list limits what locales Global Localizations delegates above
          // will support. The first element of this list is a fallback locale.
          Locale('en', 'US'),
          Locale('ru', 'RU'),
        ],
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics()),
        ],
      );
}

class AppLocalizationsDelegate extends LocalizationsDelegate<void> {
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<void> load(Locale locale) async {
    final name =
        locale.countryCode.isEmpty ? locale.languageCode : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);

    await initializeDateFormatting();
    Intl.defaultLocale = localeName;
  }

  @override
  bool shouldReload(LocalizationsDelegate<void> old) => false;
}
