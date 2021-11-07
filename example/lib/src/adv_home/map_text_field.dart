import 'package:flutter/material.dart';

class MapTextField extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final TextStyle? textStyle;
  final VoidCallback? onTap;
  final Widget? prefixWidget;
  final TextEditingController textController;
  final Key? textKey;

  const MapTextField({
    Key? key,
    this.textKey,
    this.hintText,
    this.labelText,
    this.textStyle,
    this.onTap,
    this.prefixWidget,
    required this.textController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textController,
      style: textStyle,
      onTap: onTap,
      decoration: InputDecoration(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: true,
        fillColor: Colors.grey[400],
        labelText: labelText,
        hintText: hintText,
        contentPadding: EdgeInsets.symmetric(
          vertical: 3.0,
          horizontal: 5.0,
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(
            5.0,
          ),
        ),
        prefixIcon: Chip(
          label: const Icon(
            Icons.search,
            color: Colors.black54,
          ),
          labelPadding: EdgeInsets.zero,
          backgroundColor: Colors.grey,
        ),
      ),
      maxLines: 1,
    );
  }
}
