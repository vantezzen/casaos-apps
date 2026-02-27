https://github.com/vantezzen/casaos-apps/archive/refs/heads/main.zip

## Required: VPN Credentials

Set your VPN credentials in the environment variables before starting Mediarr.
Gluetun supports all major VPN providers. See the [Gluetun provider docs](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers) for the exact variables your provider needs.

**ProtonVPN (OpenVPN) example:**
| Variable | Value |
|---|---|
| `VPN_SERVICE_PROVIDER` | `protonvpn` |
| `VPN_TYPE` | `openvpn` |
| `OPENVPN_USER` | Your username **+ `+pmp`** (e.g. `user+pmp`) |
| `OPENVPN_PASSWORD` | Your password |

**Mullvad (WireGuard) example:**
| Variable | Value |
|---|---|
| `VPN_SERVICE_PROVIDER` | `mullvad` |
| `VPN_TYPE` | `wireguard` |
| `WIREGUARD_PRIVATE_KEY` | Your WireGuard private key |
| `WIREGUARD_ADDRESS` | e.g. `10.64.0.1/32` |

## Services & Ports

Open the **Mediarr Hub** at `:8974` to access all services from one place.

| Service     | Port                                  |
| ----------- | ------------------------------------- |
| Mediarr Hub | `:8974`                               |
| Jellyfin    | `:8096`                               |
| Jellyseerr  | `:5055`                               |
| Radarr      | `:7878`                               |
| Sonarr      | `:8989`                               |
| Prowlarr    | `:9696`                               |
| qBittorrent | `:8080` (default: admin / adminadmin) |

## After Installation

1. **Wait ~2 minutes** for the auto-configurator to wire all services together
2. **Add indexers** in Prowlarr (`:9696`) — tag Cloudflare-protected ones with `flaresolverr`
3. **Set up Jellyfin** (`:8096`) — add `/data/movies` and `/data/tv` as libraries
4. **Set up Jellyseerr** (`:5055`) — use `http://[YOUR-CASAOS-IP]:8096` as the Jellyfin URL
5. **Change qBittorrent password** at `:8080` → Tools → Options → Web UI

⚠️ If `VPN_PORT_FORWARDING=on` but your provider doesn't support it, set it to `off`.
