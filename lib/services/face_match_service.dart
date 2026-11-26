import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device (offline) face matching for attendance.
///
/// Step 1: ML Kit  -> फोटोतले चेहरे शोधतो (face detection).
/// Step 2: TFLite  -> प्रत्येक चेहऱ्याचा "embedding" (अंकांची ओळख) बनवतो.
/// Step 3: Cosine similarity -> वर्गाच्या फोटोतले चेहरे आणि मुलांचे reference
///         photos यांची तुलना करून confidence (0.0 - 1.0) काढतो.
///
/// बदल (या version मध्ये):
///  * Model चा input आकार आणि layout (NCHW [1,3,H,W] किंवा NHWC [1,H,W,3])
///    आपोआप ओळखला जातो.
///  * Model ला एकापेक्षा जास्त inputs असतील (उदा. img1 + img2) तर तोच चेहरा
///    सर्व inputs ना दिला जातो आणि output ची पहिली ओळ (row 0) वापरली जाते.
///  * NCHW (Qualcomm/AI Hub) model साठी pixel 0..1, NHWC साठी जुना
///    (pixel - 127.5) / 128 normalisation.
///  * Reference फोटोचा error आता गिळला जात नाही — कारण debug console मध्ये
///    दिसतं आणि शेवटच्या error message मध्येही जोडलं जातं.
class FaceMatchService {
  FaceMatchService._();
  static final FaceMatchService instance = FaceMatchService._();

  /// pubspec.yaml मध्ये हीच path assets मध्ये असली पाहिजे.
  static const String _modelAsset = 'assets/models/mobilefacenet.tflite';

  Interpreter? _interpreter;
  int _inH = 112;
  int _inW = 112;
  int _outDim = 128;
  int _outRows = 1;
  int _inputCount = 1;
  bool _nchw = false; // true => input [1,3,H,W]; false => [1,H,W,3]

  FaceDetector? _detector;

  /// studentId -> (reference photo ची ओळख, embedding). वारंवार गणित टाळण्यासाठी.
  final Map<String, _CachedFace> _cache = {};

  /// शेवटच्या reference फोटोच्या अपयशाचं कारण (message मध्ये दाखवायला).
  String _lastRefError = '';

  // similarity -> confidence mapping (गरजेनुसार बदला)
  // sim 0.30 => 0.0 confidence,  sim 0.70 => 1.0 confidence
  // टीप: हे मूल्य model नुसार बदलतात. प्रत्यक्ष चाचणीत debug console मधले
  // "FaceMatch sim" आकडे बघून जुळवा.
  static const double _simLow = 0.30;
  static const double _simHigh = 0.70;

