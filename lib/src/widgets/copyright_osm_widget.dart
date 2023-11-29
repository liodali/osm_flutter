import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CopyrightOSMWidget extends StatelessWidget {
  final String internationalContributorName;

  CopyrightOSMWidget({
    this.internationalContributorName = "contributors",
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      height: 24,
      padding: EdgeInsets.all(3.0),
      child: Text.rich(
        TextSpan(
          text: "© ",
          children: [
            TextSpan(
              text: "OpenStreetMap",
              style: TextStyle(
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
                  } on PlatformException {}
                },
              children: [
                TextSpan(
                  text: " $internationalContributorName",
                  style: TextStyle(
                    color: Colors.black,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            )
          ],
        ),
        style: TextStyle(
          fontSize: 9,
        ),
      ),
    );
  }
}
