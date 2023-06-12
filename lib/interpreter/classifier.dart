import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imageLib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'recognitions.dart';
import 'package:typed_data/typed_data.dart';
import 'dart:typed_data';

/// Classifier
class Classifier {
  /// Instance of Interpreter
  Interpreter? _rpnInterpreter;
  Interpreter? _clsInterpreter;

  static const String MODEL_RPN_FILENAME = "model_rpn.tflite";
  static const String MODEL_CLASSIFIER_FILENAME = "model_classifier.tflite";
  static const String LABEL_FILE_NAME = "labels.txt";

  /// Result score threshold
  static const double THRESHOLD = 0.1;

  /// [ImageProcessor] used to pre-process the image
  ImageProcessor? imageProcessor;

  /// Shapes of output tensors
  List<List<int>>? _rpnOutputShapes;
  List<List<int>>? _clsOutputShapes;
  // Provide labels from training [class_mapping]
  final List<String> labels = [
    "Linear Lichen Planus",
    "Annular Lichen Planus",
    "Hypertropic Lichen Planus",
    "???"
  ];

  /// Number of results to show
  static const int NUM_RESULTS = 16; // batches
  static const int MAX_RPN_BOXES = 300;

  int? _numROIS;

  Classifier() {
    loadRPNModel();
    loadClassifierModel();
    // loadLabels();
  }

  /// Loads interpreter from asset
  void loadClassifierModel() async {
    try {
      _clsInterpreter = await Interpreter.fromAsset(
        MODEL_CLASSIFIER_FILENAME,
        options: InterpreterOptions()..threads = 1,
      );
    } catch (e) {
      print("Error while creating interpreter: $e");
    }
  }

  void loadRPNModel() async {
    try {
      _rpnInterpreter = await Interpreter.fromAsset(
        MODEL_RPN_FILENAME,
        options: InterpreterOptions()..threads = 1,
      );
    } catch (e) {
      print("Error while creating rpn interpreter: $e");
    }
  }

  List<int> applyRegr(double x, y, w, h, tx, ty, tw, th) {
    double cx = x + (w / 2);
    double cy = y + (h / 2);
    double cx1 = (tx * w) + cx;
    double cy1 = (ty * h) + cy;

    double w1 = exp(tw) * w;
    double h1 = exp(th) * h;
    double x1 = cx1 - w1 / 2;
    double y1 = cy1 - h1 / 2;

    if ((x1 * y1 * w1 * h1).isInfinite || (x1 * y1 * w1 * h1).isNaN) {
      return [x.round(), y.round(), w.round(), h.round()];
    }
    return [x1.round(), y1.round(), w1.round(), h1.round()];
  }

  List<dynamic> nonMaxSuppressionFast(
      var boxes, List<double> probs, double overlapThresh, int maxBoxes) {
    // sort boxes and prob by prob
    Map<double, dynamic> mapping = {
      for (int i = 0; i < probs.length; i++) probs[i]: boxes[i]
    };
    var sorted = Map.fromEntries(
        mapping.entries.toList()..sort(((a, b) => a.key.compareTo(b.key))));
    boxes = sorted.values.toList();
    probs = sorted.keys.toList();
    List pickedBoxes = List.filled(MAX_RPN_BOXES, List.filled(4, 0));
    List<double> pickedProbs = List<double>.filled(MAX_RPN_BOXES, 0.0);
    List<int> removedIndex = List<int>.filled(boxes.length, 0);
    int index = 0;
    for (int i = boxes.length - 1; i >= 0; i--) {
      if (removedIndex[i] == 1) {
        continue;
      }
      pickedBoxes[index] = boxes[i];
      pickedProbs[index] = probs[i];
      index++;
      removedIndex[i] = 1;
      double x1 = double.parse(boxes[i][0].toString());
      double y1 = double.parse(boxes[i][1].toString());
      double x2 = double.parse(boxes[i][2].toString());
      double y2 = double.parse(boxes[i][3].toString());

      double areaI = (x2 - x1) * (y2 - y1);

      for (int j = i - 1; j >= 0; j--) {
        if (removedIndex[j] == 1) {
          continue;
        }
        double xx1 = double.parse(boxes[j][0].toString());
        double yy1 = double.parse(boxes[j][1].toString());
        double xx2 = double.parse(boxes[j][2].toString());
        double yy2 = double.parse(boxes[j][3].toString());

        double areaJ = (xx2 - xx1) * (yy2 - yy1);
        // Find the intersection
        double Ix1 = max(x1, xx1);
        double Iy1 = max(y1, yy1);
        double Ix2 = min(x2, xx2);
        double Iy2 = min(y2, yy2);
        double Iww = max(0, Ix2 - Ix1);
        double Ihh = max(0, Iy2 - Iy1);
        double areaInt = Iww * Ihh;
        double areaUnion = areaI + areaJ - areaInt;
        double overlap = areaInt / (areaUnion + 1e-6);
        if (overlap > overlapThresh) {
          removedIndex[j] = 1;
        }
      }
      if (index >= maxBoxes) {
        break;
      }
    }
    return [pickedBoxes, pickedProbs, index];
  }

