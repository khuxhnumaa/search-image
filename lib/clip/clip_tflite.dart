import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'clip_assets.dart';

class ClipTflite {
  ClipTflite._(
    this._interpreter,
    this._imageInputIndex,
    this._textInputIndex,
    this._imageOutputIndex,
    this._textOutputIndex,
  );

  final Interpreter _interpreter;
  final int _imageInputIndex;
  final int _textInputIndex;
  final int _imageOutputIndex;
  final int _textOutputIndex;

  bool _allocated = false;

  List<int> get imageInputShape => _interpreter.getInputTensor(_imageInputIndex).shape;

  static Future<ClipTflite> load() async {
    final options = InterpreterOptions()..threads = 2;
    final interpreter = await Interpreter.fromAsset(
      ClipAssets.imageEncoderModel, // combined model
      options: options,
    );

    debugPrint('INPUT TENSORS: ${interpreter.getInputTensors().map((t) => t.shape).toList()}');
    debugPrint('OUTPUT TENSORS: ${interpreter.getOutputTensors().map((t) => t.shape).toList()}');

    final inputs = interpreter.getInputTensors();

    int? imageIdx;
    int? textIdx;

    for (var i = 0; i < inputs.length; i++) {
      final s = inputs[i].shape;
      if (s.length == 4 && (s[1] == 3 || s[3] == 3)) {
        imageIdx = i;
      } else if ((s.length == 2 && s[1] == ClipAssets.contextLength) ||
          (s.length == 1 && s[0] == ClipAssets.contextLength)) {
        textIdx = i;
      }
    }

    if (imageIdx == null || textIdx == null) {
      interpreter.close();
      throw StateError('Unable to identify image/text inputs. Shapes: ${inputs.map((t) => t.shape).toList()}');
    }

    interpreter.allocateTensors();

    int detectTextOutputIndex({
      required Interpreter interpreter,
      required int imageIdx,
      required int textIdx,
    }) {
      final imageShape = interpreter.getInputTensor(imageIdx).shape;
      final imageLen = imageShape.reduce((a, b) => a * b);
      final imageBytes = Float32List(imageLen).buffer.asUint8List();

      final textShape = interpreter.getInputTensor(textIdx).shape;
      final textLen = textShape.length == 2 ? textShape[1] : textShape[0];

      final tokensA = List<int>.filled(textLen, 0);
      final tokensB = List<int>.filled(textLen, 1);

      Uint8List pack(List<int> values) {
        switch (interpreter.getInputTensor(textIdx).type) {
          case TensorType.int32:
            return Int32List.fromList(values).buffer.asUint8List();
          case TensorType.int64:
            return Int64List.fromList(values).buffer.asUint8List();
          case TensorType.float32:
            return Float32List.fromList(values.map((e) => e.toDouble()).toList())
                .buffer
                .asUint8List();
          default:
            throw StateError('Unsupported text input type');
        }
      }

      Map<int, Object> allocOutputs() {
        final out = <int, Object>{};
        final outs = interpreter.getOutputTensors();
        for (var i = 0; i < outs.length; i++) {
          out[i] = _allocOutputForShape(outs[i].shape);
        }
        return out;
      }

      final outA = allocOutputs();
      interpreter.runForMultipleInputs([imageBytes, pack(tokensA)], outA);

      final outB = allocOutputs();
      interpreter.runForMultipleInputs([imageBytes, pack(tokensB)], outB);

      double diffFor(int i) {
        final a = _flattenFloatOutput(outA[i]!, interpreter.getOutputTensor(i).shape);
        final b = _flattenFloatOutput(outB[i]!, interpreter.getOutputTensor(i).shape);
        var sum = 0.0;
        for (var k = 0; k < a.length; k++) {
          final d = a[k] - b[k];
          sum += d * d;
        }
        return sum;
      }

      var bestIdx = 0;
      var bestDiff = -1.0;
      for (var i = 0; i < interpreter.getOutputTensors().length; i++) {
        final d = diffFor(i);
        if (d > bestDiff) {
          bestDiff = d;
          bestIdx = i;
        }
      }
      return bestIdx;
    }

    final textOut = detectTextOutputIndex(
      interpreter: interpreter,
      imageIdx: imageIdx,
      textIdx: textIdx,
    );
    final imageOut = (textOut == 0) ? 1 : 0;

    return ClipTflite._(interpreter, imageIdx, textIdx, imageOut, textOut);
  }

  int get imageEmbeddingDim {
    final out = _interpreter.getOutputTensor(_imageOutputIndex);
    final shape = out.shape;
    if (shape.length == 2 && shape[0] == 1) return shape[1];
    if (shape.length == 1) return shape[0];
    throw StateError('Unexpected image encoder output shape: $shape');
  }

