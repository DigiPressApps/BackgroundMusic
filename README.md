<!-- vim: set tw=120: -->

![](Images/README/FermataIcon.png)

# Background Music — DPA Fork

##### Per-app volume control for macOS · **DPA** = [DigiPressApps](https://github.com/DigiPressApps)

<img src="Images/README/Screenshot.png" width="340" height="443" />

---

## すぐに使う（一般ユーザー） / Quick start

**macOS 10.13 以降** · **ターミナル不要** · **署名・公証済み .pkg**

### ① 最新版をダウンロード / Download the latest installer

**👉 [Releases から最新の BackgroundMusic-*.pkg をダウンロード](https://github.com/DigiPressApps/BackgroundMusic/releases/latest)**

<a href="https://github.com/DigiPressApps/BackgroundMusic/releases/latest"><img
src="Images/README/pkg-icon.png" width="32" height="32" align="absmiddle" />
**Download latest .pkg**</a>

| | |
|---|---|
| **Latest release** | [v0.4.4-dp.1](https://github.com/DigiPressApps/BackgroundMusic/releases/tag/v0.4.4-dp.1) |
| **Direct link** | [BackgroundMusic-0.4.4-dp.1.pkg](https://github.com/DigiPressApps/BackgroundMusic/releases/download/v0.4.4-dp.1/BackgroundMusic-0.4.4-dp.1.pkg) |
| **Always newest** | https://github.com/DigiPressApps/BackgroundMusic/releases/latest |

### ② インストール / Install

1. ダウンロードした **`.pkg`** をダブルクリック / Double-click the **`.pkg`**
2. 画面の指示に従う（管理者パスワードを求められることがあります）/ Follow the installer
3. **アプリケーション** から **Background Music** を起動 / Open **Background Music** from **Applications**

メニューバーに音符アイコンが表示されれば成功です。  
When the menu-bar icon appears, you are ready.

### ③ 使い方（最小限） / Basic use

+ 各アプリの音量は、メニューバーアイコン → アプリ名のスライダーで変更 / Use the menu-bar sliders per app
+ 音量設定は **Mac 再起動後も保持** されます（DPA Fork）/ Volume settings **persist after restart** (DPA fork)
+ （任意）**システム設定 → 一般 → ログイン項目** に追加 / Optionally add to **Login Items**

> **注意 / Note:** 公式版 [0.4.3](https://github.com/kyleneideck/BackgroundMusic/releases/tag/v0.4.3) からの切り替え時は、先にアンインストールしてから入れ直すことを推奨します。  
> If upgrading from upstream **0.4.3**, uninstall the old version first.

<details><summary><strong>アンインストール / Uninstall</strong></summary>

1. **Background Music** を終了 / Quit the app
2. **ターミナル** を開き / Open **Terminal**:
   ```bash
   cd "/Applications/Background Music.app/Contents/Resources/"
   bash uninstall.sh
   ```

</details>

<details><summary><strong>うまくいかないとき / Troubleshooting</strong></summary>

+ 音が出ない → **システム設定 → サウンド** で出力デバイスを変更 / Change output device in **System Settings → Sound**
+ 初回起動時は **マイク** の許可を求められます（実際にはマイクは使いません）/ Allow **Microphone** on first launch (required by macOS, not used for recording you)
+ アプリの音量スライダーが効かない → **More Apps** 内の `(Helper)` 項目を試す / Try `(Helper)` entries under **More Apps**

詳細は下の [Troubleshooting](#troubleshooting) を参照 / See [Troubleshooting](#troubleshooting) below.

</details>

---

## この DPA 版でできること / What this DPA fork adds

音楽の自動一時停止、アプリごとの音量、システム音声の録音など、Background Music 本体の機能に加え、**DPA 版** では次が強化されています。

+ **アプリ別音量・パンの保存** — 再起動後も設定を維持
+ **再生開始時に音量を自動復元** — Finder の MP3 プレビューなど
+ **Safari / Chrome 等** のメディア再生にも音量スライダーが届きやすい

Based on [kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic). Not on the Mac App Store. Still alpha software.

不具合報告: [Issues](https://github.com/DigiPressApps/BackgroundMusic/issues) · 変更履歴: [CHANGELOG (日本語)](docs/CHANGELOG-fork-persistent-app-volumes.md)

---

## 目次 / Table of contents

**一般ユーザー:** 上の [Quick start](#すぐに使う一般ユーザー--quick-start) だけで十分です。

**開発者・詳細:** [Overview](#overview) · [DPA fork changes](#whats-different-in-this-fork) · [Build from source](#installing-from-source-code) · [Troubleshooting](#troubleshooting) · [Upstream](#upstream-project) · [License](#license)

---

# What's different in this fork

Compared to the upstream 0.4.3 release, this fork adds:

+ **Persistent per-app volume and pan** — saved by bundle ID and restored after restart
+ **Automatic volume restore when playback starts** — e.g. Finder Quick Look previews
+ **Driver past-client volume map** — volumes apply even before a HAL client registers
+ **Safari / Chrome / Whale media helper routing** — sliders reach helper processes on recent macOS

See [docs/CHANGELOG-fork-persistent-app-volumes.md](docs/CHANGELOG-fork-persistent-app-volumes.md) for details (Japanese).

# Overview

+ Automatically pause/unpause your music player when other audio sources are playing/stopped
+ Per-application volume control
+ Record system audio
+ No restart required to install

##### *Note: Background Music is still in alpha.*

## Auto-pause music

**Background Music** automatically pauses your music player when a second audio source is playing and unpauses the player when the second source has stopped.

Supported music players include [Spotify](https://www.spotify.com), [VLC](https://www.videolan.org/vlc/), [VOX](https://vox.rocks/mac-music-player), [Decibel](https://sbooth.org/Decibel/), and others.

Adding support for a new music player is usually straightforward.<sup id="a1">[1](#f1)</sup> See
[BGMMusicPlayer.h](BGMApp/BGMApp/Music%20Players/BGMMusicPlayer.h) or [open an issue](https://github.com/DigiPressApps/BackgroundMusic/issues/new).

## Application volume

**Background Music** provides a volume slider for each application. In **this DPA fork**, settings are **saved automatically** and **restored after restart**.

## Recording system audio

With **Background Music** running, use **QuickTime Player → File → New Audio Recording** and select **Background Music** as the input device. See [Apple's aggregate device guide](https://support.apple.com/en-us/HT202000) to combine with a microphone.

# Installing from Source Code

For developers only. Requires [Xcode](https://developer.apple.com/xcode/download/) 10+.

```shell
(set -eo pipefail; URL='https://github.com/DigiPressApps/BackgroundMusic/archive/master.tar.gz'; \
    cd $(mktemp -d); curl -qfL# $URL | gzcat - | tar x && \
    /bin/bash BackgroundMusic-master/build_and_install.sh -w && rm -rf BackgroundMusic-master)
```

Or clone this repo and run `/bin/bash build_and_install.sh`. See [MANUAL-INSTALL.md](https://github.com/kyleneideck/BackgroundMusic/blob/master/MANUAL-INSTALL.md).

To build a signed `.pkg`, see [docs/RELEASE-v0.4.4-dp.1.md](docs/RELEASE-v0.4.4-dp.1.md) and `package.sh`.

# Uninstall

```bash
cd "/Applications/Background Music.app/Contents/Resources/"
bash uninstall.sh
```

See [MANUAL_UNINSTALL.md](https://github.com/kyleneideck/BackgroundMusic/blob/master/MANUAL-UNINSTALL.md) for manual steps.

# Troubleshooting

If audio stops working, change the default output device in **System Settings → Sound** away from **Background Music**, then back if needed.

Allow **Microphone** access on first launch (macOS requirement for the virtual device). See [#177](/../../issues/177).

## Known issues

- **Clipping above 50% app volume** — lower other apps instead of boosting one app too high
- **Stereo output only**
- **VLC / Skype auto-pause quirks** — see upstream README or app preferences
- **Chrome device switch** — [known Chromium bug](https://bugs.chromium.org/p/chromium/issues/detail?id=557620)

More: [TODO.md](/TODO.md) · [Issues](https://github.com/DigiPressApps/BackgroundMusic/issues)

# Upstream project

Based on **[kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic)**. Upstream **0.4.3** installer: [BackgroundMusic-0.4.3.pkg](https://github.com/kyleneideck/BackgroundMusic/releases/download/v0.4.3/BackgroundMusic-0.4.3.pkg) · `brew install --cask background-music`

# Related projects

[Soundflower](https://github.com/mattingalls/Soundflower) · [BlackHole](https://github.com/ExistentialAudio/BlackHole) · [eqMac](https://github.com/nodeful/eqMac2) · [Apple AudioDriverExamples](https://developer.apple.com/library/mac/samplecode/AudioDriverExamples/Introduction/Intro.html)

## License

Copyright © 2016-2024 [Background Music contributors](https://github.com/kyleneideck/BackgroundMusic/graphs/contributors).
Additional changes in this DPA fork © [DigiPressApps](https://github.com/DigiPressApps). [GPLv2](https://www.gnu.org/licenses/gpl-2.0.html) or later.

----

<b id="f1">[1]</b> Music players need AppleScript support for `isPlaying`, `isPaused`, `play`, and `pause` for easy integration. [↩](#a1)
