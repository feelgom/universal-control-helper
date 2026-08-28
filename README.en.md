<p align="center">
  <img src=".github/assets/hero.svg" alt="Universal Control Helper — keyboard input fixes for macOS Universal Control" width="100%" />
</p>

<h1 align="center">Universal Control Helper</h1>

<p align="center">
  <strong>Brings Caps Lock input-source switching back to life across Universal Control.</strong>
  <br />
  <sub>The cursor moves to another Mac naturally. Your muscle memory should too.</sub>
</p>

<p align="center">
  <a href="https://github.com/feelgom/universal-control-helper/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/feelgom/universal-control-helper/ci.yml?branch=main&style=flat-square&label=build"></a>
  <a href="https://github.com/feelgom/universal-control-helper/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/feelgom/universal-control-helper?style=flat-square&color=5b7cfa"></a>
  <a href="https://github.com/feelgom/universal-control-helper/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/feelgom/universal-control-helper?style=flat-square&color=f5c542"></a>
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-31c48d?style=flat-square"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111827?style=flat-square&logo=apple">
</p>

<p align="center">
  <a href="README.md">한국어</a> · English
</p>

<p align="center">
  <a href="#why-you-need-it">Why you need it</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#updates">Updates</a> ·
  <a href="#development">Development</a>
</p>

---

## Why you need it

Universal Control lets one keyboard and trackpad move naturally between two Macs. But **Caps Lock input-source switching can stop working the moment you move to the other Mac** — this project started from the Korean ABC ↔ 두벌식 (Korean 2-set) case, but the same underlying bug affects any input-source pair.

Move the cursor to the other Mac and press Caps Lock like you always do, and:

1. Typing starts in the wrong input source.
2. You delete the garbled characters.
3. You click the input menu or hunt for another shortcut to switch manually.
4. The same cycle repeats every time you move between a document, a chat app, and the terminal.

> **The cursor crosses over smoothly. The input habit you rely on doesn't follow.**  
> Universal Control Helper closes that small-but-constant gap.

### Before and after

| Without Universal Control Helper | With Universal Control Helper |
| --- | --- |
| Caps Lock doesn't switch input source on the other Mac | **One Caps Lock press**, on either Mac, just like always |
| Typos from typing in the wrong input source, then retyping | The two Macs' **input source state syncs automatically** |
| Have to click the input menu or remember a different shortcut | **Same muscle memory**, no matter where the cursor is |

Universal Control Helper detects the **physical Caps Lock** press on the Mac the keyboard is attached to and relays it to whichever Mac you're controlling. It also keeps both Macs' input source in sync when you switch it another way (input menu, another shortcut).

- It does not process regular key input.
- It never collects or transmits typed text, clipboard content, or mouse events.
- It runs quietly from the menu bar, and you can turn it off any time.

**If you connect two Macs with Universal Control and switch input source with Caps Lock, this app closes the last broken piece of that experience.**

> This is an unofficial, open-source utility. It is not affiliated with or endorsed by Apple.

## Quick start

### Install script — recommended

This downloads the latest GitHub Release, verifies the published SHA-256 checksum and app signature, then installs to `/Applications`. Any existing install is moved to a backup folder in your user Library rather than deleted.

```bash
curl -fsSL https://github.com/feelgom/universal-control-helper/releases/latest/download/install.sh | bash
```

To review the script before running it:

```bash
curl -fsSL https://github.com/feelgom/universal-control-helper/releases/latest/download/install.sh -o /tmp/universal-control-helper-install.sh
less /tmp/universal-control-helper-install.sh
bash /tmp/universal-control-helper-install.sh
```

You can also skip launching the app automatically, or install to a different folder.

```bash
bash /tmp/universal-control-helper-install.sh --no-launch
bash /tmp/universal-control-helper-install.sh --install-dir "$HOME/Applications"
```

### Manual install

