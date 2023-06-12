// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:prototype1/constants.dart';

// ignore: must_be_immutable
class LoadingScreen extends StatelessWidget {
  bool confirmed;
  LoadingScreen({super.key, required this.confirmed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color.fromARGB(255, 252, 245, 245),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/prototype1.png",
              width: 100,
              height: 100,
            ),
            SizedBox(
              height: 10,
            ),
            SizedBox(
              width: 150,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                tween: Tween<double>(begin: 0, end: confirmed ? 1 : 0.6),
                builder: (context, value, child) => LinearProgressIndicator(
                    value: value,
                    color: const Color.fromARGB(255, 133, 99, 99)),
              ),
            ),
            SizedBox(
              height: 10,
            ),
            confirmed
                ? Text(
                    "Done.",
                    style: kHeadSubtitleTextStyle,
                  )
                : Text(
                    "Running Detections...",
                    style: kHeadSubtitleTextStyle,
                  )
          ],
        )));
  }
}
