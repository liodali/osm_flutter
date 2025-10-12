import 'package:flutter/material.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' show MapController;
import 'package:forui/forui.dart';

class SearchInMap extends StatefulWidget {
  final MapController controller;

  const SearchInMap({
    super.key,
    required this.controller,
  });
  @override
  State<StatefulWidget> createState() => _SearchInMapState();
}

class _SearchInMapState extends State<SearchInMap> {
  final textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    textController.addListener(onTextChanged);
  }

  void onTextChanged() {}
  @override
  void dispose() {
    textController.removeListener(onTextChanged);
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FTextField(
      controller: textController,
      onTap: () {},
      maxLines: 1,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      hint: "search for place,location,restaurant,etc ..",
      style: (styleTextField) => styleTextField.copyWith(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: styleTextField.border.map(
          (border) => border.copyWith(
            borderSide: BorderSide(
              width: 0.5,
              color: FTheme.of(context).colors.border,
            ),
          ),
        ),
      ),
      prefixBuilder: (context, style, states) {
        return Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Icon(
            FIcons.search,
            size: 18,
            color: FTheme.of(context).colors.foreground,
          ),
        );
      },
    );
  }
}
