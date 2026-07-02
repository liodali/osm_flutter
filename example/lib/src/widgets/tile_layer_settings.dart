import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin_example/src/models/map_style_configuration.dart';
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class TileLayerSettings extends StatefulWidget {
  const TileLayerSettings({super.key});

  @override
  State<TileLayerSettings> createState() => _TileLayerSettingsState();
}

class _TileLayerSettingsState extends State<TileLayerSettings> {
  final ExampleMapStyleConfiguration _config =
      ExampleMapStyleConfiguration.instance;

  void _onConfigChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _config.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    _config.removeListener(_onConfigChanged);
    super.dispose();
  }

  Future<void> _showAddTileDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final extensionController = TextEditingController(text: '.png');
    final tileSizeController = TextEditingController(text: '256');
    final maxZoomController = TextEditingController(text: '19');

    await showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        style: style,
        animation: animation,
        title: const Text('Add custom tile'),
        body: PointerInterceptor(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FTextField(
                control: FTextFieldControl.managed(
                  controller: nameController,
                ),
                hint: 'Tile name',
                autofocus: true,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FTextField(
                  control: FTextFieldControl.managed(
                    controller: urlController,
                  ),
                  hint: 'Tile URL (e.g. https://example.com/{z}/{x}/{y})',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FTextField(
                  control: FTextFieldControl.managed(
                    controller: extensionController,
                  ),
                  hint: 'Extension (e.g. .png)',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FTextField(
                  control: FTextFieldControl.managed(
                    controller: tileSizeController,
                  ),
                  hint: 'Tile size',
                  keyboardType: TextInputType.number,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FTextField(
                  control: FTextFieldControl.managed(
                    controller: maxZoomController,
                  ),
                  hint: 'Max zoom level',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FButton(
            variant: .ghost,
            onPress: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FButton(
            onPress: () {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              if (name.isEmpty || url.isEmpty) {
                return;
              }
              final tileSize = int.tryParse(tileSizeController.text) ?? 256;
              final maxZoom = int.tryParse(maxZoomController.text) ?? 19;
              _config.addCustomTile(
                name: name,
                url: url,
                tileExtension: extensionController.text.trim(),
                tileSize: tileSize,
                maxZoomLevel: maxZoom,
              );
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableTiles = _config.availableTiles;
    final customTiles = _config.customTiles;
    final canRemove = availableTiles.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Default tile'),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FPopoverMenu.tiles(
            builder: (context, controller, child) => FButton(
              variant: .outline,
              onPress: controller.toggle,
              child: child,
            ),
            menu: [
              FTileGroup(
                children: availableTiles
                    .map(
                      (tile) => FTile(
                        prefix: Icon(tile.icon),
                        title: Text(tile.name),
                        onPress: () => setState(
                          () => _config.defaultTileId = tile.id,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_config.defaultTile.icon, size: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(_config.defaultTile.name),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Custom tiles',
                  style: FTheme.of(context).typography.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FButton(
                variant: .outline,
                onPress: () => _showAddTileDialog(context),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
        if (customTiles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No custom tiles. Built-in tiles are always available.',
              style: FTheme.of(context).typography.sm.copyWith(
                color: FTheme.of(context).colors.mutedForeground,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FTileGroup(
              children: customTiles
                  .map(
                    (tile) => FTile(
                      prefix: Icon(tile.icon),
                      title: Text(tile.name),
                      suffix: FButton(
                        variant: .ghost,
                        onPress: canRemove
                            ? () => _config.removeCustomTile(tile.id)
                            : null,
                        child: const Icon(FIcons.trash),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