  int get textEmbeddingDim {
    final out = _interpreter.getOutputTensor(_textOutputIndex);
    final shape = out.shape;
    if (shape.length == 2 && shape[0] == 1) return shape[1];
    if (shape.length == 1) return shape[0];
    throw StateError('Unexpected text encoder output shape: $shape');
  }

  Float32List runImage(Float32List input, List<int> tokens) {
    if (!_allocated) {
      _interpreter.allocateTensors();
      _allocated = true;
    }

    final imageBytes = input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes);
    final textBytes = _packInts(tokens, _interpreter.getInputTensor(_textInputIndex).type);

    final outputs = <int, Object>{};
    final outTensors = _interpreter.getOutputTensors();
    for (var i = 0; i < outTensors.length; i++) {
      outputs[i] = _allocOutputForShape(outTensors[i].shape);
    }

    _interpreter.runForMultipleInputs([imageBytes, textBytes], outputs);

    final outputFlat = _flattenFloatOutput(
      outputs[_imageOutputIndex]!,
      _interpreter.getOutputTensor(_imageOutputIndex).shape,
    );

    final d = imageEmbeddingDim;
    if (outputFlat.length == d) return outputFlat;
    return Float32List.fromList(outputFlat.sublist(0, d));
  }

  Float32List runText(List<int> tokens) {
    if (!_allocated) {
      _interpreter.allocateTensors();
      _allocated = true;
    }

    final imageInput = _interpreter.getInputTensor(_imageInputIndex);
    final imageLen = imageInput.shape.reduce((a, b) => a * b);
    final imageBytes = Float32List(imageLen).buffer.asUint8List();

    final textBytes = _packInts(tokens, _interpreter.getInputTensor(_textInputIndex).type);

    final outputs = <int, Object>{};
    final outTensors = _interpreter.getOutputTensors();
    for (var i = 0; i < outTensors.length; i++) {
      outputs[i] = _allocOutputForShape(outTensors[i].shape);
    }

    _interpreter.runForMultipleInputs([imageBytes, textBytes], outputs);

    final outputFlat = _flattenFloatOutput(
      outputs[_textOutputIndex]!,
      _interpreter.getOutputTensor(_textOutputIndex).shape,
    );

    final d = textEmbeddingDim;
    if (outputFlat.length == d) return outputFlat;
    return Float32List.fromList(outputFlat.sublist(0, d));
  }

  static Uint8List _packInts(List<int> values, TensorType type) {
    switch (type) {
      case TensorType.int32:
        final a = Int32List.fromList(values);
        return a.buffer.asUint8List(a.offsetInBytes, a.lengthInBytes);
      case TensorType.int64:
        final a = Int64List.fromList(values);
        return a.buffer.asUint8List(a.offsetInBytes, a.lengthInBytes);
      case TensorType.float32:
        final a = Float32List.fromList(values.map((e) => e.toDouble()).toList());
        return a.buffer.asUint8List(a.offsetInBytes, a.lengthInBytes);
      default:
        throw StateError('Unsupported text input tensor type: $type');
    }
  }

  static Object _allocOutputForShape(List<int> shape) {
    if (shape.isEmpty) {
      return Float32List(1); // scalar output
    }
    return _allocFloatOutput(shape);
  }

  static Object _allocFloatOutput(List<int> shape) {
    if (shape.length == 1) {
      return Float32List(shape[0]);
    }
    if (shape.length == 2) {
      return List.generate(shape[0], (_) => List<double>.filled(shape[1], 0.0));
    }
    throw StateError('Unsupported output shape: $shape');
  }

  static Float32List _flattenFloatOutput(Object output, List<int> shape) {
    final expectedLen = shape.reduce((a, b) => a * b);

    if (output is Float32List) return output;
    if (output is List<double>) return Float32List.fromList(output);

    if (shape.length == 1) {
      if (output is List) {
        final flat = Float32List(expectedLen);
        for (var i = 0; i < expectedLen; i++) {
          flat[i] = (output[i] as num).toDouble();
        }
        return flat;
      }
      throw StateError('Unsupported 1D output type ${output.runtimeType} for shape $shape');
    }

    if (shape.length == 2) {
      if (output is List) {
        final flat = Float32List(expectedLen);
        var k = 0;
        for (final row in output) {
          if (row is List) {
            for (final v in row) {
              flat[k++] = (v as num).toDouble();
            }
          }
        }
        return flat;
      }
      throw StateError('Unsupported 2D output type ${output.runtimeType} for shape $shape');
    }

    throw StateError('Unsupported output shape: $shape');
  }

  void close() {
    _interpreter.close();
  }
}