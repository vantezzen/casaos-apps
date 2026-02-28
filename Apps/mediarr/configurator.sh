#!/bin/sh
# Mediarr auto-configurator
# Wires all *arr services, qBittorrent, FlareSolverr, and Prowlarr together
# on first install. Idempotent — safe to re-run.
#
# NOTE: no "set -e" — individual API call failures are logged and skipped
# rather than stopping the whole script.

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
    curl -s "$1" > /dev/null 2>&1 && return 0
    sleep 3
    n=$((n + 3))
  done
  echo "[mediarr-configurator] Timeout waiting for $2 API" >&2
  exit 1
}

extract_api_key() {
  sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' "$1"
}

# Note: no -f flag — curl exits 0 even on HTTP errors, so individual
# API failures don't kill the script. Responses are checked by content.
api_get() {
  curl -s -H "X-Api-Key: $2" "http://localhost:$1$3"
}

api_post() {
  curl -s -X POST -H "X-Api-Key: $2" -H "Content-Type: application/json" \
    -d "$4" "http://localhost:$1$3"
}

api_put() {
  curl -s -X PUT -H "X-Api-Key: $2" -H "Content-Type: application/json" \
    -d "$4" "http://localhost:$1$3"
}

# ── Phase 3: Wait for *arr API keys ───────────────────────────────────────────
wait_for_file /radarr-config/config.xml "Radarr config"
wait_for_file /sonarr-config/config.xml "Sonarr config"
wait_for_file /prowlarr-config/config.xml "Prowlarr config"

RADARR_KEY=$(extract_api_key /radarr-config/config.xml)
SONARR_KEY=$(extract_api_key /sonarr-config/config.xml)
PROWLARR_KEY=$(extract_api_key /prowlarr-config/config.xml)

echo "[mediarr-configurator] API keys extracted."
echo "[mediarr-configurator]   Radarr:   ${RADARR_KEY:+OK (${#RADARR_KEY} chars)}"
echo "[mediarr-configurator]   Sonarr:   ${SONARR_KEY:+OK (${#SONARR_KEY} chars)}"
echo "[mediarr-configurator]   Prowlarr: ${PROWLARR_KEY:+OK (${#PROWLARR_KEY} chars)}"

# ── Phase 4: Wait for *arr APIs to respond ────────────────────────────────────
wait_for_api "http://localhost:7878/api/v3/system/status?apikey=$RADARR_KEY" "Radarr"
wait_for_api "http://localhost:8989/api/v3/system/status?apikey=$SONARR_KEY" "Sonarr"
wait_for_api "http://localhost:9696/api/v1/system/status?apikey=$PROWLARR_KEY" "Prowlarr"

echo "[mediarr-configurator] All APIs reachable."

# ── Phase 5: Configure Radarr ─────────────────────────────────────────────────
echo "[mediarr-configurator] Configuring Radarr..."

EXISTING_CLIENTS=$(api_get 7878 "$RADARR_KEY" /api/v3/downloadclient)
if ! echo "$EXISTING_CLIENTS" | grep -q '"QBittorrent"'; then
  RESP=$(api_post 7878 "$RADARR_KEY" /api/v3/downloadclient \
    "{\"name\":\"qBittorrent\",\"enable\":true,\"protocol\":\"torrent\",\"priority\":1,\"implementation\":\"QBittorrent\",\"configContract\":\"QBittorrentSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"localhost\"},{\"name\":\"port\",\"value\":8080},{\"name\":\"username\",\"value\":\"$SERVICES_USERNAME\"},{\"name\":\"password\",\"value\":\"$SERVICES_PASSWORD\"},{\"name\":\"movieCategory\",\"value\":\"radarr\"},{\"name\":\"recentMoviePriority\",\"value\":0},{\"name\":\"olderMoviePriority\",\"value\":0},{\"name\":\"initialState\",\"value\":0}]}")
  if echo "$RESP" | grep -q '"id"'; then
    echo "[mediarr-configurator] Radarr: qBittorrent download client added."
  else
    echo "[mediarr-configurator] Radarr: WARNING - unexpected response adding download client: $RESP"
  fi
else
  echo "[mediarr-configurator] Radarr: qBittorrent already configured."
fi

