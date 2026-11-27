# GitHub Release notes: v0.5.0-dp.1

Copy into the DigiPressApps/BackgroundMusic release editor when publishing.

Suggested **Release title:** `Background Music 0.5.0-dp.1 (DPA Fork)`

---

## Download / ダウンロード

**English:** Requires **macOS 12.0** or later. Download **BackgroundMusic-0.5.0-dp.1.pkg**, double-click to install. **DPA** = [DigiPressApps](https://github.com/DigiPressApps).

**日本語:** **macOS 12.0** 以降。**BackgroundMusic-0.5.0-dp.1.pkg** をダウンロードしてインストール。**DPA** は DigiPressApps の略称です。

---

## Highlights / 主な機能

**English**
- Based on upstream **Background Music 0.5.0** (idle IO stop, mute button, browser helper volumes, crash fixes)
- Persist per-app volume and pan across restarts (DPA)
- Restore saved levels when playback starts (e.g. Finder Quick Look)

**日本語**
- 本家 **Background Music 0.5.0** ベース（無音時 IO 停止、ミュート、ブラウザ helper 音量、クラッシュ修正など）
- アプリ別音量・パンの永続化（DPA）
- 再生開始時の自動音量復元

**Details:** [MIGRATION](https://github.com/DigiPressApps/BackgroundMusic/blob/fork/update-to-0.5.0/docs/MIGRATION-to-0.5.0.md) · [CHANGELOG](https://github.com/DigiPressApps/BackgroundMusic/blob/fork/update-to-0.5.0/docs/CHANGELOG-fork-persistent-app-volumes.md)

---

## Notes / 注意

- Upgrading from **0.4.4-dp.1** or upstream **0.5.0**: uninstall first, then install this package (driver + app must match).
- Chrome may need a restart after Background Music launches so it uses the Background Music output device.
- Memory growth reported on upstream 0.5.0 is still under investigation; please report if you still see multi‑GB growth.
