# Fork 変更ログ: アプリ別音量の永続化と再起動後の復元

このドキュメントは、[kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic) をベースにした **DPA 版 Fork**（GitHub: [DigiPressApps/BackgroundMusic](https://github.com/DigiPressApps/BackgroundMusic)。**DPA** = DigiPressApps の略）に対し、**アプリ別音量を bundle ID で永続化し、Mac 再起動後も実音量に反映する**一連の変更を記録したものです。

公式 Background Music には、スライダー値の再起動後復元（UserDefaults 等）および「HAL クライアント登録前の SetAppVolume を past client map に残す」処理は未実装でした（ドライバ `BGM_Clients.cpp` に TODO が残存）。

---

## 変更の背景と問題

| 現象 | 原因 |
|------|------|
| 再起動後、スライダーは保存値だが音はデフォルト | 起動時の `SetAppVolume` が、まだ IO していないクライアントには効かない。ドライバが `mPastClientMap` を更新していなかった |
| 初回再生だけ一瞬フル音量 | BGMApp が audible より遅れて音量を再送していた |
| 再生中の音途切れ | 起動直後やメニュー更新時に過剰な `reapply` / PlayThrough 停止が重なった |
| audible ログの `audi` / `silt` 連打 | 短い無音通知で「無音→再生」エッジが何度も発火し、`reapply` が繰り返された |

---

## フェーズ別の実装内容

### フェーズ 1: UserDefaults 永続化（BGMApp）

**目的:** メニューのスライダー変更を bundle ID キーで保存し、UI 表示時にマージする。

| ファイル | 変更概要 |
|----------|----------|
| `BGMUserDefaults.h` / `.m` | `SavedAppVolumes` 辞書（キー `rvol` / `ppos`）。`savedAppVolume:pan:forBundleID:` / `setSavedAppVolume:pan:forBundleID:` を追加。音量 0–100、パン -100–100 をクランプ |
| `BGMAppVolumesController.mm` | スライダー変更時に UserDefaults へ保存。`mergeSavedVolumeAndPan` でドライバ未取得時に保存値を UI に反映 |
| `BGMAppVolumesController.h` | `initWithMenu:appVolumeView:audioDevices:userDefaults:` に `userDefaults` 引数を追加 |
| `BGMAppDelegate.mm` | 既存の `userDefaults` を `BGMAppVolumesController` に注入 |

永続化の保存先: 標準 UserDefaults（`com.bearisdriving.BGM.App` のサンドボックス外 plist。Fork の `PRODUCT_BUNDLE_IDENTIFIER` に依存）。

### フェーズ 2: 再生開始後のドライバ再適用（BGMApp）

**目的:** HAL クライアント（Quick Look 等）が IO 開始したあと、保存音量をドライバへ再送する。

| 機能 | 実装 |
|------|------|
| プロパティリスナー | `kAudioDeviceCustomPropertyDeviceAudibleState` と `kAudioDeviceCustomPropertyDeviceIsRunningSomewhereOtherThanBGMApp` |
| IO 先行復元 | `handleOtherAppIOChangeForVolumeRestore` — 他アプリ IO の立ち上がりで即 `scheduleReapplySavedVolumesToDriver` |
| audible バックアップ | 無音→再生、`SilentExceptMusic`→`Audible` のエッジで再適用 |
| 即時 + リトライ | 即時 `reapplySavedVolumesToDriver`、0.15s 後に 0.05 / 0.2 / 0.45s の追いかけ |
| 起動時 | メニュー構築は `pushInitialVolumesToDriver:NO`（起動時一括送信で途切れないよう抑制） |
| 新規アプリ KVO | 挿入時 `pushInitialVolumesToDriver:YES` + `scheduleReapply` |
| `pushVolumeAndPanToDriver` | UserDefaults を更新せずドライバのみ更新（再適用用） |

### フェーズ 3: 初回再生フラッシュ対策

- **IO リスナー**を audible より先に使い、Quick Look プレビュー開始直後に reapply。
- 旧 300ms デバウンスのみ → **即時 reapply + 短いリトライ**に変更。

### フェーズ 4: audible ちらつき抑制

| 定数 | 値 | 役割 |
|------|-----|------|
| `kVolumeRestoreAudibleSilentConfirmSec` | 0.35s | `silt`（完全無音）を受けてもすぐ内部状態を無音にしない。0.35s 後も無音のときだけ確定 |
| `kVolumeRestoreAudibleReapplyCooldownSec` | 2.0s | audible 経路の `reapply` を 2 秒に 1 回まで（IO 経路は常時即時） |

**注意:** Core Audio の audible 状態コード `'silt'` は `kBGMDeviceIsSilent`（完全無音）です。

### フェーズ A（ドライバ）: past client map

**目的:** クライアント未登録時に BGMApp から送った音量を、後から `AddClient` 時に適用できるようにする。

| ファイル | 変更概要 |
|----------|----------|
| `BGM_ClientMap.h` / `.cpp` | `SetPastClientRelativeVolume` / `SetPastClientPanPosition` を追加 |
| `BGM_Clients.cpp` | ライブクライアントに適用できなかった場合、bundle ID 有効なら past map へ保存（旧 TODO を実装） |

### 付随: PlayThrough 起動猶予（API のみ）

| ファイル | 変更概要 |
|----------|----------|
| `BGMPlayThrough.h` / `.cpp` | `SuppressStopIfIdleForSeconds` / `mSuppressStopIfIdleUntil` — 起動直後の `StopIfIdle` を抑制 |
| `BGMAudioDeviceManager.h` / `.mm` | `suppressStopIfIdleForLaunchGracePeriod`（15 秒） |

**現状:** `applicationDidFinishLaunching` 等からの呼び出しは未接続。音途切れ調査用に API を追加した状態。

---

## 変更ファイル一覧（本コミット）

```
BGMApp/BGMApp/BGMAppDelegate.mm
BGMApp/BGMApp/BGMAppVolumesController.h
BGMApp/BGMApp/BGMAppVolumesController.mm   （主変更）
BGMApp/BGMApp/BGMAudioDeviceManager.h
BGMApp/BGMApp/BGMAudioDeviceManager.mm
BGMApp/BGMApp/BGMPlayThrough.cpp
BGMApp/BGMApp/BGMPlayThrough.h
BGMApp/BGMApp/BGMUserDefaults.h
BGMApp/BGMApp/BGMUserDefaults.m
BGMDriver/BGMDriver/DeviceClients/BGM_ClientMap.cpp
BGMDriver/BGMDriver/DeviceClients/BGM_ClientMap.h
BGMDriver/BGMDriver/DeviceClients/BGM_Clients.cpp
docs/CHANGELOG-fork-persistent-app-volumes.md
```

---

## ビルド・インストール

```bash
cd /path/to/BackgroundMusic
xcodebuild -project BGMApp/BGMApp.xcodeproj -scheme "Background Music" -configuration Debug build
# 成果物: ~/Library/Developer/Xcode/DerivedData/BGMApp-*/Build/Products/Debug/Background Music.app
```

ドライバを変更したため、**Release/Debug ドライバの再インストール**（プロジェクトの `build_and_install.sh` 手順）が必要です。BGMApp のみ差し替えた場合、past map 側の効果はドライバ更新後に完全になります。

### 動作確認（推奨）

1. Mac 再起動後、Background Music を起動
2. Finder で MP3 プレビュー — 初回から保存音量で再生（一瞬フル音量なし）
3. Chrome / Spotify 等でも同様
4. Console（Debug ビルド）: `Other app IO started` → `reapply finished` → `audible 'audi'` の順

Debug ログ: メニューバーアイコン Option+クリックで Debug Logging。

---

## 既知の制限・今後の改善候補

- メニュー操作（`showHideExtraControls`）や KVO 挿入時に `reapply` ログが増えることがある（音量に問題なければ低優先度）
- 初回 IO と audible の両方で `scheduleReapply` が走ることがある（二重だが実害は小さい）
- `suppressStopIfIdleForLaunchGracePeriod` の呼び出し接続
- upstream への PR は Safari/Whale 等の Fork 独自コミットとの差分整理が必要

---

## 参照

- 上流: https://github.com/kyleneideck/BackgroundMusic
- DPA Fork: https://github.com/DigiPressApps/BackgroundMusic
- 関連 issue（永続化）: 上流で長年要望あり（本 Fork では独自実装）

---

*記録日: 2026-06-03*
