#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DAR="$ROOT_DIR/core/.daml/dist/raven-contracts-0.2.1.dar"
TESTS_DAR="$ROOT_DIR/tests/.daml/dist/raven-contracts-tests-0.2.1.dar"

LEDGER_HOST="127.0.0.1"
LEDGER_PORT="19065"
ADMIN_PORT="19066"
JSON_PORT="19067"
SEQ_PUBLIC_PORT="19068"
SEQ_ADMIN_PORT="19069"
MEDIATOR_ADMIN_PORT="19070"

SCRIPT_NAME="Test.Main:setup"
RUN_ALL="false"
BUILD="true"
START_SANDBOX="false"
STATIC_TIME="true"
VERBOSE="true"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --host <host>                 Ledger host (default: ${LEDGER_HOST})
  --port <port>                 Ledger gRPC port (default: ${LEDGER_PORT})
  --admin-port <port>           Admin API port (default: ${ADMIN_PORT})
  --json-port <port>            JSON API port (default: ${JSON_PORT})
  --sequencer-public-port <p>   Sequencer public port (default: ${SEQ_PUBLIC_PORT})
  --sequencer-admin-port <p>    Sequencer admin port (default: ${SEQ_ADMIN_PORT})
  --mediator-admin-port <p>     Mediator admin port (default: ${MEDIATOR_ADMIN_PORT})
  --script <Module:Entity>      Script name (default: ${SCRIPT_NAME})
  --all                         Run all scripts instead of one script
  --no-build                    Skip dpm build --all
  --start-sandbox               Start sandbox in foreground (ctrl+c to stop)
  --no-static-time              Do not pass --static-time to sandbox
  --quiet                       Less debug output
  -h, --help                    Show help

Examples:
  # Run setup against already running sandbox
  $(basename "$0") --script Test.Main:setup

  # Run all scripts against already running sandbox on custom port
  $(basename "$0") --all --port 6865

  # Build, start sandbox, and then run setup script
  $(basename "$0") --start-sandbox --script Test.Main:setup
USAGE
}

log() {
  if [[ "$VERBOSE" == "true" ]]; then
    printf '[debug] %s\n' "$*"
  fi
}

fail() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

port_open() {
  local host="$1"
  local port="$2"
  nc -z "$host" "$port" >/dev/null 2>&1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host)
        LEDGER_HOST="$2"; shift 2 ;;
      --port)
        LEDGER_PORT="$2"; shift 2 ;;
      --admin-port)
        ADMIN_PORT="$2"; shift 2 ;;
      --json-port)
        JSON_PORT="$2"; shift 2 ;;
      --sequencer-public-port)
        SEQ_PUBLIC_PORT="$2"; shift 2 ;;
      --sequencer-admin-port)
        SEQ_ADMIN_PORT="$2"; shift 2 ;;
      --mediator-admin-port)
        MEDIATOR_ADMIN_PORT="$2"; shift 2 ;;
      --script)
        SCRIPT_NAME="$2"; shift 2 ;;
      --all)
        RUN_ALL="true"; shift ;;
      --no-build)
        BUILD="false"; shift ;;
      --start-sandbox)
        START_SANDBOX="true"; shift ;;
      --no-static-time)
        STATIC_TIME="false"; shift ;;
      --quiet)
        VERBOSE="false"; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done
}

build_dars() {
  log "Building core/tests packages..."
  (cd "$ROOT_DIR" && dpm build --all)
}

check_dars() {
  [[ -f "$CORE_DAR" ]] || fail "Core DAR not found: $CORE_DAR"
  [[ -f "$TESTS_DAR" ]] || fail "Tests DAR not found: $TESTS_DAR"
  log "Core DAR:  $CORE_DAR"
  log "Tests DAR: $TESTS_DAR"
}

start_sandbox() {
  local static_time_flag=()
  if [[ "$STATIC_TIME" == "true" ]]; then
    static_time_flag+=(--static-time)
  fi

  log "Starting sandbox (foreground)."
  log "Ports: ledger=$LEDGER_PORT admin=$ADMIN_PORT json=$JSON_PORT seqPub=$SEQ_PUBLIC_PORT seqAdmin=$SEQ_ADMIN_PORT mediator=$MEDIATOR_ADMIN_PORT"

  cd "$ROOT_DIR"
  dpm sandbox \
    "${static_time_flag[@]}" \
    --ledger-api-port "$LEDGER_PORT" \
    --admin-api-port "$ADMIN_PORT" \
    --json-api-port "$JSON_PORT" \
    --sequencer-public-port "$SEQ_PUBLIC_PORT" \
    --sequencer-admin-port "$SEQ_ADMIN_PORT" \
    --mediator-admin-port "$MEDIATOR_ADMIN_PORT" \
    --dar "$CORE_DAR" \
    --dar "$TESTS_DAR"
}

run_script() {
  if ! port_open "$LEDGER_HOST" "$LEDGER_PORT"; then
    fail "No ledger is listening at ${LEDGER_HOST}:${LEDGER_PORT}. Start sandbox first or pass --start-sandbox."
  fi

  local args=(
    --dar "$TESTS_DAR"
    --ledger-host "$LEDGER_HOST"
    --ledger-port "$LEDGER_PORT"
  )

  if [[ "$STATIC_TIME" == "true" ]]; then
    args+=(--static-time)
  else
    args+=(--wall-clock-time)
  fi

  if [[ "$RUN_ALL" == "true" ]]; then
    args+=(--all)
    log "Running all scripts against ledger ${LEDGER_HOST}:${LEDGER_PORT}"
  else
    args+=(--script-name "$SCRIPT_NAME")
    log "Running script ${SCRIPT_NAME} against ledger ${LEDGER_HOST}:${LEDGER_PORT}"
  fi

  (cd "$ROOT_DIR/tests" && dpm script "${args[@]}")
}

main() {
  parse_args "$@"
  require_cmd dpm
  require_cmd nc

  log "Repo root: $ROOT_DIR"
  log "Using dpm: $(command -v dpm)"

  if [[ "$BUILD" == "true" ]]; then
    build_dars
  fi

  check_dars

  if [[ "$START_SANDBOX" == "true" ]]; then
    start_sandbox
  else
    run_script
    log "Script execution completed."
  fi
}

main "$@"
