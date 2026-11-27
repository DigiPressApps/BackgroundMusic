# Fork 変更ログ: アプリ別音量の永続化（0.5.0-dp.1 ベース）

このドキュメントは、[kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic) **v0.5.0** をベースにした **DPA 版 Fork**（[DigiPressApps/BackgroundMusic](https://github.com/DigiPressApps/BackgroundMusic)）の、**アプリ別音量永続化**まわりの変更を記録します。

移行の経緯は [MIGRATION-to-0.5.0.md](MIGRATION-to-0.5.0.md) を参照。

---

## 0.5.0-dp.1 での位置づけ

| 項目 | 内容 |
|------|------|
| ベース | Upstream `v0.5.0` |
| DPA 追加 | UserDefaults 永続化 + IO/audible 再適用 + ドライバ past client map |
| 本家に合流済みで再移植不要 | Safari / Chrome / Whale 等の helper ルーティング |
| 最低 OS | macOS **12.0+**（Xcode 27 の制約に合わせて deployment target を更新） |

---

## 機能概要

1. **永続化（BGMApp）** — bundle ID キーで `rvol` / `ppos` を UserDefaults に保存
2. **再適用** — 他アプリ IO 開始 / audible エッジでドライバへ再送（リトライ付き）
3. **past client map（BGMDriver）** — HAL クライアント未登録時の音量を保持し、`AddClient` 時に適用

詳細な設計経緯（0.4.4-dp.1 時代）は Git 履歴の `a55e508` および旧 CHANGELOG を参照。v0.5.0 では PlayThrough リスナー配置が変わっているため、起動猶予 API（`suppressStopIfIdle…`）は一旦未接続。

---

## 変更ファイル（永続化）

```
BGMApp/BGMApp/BGMAppDelegate.mm
BGMApp/BGMApp/BGMAppVolumesController.h
BGMApp/BGMApp/BGMAppVolumesController.mm
BGMApp/BGMApp/BGMUserDefaults.h
BGMApp/BGMApp/BGMUserDefaults.m
BGMDriver/BGMDriver/DeviceClients/BGM_ClientMap.cpp
BGMDriver/BGMDriver/DeviceClients/BGM_ClientMap.h
BGMDriver/BGMDriver/DeviceClients/BGM_Clients.cpp
```

---

## 動作確認チェックリスト

- [ ] Mac 再起動後、保存したアプリ音量がスライダーと実音量の両方に反映される
- [ ] Finder Quick Look / Chrome（**BGM 起動後に Chrome を起動または再起動**）でスライダーが効く
- [ ] 長時間稼働で BGMApp メモリが GB 級に増加しない（本家 v0.5.0 由来の調査対象）
