# OCR Dashboard (Flutter)

A lightweight Flutter app that lets you pick an image from the gallery and extract text using on-device OCR.

## Features

- Bottom navigation: Home / Recent / Profile
- Home: select image → extract text (with processing animation) → copy/clear
- Recent: shows last 5 OCR results (image + extracted text)
- Profile: edit photo/name/age + theme (light/dark) + language (English/Hindi)

## Tech Stack

- Flutter (Material 3)
- `google_mlkit_text_recognition` (on-device OCR)
- `image_picker` (gallery picker)
- `provider` + `shared_preferences` (state + persistence)

## Run (Android)

1. Get packages:

```bash
flutter pub get
```

2. Run on a device/emulator:

```bash
flutter run
```

## Notes

- This project is kept Android-focused (other platform folders may be removed).

