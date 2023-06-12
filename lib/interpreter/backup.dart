import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imageLib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'recognitions.dart';

/// Classifier
class Classifier {
  /// Instance of Interpreter
  Interpreter? _interpreter;

  /// Labels file loaded as list
  List<String>? _labels;

  static const String MODEL_FILE_NAME = "model.tflite";
  static const String LABEL_FILE_NAME = "labels.txt";

  /// Input size of image (height = width = 300)
  static const int INPUT_SIZE = 320;

  /// Result score threshold
  static const double THRESHOLD = 0.0;

  /// [ImageProcessor] used to pre-process the image
  ImageProcessor? imageProcessor;

  /// Padding the image to transform into square
  // int? padSize;

  /// Shapes of output tensors
  List<List<int>>? _outputShapes;

  /// Types of output tensors
  List<TfLiteType>? _outputTypes;

  /// Number of results to show
  static const int NUM_RESULTS = 10;

  Classifier() {
    loadModel();
    loadLabels();
    loadProcessor();
  }

  /// Loads interpreter from asset
  void loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        MODEL_FILE_NAME,
        options: InterpreterOptions()..threads = 4,
      );
      if (interpreter != null) {
        var outputTensors = _interpreter!.getOutputTensors();
        _outputShapes = [];
        _outputTypes = [];
        outputTensors.forEach((tensor) {
          _outputShapes!.add(tensor.shape);
          _outputTypes!.add(tensor.type);
        });
      }
      print("Model Loadeed.");
    } catch (e) {
      print("Error while creating interpreter: $e");
    }
  }

  /// Loads labels from assets
  void loadLabels() async {
    try {
      _labels = await FileUtil.loadLabels("assets/" + LABEL_FILE_NAME);
    } catch (e) {
      print("Error while loading labels: $e");
    }
  }

  void loadProcessor() {
    // padSize = max(inputImage.height, inputImage.width);
    imageProcessor ??= ImageProcessorBuilder()
        // .add(ResizeWithCropOrPadOp(padSize!, padSize!))
        // .add(ResizeOp(INPUT_SIZE, INPUT_SIZE, ResizeMethod.BILINEAR))
        .build();
  }

  /// Pre-process the image
  TensorImage getProcessedImage(TensorImage inputImage) {
    // ignore: prefer_conditional_assignment, unnecessary_null_comparison
    inputImage = imageProcessor!.process(inputImage);
    return inputImage;
  }

  /// Runs object detection on the input image
  List<Recognition> predict(imageLib.Image image) {
    if (_interpreter == null) {
      print("Interpreter not initialized");
    }

    // Create TensorImage from image
    TensorImage inputImage = TensorImage.fromImage(image);

    // Pre-process TensorImage
    inputImage = getProcessedImage(inputImage);

    // TensorBuffers for output tensors
    TensorBuffer outputLocations = TensorBufferFloat(_outputShapes![1]);
    TensorBuffer outputClasses = TensorBufferFloat(_outputShapes![3]);
    TensorBuffer outputScores = TensorBufferFloat(_outputShapes![0]);
    TensorBuffer numLocations = TensorBufferFloat(_outputShapes![2]);

    // Inputs object for runForMultipleInputs
    // Use [TensorImage.buffer] or [TensorBuffer.buffer] to pass by reference
    List<Object> inputs = [inputImage.buffer];
    // Outputs map
    Map<int, Object> outputs = {
      1: outputLocations.buffer,
      3: outputClasses.buffer,
      0: outputScores.buffer,
      2: numLocations.buffer,
    };
    // run
    _interpreter!.runForMultipleInputs(inputs, outputs);
    // Maximum number of results to show
    int resultsCount = min(NUM_RESULTS, numLocations.getIntValue(0));

    // Using labelOffset = 1 as ??? at index 0
    int labelOffset = 1;
    // Using bounding box utils for easy conversion of tensorbuffer to List<Rect>
    List<Rect> locations = BoundingBoxUtils.convert(
      tensor: outputLocations,
      valueIndex: [1, 0, 3, 2],
      boundingBoxAxis: 2,
      boundingBoxType: BoundingBoxType.BOUNDARIES,
      coordinateType: CoordinateType.RATIO,
      height: INPUT_SIZE,
      width: INPUT_SIZE,
    );
    List<Recognition> recognitions = [];
    for (int i = 0; i < resultsCount; i++) {
      // Prediction score
      var score = outputScores.getDoubleValue(i);
      // Label string
      var labelIndex = outputClasses.getIntValue(i) + labelOffset;
      var label = _labels!.elementAt(labelIndex);
      if (score > THRESHOLD) {
        // inverse of rect
        // [locations] corresponds to the image size 300 X 300
        // inverseTransformRect transforms it our [inputImage]
        Rect transformedRect = imageProcessor!
            .inverseTransformRect(locations[i], image.height, image.width);
        recognitions.add(
          Recognition(i, label, score, transformedRect),
        );
      }
    }
    return recognitions;
  }

  /// Gets the interpreter instance
  Interpreter get interpreter => _interpreter!;

  /// Gets the loaded labels
  List<String> get labels => _labels!;
}
