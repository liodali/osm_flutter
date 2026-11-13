import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

class const CopyrightOSMWidget({
  this.internationalContributorName = "contributors",
  super.key,
}) extends StatelessWidget {
  final String internationalContributorName;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE0E0E0),
      height: 24,
      padding: const EdgeInsets.all(3.0),
      child: Text.rich(
        TextSpan(
          text: "© ",
          children: [
            TextSpan(
              text: "OpenStreetMap",
              style: const TextStyle(
                color: Color(0xFF2196F3),
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  try {
                    await launchUrlString(
                      'https://www.openstreetmap.org/copyright',
                      mode: LaunchMode.externalApplication,
                    );
                  } on PlatformException catch (e, trace) {
                    debugPrint(e.toString());
                    debugPrint(trace.toString());
                  }
                },
              children: [
                TextSpan(
                  text: " $internationalContributorName",
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ],
        ),
        style: const TextStyle(fontSize: 9),
      ),
    );
  }
}
