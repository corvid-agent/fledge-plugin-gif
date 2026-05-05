# fledge-plugin-gif

Search, explore, and save GIFs from the terminal. Powered by the Tenor API.

## Install

```bash
fledge plugins install corvid-agent/fledge-plugin-gif
```

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
