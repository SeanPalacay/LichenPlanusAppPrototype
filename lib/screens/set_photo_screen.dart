// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/common_buttons.dart';
import '../constants.dart';
import 'select_photo_options_screen.dart';
import 'loading_screen.dart';
import 'package:prototype1/interpreter/classifier.dart';
import 'package:image/image.dart' as img;
import 'package:prototype1/interpreter/recognitions.dart';
import 'guide_screen.dart';

// ignore: must_be_immutable
class SetPhotoScreen extends StatefulWidget {
  const SetPhotoScreen({super.key});

  static const id = 'set_photo_screen';

  @override
  State<SetPhotoScreen> createState() => _SetPhotoScreenState();
}

class _SetPhotoScreenState extends State<SetPhotoScreen> {
  File? _image;
  File? _labeled;
  String? _predictedLabel;
  String? _accuracy;
  List _guideImages = [];
  int _section = 0;
  final _description = [
    RichText(
        textAlign: TextAlign.justify,
        text: const TextSpan(
            style: TextStyle(
                color: Colors.black,
                height: 2,
                fontSize: 16,
                fontWeight: FontWeight.w300),
            children: <TextSpan>[
              TextSpan(
                  text: "Linear Lichen Planus",
                  style: TextStyle(fontWeight: FontWeight.w400)),
              TextSpan(
                  text:
                      " (LLP) is a rare form of lichen planus skin rash that affects the skin and/or the mouth. LLP affected people develop an itchy, reddish-purple, flat-topped papules (bumps) in a linear distribution along the Blaschko's line. It can occur anywhere on the body, but it is more commonly found on the limbs, trunk, or the patient's genital area."),
            ])),
    RichText(
        textAlign: TextAlign.justify,
        text: const TextSpan(
            style: TextStyle(
                color: Colors.black,
                height: 2,
                fontSize: 16,
                fontWeight: FontWeight.w300),
            children: <TextSpan>[
              TextSpan(
                  text: "Annular Lichen Planus",
                  style: TextStyle(fontWeight: FontWeight.w400)),
              TextSpan(
                  text:
                      " (ALP) is a rare form of lichen planus that affects the skin and/or the mouth. ALP affected people develop ring-shaped, slightly raised, red or purple lesions with no central atrophy (tissue breakdown)."),
              TextSpan(
                  text:
                      "The rings may be solitary or multiple and can occur anywhere on the patient's body, but are commonly found on the arms, legs and the trunk.")
            ])),
    RichText(
        textAlign: TextAlign.justify,
        text: const TextSpan(
            style: TextStyle(
                color: Colors.black,
                height: 2,
                fontSize: 16,
                fontWeight: FontWeight.w300),
            children: <TextSpan>[
              TextSpan(
                  text: "Hypertrophic Lichen Planus",
                  style: TextStyle(fontWeight: FontWeight.w400)),
              TextSpan(
                  text:
                      " (HLP) is a common inflammatory skin condition that can affect different parts of the body, including the skin, mouth, nails, and hair. HLP typically appears as thick, raised, scaly or wart-like lesions on the skin. This lichen planus rash type is most commonly found on the shins, ankle, and lower back, but can also occur anywhere on the body."),
            ]))
  ];

  final _treatments = RichText(
      textAlign: TextAlign.justify,
      text: const TextSpan(
          style: TextStyle(
              color: Colors.black,
              height: 2,
              fontSize: 16,
              fontWeight: FontWeight.w300),
          children: <TextSpan>[
            TextSpan(
                text:
                    'There is no cure for lichen planus. The rashes are often observed to just go away on its own. If the symptoms are bothersome, dermatologists suggest the following treatments to bring relief and speed the healing process.\n\n'),
            TextSpan(
                text: 'Antihistamines',
                style: TextStyle(fontWeight: FontWeight.w400)),
            TextSpan(text: ': Pills the help alleviate itching.\n'),
            TextSpan(
                text: 'Topical Corticosteroid',
                style: TextStyle(fontWeight: FontWeight.w400)),
            TextSpan(
                text:
                    ' : Cream or ointments that are applied to the skin to reduce swelling and redness.\n'),
            TextSpan(
                text: 'Corticosteroids',
                style: TextStyle(fontWeight: FontWeight.w400)),
            TextSpan(
                text:
                    ' : Pills or shots that help when lichen planus lasts a long time and/or a patient has many bumps or sores.\n'),
            TextSpan(
                text: 'PUVA Therapy',
                style: TextStyle(fontWeight: FontWeight.w400)),
            TextSpan(
                text:
                    ' : A type of light treatment that can help clear the skin.\n'),
            TextSpan(
                text: 'Retinoic acid',
                style: TextStyle(fontWeight: FontWeight.w400)),
            TextSpan(
                text:
                    ' : Applied to the skin or given as a pill to clear the skin.\n'),
            TextSpan(
                text: 'Immunosuppressants',
                style: TextStyle(fontWeight: FontWeight.w400)),
            TextSpan(
                text:
                    ' : These medications work by suppressing the immune response that causes lichen planus.\n\n'),
            TextSpan(
                text:
                    'They may be used in severe cases or when other treatments have failed.\n\nWhen lichen planus develops in the mouth, it often does not cause pain or other symptoms. If this is the case, treatments may not be necessary. When the rashes cause pain, burning, redness, blister, sores, or ulcers, it can be treated. Some medicine is applied on the sores while other medicines come in a pill form.\n\n'),
          ]));

