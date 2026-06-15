import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/models/map_style_configuration.dart';
import 'package:forui/forui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ExampleMapStyleConfiguration _config =
      ExampleMapStyleConfiguration.instance;

  double _sliderValueToNormalized(double value, double min, double max) {
    return ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();
  }

  double _normalizedToSliderValue(double value, double min, double max) {
    return min + (value.clamp(0.0, 1.0).toDouble() * (max - min));
  }

  String _colorLabel(Color color) {
    switch (color) {
      case Colors.red:
        return 'Red';
      case Colors.blueAccent:
        return 'Blue';
      case Colors.green:
        return 'Green';
      case Colors.orange:
        return 'Orange';
      case Colors.purple:
        return 'Purple';
      case Colors.white:
        return 'White';
      case Colors.black:
        return 'Black';
      default:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Settings'),
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            FCard(
              title: const Text('Marker Styling'),
              subtitle: const Text('Choose how example markers should look.'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Marker style'),
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
                                children: [
                                  FTile(
                                    title: const Text('Icon marker'),
                                    onPress: () => setState(
                                      () => _config.markerStyle =
                                          ExampleMarkerStyle.icon,
                                    ),
                                  ),
                                  FTile(
                                    title: const Text('Image marker'),
                                    onPress: () => setState(
                                      () => _config.markerStyle =
                                          ExampleMarkerStyle.image,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            child: Text(
                              _config.markerStyle == ExampleMarkerStyle.icon
                                  ? 'Icon marker'
                                  : 'Image marker',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_config.markerStyle == ExampleMarkerStyle.icon) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Marker icon'),
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
                                  children: ExampleMapStyleConfiguration
                                      .markerIconOptions
                                      .map(
                                        (iconData) => FTile.raw(
                                          child: Row(
                                            children: [
                                              Icon(iconData, size: 18),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: Text(
                                                  iconData.codePoint ==
                                                          Icons
                                                              .person_pin
                                                              .codePoint
                                                      ? 'Person pin'
                                                      : iconData.codePoint ==
                                                            Icons
                                                                .location_on
                                                                .codePoint
                                                      ? 'Location on'
                                                      : 'Place',
                                                ),
                                              ),
                                            ],
                                          ),
                                          onPress: () => setState(
                                            () => _config.markerIcon = iconData,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_config.markerIcon, size: 18),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      _config.markerIcon.codePoint ==
                                              Icons.person_pin.codePoint
                                          ? 'Person pin'
                                          : _config.markerIcon.codePoint ==
                                                Icons.location_on.codePoint
                                          ? 'Location on'
                                          : 'Place',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Marker color'),
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
                                  children: ExampleMapStyleConfiguration
                                      .roadColorOptions
                                      .map(
                                        (color) => FTile.raw(
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.black12,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: Text(_colorLabel(color)),
                                              ),
                                            ],
                                          ),
                                          onPress: () => setState(
                                            () =>
                                                _config.markerIconColor = color,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],

                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: _config.markerIconColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      _colorLabel(_config.markerIconColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Marker size: ${_config.markerIconSize.toStringAsFixed(0)}',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FSlider(
                        control: FSliderControl.liftedContinuous(
                          interaction: FSliderInteraction.tapAndSlideThumb,
                          thumb: FSliderActiveThumb.max,
                          value: FSliderValue(
                            max: _sliderValueToNormalized(
                              _config.markerIconSize,
                              24,
                              80,
                            ),
                          ),
                          stepPercentage: 4 / (80 - 24),
                          onChange: (value) {
                            setState(() {
                              _config.markerIconSize = _normalizedToSliderValue(
                                value.max,
                                24,
                                80,
                              );
                            });
                          },
                        ),
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Marker image'),
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
                                  children: ExampleMapStyleConfiguration
                                      .markerAssetOptions
                                      .map(
                                        (path) => FTile.raw(
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: Image.asset(
                                                  path,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: Text(
                                                  path.split('/').last,
                                                ),
                                              ),
                                            ],
                                          ),
                                          onPress: () => setState(
                                            () =>
                                                _config.markerAssetPath = path,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],

                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Image.asset(
                                      _config.markerAssetPath,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      _config.markerAssetPath.split('/').last,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Image width: ${_config.markerAssetWidth.toStringAsFixed(0)}',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FSlider(
                        control: FSliderControl.liftedContinuous(
                          interaction: FSliderInteraction.tapAndSlideThumb,
                          thumb: FSliderActiveThumb.max,
                          value: FSliderValue(
                            max: _sliderValueToNormalized(
                              _config.markerAssetWidth,
                              20,
                              64,
                            ),
                          ),
                          stepPercentage: 4 / (64 - 20),
                          onChange: (value) {
                            setState(() {
                              _config.markerAssetWidth =
                                  _normalizedToSliderValue(
                                    value.max,
                                    20,
                                    64,
                                  );
                            });
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Image height: ${_config.markerAssetHeight.toStringAsFixed(0)}',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FSlider(
                        control: FSliderControl.liftedContinuous(
                          interaction: FSliderInteraction.tapAndSlideThumb,
                          thumb: FSliderActiveThumb.max,
                          value: FSliderValue(
                            max: _sliderValueToNormalized(
                              _config.markerAssetHeight,
                              24,
                              96,
                            ),
                          ),
                          stepPercentage: 4 / (96 - 24),
                          onChange: (value) {
                            setState(() {
                              _config.markerAssetHeight =
                                  _normalizedToSliderValue(
                                    value.max,
                                    24,
                                    96,
                                  );
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Preview',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: _config.buildMarkerIcon(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FCard(
                title: const Text('Road Styling'),
                subtitle: const Text(
                  'Configure the route line color, border, and road type.',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Road color'),
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
                                  children: ExampleMapStyleConfiguration
                                      .roadColorOptions
                                      .map(
                                        (color) => FTile.raw(
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.black12,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: Text(_colorLabel(color)),
                                              ),
                                            ],
                                          ),
                                          onPress: () => setState(
                                            () => _config.roadColor = color,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: _config.roadColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(_colorLabel(_config.roadColor)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FSwitch(
                        label: const Text('Show road border'),
                        value: _config.hasRoadBorder,
                        onChange: (value) {
                          setState(() {
                            _config.hasRoadBorder = value;
                          });
                        },
                      ),
                    ),
                    if (_config.hasRoadBorder) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Road border color'),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: FPopoverMenu.tiles(
                                builder: (context, controller, child) =>
                                    FButton(
                                      variant: .outline,
                                      onPress: controller.toggle,
                                      child: child,
                                    ),
                                menu: [
                                  FTileGroup(
                                    children: ExampleMapStyleConfiguration
                                        .roadBorderColorOptions
                                        .map(
                                          (color) => FTile.raw(
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.black12,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8,
                                                      ),
                                                  child: Text(
                                                    _colorLabel(color),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onPress: () => setState(
                                              () => _config.roadBorderColor =
                                                  color,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: _config.roadBorderColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        _colorLabel(_config.roadBorderColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Border width: ${_config.roadBorderWidth.toStringAsFixed(0)}',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FSlider(
                          control: FSliderControl.liftedContinuous(
                            interaction: FSliderInteraction.tapAndSlideThumb,
                            thumb: FSliderActiveThumb.max,
                            value: FSliderValue(
                              max: _sliderValueToNormalized(
                                _config.roadBorderWidth,
                                2,
                                18,
                              ),
                            ),
                            stepPercentage: 2 / (18 - 2),
                            onChange: (value) {
                              setState(() {
                                _config.roadBorderWidth =
                                    _normalizedToSliderValue(
                                      value.max,
                                      2,
                                      18,
                                    );
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Road type'),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: RoadTypeSelector(
                              isRoadTypeDotted: _config.isRoadTypeDotted,
                              onRoadTypeDottedChanged:
                                  (
                                    roadType,
                                    dotted,
                                  ) => setState(
                                    () => _config.setRoadTypeDotted(
                                      roadType,
                                      dotted,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FCard(
                title: const Text('Search Settings'),
                subtitle: const Text('Language used for location suggestions.'),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Suggestion locale'),
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
                              children: ExampleMapStyleConfiguration
                                  .supportedSearchLocales
                                  .entries
                                  .map(
                                    (entry) => FTile(
                                      title: Text(entry.value),
                                      onPress: () => setState(
                                        () => _config.searchLocale = entry.key,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          child: Text(
                            ExampleMapStyleConfiguration
                                    .supportedSearchLocales[_config
                                    .searchLocale] ??
                                'English',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoadTypeSelector extends StatelessWidget {
  const RoadTypeSelector({
    super.key,
    required this.isRoadTypeDotted,
    required this.onRoadTypeDottedChanged,
  });

  final bool Function(RoadType roadType) isRoadTypeDotted;
  final void Function(RoadType roadType, bool dotted) onRoadTypeDottedChanged;

  @override
  Widget build(BuildContext context) {
    return FTileGroup(
      children: ExampleMapStyleConfiguration.roadTypeOptions
          .map(
            (roadType) => FTile(
              title: Text(
                ExampleMapStyleConfiguration.roadTypeLabel(roadType),
              ),
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FButton(
                      variant: .outline,
                      selected: isRoadTypeDotted(roadType),
                      mainAxisSize: MainAxisSize.min,
                      onPress: () => onRoadTypeDottedChanged(
                        roadType,
                        true,
                      ),
                      child: const Text('Dotted'),
                    ),
                  ),
                  FButton(
                    variant: .outline,
                    selected: !isRoadTypeDotted(roadType),
                    mainAxisSize: MainAxisSize.min,
                    onPress: () => onRoadTypeDottedChanged(
                      roadType,
                      false,
                    ),
                    child: const Text('Solid'),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
