<!-- vim: set tw=120: -->

![](Images/README/FermataIcon.png)

# Background Music — DPA Fork
##### macOS audio utility · based on [kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic)

<img src="Images/README/Screenshot.png" width="340" height="443" />

**English:** This repository is the **DPA** fork of [kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic). **DPA** stands for [DigiPressApps](https://github.com/DigiPressApps). It adds **persistent per-app volumes**, **automatic volume restore after reboot**, and improved routing for browser media helpers. Signed `.pkg` installers are published under [Releases](https://github.com/DigiPressApps/BackgroundMusic/releases/latest).

**日本語:** [kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic) をベースにした **DPA 版 Fork** です。**DPA** は [DigiPressApps](https://github.com/DigiPressApps) の略称です。**アプリ別音量の永続化**、**再起動後の音量復元**、ブラウザのメディアヘルパー向けルーティングなどを追加しています。署名・公証済み `.pkg` は [Releases](https://github.com/DigiPressApps/BackgroundMusic/releases/latest) から入手できます（ターミナル不要）。

##### *Note: Background Music is still in alpha. This fork is not distributed on the Mac App Store.*

[What's different](#whats-different-in-this-fork)<br/>
[Overview](#overview)<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Auto-pause music](#auto-pause-music)<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Application volume](#application-volume)<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Recording system audio](#recording-system-audio)<br/>
[Download](#download)<br/>
[Run / Configure](#run--configure)<br/>
[Build and Install](#installing-from-source-code)</br>
[Uninstall](#uninstall)<br/>
[Troubleshooting](#troubleshooting)<br/>
[Upstream project](#upstream-project)<br/>
[Related Projects](#related-projects)<br/>
[License](#license)<br/>

# What's different in this fork

Compared to the upstream 0.4.3 release, this fork adds:

+ **Persistent per-app volume and pan** — saved by bundle ID in UserDefaults and restored after quitting BGMApp or restarting your Mac
+ **Automatic volume restore when playback starts** — reapplies saved levels when other apps begin audio I/O (e.g. Finder Quick Look previews)
+ **Driver past-client volume map** — volumes set before a HAL client registers are applied when the app starts playing
+ **Safari / Chrome / Whale media helper routing** — per-app sliders reach helper processes that upstream could not control on recent macOS versions

**日本語での要約**

+ **アプリ別音量・パンの永続化** — 再起動後も保存値を復元
+ **再生開始時の音量復元** — Finder プレビュー等で IO 開始時に再適用
+ **ドライバ past-client map** — HAL クライアント登録前の音量も後から反映
+ **Safari / Chrome 等のメディアヘルパー対応**

See [docs/CHANGELOG-fork-persistent-app-volumes.md](docs/CHANGELOG-fork-persistent-app-volumes.md) for details (Japanese).

# Overview

+ Automatically pause/unpause your music player when other audio sources are playing/stopped
+ Per-application volume control
+ Record system audio
+ No restart required to install

## Auto-pause music

**Background Music** automatically pauses your music player when a second audio source is playing and unpauses the player when the second source has stopped.

The auto-pause feature currently supports following music players:

+ [iTunes](https://www.apple.com/itunes/)
+ [Spotify](https://www.spotify.com)
+ [VLC](https://www.videolan.org/vlc/)
+ [VOX](https://vox.rocks/mac-music-player)
+ [Decibel](https://sbooth.org/Decibel/)
+ [Hermes](http://hermesapp.org/)
+ [Swinsian](https://swinsian.com/)
+ [GPMDP](https://www.googleplaymusicdesktopplayer.com/)

Adding support for a new music player is usually straightforward.<sup id="a1">[1](#f1)</sup> If you don't know how to program, or just don't feel
like it, feel free to [create an issue](https://github.com/DigiPressApps/BackgroundMusic/issues/new). Otherwise, see
[BGMMusicPlayer.h](BGMApp/BGMApp/Music%20Players/BGMMusicPlayer.h).

## Application volume

**Background Music** provides a volume slider for each application running your system. You can boost quiet applications above their maximum volume.

**In this fork**, volume and pan settings are **saved automatically** and **restored after restart** when each app starts playing audio again. See [CHANGELOG](docs/CHANGELOG-fork-persistent-app-volumes.md) for details.

## Recording system audio

You can record system audio with **Background Music**. With **Background Music** running, launch **QuickTime Player** and select **File > New Audio Recording** (or **New Screen Recording**, **New Movie Recording**). Then click the dropdown menu (`⌄`) next to the record button and select **Background Music** as the input device.

You can record system audio and a microphone together by creating an [aggregate
device](https://support.apple.com/en-us/HT202000) that combines your input device (usually Built-in Input) with
the **Background Music** device. You can create the aggregate device using the **Audio MIDI Setup** utility under
***/Applications/Utilities***.

# Download

**Requires macOS 10.13+**.

## DPA Fork (recommended / 推奨)

Download the latest **signed and notarized** installer from this repository:

<a href="https://github.com/DigiPressApps/BackgroundMusic/releases/latest"><img
src="Images/README/pkg-icon.png" width="32" height="32" align="absmiddle" />
BackgroundMusic-*.pkg (latest release)</a>

**English:** Download **BackgroundMusic-0.4.4-dp.1.pkg** (or newer) from [Releases](https://github.com/DigiPressApps/BackgroundMusic/releases/latest), double-click to install, then open **Background Music** from **Applications**. No Terminal required.

**日本語:** [Releases](https://github.com/DigiPressApps/BackgroundMusic/releases/latest) から **BackgroundMusic-0.4.4-dp.1.pkg**（またはそれ以降）をダウンロードし、ダブルクリックでインストール。**アプリケーション** から **Background Music** を起動してください。

> **Note / 注意:** If upgrading from the upstream **0.4.3** release, uninstall the previous version first. / 公式 **0.4.3** からの場合は、先にアンインストールしてから入れ直すことを推奨します。

Current release checksum (v0.4.4-dp.1):

> SHA256: `a1035e06cde801ba153d79216c579b60510517abc2c4cd7e1e3267bb98bef8d4`

## Upstream (original project / 公式版)

The original project by Kyle Neideck is still available separately:

+ [kyleneideck/BackgroundMusic releases](https://github.com/kyleneideck/BackgroundMusic/releases) — **version 0.4.3**
+ Homebrew (upstream cask): `brew install --cask background-music`

<a href="https://github.com/kyleneideck/BackgroundMusic/releases/download/v0.4.3/BackgroundMusic-0.4.3.pkg"><img
src="Images/README/pkg-icon.png" width="32" height="32" align="absmiddle" />
BackgroundMusic-0.4.3.pkg (upstream)</a>

# Run / Configure

Just run `Applications > Background Music.app`! **Background Music** sets itself as your default output device under
`System Settings > Sound` when it starts up (and sets it back on Quit).

### Launch at Startup (Optional)

Add **Background Music** to `System Settings > General > Login Items`.

# Installing from Source Code

**Background Music** usually takes less than a minute to build. You need [Xcode](https://developer.apple.com/xcode/download/) version
10 or higher.

### Option 1

1. Open **Terminal**.
2. Copy and paste the following command into **Terminal**:

```shell
(set -eo pipefail; URL='https://github.com/DigiPressApps/BackgroundMusic/archive/master.tar.gz'; \
    cd $(mktemp -d); echo Downloading $URL to $(pwd); curl -qfL# $URL | gzcat - | tar x && \
    /bin/bash BackgroundMusic-master/build_and_install.sh -w && rm -rf BackgroundMusic-master)
```

<details><summary>More info...</summary>

This command uses `/bin/bash` instead of `bash` in case someone has a nonstandard Bash in their `$PATH`. However, it doesn't do this for `tar` or `curl`. In addition, `build_and_install.sh` doesn't call programs by absolute paths. This command also uses `gzcat - | tar x` instead of `tar xz` because `gzcat` will also check the file's integrity (gzip files
include a checksum), and will ensure that a half-downloaded copy of `build_and_install.sh` doesn't run.

</details>

### Option 2

1. Clone or [download](https://github.com/DigiPressApps/BackgroundMusic/archive/master.zip) this fork.
2. If the project is in a zip, unzip it.
3. Open **Terminal** and [change the directory](https://github.com/0nn0/terminal-mac-cheatsheet#core-commands) to the
   directory containing the project.
4. Run: `/bin/bash build_and_install.sh`.

The script restarts the system audio process (coreaudiod) at the end of the installation, so pause any applications
playing audio if you can.

To manually build and install, see [MANUAL_INSTALL.md](https://github.com/kyleneideck/BackgroundMusic/blob/master/MANUAL-INSTALL.md).

# Uninstall

To uninstall **Background Music** from your system, follow these steps:

1. Open **Terminal**.
2. To locate `uninstall.sh`, run: `cd /Applications/Background\ Music.app/Contents/Resources/`.
3. Run: `bash uninstall.sh`.

If you cannot locate `uninstall.sh`, you can [download this fork](https://github.com/DigiPressApps/BackgroundMusic/archive/master.zip) again.

To manually uninstall, see [MANUAL_UNINSTALL.md](https://github.com/kyleneideck/BackgroundMusic/blob/master/MANUAL-UNINSTALL.md).

# Troubleshooting

If Background Music crashes and your audio stops working, open `System Settings > Sound` and change your
system's default output device to something other than the **Background Music device**. If it already is, then
change the default device and then change it back again.

Make sure you allow "microphone access" when you first run Background Music. If you denied it, go to
`System Settings > Security & Privacy > Privacy > Microphone`, find Background Music in the list
and check the box next to it. Background Music doesn't actually listen to your microphone. It needs
the permission because it gets your system audio from its virtual input device, which macOS counts
as a microphone. (We're working on it in [#177](/../../issues/177).)

If the volume slider for an app isn't working, try looking in `More Apps` for entries like `Some
App (Helper)`. For some meeting or video chat apps, you may need to do this to change the current
meeting volume.

## Known issues and solutions

- **Setting an application's volume above 50% can cause [clipping](https://en.wikipedia.org/wiki/Clipping_(audio)).**

    - Set your volume to its maximum level and lower the volumes of other applications.

- **Only 2-channel (stereo) audio devices are currently supported for output.**

- **VLC pauses iTunes or Spotify when playing, and stops Background Music from unpausing your music afterward.**

    - Under VLC's preferences, select **Show All**. Navigate to **Interface > Main interfaces > macosx** and change *Control external music players* to either *Do nothing* or *Pause and resume iTunes/Spotify*.

- **Skype pauses iTunes during calls.**

    - To disable this, uncheck *Pause iTunes during calls* on the **General** tab of **Skype**'s preferences.

- **Plugging in or unplugging headphones when Background Music isn't running causes silence in the system audio.**
    - Navigate to **System Settings > Sound**. Click the **Output** tab and change your default output device to something other than the **Background Music** device. Alternatively, press **Option + Click** on the sound icon within the menu bar to select a different output device. This happens when macOS remembers that the **Background Music** device was your default audio device the last time you used (or didn't use) headphones.

- **[A Chrome bug](https://bugs.chromium.org/p/chromium/issues/detail?id=557620) stops Chrome from switching to the Background Music device after you open Background Music.**
    - Chrome's audio will still play, but **Background Music** won't be aware of it.

- **Some applications play notification sounds that are only just long enough to trigger an auto-pause.**
    - Increase the `kPauseDelayNSec` constant in [BGMAutoPauseMusic.mm](/BGMApp/BGMApp/BGMAutoPauseMusic.mm). It will increase your music's overlap time over other audio, so don't increase it too much. See [#5](https://github.com/kyleneideck/BackgroundMusic/issues/5) for details.

Many other issues are listed in [TODO.md](/TODO.md) and in [GitHub Issues](https://github.com/DigiPressApps/BackgroundMusic/issues).

# Upstream project

This fork is based on **[kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic)**. For the original documentation, issue tracker, and unsigned/snapshot builds, see the upstream repository.

To report bugs specific to **this DPA fork** (persistent volumes, signed releases, browser helper routing), please use [DPA Background Music issues](https://github.com/DigiPressApps/BackgroundMusic/issues).

# Related projects

- [Core Audio User-Space Driver
  Examples](https://developer.apple.com/library/mac/samplecode/AudioDriverExamples/Introduction/Intro.html)
  The sample code from Apple that BGMDriver is based on.
- [Soundflower](https://github.com/mattingalls/Soundflower) - "MacOS system extension that allows applications to pass
  audio to other applications."
- [WavTap](https://github.com/pje/WavTap) - "globally capture whatever your mac is playing—-as simply as a screenshot"
- [eqMac](http://www.bitgapp.com/eqmac/), [GitHub](https://github.com/nodeful/eqMac2) - "System-wide Audio Equalizer for the Mac"
- [llaudio](https://github.com/mountainstorm/llaudio) - "An old piece of work to reverse engineer the Mac OSX
  user/kernel audio interface. Shows how to read audio straight out of the kernel as you would on Darwin (where most the
  OSX goodness is missing)"
- [mute.fm](http://www.mutefm.com), [GitHub](https://github.com/jaredsohn/mutefm) (Windows) - Auto-pause music
- [Jack OS X](http://www.jackosx.com) - "A Jack audio connection kit implementation for Mac OS X"
- [PulseAudio OS X](https://github.com/zonque/PulseAudioOSX) - "PulseAudio for Mac OS X"
- [Sound Pusher](https://github.com/q-p/SoundPusher) - "Virtual audio device, real-time encoder and SPDIF forwarder for
  Mac OS X"
- [Zirkonium](https://code.google.com/archive/p/zirkonium) - "An infrastructure and application for multi-channel sound
  spatialization on MacOS X."
- [BlackHole](https://github.com/ExistentialAudio/BlackHole) - "a modern macOS virtual audio driver that allows applications to pass audio to other applications with zero additional latency."

### Non-free

- [Audio Hijack](https://rogueamoeba.com/audiohijack/), [SoundSource](https://rogueamoeba.com/soundsource/) - "Capture
  Audio From Anywhere on Your Mac", "Get truly powerful control over all the audio on your Mac!"
- [Sound Siphon](https://staticz.com/soundsiphon/), [Sound Control](https://staticz.com/soundcontrol/) - System/app audio recording, per-app volumes, system audio equaliser
- [SoundBunny](https://www.prosofteng.com/soundbunny-mac-volume-control/) - "Control application volume independently."
- [Boom 2](https://www.globaldelight.com/boom/) - "The Best Volume Booster & Equalizer For Mac"

## License

Copyright © 2016-2024 [Background Music contributors](https://github.com/kyleneideck/BackgroundMusic/graphs/contributors).
Additional changes in this DPA fork © [DigiPressApps](https://github.com/DigiPressApps). Licensed under [GPLv2](https://www.gnu.org/licenses/gpl-2.0.html), or any later version.

**Background Music** includes code from:

- [Core Audio User-Space Driver
  Examples](https://developer.apple.com/library/mac/samplecode/AudioDriverExamples/Introduction/Intro.html), [original
  license](LICENSE-Apple-Sample-Code), Copyright (C) 2013 Apple Inc. All Rights Reserved.
- [Core Audio Utility
  Classes](https://developer.apple.com/library/content/samplecode/CoreAudioUtilityClasses/Introduction/Intro.html),
  [original license](LICENSE-Apple-Sample-Code), Copyright (C) 2014 Apple Inc. All Rights Reserved.

----

<b id="f1">[1]</b> However, if the music player doesn't support AppleScript, or doesn't support the events Background
Music needs (`isPlaying`, `isPaused`, `play` and `pause`), it can take significantly more effort to add. (And in some
cases would require changes to the music player itself.) [↩](#a1)


