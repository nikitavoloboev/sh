#!/usr/bin/env bash
set -euo pipefail

# Detect arch
case "$(uname -m)" in
  arm64)   GOARCH="arm64" ;;
  x86_64)  GOARCH="amd64" ;;
  *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

LATEST="$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)"   # e.g. go1.23.1
FNAME="${LATEST}.darwin-${GOARCH}.tar.gz"
BASE_URL="https://dl.google.com/go"
URL="${BASE_URL}/${FNAME}"
SHA_URL="${URL}.sha256"

echo "Latest: ${LATEST}"
TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT
cd "$TMPDIR"

echo "Downloading ${FNAME}…"
curl -fL --retry 3 --retry-delay 2 -O "$URL"
curl -fL --retry 3 --retry-delay 2 -o "${FNAME}.sha256" "$SHA_URL"

# Fallback for when dl.google.com is unavailable or the checksum payload is not plain text
EXPECTED="$(sed 's/ .*//' "${FNAME}.sha256" | tr -d '\n\r\t ' )"
if [[ ! "$EXPECTED" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "Checksum payload from ${SHA_URL} looked wrong; retrying via go.dev fallback…"
  FALLBACK_URL="https://go.dev/dl/?mode=download&filename=${FNAME}.sha256"
  curl -fL --retry 3 --retry-delay 2 -o "${FNAME}.sha256" "$FALLBACK_URL"
  EXPECTED="$(sed 's/ .*//' "${FNAME}.sha256" | tr -d '\n\r\t ' )"
fi

# Verify checksum (handles either 'checksum' or 'checksum  filename' formats)
if [[ ! "$EXPECTED" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "Checksum download failed: unexpected contents in ${TMPDIR}/${FNAME}.sha256" >&2
  exit 1
fi
ACTUAL="$(shasum -a 256 "${FNAME}" | awk '{print $1}')"
if [[ "$EXPECTED" != "$ACTUAL" ]]; then
  echo "Checksum mismatch! Expected ${EXPECTED}, got ${ACTUAL}"; exit 1
fi
echo "Checksum OK."

echo "Removing old /usr/local/go…"
sudo rm -rf /usr/local/go

echo "Installing ${FNAME} to /usr/local…"
sudo tar -C /usr/local -xzf "${FNAME}"

# Ensure PATH has /usr/local/go/bin early (good for shells that don't already have it)
if ! command -v go >/dev/null 2>&1 || [[ "$(which go)" != "/usr/local/go/bin/go" ]]; then
  echo 'export PATH=/usr/local/go/bin:$PATH' >> "${HOME}/.bash_profile"
  echo 'export PATH=/usr/local/go/bin:$PATH' >> "${HOME}/.zprofile"
  # shell will pick this up next login; current session may need: export PATH=/usr/local/go/bin:$PATH
fi

echo "Installed:"
/usr/local/go/bin/go version
