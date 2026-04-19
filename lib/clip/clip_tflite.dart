import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'clip_assets.dart';

class ClipTflite {
  ClipTflite._(this._imageInterpreter, this._textInterpreter);

  final Interpreter _imageInterpreter;
  final Interpreter _textInterpreter;

  bool _imageAllocated = false;
  bool _textAllocated = false;

  List<int> get imageInputShape => _imageInterpreter.getInputTensor(0).shape;

  static Future<ClipTflite> load() async {
    final options = InterpreterOptions()..threads = 2;

    final imageInterpreter = await Interpreter.fromAsset(ClipAssets.imageEncoderModel, options: options);
    final textInterpreter = await Interpreter.fromAsset(ClipAssets.textEncoderModel, options: options);

    // Ensure image encoder input is a concrete 4D shape and allocate tensors.
    // If allocation fails here, we must NOT continue; otherwise later `run()`
    // commonly throws the native `Bad state: failed precondition`.
    try {
      final s = imageInterpreter.getInputTensor(0).shape;

      bool needsResize = s.length != 4;
      if (!needsResize) {
        final has3 = (s.length == 4) && (s[1] == 3 || s[3] == 3);
        needsResize = !has3;
      }

      if (needsResize) {
        // Try NCHW first (common for PyTorch exports), then NHWC.
        try {
          imageInterpreter.resizeInputTensor(0, [1, 3, ClipAssets.imageSize, ClipAssets.imageSize]);
          imageInterpreter.allocateTensors();
        } catch (_) {
          imageInterpreter.resizeInputTensor(0, [1, ClipAssets.imageSize, ClipAssets.imageSize, 3]);
          imageInterpreter.allocateTensors();
        }
      } else {
        imageInterpreter.allocateTensors();
      }
    } catch (e) {
      imageInterpreter.close();
      textInterpreter.close();
      rethrow;
    }

    // Ensure text encoder input shape matches our context length.
    try {
      final inputTensors = textInterpreter.getInputTensors();
      if (inputTensors.isEmpty) {
        throw StateError('Text encoder has no input tensors.');
      }

      final t0 = inputTensors[0].shape;
      if (t0.length == 2 && t0[0] == 1 && t0[1] != ClipAssets.contextLength) {
        textInterpreter.resizeInputTensor(0, [1, ClipAssets.contextLength]);
      } else if (t0.length == 1 && t0[0] != ClipAssets.contextLength) {
        textInterpreter.resizeInputTensor(0, [ClipAssets.contextLength]);
      } else if (t0.length != 1 && t0.length != 2) {
        throw StateError('Unexpected text input shape: $t0');
      }

      if (inputTensors.length >= 2) {
        final t1 = inputTensors[1].shape;
        if (t1.length == 2 && t1[0] == 1 && t1[1] != ClipAssets.contextLength) {
          textInterpreter.resizeInputTensor(1, [1, ClipAssets.contextLength]);
        } else if (t1.length == 1 && t1[0] != ClipAssets.contextLength) {
          textInterpreter.resizeInputTensor(1, [ClipAssets.contextLength]);
        }
      }

      textInterpreter.allocateTensors();
    } catch (e) {
      imageInterpreter.close();
      textInterpreter.close();
      rethrow;
    }

    final m = ClipTflite._(imageInterpreter, textInterpreter);
    m._imageAllocated = true;
    m._textAllocated = true;
    return m;
  }

  int get imageEmbeddingDim {
    final out = _imageInterpreter.getOutputTensor(0);
    final shape = out.shape;
    if (shape.length == 2 && shape[0] == 1) return shape[1];
    if (shape.length == 1) return shape[0];
    throw StateError('Unexpected image encoder output shape: $shape');
  }

  int get textEmbeddingDim {
    final out = _textInterpreter.getOutputTensor(0);
    final shape = out.shape;
    if (shape.length == 2 && shape[0] == 1) return shape[1];
    if (shape.length == 1) return shape[0];
    throw StateError('Unexpected text encoder output shape: $shape');
  }

  /// Expects a flattened float32 tensor matching the model input.
  Float32List runImage(Float32List input) {
    if (!_imageAllocated) {
      _imageInterpreter.allocateTensors();
      _imageAllocated = true;
    }
    final inputTensor = _imageInterpreter.getInputTensor(0);
    final inputShape = inputTensor.shape;
    final expected = inputShape.reduce((a, b) => a * b);
    if (input.length != expected) {
      throw StateError('Image input length ${input.length} does not match expected $expected for shape $inputShape');
    }

    final outTensor = _imageInterpreter.getOutputTensor(0);
    final outShape = outTensor.shape;

    final output = _allocFloatOutput(outShape);
    // IMPORTANT: pass raw bytes so tflite_flutter does NOT try to infer/resize
    // the input tensor shape from a 1D Dart List (which would break fixed-rank models).
    final inputBytes = input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes);
    _imageInterpreter.run(inputBytes, output);

