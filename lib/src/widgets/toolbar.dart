import 'package:candlesticks_plus/src/theme/theme_data.dart';
import 'package:candlesticks_plus/src/widgets/toolbar_action.dart';
import 'package:flutter/material.dart';

class ToolBar extends StatelessWidget {
  const ToolBar({
    Key? key,
    required this.onZoomInPressed,
    required this.onZoomOutPressed,
    required this.children,
    required this.showZoomButtons,
  }) : super(key: key);

  final void Function() onZoomInPressed;
  final void Function() onZoomOutPressed;
  final List<Widget> children;
  final bool showZoomButtons;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).background,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Row(
          children: [
            Visibility(
              visible: showZoomButtons,
              child: ToolBarAction(
                onPressed: onZoomOutPressed,
                child: Icon(
                  Icons.remove,
                  color: Theme.of(context).grayColor,
                ),
              ),
            ),
            Visibility(
              visible: showZoomButtons,
              child: ToolBarAction(
                onPressed: onZoomInPressed,
                child: Icon(
                  Icons.add,
                  color: Theme.of(context).grayColor,
                ),
              ),
            ),
            ...children
          ],
        ),
      ),
    );
  }
}
