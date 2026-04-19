class ClipAssets {
  static const String imageEncoderModel = 'assets/models/clip_image_encoder.tflite';
  static const String textEncoderModel = 'assets/models/clip_text_encoder.tflite';

  static const String vocabJson = 'assets/tokenizer/vocab.json';
  static const String mergesTxt = 'assets/tokenizer/merges.txt';

  // Optional HuggingFace-style tokenizer JSON (contains vocab + merges).
  static const String tokenizerJson = 'assets/tokenizer/tokenizer.json';

  // Common CLIP defaults.
  static const int contextLength = 77;

  // OpenAI CLIP image normalization.
  static const List<double> imageMean = [0.48145466, 0.4578275, 0.40821073];
  static const List<double> imageStd = [0.26862954, 0.26130258, 0.27577711];

  static const int imageSize = 224;
}
