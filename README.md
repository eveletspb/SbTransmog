# SbTransmog

Client addon for the AzerothCore `mod-transmog` module.


## Requirements

- World of Warcraft 3.3.5a (interface 30300)
- A server running a compatible `mod-transmog` version
- fork  https://github.com/eveletspb/mod-transmog

## Installation

Place this repository in the game client as:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── SbTransmog/
            ├── SbTransmog.toc
            ├── Core.lua
            └── ...
```

Enable `SbTransmog` in the addon list on the character-selection screen.

## Compatibility

The addon communicates with the server through the `AC_TRANSMOG` protocol
prefix, version **5**. Update the addon and `mod-transmog` together; older
protocol versions are rejected.

## Usage

Open `/transmog` anywhere, without interacting with an NPC. Select an equipped
slot, search by item name (press Enter or Search), and choose a quality from the
quality dropdown. Search uses the player's server locale and ignores case.
The server filters the entire compatible collection before pagination and sorts
by quality descending, then name. Clear the search and select All qualities to
show the full collection. Applying appearances and managing outfits use the same
server validation and costs as before.

## License

AGPL-3.0. See [LICENSE](LICENSE).