    final outputFlat = _flattenFloatOutput(output, outShape);

    // Normalize to [D]
    final d = imageEmbeddingDim;
    if (outputFlat.length == d) return outputFlat;
    return Float32List.fromList(outputFlat.sublist(0, d));
  }

  /// Expects token ids shaped `[contextLength]` flattened.
  Float32List runText(List<int> tokens) {
    if (!_textAllocated) {
      _textInterpreter.allocateTensors();
      _textAllocated = true;
    }
    final inputTensors = _textInterpreter.getInputTensors();
    if (inputTensors.isEmpty) {
      throw StateError('Text encoder has no input tensors.');
    }

    final shape = inputTensors[0].shape;

    // Accept either [1, T] or [T].
    int expected;
    if (shape.length == 2 && shape[0] == 1) {
      expected = shape[1];
    } else if (shape.length == 1) {
      expected = shape[0];
    } else {
      throw StateError('Unexpected text input shape: $shape');
    }

    if (tokens.length != expected) {
      throw StateError('Token length ${tokens.length} does not match expected $expected for shape $shape');
    }

    Uint8List packInts(List<int> values, TensorType type) {
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

    final outTensor = _textInterpreter.getOutputTensor(0);
    final outShape = outTensor.shape;
    final output = _allocFloatOutput(outShape);

    final input0Bytes = packInts(tokens, inputTensors[0].type);

    if (inputTensors.length >= 2) {
      // Common pattern: [input_ids, attention_mask]
      final attentionMask = List<int>.filled(tokens.length, 1);
      for (var i = 0; i < attentionMask.length; i++) {
        attentionMask[i] = tokens[i] == 0 ? 0 : 1;
      }

      final input1Bytes = packInts(attentionMask, inputTensors[1].type);
      _textInterpreter.runForMultipleInputs([input0Bytes, input1Bytes], {0: output});
    } else {
      _textInterpreter.run(input0Bytes, output);
    }

    final outputFlat = _flattenFloatOutput(output, outShape);

    final d = textEmbeddingDim;
    if (outputFlat.length == d) return outputFlat;
    return Float32List.fromList(outputFlat.sublist(0, d));
  }

  static Object _allocFloatOutput(List<int> shape) {
    if (shape.length == 1) {
      return Float32List(shape[0]);
    }
    if (shape.length == 2) {
      // tflite_flutter commonly expects nested Dart Lists for multi-dim outputs.
      // Some delegates also return List<double> even if we allocate typed lists.
      return List.generate(shape[0], (_) => List<double>.filled(shape[1], 0.0));
    }
    throw StateError('Unsupported output shape: $shape');
  }

  static Float32List _flattenFloatOutput(Object output, List<int> shape) {
    final expectedLen = shape.reduce((a, b) => a * b);

    // Fast paths.
    if (output is Float32List) return output;
    if (output is List<double>) return Float32List.fromList(output);

    if (shape.length == 1) {
      if (output is List) {
        final flat = Float32List(expectedLen);
        if (output.length != expectedLen) {
          throw StateError('Unexpected 1D output length ${output.length} for shape $shape');
        }
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
          if (row is Float32List) {
            for (var j = 0; j < row.length; j++) {
              if (k >= expectedLen) break;
              flat[k++] = row[j];
            }
            continue;
          }

          if (row is List) {
            for (final v in row) {
              if (k >= expectedLen) break;
              flat[k++] = (v as num).toDouble();
            }
            continue;
          }

          if (row is num) {
            if (k < expectedLen) flat[k++] = row.toDouble();
            continue;
          }

          throw StateError('Unsupported 2D row type ${row.runtimeType} for shape $shape');
        }

        if (k != expectedLen) {
          throw StateError('Unexpected flattened output length $k for shape $shape');
        }
        return flat;
      }
      throw StateError('Unsupported 2D output type ${output.runtimeType} for shape $shape');
    }

    throw StateError('Unsupported output shape: $shape');
  }

  void close() {
    _imageInterpreter.close();
    _textInterpreter.close();
  }
}
