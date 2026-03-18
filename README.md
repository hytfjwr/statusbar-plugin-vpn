# VPN Plugin for StatusBar

VPN connection status widget for [StatusBar](https://github.com/hytfjwr/StatusBar).

## Features

- VPN connection status indicator
- Periodic status polling (5s interval)

## Install

In StatusBar preferences → Plugins → Add Plugin:

```
hytfjwr/statusbar-plugin-vpn
```

## Development

```bash
make build      # Release build
make dev        # Build & install locally
make release    # Build & publish GitHub Release
```

## Requirements

- macOS 26+
- [StatusBar](https://github.com/hytfjwr/StatusBar)

## License

MIT
