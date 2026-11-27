# DPA Fork: Upstream v0.5.0 への移行メモ

作業ブランチ: `fork/update-to-0.5.0`  
ベース: [kyleneideck/BackgroundMusic v0.5.0](https://github.com/kyleneideck/BackgroundMusic/releases/tag/v0.5.0)  
目標リリース: **0.5.0-dp.1**

## 方針

1. `v0.5.0` を土台にする（`master` への巨大 merge は避ける）
2. DPA 独自の **アプリ別音量永続化** を再適用
3. 本家 v0.5.0 で報告された **メモリ肥大 / 突然終了** を調査・修正
4. Xcode 27 向けビルド修正（deployment target など）を同梱

## 取り込んだ本家 v0.5.0 の要点

- 無音時に PlayThrough / IO を止める（マイクインジケータ対策）
- BGMDevice リスナーを `BGMPlayThrough` → `BGMAudioDeviceManager` へ移設
- ブラウザ helper 向け音量ルーティング（Fork 由来の一部が本家に合流済み）
- アプリ別ミュート、自動一時停止の遅延設定 など

## DPA として再適用したもの

| 領域 | 内容 |
|------|------|
| `BGMUserDefaults` | `SavedAppVolumes`（`rvol` / `ppos`） |
| `BGMAppVolumesController` | 保存・UI マージ・IO/audible 時の `reapply` |
| `BGMAppDelegate` | `userDefaults` 注入 |
| `BGM_ClientMap` / `BGM_Clients` | past client map（本家 TODO の実装） |

**未接続（意図的）:** 旧 Fork の `suppressStopIfIdleForLaunchGracePeriod`  
v0.5.0 で `StopIfIdle` / リスナー配置が大きく変わったため、単純移植はしない。必要なら新アーキテクチャ向けに再設計する。

## ビルド修正（Xcode 27.2）

- `MACOSX_DEPLOYMENT_TARGET` を **10.13 → 12.0**（Xcode が 10.13 を拒否するため）
- deprecated API を置換（`NSOnState` → `NSControlStateValueOn`、`NSStatusItem.image` → `button.image`、`URLForApplicationWithBundleIdentifier` など）

## メモリ調査（Phase 2）

ユーザー報告: 本家 v0.5.0 起動中にメモリが増加し 4GB 超、アプリが突然終了することがある。

### 優先仮説

1. アイドル停止後の PlayThrough Start/Stop とリングバッファ寿命
2. `BGM_Clients` の inactivity `dispatch_source` タイマー寿命
3. プロパティリスナーの多重登録（現状は `bgmDeviceListenersRegistered` ガードあり）
4. jetsam による強制終了（「いつの間にか終了」）

### 推奨再現手順

1. 本家または本ブランチのビルドを起動
2. Instruments → Allocations / Leaks で BGMApp を監視
3. 再生開始/停止を繰り返し、無音放置も試す
4. `log show --predicate 'eventMessage CONTAINS "jetsam" OR process CONTAINS "Background Music"' --last 6h`

## ビルド確認（実施済み）

```bash
xcodebuild -project BGMApp/BGMApp.xcodeproj -scheme "Background Music" -configuration Debug build
xcodebuild -project BGMDriver/BGMDriver.xcodeproj -scheme "Background Music Device" -configuration Debug build
xcodebuild -project BGMApp/BGMApp.xcodeproj -scheme BGMXPCHelper -configuration Debug build
```

いずれも **BUILD SUCCEEDED**（2026-11-27、Xcode 27.2）。

## 次のステップ

1. 実機で Debug インストールし、音量永続化のスモークテスト
2. Instruments でメモリ成長を確認し、必要なら修正コミット
3. README / Release ノートを整えて `0.5.0-dp.1` pkg を作成・公証
