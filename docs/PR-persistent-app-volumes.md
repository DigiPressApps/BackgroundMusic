# Pull Request: アプリ別音量の永続化と再起動後の復元

## PR タイトル（案）

```
Persist per-app volumes and restore levels after reboot and IO start
```

日本語サブタイトル（Fork 内 PR 用）:

```
アプリ別音量の永続化と、再起動・再生開始後の音量復元
```

---

## Summary（PR 本文に貼り付け）

```markdown
## Summary

- Persist per-app relative volume and pan in UserDefaults keyed by bundle ID (`SavedAppVolumes` / `rvol` / `ppos`).
- Re-apply saved levels to the BGM driver when other apps start IO and on audible-state edges, with immediate push plus short retries for late HAL clients (e.g. Quick Look).
- Update the driver past-client map when `SetAppVolume` runs before a process becomes a HAL client (implements existing TODO in `BGM_Clients.cpp`).
- Reduce spurious re-applies from brief audible-state flicker (`silt` ↔ `audi`) via delayed silent confirmation and a 2s audible-path cooldown.
- Add optional PlayThrough `StopIfIdle` launch grace API (not yet wired from delegate).

## Motivation

After a Mac restart, menu sliders could show saved values but audio played at default level until the user moved a slider. Root causes: volumes were not persisted in official builds, early `SetAppVolume` calls did not update `mPastClientMap`, and BGMApp often re-applied volumes only after audible state changed.

## Test plan

- [ ] Clean build BGMApp (Debug) and reinstall BGMDriver from this branch
- [ ] Set Finder (or Chrome) app volume below 100%, quit BGMApp, relaunch — slider and audio match
- [ ] Reboot Mac, launch Background Music, preview MP3 in Finder — no initial full-volume flash
- [ ] Repeat preview stop/start after ~10s silence — volume still correct
- [ ] Spotify / Chrome playback — volumes unchanged after reboot
- [ ] (Debug) Console: `Other app IO started` then `reapply finished` before or with `audible 'audi'`
- [ ] Driver-only: new app launch applies past volume without moving slider

## Notes

- Fork-specific browser/helper routing commits on `master` are unchanged by this branch.
- See `docs/CHANGELOG-fork-persistent-app-volumes.md` for a detailed Japanese change log.
```

---

## 手順（DPA / DigiPressApps/BackgroundMusic）

### 1. ブランチを push 済みであること

```bash
cd /path/to/BackgroundMusic
git fetch origin
git checkout feature/persistent-app-volumes-restore
```

### 2. GitHub で Pull Request を作成

**ベース:** `DigiPressApps/BackgroundMusic` → `master`  
**比較:** `feature/persistent-app-volumes-restore`

Web UI:

1. https://github.com/DigiPressApps/BackgroundMusic/compare
2. base: `master` ← compare: `feature/persistent-app-volumes-restore`
3. タイトル・本文は上記 Summary を使用

CLI（`gh` 利用時）:

```bash
cd /path/to/BackgroundMusic
git push -u origin feature/persistent-app-volumes-restore

gh pr create --repo DigiPressApps/BackgroundMusic \
  --base master \
  --head feature/persistent-app-volumes-restore \
  --title "Persist per-app volumes and restore levels after reboot and IO start" \
  --body-file docs/PR-persistent-app-volumes.md
```

`gh pr create --body-file` はファイル全体を入れると見出しが重複するため、**Summary セクションのみ**をコピーして `--body` に渡すか、Web で編集してください。

### 3. マージ前チェック

- [ ] Xcode で `Background Music` スキームがビルドできる
- [ ] ドライバインストール手順を README / 既存 Fork 手順に従って実施
- [ ] 上記 Test plan を実機で確認

### 4. マージ後

```bash
git checkout master
git pull origin master
```

Release 用にタグ付けする場合は Fork のリリース手順に従ってください。

---

## upstream（kyleneideck/BackgroundMusic）への PR

本 Fork の `master` には Safari / Whale ヘルパー向けルーティング等の独自コミットが含まれます。上流へ送る場合は:

1. `upstream/master` から専用ブランチを切る  
2. 本 PR のコミットのみ cherry-pick、またはファイル単位で移植  
3. 競合（`BGMAppVolumesController` 等）を手動解消  

永続化のみを上流に提案する場合は、本ブランチの 12 ファイル + `docs/` に絞るのが安全です。
