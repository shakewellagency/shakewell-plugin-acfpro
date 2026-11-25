#!/usr/bin/env bash
#
# Copies the newest upstream ACF PRO release into the working tree and writes
# a comparison against the official free release to $REPORT.
#
# Outputs (to $GITHUB_OUTPUT when set): version=<x.y.z>, changed=true|false

set -euo pipefail

UPSTREAM="https://github.com/pronamic/advanced-custom-fields-pro.git"
OFFICIAL="https://github.com/AdvancedCustomFields/acf.git"
REPORT="${REPORT:-sync-report.md}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

out() { [[ -n "${GITHUB_OUTPUT:-}" ]] && echo "$1" >> "$GITHUB_OUTPUT"; echo "$1"; }

current="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*([0-9.]+).*/\1/p' acf.php | head -1)"
latest="$(git ls-remote --tags --refs "$UPSTREAM" | sed -nE 's#.*refs/tags/v([0-9]+(\.[0-9]+)+)$#\1#p' | sort -V | tail -1)"

if [[ -z "$current" || -z "$latest" ]]; then
  echo "Could not read versions (current='$current' latest='$latest')" >&2
  exit 1
fi

newest="$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)"
if [[ "$latest" == "$current" || "$newest" == "$current" ]]; then
  out "changed=false"
  out "version=$current"
  exit 0
fi

git clone -q --depth 1 --branch "v$latest" "$UPSTREAM" "$WORK/upstream"
upstream_sha="$(git -C "$WORK/upstream" rev-parse HEAD)"

# Replace the plugin files, keeping only what this repository adds.
rsync -a --delete \
  --exclude='.git/' --exclude='.github/' \
  --exclude='/composer.json' --exclude='/README.md' --exclude="/$REPORT" \
  "$WORK/upstream/" ./

{
  echo "## ACF PRO $current to $latest"
  echo
  echo "Upstream: \`pronamic/advanced-custom-fields-pro\` tag \`v$latest\` (\`$upstream_sha\`)."
  echo
} > "$REPORT"

if git clone -q --depth 1 --branch "$latest" "$OFFICIAL" "$WORK/official" 2>/dev/null; then
  expected='^(acf\.php|readme\.txt|vendor/composer/autoload_classmap\.php|vendor/composer/autoload_static\.php)$'
  pro_only='^(pro(/|$)|src/Pro(/|$)|assets/build/(css|js)/pro(/|$))'

  # Files present in both copies whose contents differ.
  differing="$(diff -rq --strip-trailing-cr -x .git -x .github "$WORK/upstream" "$WORK/official" \
    | sed -nE "s#^Files $WORK/upstream/(.*) and .* differ\$#\1#p" || true)"
  # Files only the PRO copy has.
  extra="$(diff -rq -x .git -x .github "$WORK/upstream" "$WORK/official" \
    | sed -nE "s#^Only in $WORK/upstream/?([^:]*): (.*)\$#\1/\2#p" | sed 's#^/##' || true)"

  unexpected_diff="$(printf '%s\n' "$differing" | grep -vE "$expected" | grep -v '^$' || true)"
  unexpected_extra="$(printf '%s\n' "$extra" | grep -vE "$pro_only" | grep -vE '^README\.md$' | grep -v '^$' || true)"
  header_lines="$(diff --strip-trailing-cr "$WORK/upstream/acf.php" "$WORK/official/acf.php" | grep -c '^[<>]' || true)"

  {
    echo "Compared with the official free release \`AdvancedCustomFields/acf\` tag \`$latest\`."
    echo
    echo "### Unexpected differences"
    echo
    if [[ -z "$unexpected_diff" && -z "$unexpected_extra" && "$header_lines" -le 6 ]]; then
      echo "None. Outside the PRO-only folders the two copies match, apart from the plugin header, \`readme.txt\` and the Composer autoload maps."
    else
      echo "**Read these before merging.**"
      echo
      [[ -n "$unexpected_diff" ]] && { echo "Differ from the free release:"; echo; printf '%s\n' "$unexpected_diff" | sed 's/^/- `/; s/$/`/'; echo; }
      [[ -n "$unexpected_extra" ]] && { echo "Present only in the PRO copy, outside the PRO folders:"; echo; printf '%s\n' "$unexpected_extra" | sed 's/^/- `/; s/$/`/'; echo; }
      [[ "$header_lines" -gt 6 ]] && echo "\`acf.php\` differs from the free release by $header_lines lines; only the 3 header lines are expected to differ."
    fi
    echo
  } >> "$REPORT"
else
  {
    echo "### Unexpected differences"
    echo
    echo "**Not checked.** The official free repository has no tag \`$latest\`, so this release could not be compared. Review the diff by hand."
    echo
  } >> "$REPORT"
fi

{
  echo "### PRO-only PHP worth a look"
  echo
  hits="$(grep -rnE '\beval[[:space:]]*\(|gzinflate|str_rot13|shell_exec|passthru|proc_open|popen[[:space:]]*\(|create_function' \
    --include='*.php' pro src/Pro 2>/dev/null | cut -c1-200 || true)"
  if [[ -z "$hits" ]]; then echo "No use of \`eval\`, shell or obfuscation functions."; else echo '```'; echo "$hits"; echo '```'; fi
  echo
  echo "Hosts referenced in PRO-only PHP:"
  echo
  grep -rhoE 'https?://[A-Za-z0-9.-]+' --include='*.php' pro src/Pro 2>/dev/null | sort | uniq -c | sort -rn | sed 's/^ *//; s/^/- /'
} >> "$REPORT"

out "changed=true"
out "version=$latest"