  Classifier? _classifier;
  double? _imageDisplaySize;
  img.BitmapFont? _robotoFont;
  bool _isLoading = false;
  bool _confirmed = false;
  // TFLite Features //
  //  Initialization
  @override
  void initState() {
    super.initState();
    _classifier = Classifier();
    _loadFonts();
    _initImages();
  }

  Future _initImages() async {
    // >> To get paths you need these 2 lines
    final manifestContent = await rootBundle.loadString('AssetManifest.json');

    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    // >> To get paths you need these 2 lines

    final imagePaths = manifestMap.keys
        .where((String key) => key.contains('use_guide/'))
        .toList();

    setState(() {
      _guideImages = imagePaths;
    });
  }

  Future _loadFonts() async {
    ByteData fontData = await rootBundle.load("assets/roboto.zip");

    setState(() {
      _robotoFont = img.BitmapFont.fromZip(fontData.buffer.asUint8List());
    });
  }

  Future _classifyImage(File file) async {
    int THRESHOLD = 30;
    int IMAGE_SIZE = 224;
    var image = img.decodeImage(file.readAsBytesSync());
    // resize image
    var reduced = img.copyResize(image!,
        width: IMAGE_SIZE,
        height: IMAGE_SIZE,
        interpolation: img.Interpolation.cubic); // resiize]
    // reduced = img.copyRotate(reduced, 90);
    // reduced = img.flipVertical(reduced);
    // exit function if classifier object is not initialized
    if (_classifier == null) return;
    List<Recognition> recognitions = await _classifier!.predict(reduced);
    if (recognitions.isNotEmpty) {
      double score = recognitions[0].score;
      var value = (score * 100);
      if (value >= THRESHOLD) {
        for (int i = 0; i < recognitions.length; i++) {
          List location = [
            (recognitions[i].location!.left * (image!.width / reduced.width))
                .round(),
            (recognitions[i].location!.top * (image.height / reduced.height))
                .round(),
            (recognitions[i].location!.right * (image.width / reduced.width))
                .round(),
            (recognitions[i].location!.bottom * (image.height / reduced.height))
                .round()
          ];
          // get rid of out of bounds vertex locations
          for (int j = 0; j < location.length; j++) {
            location[j] = location[j] < 0 ? 0 : location[j];
            location[j] = (j + 1) % 2 != 0 && location[j] > image.width
                ? image.width
                : location[j];
            location[j] = (j + 1) % 2 == 0 && location[j] > image.height
                ? image.height
                : location[j];
          }
          if (recognitions[i].label == recognitions[0].label &&
              recognitions[i].score > 0.3) {
            // Draw Rect
            image = img.drawRect(image, location[0], location[1], location[2],
                location[3], 0xFF0000FF);
            // Label Detections
            image = img.drawString(
                image,
                _robotoFont!,
                location[0],
                location[3] > image.height - 24 ? location[1] : location[3],
                "${(recognitions[i].score * 100).toStringAsFixed(2)}%");
          }
        }
      }

      final jpg = img.encodeJpg(image!);
      File labeled = file.copySync("${file.path}(labeld).jpg");
      labeled.writeAsBytes(jpg);
      setState(() {
        if (value >= THRESHOLD) {
          _accuracy = value.toStringAsFixed(2).substring(0, 5);
          _predictedLabel = recognitions[0].label;
          _labeled = labeled;
          _imageDisplaySize = image!.height.toDouble() > 400
              ? image.height.toDouble()
              : 400.toDouble();
        } else {
          _accuracy = null;
          _predictedLabel = "Lichen Planus Not Detected";
          _labeled = null;
        }
      });
    } else {
      print("error no recognitions");
    }
  }
  ////////////////////////////////////////////

