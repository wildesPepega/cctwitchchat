# Twitch Chat Client for CC: Tweaked

A Twitch chat client that runs inside Minecraft on a ComputerCraft: Tweaked
computer or turtle. Read and write Twitch chat in-game, show the chat history
on an attached monitor, see real Twitch name colors, highlight your own
mentions, mark 7TV emotes, and auto-update straight from this GitHub repo.

---

## Features

- **Login storage** – your username and OAuth token are entered once (token
  input is hidden) and stored locally in an obfuscated file. See the security
  note below.
- **Real Twitch name colors** – read from the IRCv3 `color` tag and mapped to
  the nearest of ComputerCraft's 16 colors.
- **Mention highlight** – any message containing your name gets a highlighted
  background.
- **Monitor support** – attach a monitor and the scrolling chat history is
  drawn there automatically (advanced/color monitor recommended).
- **Multi-channel read** – join extra channels to read with `/join`, change
  the channel you write to with `/switch`.
- **7TV emote highlighting** – global and channel 7TV emote *names* are colored
  in the message text (the images themselves cannot be shown – CC has no way to
  render pictures).
- **Auto-update** – on launch the script checks this repo's `version.txt`; if a
  newer version exists it downloads the new `twitch.lua`, overwrites itself, and
  reboots.

---

## Requirements

- Minecraft with **CC: Tweaked** (included in All The Mods 10 and many packs).
- The HTTP API must be enabled (default in most single-player setups). The
  domains `irc-ws.chat.twitch.tv`, `7tv.io`, `decapi.me`, and
  `raw.githubusercontent.com` must not be blocked in the server config.
- A Twitch **OAuth token** for the account that will chat. Generate one with a
  token generator such as twitchtokengenerator.com or twitchapps.com/tmi. The
  token looks like `oauth:xxxxxxxxxxxxxxxx`.

---

## Installation

On the in-game computer:

```
wget https://raw.githubusercontent.com/wildesPepega/cctwitchchat/main/twitch.lua twitch
```

Or paste it manually:

```
edit twitch
```

…then paste the contents of `twitch.lua`, save with Ctrl, and exit.

Run it with:

```
twitch
```

On first launch you'll be asked for your Twitch username and OAuth token
(hidden), then for the channel to join.

---

## Configuring the auto-updater

Open `twitch.lua` and edit these lines near the top to point at your own repo:

```lua
local REPO_USER   = "YOUR_GITHUB_USERNAME"
local REPO_NAME   = "YOUR_REPO_NAME"
local REPO_BRANCH = "main"
```

Your repo should contain:

- `twitch.lua` – the script itself
- `version.txt` – a single line with the current version, e.g. `1.0`

To publish an update: bump `local VERSION` in `twitch.lua`, push the new
`twitch.lua`, and set `version.txt` to the same new number. Clients update on
their next launch.

---

## Commands

| Command            | Description                              |
|--------------------|------------------------------------------|
| `/join <channel>`  | Join another channel (read its chat)     |
| `/switch <channel>`| Change the channel you send messages to  |
| `/channels`        | List joined channels                     |
| `/clear`           | Clear the chat history                   |
| `/logout`          | Delete the stored login                  |
| `/help`            | Show the command list                    |
| `/quit`            | Exit                                     |

---

## 7TV emote endpoints used

- Global emotes: `https://7tv.io/v3/emote-sets/global`
- Channel emotes: `https://7tv.io/v3/users/twitch/{twitch_id}`
- Twitch user-id lookup: `https://decapi.me/twitch/id/{login}`

Only emote **names** are used, to color matching words in chat. No images are
downloaded or displayed.

---

## Security note (please read)

The stored login is **obfuscated, not securely encrypted**. The computer needs
the token in clear text to log in to Twitch, and the obfuscation key is inside
the script, so anyone with access to the computer (or the script) can recover
the token. Treat it like a password stored in a plain config file:

- Prefer a **dedicated bot/test account**, not your main Twitch account.
- If a token is ever exposed, **revoke/regenerate it** in your token generator.
- Use `/logout` to remove the stored login from the computer.

If you want maximum safety, modify the script to ask for the token on every
launch and never write it to disk.

---

## Limitations

- ComputerCraft terminals/monitors render text and 16 colors only – no emote
  images, no video, no full RGB. Name colors are approximated to the nearest CC
  color, and emotes are shown as colored text.
- ComputerCraft does not use full UTF-8; the script maps common characters
  (German umlauts, €, typographic quotes) to ASCII equivalents and replaces
  other non-displayable bytes with `?`.
- Following a channel is **not** possible from a chat client – Twitch removed
  the public follow endpoint years ago. `/join` only reads a channel's chat.

---

## License

Do whatever you like with it. No warranty.