  /// Runs obect detection on the input image
  Future predict(imageLib.Image image) async {
    loadRPNModel();
    if (_rpnInterpreter == null) {
      print("RPN interpreter not initialized");
    }
    // Create InpuTensor for model
    TensorBuffer inputImage = TensorBuffer.createFixedSize(
        _rpnInterpreter!.getInputTensors()[0].shape,
        _rpnInterpreter!.getOutputTensors()[0].type);
    // Preprocess image channels according to model
    final data = image.getBytes();

    List<double> imageAsList = List<double>.filled(
        inputImage.shape[1] * inputImage.shape[2] * inputImage.shape[3], 0.0);
    List<double> imgchannelmean = [103.939, 116.779, 123.68];
    int index = 0;
    for (int i = 0; i < data.length; i += 4) {
      for (int j = 0; j < 3; j++) {
        imageAsList[index] = data[i + j].toDouble() - imgchannelmean[j];
        index++;
      }
    }
    // print(imageAsList[index - 3] + imgchannelmean[0]);
    // print(imageAsList[index - 2] + imgchannelmean[1]);
    // print(imageAsList[index - 1] + imgchannelmean[2]);
    inputImage.loadBuffer(Float32List.fromList(imageAsList).buffer);
    // Use [TensorImage.buffer] or [TensorBuffer.buffer] to pass by reference
    List<Object> inputs = [inputImage.buffer];
    TensorBuffer regrLayer = TensorBuffer.createFixedSize(
        _rpnInterpreter!.getOutputTensors()[0].shape,
        _rpnInterpreter!.getOutputTensors()[0].type);
    TensorBuffer rpnLayer = TensorBuffer.createFixedSize(
        _rpnInterpreter!.getOutputTensors()[1].shape,
        _rpnInterpreter!.getOutputTensors()[1].type);
    // run on RPN model
    Map<int, Object> rpnOutputs = {0: regrLayer.buffer, 1: rpnLayer.buffer};

    _rpnInterpreter!.runForMultipleInputs(inputs, rpnOutputs);
    _rpnInterpreter!.close();
    // Then we calculate the features from the output of the rpn model (RPN TO ROI)
    // List<int> anchorSizes = [32, 64, 128];
    // Match anchors from Config.py
    double scaler = 224 / 300;
    List<double> anchorSizes = [64 * (scaler), 128 * (scaler), 256 * (scaler)];
    List<List<double>> anchorRatios = [
      [1, 1],
      [1, 2],
      [2, 1],
    ];

    double rpnStride = 16;

    var A = List.filled(
            4 * rpnLayer.shape[1] * rpnLayer.shape[2] * rpnLayer.shape[3], 0.0)
        .reshape([4, rpnLayer.shape[1], rpnLayer.shape[2], rpnLayer.shape[3]]);

    double standardScaling = 4.0;

    int currentLayer = 0;

    for (int i = 0; i < anchorSizes.length; i++) {
      // anchorSizes Length
      for (int j = 0; j < anchorRatios.length; j++) {
        // anchorRatios Length
        double anchorX = (anchorSizes[i] * anchorRatios[j][0]) / rpnStride;
        double anchorY = (anchorSizes[i] * anchorRatios[j][1]) / rpnStride;
        // the Kth anchor of all position in the feature map (9th in total)
        var regr = List<double>.filled(
                4 * regrLayer.shape[1] * regrLayer.shape[2], 0.0)
            .reshape([4, regrLayer.shape[1], regrLayer.shape[2]]);
        // proceed to transposition
        for (int m = 0; m < regr.shape[0]; m++) {
          // 2
          for (int n = 0; n < regr.shape[1]; n++) {
            // 0
            for (int p = 0; p < regr.shape[2]; p++) {
              // 1
              int index = (n * regrLayer.shape[2] * regrLayer.shape[3]) +
                  (p * regrLayer.shape[3]) +
                  (m + (4 * currentLayer));
              regr[m][n][p] = regrLayer.getDoubleValue(index) / standardScaling;
            }
          }
        }
        // Calculate anchor position and size for each feature map point
        for (int Y = 0; Y < rpnLayer.shape[1]; Y++) {
          for (int X = 0; X < rpnLayer.shape[2]; X++) {
            // Getting positions
            double x = X.toDouble() - (anchorX / 2); // Top left x coordinate
            double y = Y.toDouble() - (anchorY / 2); // Top left y coordinate
            double w = anchorX; // Width of current anchor
            double h = anchorY; // Height of current anchor

            // Applying regression layer
            double tx = regr[0][Y][X];
            double ty = regr[1][Y][X];
            double tw = regr[2][Y][X];
            double th = regr[3][Y][X];

            var regressed = applyRegr(x, y, w, h, tx, ty, tw, th);
            // Avoid width height exceeding 1 (?)
            regressed[2] = max(1, regressed[2]);
            regressed[3] = max(1, regressed[3]);
            // Convert (x,y,w,h) to (x1,y1,x2,y2)
            regressed[2] += regressed[0];
            regressed[3] += regressed[1];
            // Avoid bbboxes outside feature map
            A[0][Y][X][currentLayer] = max(0, regressed[0]);
            A[1][Y][X][currentLayer] = max(0, regressed[1]);
            A[2][Y][X][currentLayer] = min(rpnLayer.shape[2] - 1, regressed[2]);
            A[3][Y][X][currentLayer] = min(rpnLayer.shape[1] - 1, regressed[3]);
          }
        }
        currentLayer += 1;
      }
    }
    // create an empty array to hold all_boxes
    int totalNumBoxes =
        rpnLayer.shape[1] * rpnLayer.shape[2] * rpnLayer.shape[3];
    var allBoxes = List<int>.filled(
            regrLayer.shape[0] *
                regrLayer.shape[1] *
                regrLayer.shape[2] *
                regrLayer.shape[3],
            0,
            growable: true)
        .reshape([totalNumBoxes, 4]);
    // transpose A and reshape to get all_boxes
    for (int i = 0; i < A.shape[0]; i++) {
      for (int j = 0; j < A.shape[3]; j++) {
        for (int k = 0; k < A.shape[1]; k++) {
          for (int l = 0; l < A.shape[2]; l++) {
            int index = l +
                k * A.shape[2] +
                j * A.shape[2] * A.shape[1] +
                i * A.shape[2] * A.shape[1] * A.shape[3];
            allBoxes[index % totalNumBoxes][(index / totalNumBoxes).floor()] =
                A[i][k][l][j];
          }
        }
      }
    }
    // tranpose probs
    var allProbs = List<double>.filled(
        rpnLayer.shape[1] * rpnLayer.shape[2] * rpnLayer.shape[3], 0.0,
        growable: true);
    for (int i = 0; i < rpnLayer.shape[3]; i++) {
      for (int j = 0; j < rpnLayer.shape[1]; j++) {
        for (int k = 0; k < rpnLayer.shape[2]; k++) {
          int index = i +
              (k * rpnLayer.shape[3]) +
              (j * rpnLayer.shape[3] * rpnLayer.shape[2]);
          int indexT = k +
              (j * rpnLayer.shape[2]) +
              (i * rpnLayer.shape[2] * rpnLayer.shape[1]);
          allProbs[indexT] = rpnLayer.getDoubleValue(index);
        }
      }
    }
    // remove illegal bbox along with probabilities
    int i = allBoxes.length - 1;
    while (i >= 0) {
      if ((allBoxes[i][0] - allBoxes[i][2] >= 0 ||
          allBoxes[i][1] - allBoxes[i][3] >= 0)) {
        allBoxes.removeAt(i);
        allProbs.removeAt(i);
      }
      i--;
    }
    // non max supression fast
    var result = nonMaxSuppressionFast(allBoxes, allProbs, 0.7, MAX_RPN_BOXES);
    // Connvert to x y w h
    for (int i = 0; i < result[2]; i++) {
      result[0][i][2] -= result[0][i][0];
      result[0][i][3] -= result[0][i][1];
    }
    // Apply spatial pyramid pooling to ROIs
    // Apply Classifier Model
    final Map<String, List<dynamic>> bboxes = {};
    final Map<String, List<double>> probs = {};

    List<double> predictions = List<double>.filled(4, 0.0);
    List<double> clsRegrStd = [8.0, 8.0, 4.0, 4.0];

    loadClassifierModel();

    _numROIS = _clsInterpreter!.getInputTensors()[1].shape[1];
    List<double> ROIS = List<double>.filled(_numROIS! * 4, 0.0);

    for (int i = 0; i < (result[2] / _numROIS) + 1; i++) {
      if (i >= NUM_RESULTS) {
        break;
      }
      for (int j = 0; j < _numROIS!; j++) {
        for (int k = 0; k < 4; k++) {
          if (j + (i * _numROIS!) < result[2]) {
            ROIS[(j * 4) + k] = (result[0][j + (i * _numROIS!)][k]).toDouble();
          } else {
            ROIS[(j * 4) + k] = ROIS[k];
          }
        }
      }
      // Outputs Buffer of classifier
      TensorBuffer PregrLayer = TensorBuffer.createFixedSize(
          _clsInterpreter!.getOutputTensors()[0].shape,
          _clsInterpreter!.getOutputTensors()[0].type);
      TensorBuffer PclsLayer = TensorBuffer.createFixedSize(
          _clsInterpreter!.getOutputTensors()[1].shape,
          _clsInterpreter!.getOutputTensors()[1].type);
      TensorBuffer inputROIS = TensorBuffer.createFixedSize(
          _clsInterpreter!.getInputTensors()[1].shape,
          _clsInterpreter!.getInputTensors()[1].type);

      inputROIS.loadBuffer(Float32List.fromList(ROIS).buffer);

      List<Object> clsInputs = [inputImage.buffer, inputROIS.buffer];
      Map<int, Object> clsOuputs = {0: PregrLayer.buffer, 1: PclsLayer.buffer};

      _clsInterpreter!.runForMultipleInputs(clsInputs, clsOuputs);

      for (int ii = 0; ii < PclsLayer.shape[1]; ii++) {
        for (int p = 0; p < PclsLayer.shape[2]; p++) {
          predictions[p] =
              PclsLayer.getDoubleValue(ii * PclsLayer.shape[2] + p);
        }
        int predictedClass = predictions.indexOf(predictions.reduce(max));
        if (predictions.reduce(max) < THRESHOLD ||
            predictedClass == PclsLayer.shape[2] - 1) {
          continue;
        }
        String className = labels.elementAt(predictedClass);

        if (!bboxes.containsKey(className)) {
          bboxes[className] = [];
          probs[className] = [];
        }

        // regression
        double x = ROIS[(ii * 4) + 0];
        double y = ROIS[(ii * 4) + 1];
        double w = ROIS[(ii * 4) + 2];
        double h = ROIS[(ii * 4) + 3];

        double tx = PregrLayer.getDoubleValue(
            (ii * PregrLayer.shape[2]) + (4 * predictedClass + 0));
        double ty = PregrLayer.getDoubleValue(
            (ii * PregrLayer.shape[2]) + (4 * predictedClass + 1));
        double tw = PregrLayer.getDoubleValue(
            (ii * PregrLayer.shape[2]) + (4 * predictedClass + 2));
        double th = PregrLayer.getDoubleValue(
            (ii * PregrLayer.shape[2]) + (4 * predictedClass + 3));

        tx /= clsRegrStd[0];
        ty /= clsRegrStd[1];
        tw /= clsRegrStd[2];
        th /= clsRegrStd[3];

        var regressed = applyRegr(x, y, w, h, tx, ty, tw, th);

        // add predictions to respective classes
        bboxes[className]!.add([
          regressed[0] * rpnStride,
          regressed[1] * rpnStride,
          (regressed[2] + regressed[0]) * rpnStride,
          (regressed[3] + regressed[1]) * rpnStride
        ]);
        probs[className]!.add(predictions.reduce(max));
      }
    }
    _clsInterpreter!.close();
    List<Recognition> recognitions = [];
    // Detections
    bboxes.forEach((key, boxes) {
      result = nonMaxSuppressionFast(boxes, probs[key]!, 0.2, MAX_RPN_BOXES);
      for (int i = 0; i < result[2]; i++) {
        recognitions.add(
          Recognition(
              i,
              key,
              result[1][i],
              Rect.fromLTRB(result[0][i][0], result[0][i][1], result[0][i][2],
                  result[0][i][3])),
        );
      }
    });
    if (recognitions.isEmpty) {
      recognitions.add(Recognition(0, "", 0.0, Rect.fromLTRB(0, 0, 0, 0)));
    }
    recognitions.sort(((b, a) => a.score.compareTo(b.score)));
    for (int i = 0; i < recognitions.length; i++)
      print(
          "Class: ${recognitions[i].label} : Score: ${recognitions[i].score} : Rect:${recognitions[i].location}");
    return recognitions;
  }

  /// Gets the interpreter instance
  Interpreter get rpnInterpreter => _rpnInterpreter!;
  Interpreter get clsInterpreter => _clsInterpreter!;

  /// Gets the loaded labels
  // List<String> get labels => _labels!;
}
