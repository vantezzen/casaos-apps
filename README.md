# Mediarr

1. Open the casaOS App Store
2. Below the featured apps on the right, click on the number of available apps to open the app store list (e.g. "200 apps")
3. Click "More Apps". This will turn the button into an input field. Paste the following URL and press "Add":

> https://github.com/vantezzen/casaos-apps/archive/refs/heads/main.zip

## How to install

The default credentials are `admin` / `mediarr`. Optionally change them by filling in `SERVICES_USERNAME` and `SERVICES_PASSWORD` in the "configurator" service **before** starting.

Set your VPN credentials in the environment variables of the "vpn" service **before** starting Mediarr!
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

⚠️ Set `VPN_PORT_FORWARDING=off` if your provider doesn't support it!

## After Installation

Installation takes a little while since it sets up a lor of services for you.

1. **Wait ~2 minutes** for the auto-configurator to wire all services together. You can see if services are up inside the Mediarr page
2. **Add indexers** in Prowlarr (`:9696`) — tag Cloudflare-protected ones with `flaresolverr`
3. **Set up Jellyfin** (`:8096`) — add `/data/movies` and `/data/tv` as libraries
4. **Set up Jellyseerr** (`:5055`) — use `http://[YOUR-CASAOS-IP]:8096` as the Jellyfin URL
