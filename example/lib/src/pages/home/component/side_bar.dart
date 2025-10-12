import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin_example/src/common/router_config.dart';
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class SideBar extends StatelessWidget {
  const SideBar({super.key, this.width = 100});
  final double width;
  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        child: FSidebar(
          width: width,
          traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
          style: (style) => style.copyWith(
            constraints: BoxConstraints.expand(
              width: width,
            ),
            decoration: BoxDecoration(
              color: FTheme.of(context).colors.background,
            ),
          ),
          children: [
            SizedBox(height: MediaQuery.viewPaddingOf(context).top),
            FItem(
              onPress: () {
                context.router.pushSearch();
              },
              title: const Text("search example"),
            ),
            FItem(
              onPress: () {
                context.router.pushHook();
              },
              title: const Text("map with hook example"),
            ),
            PointerInterceptor(
              child: FItem(
                onPress: () async {
                  await context.router.pushOldHome();
                },
                title: const Text("old home example"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
