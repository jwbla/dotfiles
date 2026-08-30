#!/usr/bin/env bash
# rgtv_glance.sh — JSON feeds for the quickshell "rgtv at a glance" panel
# (quickshell/services/Rgtv.qml). Each subcommand prints ONE JSON document on
# stdout; when its primary source is unreachable it prints a one-line reason on
# stderr and exits 1 so the panel can show the failure instead of stale data.
#
#   rgtv_glance.sh prs         open PRs across the Gitea org + head-commit CI status
#   rgtv_glance.sh repos       default-branch CI state for every org repo
#   rgtv_glance.sh alerts      firing Prometheus alerts + down scrape targets
#   rgtv_glance.sh services    fleet homepage links with their server-side health probe
#   rgtv_glance.sh dashboards  Grafana dashboards (anonymous search)
#
# Sources (all LAN, see rgtv-infra/fleet.json for the fleet layout):
#   - Gitea         needs a token: $GITEA_TOKEN, else the tea login for $RGTV_GITEA
#                   (~/.config/tea/config.yml — never printed, only read)
#   - Prometheus    LAN-only on the observability LXC (fleet vmid 911 -> .211), not
#                   behind caddy, so it is addressed by IP
#   - homepage      the fleet dashboard already probes every service's health URL
#                   server-side, so this reuses that instead of re-probing
#   - Grafana       anonymous viewer is enabled, /api/search works without auth
set -euo pipefail

GITEA="${RGTV_GITEA:-https://gitea.i.realgamers.tv}"
ORG="${RGTV_GITEA_ORG:-RealGamers}"
HOMEPAGE="${RGTV_HOMEPAGE:-https://home.i.realgamers.tv}"
GRAFANA="${RGTV_GRAFANA:-https://grafana.i.realgamers.tv}"
PROM="${RGTV_PROM:-http://192.168.1.211:9090}"
TIMEOUT="${RGTV_TIMEOUT:-8}"
# Gitea serialises bursts: 15 status calls at once take ~5.5s, six at a time
# ~1.1s. Workers below go through `throttle` to stay under this.
PARALLEL="${RGTV_PARALLEL:-6}"

