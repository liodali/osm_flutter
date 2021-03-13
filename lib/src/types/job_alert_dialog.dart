import 'package:flutter/material.dart';

class JobAlertDialog extends StatefulWidget {
  final VoidCallback? callback;

  JobAlertDialog({this.callback});

  @override
  State<StatefulWidget> createState() => _JobAlertDialogState();
}

class _JobAlertDialogState extends State<JobAlertDialog> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      widget.callback!();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          Text("Wait Please"),
        ],
      ),
    );
  }
}
