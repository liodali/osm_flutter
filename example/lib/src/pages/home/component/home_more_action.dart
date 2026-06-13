import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/models/map_widget_configuration.dart'
    show MoreActionConfig;
import 'package:flutter_osm_plugin_example/src/pages/home/main_example.dart'
    show ActivationUserLocation, DirectionRouteLocation;
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class HomeMoreAction extends StatelessWidget {
  const HomeMoreAction({
    super.key,
    required this.configuration,
  });
  final MoreActionConfig configuration;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return HomeMoreActionDesktop(
        configuration: configuration,
      );
    }
    return PointerInterceptor(
      child: HomeMoreActionMobile(
        configuration: configuration,
      ),
    );
  }
}

class HomeMoreActionDesktop extends StatelessWidget {
  const HomeMoreActionDesktop({super.key, required this.configuration});
  final MoreActionConfig configuration;

  @override
  Widget build(BuildContext context) {
    return FPopoverMenu(
      menuAnchor: Alignment.topRight,
      childAnchor: Alignment.bottomRight,
      menu: [
        FItemGroup(
          children: [],
        ),
      ],
      builder: (context, controller, child) => FHeaderAction(
        icon: const Icon(FIcons.cog),
        onPress: controller.toggle,
      ),
    );
  }
}

class HomeMoreActionMobile extends StatefulWidget {
  const HomeMoreActionMobile({
    super.key,
    required this.configuration,
  });
  final MoreActionConfig configuration;

  @override
  State<HomeMoreActionMobile> createState() => _HomeMoreActionMobileState();
}

class _HomeMoreActionMobileState extends State<HomeMoreActionMobile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
    });
    _controller.toggle();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) => FCollapsible(
            value: _animation.value,
            child: Stack(
              children: [
                Positioned(
                  bottom: 32,
                  right: 15,
                  child: ActivationUserLocation(
                    controller: widget.configuration.controller,
                    trackingNotifier: widget.configuration.trackingNotifier,
                    userLocation: widget.configuration.userLocationNotifier,
                    userLocationIcon: widget.configuration.userLocationIcon,
                  ),
                ),
                Positioned(
                  bottom: 148,
                  right: 15,
                  child: FTappable(
                    onPress: () async {
                      Future.forEach(widget.configuration.geos.value, (
                        GeoPoint element,
                      ) async {
                        await widget.configuration.controller.removeMarker(
                          element,
                        );
                        await Future.delayed(
                          const Duration(milliseconds: 100),
                        );
                      }).then((_) {
                        widget.configuration.geos.value.clear();
                      });
                    },
                    child: const Icon(FIcons.trash),
                  ),
                ),
                Positioned(
                  bottom: 92,
                  right: 15,
                  child: DirectionRouteLocation(
                    controller: widget.configuration.controller,
                  ),
                ),
              ],
            ),
          ),
        ),
        FButton(
          onPress: _toggle,
          child: Icon(
            _expanded ? FIcons.settings : FIcons.x,
          ),
        ),
      ],
    );
  }
}