Download `UniversalControlHelper-macOS-universal.zip` from the [latest Release](https://github.com/feelgom/universal-control-helper/releases/latest), unzip it, and move `Universal Control Helper.app` to `/Applications`.

> [!IMPORTANT]
> Public builds without an Apple Developer ID configured ship with an ad-hoc signature, so on first launch you may need to Control-click the app in Finder and choose **Open**. Once Developer ID credentials are registered, the same pipeline automatically ships a signed and notarized app instead.

## Usage

Install the app on both Macs, then match up roles and a pairing code.

| Mac | Role | Permissions needed | What to do |
| --- | --- | --- | --- |
| The Mac the keyboard is plugged into | **Keyboard Mac (Source)** | Input Monitoring, Local Network | Note the auto-generated code |
| The other Mac you're controlling | **Target Mac (Target)** | Local Network | Enter Source's code |

1. Connect both Macs to the same local network and enable Universal Control.
2. Open Settings from the menu bar (**Settings…**) or with `Command-,`.
3. Set the Mac the keyboard is attached to as Source, and the other one as Target.
4. Enter the auto-generated **pairing code** shown on Source into Target.
5. Approve the local network prompts that appear on both Macs on first connection, and approve Input Monitoring on Source only.

The Settings window is organized into General, Connection, Source-only Input Permissions, and Software Update, in that order. Pressing `Command-W` while the window is open keeps the menu bar app running but hides it from `Command-Tab`. Reopen it from the menu bar's **Settings…**. Local Network permission is requested automatically by macOS on first connection, so it isn't a separate settings item. Accessibility permission is not required.

The menu bar menu only shows an on/off switch, Settings, and Quit. Role, pairing code, connection, and updates are all managed from the Settings window. Turning off **Use Universal Control Helper** — from the top switch or Settings — pauses both input-source syncing and the connection between the two Macs. Turning on **Launch automatically when you log in to your Mac** registers it as a macOS login item without a separate helper process.

## How it works

```text
Physical Caps Lock + configured input source pair
              │
              ▼
Source Mac ── Bonjour / same LAN ──▶ Target Mac
 detects Caps Lock   verifies 6-digit code   switches input source
```

- Source only detects the physical Caps Lock press on the keyboard and never blocks key input.
- Between two current versions, input source state changed from the input menu or another shortcut is also synced.
- Target is discovered automatically via Bonjour, and only connections with a matching code are processed.
- Target checks its current input source, then switches directly between the two input sources chosen in Settings using the macOS API.
- Regular key input, typed text, clipboard content, and mouse events are never collected or transmitted.

### Current scope

- macOS 13 or later
- Any pair of input sources you choose in Settings (defaults to `ABC ↔ 두벌식`; change it under **Input sources to toggle** in Settings for a different language pair)
- A trusted, shared local network
- While Source is running, its current input source state is relayed to Target automatically

The pairing code only distinguishes this app's connections from others on the same network — it does not provide network encryption. Do not use this on public or untrusted networks.

## Updates

The app checks for EdDSA-signed updates from GitHub Releases using [Sparkle](https://sparkle-project.org/). The **Software Update** section in Settings shows the current version and lets you choose **Check for Updates…**, and periodic background checks are also supported.

Source uses the Input Monitoring permission so it can detect the physical Caps Lock press even while Universal Control is forwarding the keyboard to Target. Target does not need this permission. If the switch is on but the current build shows as not permitted, use **Re-register permission…** in Settings and approve the macOS prompt. If the app doesn't appear automatically in the permission list, click `+` in Input Monitoring settings and select `/Applications/Universal Control Helper.app`. Ad-hoc-signed builds without a Developer ID can't fully rule out macOS asking to re-approve permission after an update; adopting a Developer ID lets the app keep the same signing identity across updates.

## Development

```bash
swift test -Xswiftc -warnings-as-errors
BUILD_UNIVERSAL=1 ./scripts/build-app.sh
REQUIRE_UNIVERSAL=1 ./scripts/verify-release.sh
```

Pushing a `v*` tag runs tests, builds the Universal Binary, signs with Sparkle, generates the appcast, and uploads the Release via GitHub Actions. Developer ID signing and notarization are added automatically when Apple credentials are configured. See [RELEASING.md](RELEASING.md) for the full process.

## Star History

<p align="center">
  <a href="https://www.star-history.com/?repos=feelgom%2Funiversal-control-helper&type=date&legend=top-left">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=feelgom/universal-control-helper&type=date&theme=dark&legend=top-left&sealed_token=FwEg8EPGkwsDKHlbN4MhzmytFu5S0LOeuuX13EWlrAvb6dZKzGz0W7xg_2wxftWukmAlnqMS9DlVzbhB1zmZXNecoFq1n6Y6Mt30B8OCIzTj10uCc3ZKJQ" />
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=feelgom/universal-control-helper&type=date&legend=top-left&sealed_token=FwEg8EPGkwsDKHlbN4MhzmytFu5S0LOeuuX13EWlrAvb6dZKzGz0W7xg_2wxftWukmAlnqMS9DlVzbhB1zmZXNecoFq1n6Y6Mt30B8OCIzTj10uCc3ZKJQ" />
      <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=feelgom/universal-control-helper&type=date&legend=top-left&sealed_token=FwEg8EPGkwsDKHlbN4MhzmytFu5S0LOeuuX13EWlrAvb6dZKzGz0W7xg_2wxftWukmAlnqMS9DlVzbhB1zmZXNecoFq1n6Y6Mt30B8OCIzTj10uCc3ZKJQ" />
    </picture>
  </a>
</p>

## Security and contributions

- Please report security issues through the private channel described in the [security policy](SECURITY.md) rather than a public issue.
- Bug reports and feature suggestions are welcome on [GitHub Issues](https://github.com/feelgom/universal-control-helper/issues).
- The code is distributed under the [MIT License](LICENSE).
