# App Store Review Notes

Image Studio is a native SwiftUI app. It opens directly to the image generator and does not embed a Puter web login or a visible WebView.

## How To Test

1. Launch the app.
2. Enter a prompt on the generator screen.
3. Choose a style, size, model, and quality when available.
4. Tap Generate.
5. Open Gallery to confirm the generated image was saved locally.
6. Open an image detail view to Save, Share, Copy Prompt, Regenerate, or Delete.

## Backend

Debug builds call the local development API at `http://127.0.0.1:8787`. Release builds must be pointed at the deployed HTTPS API by replacing `https://api.your-domain.example` in `project.yml`.

The iOS app calls only the custom API endpoint:

```text
POST /v1/images/generations
```

The app does not contain `PUTER_AUTH_TOKEN` and does not call `api.puter.com`. Puter authentication remains on the backend under `/root/puter-api-proof` for local development.

## Privacy And Safety

Prompts and generated images are sent to the generation backend and AI providers as needed. The app requests Photos permission only after the user taps Save. There is no public community feed in v1.

Provider moderation or backend rejection is shown as a friendly retryable error. Raw provider stack traces are not shown to users.
