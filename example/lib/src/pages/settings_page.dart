import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Settings'),
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FCard(
              title: const Text('Map Settings'),
              subtitle: const Text('Configure default map behavior.'),
              child: Column(
                children: [
                  const FTextField(
                    label: Text('Default Zoom Level'),
                    hint: '16',
                  ),
                  const SizedBox(height: 10),
                  const FTextField(
                    label: Text('Default Latitude'),
                    hint: '47.4358055',
                  ),
                  const SizedBox(height: 10),
                  const FTextField(
                    label: Text('Default Longitude'),
                    hint: '8.4737324',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FCard(
              title: const Text('Tile Layer'),
              subtitle: const Text('Select the default tile source.'),
              child: Column(
                children: [
                  FItem(
                    onPress: () {},
                    title: const Text('OpenStreetMap (default)'),
                  ),
                  FItem(
                    onPress: () {},
                    title: const Text('Cycle Map'),
                  ),
                  FItem(
                    onPress: () {},
                    title: const Text('Public Transport'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
