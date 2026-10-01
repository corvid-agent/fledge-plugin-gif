# fledge-plugin-gif

Search, explore, and save GIFs from the terminal. Powered by GIPHY's Tenor-compatible API (Tenor itself shut down 2026-06-30).

## Install

```bash
fledge plugins install corvid-agent/fledge-plugin-gif
```


## Configuration

Tenor's public API was discontinued on 2026-06-30. This plugin uses **GIPHY's Tenor-compatible** endpoints (`https://api.giphy.com/v2/...`) with `contentfilter=medium`.

Set a GIPHY developer key in the environment (no default; never commit a key):

```bash
export GIPHY_API_KEY=…   # required
# TENOR_API_KEY=…        # optional legacy alias; same GIPHY key
```

Get a key from the [GIPHY developer dashboard](https://developers.giphy.com/dashboard/). Attribution: Powered By GIPHY.

## Usage

```bash
# Search for GIFs
fledge gif search "nice work"
fledge gif search thumbs up --limit 5

# Browse trending GIFs
fledge gif trending

# Get a random GIF
fledge gif random "celebration"

# Save your favorites
fledge gif save celebration https://media.tenor.com/...
fledge gif list
fledge gif get celebration

# Download a GIF to disk
fledge gif download https://media.tenor.com/... party.gif

# Remove a saved GIF
fledge gif remove celebration

# Output as JSON
fledge gif search "wow" --json
```

## Build

```bash
swift build -c release
mkdir -p bin
cp .build/release/fledge-plugin-gif bin/fledge-gif
```

## Test

```bash
swift test
```
