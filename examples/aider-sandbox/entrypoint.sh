#!/bin/sh
set -e

# Inject a <base> tag into Streamlit's static index.html so that its
# relative asset paths (./static/js/..., ./favicon.png, etc.) resolve
# through the sandbox-router's full path prefix instead of dropping the
# port segment.
#
# Without <base>, the browser at /sandbox/ns/name/8501 treats 8501 as a
# filename and resolves ./static/... to /sandbox/ns/name/static/... —
# the router rejects that because "static" is not a valid port.
#
# With <base href="/sandbox/ns/name/8501/">, all relative URLs resolve
# to /sandbox/ns/name/8501/static/... which the router parses correctly.

SANDBOX_NAME="$(hostname)"
SANDBOX_NS="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null || echo default)"
SANDBOX_PORT="${SANDBOX_EXPOSED_PORT:-8501}"
SANDBOX_PREFIX="${SANDBOX_ROUTER_PREFIX:-/sandbox}"
BASE_PATH="${SANDBOX_PREFIX}/${SANDBOX_NS}/${SANDBOX_NAME}/${SANDBOX_PORT}"

if [ -n "$OPENAI_API_KEY_PATH" ] && [ -f "$OPENAI_API_KEY_PATH" ]; then
  export OPENAI_API_KEY="$(cat "$OPENAI_API_KEY_PATH")"
fi

INDEX_HTML=$(python3 -c "import streamlit, os; print(os.path.join(os.path.dirname(streamlit.__file__), 'static', 'index.html'))")

if ! grep -q '<base href=' "$INDEX_HTML"; then
  sed -i "s|<head>|<head><base href=\"${BASE_PATH}/\" />|" "$INDEX_HTML"
  echo "[entrypoint] injected <base href=\"${BASE_PATH}/\"> into ${INDEX_HTML}" >&2
fi

exec "$@"
