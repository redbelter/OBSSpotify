# OBSSpotify

Now-playing + chat overlays for the OBS rig (Main PC -> Beelink split).

## Now-playing pipeline
- `np_serve.ps1` runs on the MAIN PC (scheduled task `NpServe`). Reads the active
  media session via Windows.Media.Control GSMTCS (`TryGetMediaPropertiesAsync` ->
  Title + Artist + PlaybackStatus; works for Spotify AND Chrome/YouTube), writes
  `np.txt`, and pushes `Label|Title` to `http://192.168.15.16:5197/push`.
- `np_page_beelink.ps1` runs on the Beelink (task `NpPage`, path `C:\stream\np_page.ps1`).
  Raw TcpListener on :5197; caches the pushed state, fetches iTunes artwork on track
  change (artworkUrl100 -> 100x100bb, embedded base64), serves the composed card HTML.
For browser sources (`youtube` etc) the publisher appends the source URL:
`[youtube] Now playing: Artist - Title :: https://www.youtube.com/watch?v=...`. The URL is
resolved by `np_url.py`, which matches the GSMTCS page title against Firefox's places.sqlite
(read-only copy). Spotify lines carry no URL suffix.

`np.txt` format: `[source] Label: Artist - Title`, where source is `spotify`, `youtube`
(or lowercase AUMID for other hosts), Label is `Now playing`/`Paused`. The push payload to
the Beelink stays unprefixed `Label|Title` so the compositor parses it unchanged.

- OBS now-playing browser source points at `http://192.168.15.16:5197/`.

Notes: WinRT calls are gated to track-change/every-30s to avoid input hitches on the gaming box.
Main->Beelink push direction avoids the inbound-firewall issue on Main (all Public profiles).

## Chat overlay
- `chat_widget.html`: WebSocket IRC to `irc-ws.chat.twitch.tv:443` as anonymous viewer,
  renders only `Username: message` chips (VT323), transparent background, `--acc` theme var.