EXISTING_FOLDERS=$(api_get 7878 "$RADARR_KEY" /api/v3/rootfolder)
if ! echo "$EXISTING_FOLDERS" | grep -q '"/data/movies"'; then
  RESP=$(api_post 7878 "$RADARR_KEY" /api/v3/rootfolder "{\"path\":\"/data/movies\"}")
  if echo "$RESP" | grep -q '"id"'; then
    echo "[mediarr-configurator] Radarr: /data/movies root folder added."
  else
    echo "[mediarr-configurator] Radarr: WARNING - unexpected response adding root folder: $RESP"
  fi
fi

# ── Phase 6: Configure Sonarr ─────────────────────────────────────────────────
echo "[mediarr-configurator] Configuring Sonarr..."

EXISTING_CLIENTS=$(api_get 8989 "$SONARR_KEY" /api/v3/downloadclient)
if ! echo "$EXISTING_CLIENTS" | grep -q '"QBittorrent"'; then
  RESP=$(api_post 8989 "$SONARR_KEY" /api/v3/downloadclient \
    "{\"name\":\"qBittorrent\",\"enable\":true,\"protocol\":\"torrent\",\"priority\":1,\"implementation\":\"QBittorrent\",\"configContract\":\"QBittorrentSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"localhost\"},{\"name\":\"port\",\"value\":8080},{\"name\":\"username\",\"value\":\"$SERVICES_USERNAME\"},{\"name\":\"password\",\"value\":\"$SERVICES_PASSWORD\"},{\"name\":\"tvCategory\",\"value\":\"sonarr\"},{\"name\":\"recentTvPriority\",\"value\":0},{\"name\":\"olderTvPriority\",\"value\":0},{\"name\":\"initialState\",\"value\":0}]}")
  if echo "$RESP" | grep -q '"id"'; then
    echo "[mediarr-configurator] Sonarr: qBittorrent download client added."
  else
    echo "[mediarr-configurator] Sonarr: WARNING - unexpected response adding download client: $RESP"
  fi
else
  echo "[mediarr-configurator] Sonarr: qBittorrent already configured."
fi

EXISTING_FOLDERS=$(api_get 8989 "$SONARR_KEY" /api/v3/rootfolder)
if ! echo "$EXISTING_FOLDERS" | grep -q '"/data/tv"'; then
  RESP=$(api_post 8989 "$SONARR_KEY" /api/v3/rootfolder "{\"path\":\"/data/tv\"}")
  if echo "$RESP" | grep -q '"id"'; then
    echo "[mediarr-configurator] Sonarr: /data/tv root folder added."
  else
    echo "[mediarr-configurator] Sonarr: WARNING - unexpected response adding root folder: $RESP"
  fi
fi

# ── Phase 7: Configure Prowlarr ───────────────────────────────────────────────
echo "[mediarr-configurator] Configuring Prowlarr..."

echo "[mediarr-configurator] Prowlarr: fetching tags..."
EXISTING_TAGS=$(api_get 9696 "$PROWLARR_KEY" /api/v1/tag)
echo "[mediarr-configurator] Prowlarr: tags response: $EXISTING_TAGS"

if ! echo "$EXISTING_TAGS" | grep -q '"flaresolverr"'; then
  echo "[mediarr-configurator] Prowlarr: creating flaresolverr tag..."
  TAG_RESP=$(api_post 9696 "$PROWLARR_KEY" /api/v1/tag '{"label":"flaresolverr"}')
  echo "[mediarr-configurator] Prowlarr: tag response: $TAG_RESP"
  FLARE_TAG_ID=$(echo "$TAG_RESP" | jq -r '.id // empty')
  FLARE_TAG_ID=${FLARE_TAG_ID:-1}
else
  FLARE_TAG_ID=$(echo "$EXISTING_TAGS" | jq -r '.[] | select(.label == "flaresolverr") | .id')
  FLARE_TAG_ID=${FLARE_TAG_ID:-1}
fi
echo "[mediarr-configurator] Prowlarr: FlareSolverr tag ID: $FLARE_TAG_ID"

echo "[mediarr-configurator] Prowlarr: fetching indexer proxies..."
EXISTING_PROXIES=$(api_get 9696 "$PROWLARR_KEY" /api/v1/indexerProxy)
echo "[mediarr-configurator] Prowlarr: proxies response: $EXISTING_PROXIES"

