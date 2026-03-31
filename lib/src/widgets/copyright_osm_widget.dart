import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CopyrightOSMWidget extends StatelessWidget {
  final String internationalContributorName;

  const CopyrightOSMWidget({
    this.internationalContributorName = "contributors",
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      height: 24,
      padding: const EdgeInsets.all(3.0),
      child: Text.rich(
        TextSpan(
          text: "© ",
          children: [
            TextSpan(
              text: "OpenStreetMap",
              style: const TextStyle(
                color: Colors.blue,
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
                    color: Colors.black,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            )
          ],
        ),
        style: const TextStyle(
          fontSize: 9,
        ),
      ),
    );
  }
}
