#!/bin/sh
# Mediarr auto-configurator
# Wires all *arr services, qBittorrent, FlareSolverr, and Prowlarr together
# on first install. Idempotent — safe to re-run.
set -e

# ── Guard: skip if already configured ─────────────────────────────────────────
if [ -f /state/configured ]; then
  echo "[mediarr-configurator] Already configured, exiting."
  exit 0
fi

echo "[mediarr-configurator] Starting auto-configuration..."

# ── Helper functions ───────────────────────────────────────────────────────────

wait_for_file() {
  echo "[mediarr-configurator] Waiting for $2..."
  n=0
  while [ $n -lt 120 ]; do
    [ -f "$1" ] && grep -q "<ApiKey>" "$1" 2>/dev/null && return 0
    sleep 2
    n=$((n + 2))
  done
  echo "[mediarr-configurator] Timeout waiting for $2 (path: $1)" >&2
  exit 1
}

wait_for_api() {
  echo "[mediarr-configurator] Waiting for $2 API..."
  n=0
  while [ $n -lt 120 ]; do
    curl -sf "$1" > /dev/null 2>&1 && return 0
    sleep 3
    n=$((n + 3))
  done
  echo "[mediarr-configurator] Timeout waiting for $2 API" >&2
  exit 1
}

extract_api_key() {
  sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' "$1"
}

api_get() {
  curl -sf -H "X-Api-Key: $2" "http://localhost:$1$3"
}

api_post() {
  curl -sf -X POST -H "X-Api-Key: $2" -H "Content-Type: application/json" \
    -d "$4" "http://localhost:$1$3"
}

api_put() {
  curl -sf -X PUT -H "X-Api-Key: $2" -H "Content-Type: application/json" \
    -d "$4" "http://localhost:$1$3"
}

# ── Phase 3: Wait for *arr API keys ───────────────────────────────────────────
wait_for_file /radarr-config/config.xml "Radarr config"
wait_for_file /sonarr-config/config.xml "Sonarr config"
wait_for_file /prowlarr-config/config.xml "Prowlarr config"

RADARR_KEY=$(extract_api_key /radarr-config/config.xml)
SONARR_KEY=$(extract_api_key /sonarr-config/config.xml)
PROWLARR_KEY=$(extract_api_key /prowlarr-config/config.xml)

echo "[mediarr-configurator] API keys extracted successfully."

# ── Phase 4: Wait for *arr APIs to respond ────────────────────────────────────
wait_for_api "http://localhost:7878/api/v3/system/status?apikey=$RADARR_KEY" "Radarr"
wait_for_api "http://localhost:8989/api/v3/system/status?apikey=$SONARR_KEY" "Sonarr"
wait_for_api "http://localhost:9696/api/v1/system/status?apikey=$PROWLARR_KEY" "Prowlarr"

echo "[mediarr-configurator] All APIs reachable."

# ── Phase 5: Configure Radarr ─────────────────────────────────────────────────
echo "[mediarr-configurator] Configuring Radarr..."

EXISTING_CLIENTS=$(api_get 7878 "$RADARR_KEY" /api/v3/downloadclient)
if ! echo "$EXISTING_CLIENTS" | grep -q '"QBittorrent"'; then
  api_post 7878 "$RADARR_KEY" /api/v3/downloadclient \
    "{\"name\":\"qBittorrent\",\"enable\":true,\"protocol\":\"torrent\",\"priority\":1,\"implementation\":\"QBittorrent\",\"configContract\":\"QBittorrentSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"localhost\"},{\"name\":\"port\",\"value\":8080},{\"name\":\"username\",\"value\":\"$SERVICES_USERNAME\"},{\"name\":\"password\",\"value\":\"$SERVICES_PASSWORD\"},{\"name\":\"movieCategory\",\"value\":\"radarr\"},{\"name\":\"recentMoviePriority\",\"value\":0},{\"name\":\"olderMoviePriority\",\"value\":0},{\"name\":\"initialState\",\"value\":0}]}" > /dev/null
  echo "[mediarr-configurator] Radarr: qBittorrent download client added."
else
  echo "[mediarr-configurator] Radarr: qBittorrent already configured."
fi

EXISTING_FOLDERS=$(api_get 7878 "$RADARR_KEY" /api/v3/rootfolder)
if ! echo "$EXISTING_FOLDERS" | grep -q '"/data/movies"'; then
  api_post 7878 "$RADARR_KEY" /api/v3/rootfolder \
    "{\"path\":\"/data/movies\"}" > /dev/null
  echo "[mediarr-configurator] Radarr: /data/movies root folder added."
fi

# ── Phase 6: Configure Sonarr ─────────────────────────────────────────────────
echo "[mediarr-configurator] Configuring Sonarr..."

EXISTING_CLIENTS=$(api_get 8989 "$SONARR_KEY" /api/v3/downloadclient)
if ! echo "$EXISTING_CLIENTS" | grep -q '"QBittorrent"'; then
  api_post 8989 "$SONARR_KEY" /api/v3/downloadclient \
    "{\"name\":\"qBittorrent\",\"enable\":true,\"protocol\":\"torrent\",\"priority\":1,\"implementation\":\"QBittorrent\",\"configContract\":\"QBittorrentSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"localhost\"},{\"name\":\"port\",\"value\":8080},{\"name\":\"username\",\"value\":\"$SERVICES_USERNAME\"},{\"name\":\"password\",\"value\":\"$SERVICES_PASSWORD\"},{\"name\":\"tvCategory\",\"value\":\"sonarr\"},{\"name\":\"recentTvPriority\",\"value\":0},{\"name\":\"olderTvPriority\",\"value\":0},{\"name\":\"initialState\",\"value\":0}]}" > /dev/null
  echo "[mediarr-configurator] Sonarr: qBittorrent download client added."
