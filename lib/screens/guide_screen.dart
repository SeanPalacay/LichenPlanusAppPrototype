// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class UserGuide extends StatelessWidget {
  List items = [];
  int section = -1;
  UserGuide({super.key, required this.items, required this.section});
  final List _sections = ["CLOSE", "USER UPLOAD", "CROPPER", "RESULTS"];
  int _activeIndex = 0;
  int activeSectionIndex = 0;

  List<List<int>> itemsColor = [
    [0, 14, 14],
    [-7, 4, 14],
    [14, 14, 14],
    [0, 14, 14],
  ];

  final controller1 = CarouselController();
  final controller2 = CarouselController();

  List<int> sectionitems = [0, 1, 5, 10, 15];
  bool inTransition = false;
  @override
  Widget build(BuildContext context) {
    _activeIndex = sectionitems[section];
    activeSectionIndex = section;
    return ElevatedButton(
      onPressed: () => showUserGuide(context),
      style: ElevatedButton.styleFrom(
          elevation: 5,
          backgroundColor: Color.fromARGB(255, 241, 167, 98),
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(15)),
      child: const Text(
        '?',
        style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }

  void showUserGuide(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Color.fromARGB(255, 236, 228, 228),
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'USER MANUAL',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 2),
                      ),
                      const SizedBox(height: 12),
                      CarouselSlider(
                        carouselController: controller1,
                        options: CarouselOptions(
                            height: 600,
                            viewportFraction: 1,
                            initialPage: _activeIndex,
                            enableInfiniteScroll: false,
                            onPageChanged: (index, reason) => setState(() {
                                  if (!inTransition) {
                                    inTransition = true;
                                    if (sectionitems.contains(index)) {
                                      if (sectionitems.indexOf(index) ==
                                          sectionitems.length - 1) {
                                        controller2.jumpToPage(0);
                                      } else {
                                        controller2.jumpToPage(
                                            sectionitems.indexOf(index));
                                      }
                                    }
                                    if (index < sectionitems.length ||
                                        index != 0) {
                                      if (sectionitems.contains(index + 1)) {
                                        controller2.jumpToPage(
                                            sectionitems.indexOf(index + 1) -
                                                1);
                                      }
                                    }
                                    inTransition = false;
                                  }
                                  _activeIndex = index;
                                })),
                        items: items.map((i) {
                          return Builder(
                            builder: (BuildContext context) {
                              return SizedBox(
                                width: MediaQuery.of(context).size.width,
                                child: FittedBox(
                                    fit: BoxFit.contain, child: Image.asset(i)),
                              );
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      SizedBox(
                        width: 200,
                        child: FittedBox(
                            child: AnimatedSmoothIndicator(
                          activeIndex: _activeIndex,
                          count: items.length,
                          effect: WormEffect(
                            activeDotColor: activeSectionIndex == 0
                                ? const Color.fromARGB(255, 116, 56, 56)
                                : Color.fromARGB(
                                    255,
                                    87 - itemsColor[activeSectionIndex][0],
                                    87 - itemsColor[activeSectionIndex][1],
                                    87 - itemsColor[activeSectionIndex][2]),
                          ),
                        )),
                      ),
                      const SizedBox(height: 12),
                      CarouselSlider(
                        carouselController: controller2,
                        options: CarouselOptions(
                            height: 45.0,
                            viewportFraction: 0.55,
                            enlargeCenterPage: true,
                            initialPage: activeSectionIndex,
                            enlargeFactor: 0.2,
                            onPageChanged: (index, reason) => setState(() {
                                  if (!inTransition) {
                                    inTransition = true;
                                    controller1.jumpToPage(sectionitems[index]);
                                    inTransition = false;
                                  }
                                  activeSectionIndex = index;
                                  _activeIndex = sectionitems[index];
                                })),
                        items: _sections.map((i) {
                          return Builder(
                            builder: (BuildContext context) {
                              return GestureDetector(
                                  onTap: () => i == "CLOSE" &&
                                          _sections[activeSectionIndex] == i
                                      ? Navigator.of(context).pop()
                                      : () => {},
                                  child: Container(
                                      width: MediaQuery.of(context).size.width,
                                      // margin:
                                      //     const EdgeInsets.symmetric(horizontal: 0.0),
                                      decoration: BoxDecoration(
                                          color: i == "CLOSE"
                                              ? const Color.fromARGB(
                                                  255, 116, 56, 56)
                                              : Color.fromARGB(
                                                  _sections[activeSectionIndex] ==
                                                          i
                                                      ? 255
                                                      : 174,
                                                  87 -
                                                      itemsColor[activeSectionIndex]
                                                          [0],
                                                  87 -
                                                      itemsColor[activeSectionIndex]
                                                          [1],
                                                  87 -
                                                      itemsColor[activeSectionIndex]
                                                          [2]),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Center(
                                        child: Text(
                                          i,
                                          style: const TextStyle(
                                              fontSize: 18.0,
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: 2,
                                              color: Colors.white),
                                        ),
                                      )));
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          });
        });
  }
}