  // ---------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------
  Future<void> _ensureReady() async {
    if (_interpreter == null) {
      try {
        _interpreter = await Interpreter.fromAsset(_modelAsset);
      } catch (_) {
        throw 'Face model not found. Put mobilefacenet.tflite in '
            'assets/models/ and add it to pubspec.yaml.';
      }
      final interp = _interpreter!;
      final inputs = interp.getInputTensors();
      _inputCount = inputs.length;

      final inShape = inputs.first.shape; // [1,3,H,W] किंवा [1,H,W,3]
      if (inShape.length == 4 && inShape[1] == 3 && inShape[3] != 3) {
        _nchw = true;
        _inH = inShape[2];
        _inW = inShape[3];
      } else {
        _nchw = false;
        _inH = inShape[1];
        _inW = inShape[2];
      }

      final outShape = interp.getOutputTensor(0).shape; // [R,N] किंवा [1,N]
      _outDim = outShape.last;
      _outRows = outShape.length >= 2 ? outShape.first : 1;

      debugPrint('FaceMatch model: inputs=$_inputCount '
          'inShape=$inShape nchw=$_nchw outShape=$outShape');
    }
    _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: false,
        enableClassification: false,
        enableTracking: false,
        minFaceSize: 0.05, // वर्गाच्या फोटोत लहान चेहरे पण पकडायला
      ),
    );
  }

  void dispose() {
    _detector?.close();
    _detector = null;
    _interpreter?.close();
    _interpreter = null;
    _cache.clear();
  }

  // ---------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------
  /// [classPhoto] = कॅमेऱ्याचा फोटो (JPEG bytes).
  /// [references] = { studentId: 'data:image/jpeg;base64,...' } (Admin ने ठेवलेले).
  /// परत: { studentId: confidence 0.0-1.0 } — ज्याचा चेहरा सापडला नाही तो Map मध्ये नसतो.
  Future<Map<String, double>> match(
      Uint8List classPhoto,
      Map<String, String> references,
      ) async {
    await _ensureReady();
    _lastRefError = '';

    // 1) reference embeddings (cache मधून / नवीन)
    final refs = <String, List<double>>{};
    for (final e in references.entries) {
      if (e.value.isEmpty) continue;
      final emb = await _referenceEmbedding(e.key, e.value);
      if (emb != null) refs[e.key] = emb;
    }
    if (refs.isEmpty) {
      final why = _lastRefError.isEmpty ? '' : ' (Reason: $_lastRefError)';
      throw 'No student has a usable reference face photo. '
          'Ask Admin to add clear face photos for students.$why';
    }

    // 2) वर्गाच्या फोटोतले सर्व चेहरे
    final decoded = img.decodeImage(classPhoto);
    if (decoded == null) throw 'Could not read the class photo.';
    final baked = img.bakeOrientation(decoded); // EXIF rotation नीट करतो
    final faces = await _detectFaces(baked);
    if (faces.isEmpty) return {};

    final faceEmbs = <List<double>>[];
    for (final f in faces) {
      final crop = _cropFace(baked, f.boundingBox);
      if (crop != null) faceEmbs.add(_embed(crop));
    }
    if (faceEmbs.isEmpty) return {};

    // 3) सर्व (मूल, चेहरा) जोड्यांची similarity
    final pairs = <_Pair>[];
    refs.forEach((sid, rEmb) {
      for (var i = 0; i < faceEmbs.length; i++) {
        pairs.add(_Pair(sid, i, _cosine(rEmb, faceEmbs[i])));
      }
    });
    pairs.sort((a, b) => b.sim.compareTo(a.sim));

    // 4) Greedy 1-to-1: एका चेहऱ्याला एकच मूल, एका मुलाला एकच चेहरा
    final usedStudents = <String>{};
    final usedFaces = <int>{};
    final out = <String, double>{};
    for (final p in pairs) {
      if (usedStudents.contains(p.studentId) || usedFaces.contains(p.faceIdx)) {
        continue;
      }
      debugPrint('FaceMatch sim student=${p.studentId} '
          'face=${p.faceIdx} sim=${p.sim.toStringAsFixed(3)}');
      final conf = ((p.sim - _simLow) / (_simHigh - _simLow)).clamp(0.0, 1.0);
      if (conf <= 0) continue; // खूपच कमी — "not seen"
      out[p.studentId] = conf;
      usedStudents.add(p.studentId);
      usedFaces.add(p.faceIdx);
    }
    return out;
  }

  // ---------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------
  Future<List<double>?> _referenceEmbedding(String id, String dataUri) async {
    final key = '${dataUri.length}:${dataUri.hashCode}';
    final cached = _cache[id];
    if (cached != null && cached.key == key) return cached.embedding;

    try {
      final comma = dataUri.indexOf(',');
      final raw = comma < 0 ? dataUri : dataUri.substring(comma + 1);
      final decoded = img.decodeImage(base64Decode(raw));
      if (decoded == null) {
        _lastRefError = 'photo could not be decoded';
        return null;
      }
      final baked = img.bakeOrientation(decoded);
      final faces = await _detectFaces(baked);
      if (faces.isEmpty) {
        _lastRefError = 'no face detected in the reference photo';
        return null;
      }

      // सर्वात मोठा चेहरा = मुलाचा
      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));
      final crop = _cropFace(baked, faces.first.boundingBox);
      if (crop == null) {
        _lastRefError = 'face too small to crop';
        return null;
      }

      final emb = _embed(crop);
      _cache[id] = _CachedFace(key, emb);
      return emb;
    } catch (e, st) {
      // आधी इथे error गिळला जात होता. आता कारण दिसतं.
      _lastRefError = e.toString();
      debugPrint('FaceMatch reference error for $id: $e\n$st');
      return null;
    }
  }

  Future<List<Face>> _detectFaces(img.Image image) async {
    // ML Kit ला file path लागतो — म्हणून temp file बनवतो.
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/face_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(img.encodeJpg(image, quality: 92));
    try {
      return await _detector!.processImage(InputImage.fromFilePath(file.path));
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  img.Image? _cropFace(img.Image src, dynamic box) {
    // थोडी margin ठेवतो (कपाळ/हनुवटी कापली जाऊ नये).
    final w = box.width as double;
    final h = box.height as double;
    final mx = w * 0.15;
    final my = h * 0.15;
    final x = math.max(0, (box.left as double) - mx).toInt();
    final y = math.max(0, (box.top as double) - my).toInt();
    final cw = math.min(src.width - x, (w + 2 * mx).toInt());
    final ch = math.min(src.height - y, (h + 2 * my).toInt());
    if (cw < 20 || ch < 20) return null;
    final crop = img.copyCrop(src, x: x, y: y, width: cw, height: ch);
    return img.copyResize(crop, width: _inW, height: _inH);
  }

  /// Pixel -> model चं मूल्य.
  ///  NCHW (AI Hub MobileFaceNet) : 0.0 .. 1.0
  ///  NHWC (जुनी MobileFaceNet)   : (pixel - 127.5) / 128
  double _norm(num v) => _nchw ? v / 255.0 : (v - 127.5) / 128.0;

  List<double> _embed(img.Image face) {
    final Object input;
    if (_nchw) {
      // [1, 3, H, W]
      input = [
        List.generate(
          3,
              (c) => List.generate(
            _inH,
                (y) => List.generate(_inW, (x) {
              final p = face.getPixel(x, y);
              final v = c == 0 ? p.r : (c == 1 ? p.g : p.b);
              return _norm(v);
            }),
          ),
        ),
      ];
    } else {
      // [1, H, W, 3]
      input = [
        List.generate(
          _inH,
              (y) => List.generate(_inW, (x) {
            final p = face.getPixel(x, y);
            return [_norm(p.r), _norm(p.g), _norm(p.b)];
          }),
        ),
      ];
    }

    // Output: [R, N]  (R = 1 किंवा 2 ...)
    final output = List.generate(
      _outRows,
          (_) => List<double>.filled(_outDim, 0.0),
    );

    if (_inputCount == 1) {
      _interpreter!.run(input, output);
    } else {
      // img1, img2 ... सर्वांना तोच चेहरा; आपल्याला फक्त row 0 हवी.
      final inputs = List<Object>.filled(_inputCount, input);
      _interpreter!.runForMultipleInputs(inputs, {0: output});
    }

    // L2 normalise
    final v = output[0];
    var norm = 0.0;
    for (final d in v) {
      norm += d * d;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return v;
    return v.map((d) => d / norm).toList();
  }

  double _cosine(List<double> a, List<double> b) {
    var dot = 0.0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      dot += a[i] * b[i];
    }
    return dot; // दोन्ही L2-normalised आहेत
  }
}

class _CachedFace {
  _CachedFace(this.key, this.embedding);
  final String key;
  final List<double> embedding;
}

class _Pair {
  _Pair(this.studentId, this.faceIdx, this.sim);
  final String studentId;
  final int faceIdx;
  final double sim;
}