# Offline CLIP assets

This app is designed to run fully offline on-device.

## What must exist in assets

### Tokenizer (required)

Folder: `assets/tokenizer/`

Required files:
- `vocab.json`
- `merges.txt`

You can download them with:

```powershell
Set-Location .
.\tools\download_clip_tokenizer.ps1
```

### TFLite models (required)

Folder: `assets/models/`

Required files:
- `clip_image_encoder.tflite`
- `clip_text_encoder.tflite`

This workspace currently uses Apache-2.0 licensed MobileCLIP-S2 TFLite encoders (downloaded into the filenames above).

## Notes

If you want to replace these models with a different CLIP/MobileCLIP export, keep the same filenames or update the paths in `lib/clip/clip_assets.dart`.

## Quick validation

After placing the `.tflite` files, run:

```powershell
flutter pub get
flutter run
```

In the app:
- The search icon becomes enabled
- Indexing progress appears while embeddings are being built
