import 'package:comicslate/models/comics.dart';
import 'package:comicslate/models/comics_category.dart';
import 'package:comicslate/models/comicslate_client.dart';
import 'package:comicslate/view/comics_page.dart';
import 'package:comicslate/view/helpers/comics_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ComicsList extends StatelessWidget {
  final String title;

  const ComicsList({@required this.title}) : assert(title != null);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: FutureBuilder<List<ComicsCategory>>(
          future: ComicslateClient(language: 'ru').getComicsList(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final allComics = <Comics>[];
              snapshot.data.forEach((comicsCategory) =>
                  allComics.addAll(comicsCategory.comicses));
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).orientation ==
                            Orientation.portrait
                        ? 2
                        : 4),
                itemCount: allComics.length,
                itemBuilder: (context, i) => ComicsCard(
                      imageUrl: allComics[i].thumbnailURL.toString(),
                      title: allComics[i].name,
                      callback: () {
                        print('image $i');
                        _openComics(context, allComics[i]);
                      },
                    ),
              );
            } else {
              return Center(
                child: const CircularProgressIndicator(),
              );
            }
          },
        ),
      );

  void _openComics(BuildContext context, Comics comics) {
    Navigator.push(
        context,
        MaterialPageRoute(
            settings: const RouteSettings(name: '/read-comics'),
            builder: (context) => ComicsPage(comics: comics)));
  }
}
