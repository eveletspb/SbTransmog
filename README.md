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
prefix. This value must stay synchronized with `mod-transmog`.

## License

AGPL-3.0. See [LICENSE](LICENSE).