die() { echo "rgtv_glance: $*" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Quiet GET. Non-2xx and transport errors both fail the call so callers can
# fall back with `|| echo null`.
get() { curl -sf -m "$TIMEOUT" "$@"; }

# Block until fewer than $PARALLEL background workers are running.
throttle() {
    while (( $(jobs -rp | wc -l) >= PARALLEL )); do
        wait -n || true
    done
}

gitea_token() {
    if [[ -n "${GITEA_TOKEN:-}" ]]; then
        printf '%s' "$GITEA_TOKEN"
        return 0
    fi
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/tea/config.yml"
    [[ -r "$cfg" ]] || return 1
    # tea stores a list of logins; pick the token of the one whose url is our
    # host so a second login for another Gitea can't be used by mistake.
    awk -v host="$GITEA" '
        /^[[:space:]]*-[[:space:]]*name:/ { url = ""; tok = "" }
        /^[[:space:]]+url:/   { url = $2; gsub(/["'"'"']/, "", url); sub(/\/$/, "", url) }
        /^[[:space:]]+token:/ { tok = $2; gsub(/["'"'"']/, "", tok) }
        url == host && tok != "" { print tok; exit }
    ' "$cfg"
}

gapi() { get -H "Authorization: token $TOKEN" "$GITEA/api/v1$1"; }

# ---------------------------------------------------------------- prs ------

# shellcheck disable=SC2016
PR_JQ='
def count(f): [ .[] | select(f) ] | length;
($d // {}) as $d
| ($s.statuses // []) as $st
| $e.repository.full_name as $full
| {
    full: $full,
    repo: $e.repository.name,
    number: $e.number,
    title: $e.title,
    author: $e.user.login,
    url: $e.html_url,
    actions_url: ($host + "/" + $full + "/actions"),
    draft: ($d.draft // $e.pull_request.draft // false),
    mergeable: $d.mergeable,
    head_ref: ($d.head.ref // ""),
    base_ref: ($d.base.ref // ""),
    additions: ($d.additions // 0),
    deletions: ($d.deletions // 0),
    changed_files: ($d.changed_files // 0),
    comments: ($e.comments // 0),
    created_at: $e.created_at,
    updated_at: $e.updated_at,
    ci: {
      state: (if $s == null then "unknown" elif ($st | length) == 0 then "none" else $s.state end),
      total: ($st | length),
      success: ($st | count(.status == "success")),
      pending: ($st | count(.status == "pending")),
      failure: ($st | count(.status == "failure" or .status == "error")),
      skipped: ($st | count(.status == "skipped")),
      failing_url: (
        [ $st[] | select(.status == "failure" or .status == "error") | .target_url ] | first // null
        | if . == null then null elif startswith("http") then . else $host + . end
      )
    },
    reviews: {
      approved: ([ $r[] | select(.state == "APPROVED") | .user.login ] | unique),
      changes:  ([ $r[] | select(.state == "REQUEST_CHANGES") | .user.login ] | unique),
      requested: ([ $d.requested_reviewers[]? | .login ])
    }
  }'

pr_worker() {
    local entry="$1" out="$2"
    local full number detail sha status reviews
    full=$(jq -r '.repository.full_name' <<<"$entry")
    number=$(jq -r '.number' <<<"$entry")
    detail=$(gapi "/repos/$full/pulls/$number" || echo null)
    sha=$(jq -r '.head.sha // empty' <<<"$detail")
    status=null
    reviews='[]'
    if [[ -n "$sha" ]]; then
        status=$(gapi "/repos/$full/commits/$sha/status" || echo null)
        reviews=$(gapi "/repos/$full/pulls/$number/reviews" || echo '[]')
    fi
    jq -n -c --argjson e "$entry" --argjson d "$detail" --argjson s "$status" \
        --argjson r "$reviews" --arg host "$GITEA" "$PR_JQ" > "$out"
}

cmd_prs() {
    TOKEN=$(gitea_token) || die "no Gitea token: set GITEA_TOKEN or 'tea login add' for $GITEA"
    [[ -n "$TOKEN" ]] || die "no Gitea token: set GITEA_TOKEN or 'tea login add' for $GITEA"
    local list
    list=$(gapi "/repos/issues/search?type=pulls&state=open&owner=$ORG&limit=50") \
        || die "gitea unreachable at $GITEA"

    local i=0
    while IFS= read -r entry; do
        throttle
        pr_worker "$entry" "$tmp/pr-$i.json" &
        i=$((i + 1))
    done < <(jq -c '.[]' <<<"$list")
    wait

    if (( i == 0 )); then
        echo "[]"
    else
        jq -s 'sort_by(.updated_at) | reverse' "$tmp"/pr-*.json
    fi
}

# -------------------------------------------------------------- repos ------

# shellcheck disable=SC2016
REPO_JQ='
def count(f): [ .[] | select(f) ] | length;
($s.statuses // []) as $st
| {
    name: $r.name,
    full: $r.full_name,
    url: $r.html_url,
    actions_url: ($r.html_url + "/actions"),
    default_branch: $r.default_branch,
    updated_at: $r.updated_at,
    sha: (($s.sha // "")[0:7]),
    ci: {
      state: (if $s == null then "unknown" elif ($st | length) == 0 then "none" else $s.state end),
      total: ($st | length),
      success: ($st | count(.status == "success")),
      pending: ($st | count(.status == "pending")),
      failure: ($st | count(.status == "failure" or .status == "error"))
    }
  }'

repo_worker() {
    local repo="$1" out="$2"
    local full branch status
    full=$(jq -r '.full_name' <<<"$repo")
    branch=$(jq -r '.default_branch' <<<"$repo")
    status=$(gapi "/repos/$full/commits/$branch/status" || echo null)
    jq -n -c --argjson r "$repo" --argjson s "$status" "$REPO_JQ" > "$out"
}

cmd_repos() {
    TOKEN=$(gitea_token) || die "no Gitea token: set GITEA_TOKEN or 'tea login add' for $GITEA"
    [[ -n "$TOKEN" ]] || die "no Gitea token: set GITEA_TOKEN or 'tea login add' for $GITEA"
    local list
    list=$(gapi "/orgs/$ORG/repos?limit=50") || die "gitea unreachable at $GITEA"

    local i=0
    while IFS= read -r repo; do
        throttle
        repo_worker "$repo" "$tmp/repo-$i.json" &
        i=$((i + 1))
    done < <(jq -c '.[] | select(.archived | not)' <<<"$list")
    wait

    if (( i == 0 )); then
        echo "[]"
    else
        # Failing first, then most recently pushed.
        jq -s 'sort_by((if .ci.state == "failure" or .ci.state == "error" then 0 else 1 end), .updated_at)
               | (map(select(.ci.state == "failure" or .ci.state == "error")) | reverse)
                 + (map(select(.ci.state != "failure" and .ci.state != "error")) | sort_by(.updated_at) | reverse)' \
            "$tmp"/repo-*.json
    fi
}

# ------------------------------------------------------------- alerts ------

cmd_alerts() {
    local alerts targets
    alerts=$(get "$PROM/api/v1/alerts") || die "prometheus unreachable at $PROM"
    targets=$(get "$PROM/api/v1/targets?state=any" || echo '{"data":{"activeTargets":[]}}')

    # Watchdog is the always-firing dead-man alert: its ABSENCE is the problem,
    # so it is folded into a boolean instead of listed.
    jq -n --argjson a "$alerts" --argjson t "$targets" --arg prom "$PROM" '
      def rank: if . == "critical" then 0 elif . == "warning" then 1 else 2 end;
      {
        alerts: ([ $a.data.alerts[]
          | select(.labels.alertname != "Watchdog")
          | {
              name: .labels.alertname,
              severity: (.labels.severity // "none"),
              state: .state,
              service: (.labels.service // .labels.svc // .labels.job // ""),
              instance: (.labels.instance // ""),
              summary: (.annotations.summary // .labels.alertname),
              description: (.annotations.description // ""),
              active_at: .activeAt,
              url: ($prom + "/alerts?search=" + .labels.alertname)
            } ]
          | sort_by((.severity | rank), .active_at)),
        watchdog: ([ $a.data.alerts[] | select(.labels.alertname == "Watchdog" and .state == "firing") ] | length > 0),
        targets: {
          total: ($t.data.activeTargets | length),
          down: [ $t.data.activeTargets[] | select(.health != "up")
                  | { job: .labels.job, instance: .labels.instance, error: (.lastError // "") } ]
        },
        url: ($prom + "/alerts")
      }'
}

# ----------------------------------------------------------- services ------

cmd_services() {
    local links
    links=$(get "$HOMEPAGE/api/links") || die "homepage unreachable at $HOMEPAGE"

    while IFS= read -r id; do
        throttle
        (
            h=$(get "$HOMEPAGE/api/links/$id/health" || echo '{"status":"unknown"}')
            jq -c --arg id "$id" '{ id: $id, status: (.status // "unknown") }' <<<"$h"
        ) > "$tmp/h-$id.json" &
    done < <(jq -r '.[].id' <<<"$links")
    wait

    cat "$tmp"/h-*.json | jq -s '.' > "$tmp/health.json"

    jq --slurpfile h "$tmp/health.json" '
      ($h[0] | map({ key: .id, value: .status }) | from_entries) as $hm
      | [ .[] | {
            id, title, group,
            description: (.description // ""),
            href: (.href // ""),
            health_url: (.healthUrl // ""),
            status: ($hm[.id] // "unknown"),
            order: (.order // 0)
          } ]
      | sort_by(.order)' <<<"$links"
}

# --------------------------------------------------------- dashboards ------

cmd_dashboards() {
    local d
    d=$(get "$GRAFANA/api/search?type=dash-db") || die "grafana unreachable at $GRAFANA"
    jq --arg g "$GRAFANA" '[ .[] | { title, uid, url: ($g + .url), tags } ] | sort_by(.title)' <<<"$d"
}

# ---------------------------------------------------------------------------

case "${1:-}" in
    prs)        cmd_prs ;;
    repos)      cmd_repos ;;
    alerts)     cmd_alerts ;;
    services)   cmd_services ;;
    dashboards) cmd_dashboards ;;
    *)
        sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2
        exit 2
        ;;
esac