  Future _pickImage(ImageSource source) async {
    try {
      final take = await ImagePicker()
          .pickImage(source: source, maxHeight: 720, maxWidth: 480);
      if (take == null) return;
      File? image = File(take.path);
      image = await _cropImage(imageFile: image);
      if (image == null) return;
      setState(() {
        Navigator.of(context).pop();
        _isLoading = true;
      });
      await Future.delayed(const Duration(seconds: 1));
      await _classifyImage(image);
      setState(() {
        _confirmed = true;
        _section = 3;
      });
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isLoading = false;
        _confirmed = false;
        _image = image;
      });
    } on PlatformException catch (e) {
      print(e);
      Navigator.of(context).pop();
    }
  }

  Future<File?> _cropImage({required File imageFile}) async {
    CroppedFile? croppedImage =
        await ImageCropper().cropImage(sourcePath: imageFile.path);
    if (croppedImage == null) return null;
    return File(croppedImage.path);
  }

  void _showSelectPhotoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25.0),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.28,
          maxChildSize: 0.4,
          minChildSize: 0.28,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: SelectPhotoOptionsScreen(
                onTap: _pickImage,
              ),
            );
          }),
    );
  }

  void _showResultsDetails(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: const Color.fromARGB(255, 252, 245, 245),
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25.0),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
          initialChildSize:
              _imageDisplaySize! / MediaQuery.of(context).size.height + 0.1 <= 1
                  ? _imageDisplaySize! / MediaQuery.of(context).size.height +
                      0.1
                  : 0.95,
          maxChildSize: 1,
          minChildSize:
              _imageDisplaySize! / MediaQuery.of(context).size.height <= 1
                  ? _imageDisplaySize! / MediaQuery.of(context).size.height
                  : 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 25,
                    ),
                    const Text(
                      'DETECTIONS',
                      style: TextStyle(
                          color: Color.fromARGB(255, 129, 30, 30),
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 10),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    Container(
                      width: 400,
                      height: _imageDisplaySize! - 100,
                      decoration: BoxDecoration(
                          image: DecorationImage(
                              alignment: Alignment.center,
                              image: FileImage(_labeled!),
                              fit: BoxFit.contain)),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Text(
                      '$_predictedLabel',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color.fromARGB(255, 87, 69, 69)),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    const Text(
                      'Diagnosis',
                      textAlign: TextAlign.start,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Padding(
                        padding: const EdgeInsets.only(left: 25, right: 25),
                        child: _description[
                            _classifier!.labels.indexOf(_predictedLabel!)]),
                    const Padding(
                      padding: EdgeInsets.only(left: 25, right: 25),
                      child: Text(
                        '\nCOMMON DERMATOLOGICAL TREATMENTS FOR LICHEN PLANUS\n',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w400),
                      ),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(left: 25, right: 25),
                        child: _treatments)
                  ],
                ));
          }),
    );
  }

  @override
  Widget build(BuildContext context) => _isLoading
      ? LoadingScreen(
          confirmed: _confirmed,
        )
      : Scaffold(
          backgroundColor: Color.fromARGB(255, 252, 245, 245),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 20, right: 20, bottom: 30, top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            height: 30,
                          ),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Lichen Planus',
                                        style: kHeadTextStyle,
                                      ),
                                      SizedBox(
                                        height: 12,
                                      ),
                                      Text(
                                        'Skin Rash Identifier',
                                        style: TextStyle(
                                            fontSize: 18,
                                            color: Color.fromARGB(
                                                255, 138, 92, 92)),
                                      )
                                    ]),
                                UserGuide(
                                  items: _guideImages,
                                  section: _section,
                                )
                              ]),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          _showSelectPhotoOptions(context);
                        },
                        onVerticalDragEnd: (DragEndDetails details) {
                          if (details.primaryVelocity! < 8 &&
                              _labeled != null) {
                            _showResultsDetails(context);
                          }
                        },
                        child: Center(
                          child: Container(
                              height: 300.0,
                              width: 300.0,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.fromARGB(255, 233, 210, 210),
                              ),
                              child: Center(
                                child: _image == null
                                    ? const Text(
                                        'Take or Upload a Photo of your Skin',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Color.fromARGB(
                                                255, 170, 129, 129)),
                                      )
                                    : CircleAvatar(
                                        backgroundImage: FileImage(_image!),
                                        radius: 300.0,
                                      ),
                              )),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Patient's Skin",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      _predictedLabel != null
                          ? Text(
                              '$_predictedLabel',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 24,
                                  color: Color.fromARGB(255, 94, 71, 71)),
                            )
                          : const Text(""),
                      const SizedBox(
                        height: 12,
                      ),
                      _accuracy != null
                          ? Text(
                              'Confidence: $_accuracy %',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          : const Text(""),
                      const SizedBox(
                        height: 80,
                      ),
                      CommonButtons(
                        onTap: () => _showSelectPhotoOptions(context),
                        backgroundColor: const Color.fromARGB(255, 133, 99, 99),
                        textColor: Colors.white,
                        textLabel: _image == null
                            ? 'Upload a Photo'
                            : "Upload New Photo",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
}