else
  echo "[mediarr-configurator] Sonarr: qBittorrent already configured."
fi

EXISTING_FOLDERS=$(api_get 8989 "$SONARR_KEY" /api/v3/rootfolder)
if ! echo "$EXISTING_FOLDERS" | grep -q '"/data/tv"'; then
  api_post 8989 "$SONARR_KEY" /api/v3/rootfolder \
    "{\"path\":\"/data/tv\"}" > /dev/null
  echo "[mediarr-configurator] Sonarr: /data/tv root folder added."
fi

# ── Phase 7: Configure Prowlarr ───────────────────────────────────────────────
echo "[mediarr-configurator] Configuring Prowlarr..."

EXISTING_TAGS=$(api_get 9696 "$PROWLARR_KEY" /api/v1/tag)
if ! echo "$EXISTING_TAGS" | grep -q '"flaresolverr"'; then
  TAG_RESP=$(api_post 9696 "$PROWLARR_KEY" /api/v1/tag '{"label":"flaresolverr"}')
  FLARE_TAG_ID=$(echo "$TAG_RESP" | jq -r '.id')
else
  FLARE_TAG_ID=$(echo "$EXISTING_TAGS" | jq -r '.[] | select(.label == "flaresolverr") | .id')
fi

EXISTING_PROXIES=$(api_get 9696 "$PROWLARR_KEY" /api/v1/indexerProxy)
if ! echo "$EXISTING_PROXIES" | grep -q '"FlareSolverr"'; then
  api_post 9696 "$PROWLARR_KEY" /api/v1/indexerProxy \
    "{\"name\":\"FlareSolverr\",\"implementation\":\"FlareSolverr\",\"configContract\":\"FlareSolverrSettings\",\"tags\":[${FLARE_TAG_ID:-1}],\"fields\":[{\"name\":\"host\",\"value\":\"http://localhost:8191\"},{\"name\":\"requestTimeout\",\"value\":60}]}" > /dev/null
  echo "[mediarr-configurator] Prowlarr: FlareSolverr proxy added."
else
  echo "[mediarr-configurator] Prowlarr: FlareSolverr already configured."
fi

EXISTING_APPS=$(api_get 9696 "$PROWLARR_KEY" /api/v1/applications)
if ! echo "$EXISTING_APPS" | grep -q '"Radarr"'; then
  api_post 9696 "$PROWLARR_KEY" /api/v1/applications \
    "{\"name\":\"Radarr\",\"syncLevel\":\"fullSync\",\"implementation\":\"Radarr\",\"configContract\":\"RadarrSettings\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://localhost:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://localhost:7878\"},{\"name\":\"apiKey\",\"value\":\"$RADARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[2000,2010,2020,2030,2040,2045,2050,2060,2070,2080]}]}" > /dev/null
  echo "[mediarr-configurator] Prowlarr: Radarr application added."
else
  echo "[mediarr-configurator] Prowlarr: Radarr already configured."
fi

if ! echo "$EXISTING_APPS" | grep -q '"Sonarr"'; then
  api_post 9696 "$PROWLARR_KEY" /api/v1/applications \
    "{\"name\":\"Sonarr\",\"syncLevel\":\"fullSync\",\"implementation\":\"Sonarr\",\"configContract\":\"SonarrSettings\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://localhost:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://localhost:8989\"},{\"name\":\"apiKey\",\"value\":\"$SONARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[5000,5010,5020,5030,5040,5045,5050,5060,5070,5080]}]}" > /dev/null
  echo "[mediarr-configurator] Prowlarr: Sonarr application added."
else
  echo "[mediarr-configurator] Prowlarr: Sonarr already configured."
fi

# ── Phase 8: Enable authentication on all *arr services ───────────────────────
echo "[mediarr-configurator] Configuring authentication for all *arr services..."

set_arr_auth() {
  _url="http://localhost:${1}/api/${3}/config/host"
  _current=$(curl -sf -H "X-Api-Key: $2" "$_url") || {
    echo "[mediarr-configurator] $4: could not fetch host config, skipping auth."
    return
  }
  _updated=$(echo "$_current" | jq \
    --arg u "$SERVICES_USERNAME" \
    --arg p "$SERVICES_PASSWORD" \
    '.authenticationMethod = "forms" | .authenticationRequired = "enabled" | .username = $u | .password = $p')
  curl -sf -X PUT -H "X-Api-Key: $2" -H "Content-Type: application/json" \
    -d "$_updated" "$_url" > /dev/null
  echo "[mediarr-configurator] $4: authentication enabled (user: $SERVICES_USERNAME)."
}

set_arr_auth 7878 "$RADARR_KEY"   "v3" "Radarr"
set_arr_auth 8989 "$SONARR_KEY"   "v3" "Sonarr"
set_arr_auth 9696 "$PROWLARR_KEY" "v1" "Prowlarr"

# ── Phase 9: Mark as configured ───────────────────────────────────────────────
touch /state/configured
echo "[mediarr-configurator] Auto-configuration complete. All services wired."