if ! echo "$EXISTING_PROXIES" | grep -q '"FlareSolverr"'; then
  RESP=$(api_post 9696 "$PROWLARR_KEY" /api/v1/indexerProxy \
    "{\"name\":\"FlareSolverr\",\"implementation\":\"FlareSolverr\",\"configContract\":\"FlareSolverrSettings\",\"tags\":[$FLARE_TAG_ID],\"fields\":[{\"name\":\"host\",\"value\":\"http://localhost:8191\"},{\"name\":\"requestTimeout\",\"value\":60}]}")
  if echo "$RESP" | grep -q '"id"'; then
    echo "[mediarr-configurator] Prowlarr: FlareSolverr proxy added."
  else
    echo "[mediarr-configurator] Prowlarr: WARNING - unexpected response adding FlareSolverr: $RESP"
  fi
else
  echo "[mediarr-configurator] Prowlarr: FlareSolverr already configured."
fi

echo "[mediarr-configurator] Prowlarr: fetching applications..."
EXISTING_APPS=$(api_get 9696 "$PROWLARR_KEY" /api/v1/applications)
echo "[mediarr-configurator] Prowlarr: applications response: $EXISTING_APPS"

if ! echo "$EXISTING_APPS" | grep -q '"Radarr"'; then
  RESP=$(api_post 9696 "$PROWLARR_KEY" /api/v1/applications \
    "{\"name\":\"Radarr\",\"syncLevel\":\"fullSync\",\"implementation\":\"Radarr\",\"configContract\":\"RadarrSettings\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://localhost:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://localhost:7878\"},{\"name\":\"apiKey\",\"value\":\"$RADARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[2000,2010,2020,2030,2040,2045,2050,2060,2070,2080]}]}")
  if echo "$RESP" | grep -q '"id"'; then
    echo "[mediarr-configurator] Prowlarr: Radarr application added."
  else
    echo "[mediarr-configurator] Prowlarr: WARNING - unexpected response adding Radarr: $RESP"
  fi
else
  echo "[mediarr-configurator] Prowlarr: Radarr already configured."
fi

if ! echo "$EXISTING_APPS" | grep -q '"Sonarr"'; then
  RESP=$(api_post 9696 "$PROWLARR_KEY" /api/v1/applications \
    "{\"name\":\"Sonarr\",\"syncLevel\":\"fullSync\",\"implementation\":\"Sonarr\",\"configContract\":\"SonarrSettings\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://localhost:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://localhost:8989\"},{\"name\":\"apiKey\",\"value\":\"$SONARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[5000,5010,5020,5030,5040,5045,5050,5060,5070,5080]}]}")
  if echo "$RESP" | grep -q '"id"'; then
    echo "[mediarr-configurator] Prowlarr: Sonarr application added."
  else
    echo "[mediarr-configurator] Prowlarr: WARNING - unexpected response adding Sonarr: $RESP"
  fi
else
  echo "[mediarr-configurator] Prowlarr: Sonarr already configured."
fi

# ── Phase 8: Enable authentication on all *arr services ───────────────────────
echo "[mediarr-configurator] Configuring authentication for all *arr services..."

set_arr_auth() {
  _url="http://localhost:${1}/api/${3}/config/host"
  _current=$(curl -s -H "X-Api-Key: $2" "$_url")
  if [ -z "$_current" ]; then
    echo "[mediarr-configurator] $4: empty response from host config, skipping auth."
    return
  fi
  _updated=$(echo "$_current" | jq \
    --arg u "$SERVICES_USERNAME" \
    --arg p "$SERVICES_PASSWORD" \
    '.authenticationMethod = "forms" | .authenticationRequired = "enabled" | .username = $u | .password = $p')
  RESP=$(curl -s -X PUT -H "X-Api-Key: $2" -H "Content-Type: application/json" \
    -d "$_updated" "$_url")
  if echo "$RESP" | grep -q '"id"'; then
    echo "[mediarr-configurator] $4: authentication enabled (user: $SERVICES_USERNAME)."
  else
    echo "[mediarr-configurator] $4: WARNING - unexpected response enabling auth: $RESP"
  fi
}

set_arr_auth 7878 "$RADARR_KEY"   "v3" "Radarr"
set_arr_auth 8989 "$SONARR_KEY"   "v3" "Sonarr"
set_arr_auth 9696 "$PROWLARR_KEY" "v1" "Prowlarr"

# ── Phase 9: Mark as configured ───────────────────────────────────────────────
touch /state/configured
echo "[mediarr-configurator] Auto-configuration complete. All services wired."
