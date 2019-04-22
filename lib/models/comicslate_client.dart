import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:comicslate/models/comic.dart';
import 'package:comicslate/models/comic_strip.dart';
import 'package:comicslate/models/storage.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'serializers.dart';

@immutable
class ComicslateClient {
  final String language;
  final Storage offlineStorage;
  final Storage prefetchCache;

  static final Uri _baseUri = Uri.parse('https://app.comicslate.org/');

  const ComicslateClient({
    @required this.language,
    @required this.offlineStorage,
    @required this.prefetchCache,
  });

  Future<http.Response> request(String path,
      [Map<String, dynamic> queryParameters = const {}]) async {
    final response = await http.get(
        _baseUri
            .replace(path: path, queryParameters: queryParameters)
            .toString(),
        headers: {
          HttpHeaders.acceptLanguageHeader: language,
        });
    if (response.statusCode != 200) {
      try {
        throw Exception('$path: ${json.decode(response.body)}');
      } on FormatException catch (e) {
        throw Exception('$path: $e: ${response.body}');
      }
    }
    return response;
  }

  Future<dynamic> requestJson(String path) async {
    String body;
    try {
      body = (await request(path)).body;
      offlineStorage.store(path, utf8.encode(body));
    } on SocketException {
      final offlineData = await offlineStorage.fetch(path);
      if (offlineData == null) {
        rethrow;
      }
      body = utf8.decode(offlineData);
    }
    return json.decode(body);
  }

  Stream<List<Comic>> getComicsList() async* {
    final List comics = await requestJson('comics');
    yield comics
        .map((comic) => serializers.deserializeWith(Comic.serializer, comic))
        .toList();
  }

  Stream<List<String>> getStoryStripsList(Comic comic) async* {
    yield List<String>.from(
        (await requestJson('comics/${comic.id}/strips'))['storyStrips']);
  }

  Future<ComicStrip> _fetchStrip(
    Comic comic,
    String stripId, {
    @required bool allowFromCache,
  }) async {
    final stripMetaPath = 'comics/${comic.id}/strips/$stripId';
    dynamic jsonData;

    if (allowFromCache) {
      final cachedBytes = await prefetchCache.fetch(stripMetaPath);
      if (cachedBytes != null) {
        jsonData = json.decode(utf8.decode(cachedBytes));
      }
    }
    if (jsonData == null) {
      jsonData = await requestJson(stripMetaPath);
      await prefetchCache.store(
          stripMetaPath, utf8.encode(json.encode(jsonData)));
    }
    final strip = serializers.deserializeWith(ComicStrip.serializer, jsonData);

    final stripRenderPath = '$stripMetaPath/render';
    Uint8List imageBytes;
    if (allowFromCache) {
      imageBytes = await prefetchCache.fetch(stripRenderPath);
    }
    if (imageBytes == null) {
      try {
        imageBytes =
            (await request('comics/${comic.id}/strips/$stripId/render'))
                .bodyBytes;
      } catch (e) {
        print(e);
      }
      if (imageBytes != null) {
        await prefetchCache.store(stripRenderPath, imageBytes);
      }
    }

    return strip.rebuild((b) => b.imageBytes = imageBytes);
  }

  Stream<ComicStrip> getStrip(
    Comic comic,
    String stripId, {
    bool allowFromCache = true,
    List<String> prefetch = const [],
  }) async* {
    final strip =
        await _fetchStrip(comic, stripId, allowFromCache: allowFromCache);
    () async {
      for (final prefetchStripId in prefetch) {
        if (prefetchStripId != stripId) {
          await _fetchStrip(comic, prefetchStripId, allowFromCache: true);
        }
      }
    }();
    yield strip;
  }
}
