import 'dart:typed_data';

import 'package:comicslate/models/comic.dart';
import 'package:comicslate/models/comic_strip.dart';
import 'package:comicslate/models/comicslate_client.dart';
import 'package:comicslate/view_model/comic_page_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ComicPage extends StatelessWidget {
  final Comic comic;

  ComicPage({@required this.comic}) : assert(comic != null);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(comic.name)),
        // Get a list of stripsId
        body: FutureBuilder<Iterable<String>>(
          future:
              const ComicslateClient(language: 'ru').getStoryStripsList(comic),
          builder: (context, stripListSnapshot) {
            if (stripListSnapshot.hasData) {
              // Load image
              return ImagePageViewWidget(
                comic: comic,
                stripIds: stripListSnapshot.data,
              );
            } else {
              return Center(child: const CircularProgressIndicator());
            }
          },
        ),
      );
}

// TODO(ksheremet): Rename
class ImagePageViewWidget extends StatefulWidget {
  final Iterable<String> stripIds;
  final Comic comic;

  ImagePageViewWidget({@required this.comic, @required this.stripIds})
      : assert(stripIds != null && stripIds.isNotEmpty),
        assert(comic != null);

  @override
  _ImagePageViewWidgetState createState() => _ImagePageViewWidgetState();
}

class _ImagePageViewWidgetState extends State<ImagePageViewWidget> {
  PageController _controller;
  ComicPageViewModel _viewModel;
  bool _isOrientationSetup = false;

  @override
  void initState() {
    _viewModel = ComicPageViewModel(comic: widget.comic);
    super.initState();
  }

  // TODO(ksheremet): Cache images
  // TODO(ksheremet): ZoomIn ZoomOut images
  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
        future: _viewModel.getLastSeenPage(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _controller = PageController(initialPage: snapshot.data);
            return PageView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _controller,
              itemCount: widget.stripIds.length,
              itemBuilder: (context, i) => FutureBuilder<ComicStrip>(
                  future: const ComicslateClient(language: 'ru')
                      .getStrip(widget.comic, widget.stripIds.elementAt(i)),
                  builder: (context, stripSnapshot) {
                    if (stripSnapshot.hasData) {
                      if (!_isOrientationSetup) {
                        setUpOrientation(stripSnapshot.data.imageBytes);
                      }
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('${widget.stripIds.elementAt(i)} '
                              '${stripSnapshot.data.title}'),
                          Image.memory(stripSnapshot.data.imageBytes),
                          Text('${stripSnapshot.data.author}: '
                              '${stripSnapshot.data.lastModified}'),
                        ],
                      );
                    } else {
                      return Center(child: const CircularProgressIndicator());
                    }
                  }),
              onPageChanged: (index) {
                _viewModel.setLastSeenPage(index);
              },
            );
          } else {
            return const CircularProgressIndicator();
          }
        },
      );

  // TODO(ksheremet): Consider more elegant solution
  void setUpOrientation(Uint8List imageBytes) {
    final image = MemoryImage(imageBytes);
    image
        .resolve(createLocalImageConfiguration(context))
        .addListener((imageInfo, error) {
      print('height: ${imageInfo.image.height}; '
          'width = ${imageInfo.image.width}');
      _isOrientationSetup = true;
      if (imageInfo.image.width > imageInfo.image.height) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ]);
      } else {
        SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      }
    });
  }
}
