#!/usr/bin/env bash
# Regenerate bucket/*.json from the latest GitHub releases of the upstream CLI
# repos. Idempotent: run any time; the workflow commits only when output changes.
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "${0}")/.."

manifest() {
  local name="${1}" repo="${2}" desc="${3}"
  local tag version base sums zip sha
  tag="$(gh api "repos/tsvsheet/${repo}/releases/latest" --jq .tag_name)"
  version="${tag#v}"
  base="https://github.com/tsvsheet/${repo}/releases/download/${tag}"
  sums="$(curl -fsSL "${base}/checksums.txt")"
  zip="${name}-${version}-windows-amd64.zip"
  sha="$(printf '%s\n' "${sums}" | awk -v f="${zip}" '$2 == f { print $1 }')"
  if [ -z "${sha}" ]; then
    echo "missing checksum for ${zip}" >&2
    return 1
  fi

  mkdir -p bucket
  jq -n \
    --arg version "${version}" \
    --arg desc "${desc}" \
    --arg url "${base}/${zip}" \
    --arg hash "${sha}" \
    --arg exe "${name}-windows-amd64.exe" \
    --arg alias "${name}" \
    --arg repo "https://github.com/tsvsheet/${repo}" \
    --arg auto "https://github.com/tsvsheet/${repo}/releases/download/v\$version/${name}-\$version-windows-amd64.zip" \
    '{
      version: $version,
      description: $desc,
      homepage: "https://tsvsheet.com",
      license: "MIT",
      architecture: { "64bit": { url: $url, hash: $hash } },
      bin: [[ $exe, $alias ]],
      checkver: { github: $repo },
      autoupdate: { architecture: { "64bit": { url: $auto } } }
    }' >"bucket/${name}.json"
  echo "bucket/${name}.json ← ${tag}"
}

manifest tsv tsvsheet.go "Spreadsheet for plain text — compute .tsvt grids of values and =formulas"
manifest isnow isnow.go "Match instants against isnow date/time patterns"
