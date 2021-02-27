import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class LocationAppExample extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _LocationAppExampleState();
}

class _LocationAppExampleState extends State<LocationAppExample> {
  ValueNotifier<GeoPoint> notifier = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(""),
          RaisedButton(
            onPressed: () async {
              await Navigator.pushNamed(context, "/search");
            },
            child: Text("pick address"),
          ),
        ],
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  ValueNotifier<GeoPoint> notifierGeoPoint = ValueNotifier(null);
  ValueNotifier<bool> notifierAutoCompletion = ValueNotifier(false);
  MapController controller = MapController(
    initMapWithUserPosition: true,
  );
  StreamController<List<SearchInfo>> streamSuggestion;
  Future<List<SearchInfo>> _futureSuggestionAddress;
  final TextEditingController textEditingController = TextEditingController();
  String oldText = "";

  @override
  void initState() {
    super.initState();
    streamSuggestion = StreamController();

    /// to wait map initialize and should activate advanced picker
    Future.delayed(Duration(seconds: 5), () async {
      controller.advancedPositionPicker();
    });
    textEditingController.addListener(onChanged);
  }

  @override
  void dispose() {
    textEditingController.removeListener(onChanged);
    super.dispose();
  }

  void onChanged() {
    final v = textEditingController.text;
    if (v.length % 3 == 0 && oldText != v) {
      oldText = v;
      Future.delayed(Duration(seconds: 3), () async {
        notifierAutoCompletion.value = true;
        _futureSuggestionAddress = addressSuggestion(
          v,
          limitInformation: 5,
        );
        _futureSuggestionAddress.then((value) {
          streamSuggestion.sink.add(value);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: TextField(
          controller: textEditingController,
          onChanged: (v) async {
            if (v.isEmpty) {
              notifierAutoCompletion.value = false;
              await streamSuggestion.close();
              setState(() {
                streamSuggestion = StreamController();
              });
            }
          },
          onEditingComplete: () async {
            notifierAutoCompletion.value = false;
            await streamSuggestion.close();
            setState(() {
              streamSuggestion = StreamController();
            });
          },
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.search,
              color: Colors.black,
            ),
            focusColor: Colors.black,
            filled: true,
            hintText: "search",
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            fillColor: Colors.grey[300],
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          OSMFlutter(
            controller: controller,
            showDefaultInfoWindow: false,
            useSecureURL: true,
            onGeoPointClicked: (geoPoint) {},
          ),
          Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            height: MediaQuery.of(context).size.height / 4,
            child: ValueListenableBuilder<bool>(
              valueListenable: notifierAutoCompletion,
              builder: (ctx, isVisible, child) {
                if (isVisible) {
                  return child;
                }
                return Container();
              },
              child: StreamBuilder<List<SearchInfo>>(
                stream: streamSuggestion.stream,
                builder: (ctx, snap) {
                  if (snap.hasData) {
                    return Card(
                      child: ListView.builder(
                        itemExtent: 50.0,
                        itemBuilder: (ctx, index) {
                          return ListTile(
                            title: Text(
                              snap.data[index].address.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                            ),
                            onTap: () {},
                          );
                        },
                        itemCount: snap.data.length,
                      ),
                    );
                  } else if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  return Container();
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          GeoPoint p = await controller.selectAdvancedPositionPicker();
          Navigator.pop(context, p);
        },
        child: Icon(Icons.arrow_forward),
      ),
    );
  }
}
