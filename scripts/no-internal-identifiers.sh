#!/usr/bin/env bash

set -u

# Intentional failure used only to prove that the required check blocks merging.
printf 'required-check blocking proof\n' >&2
exit 1

readonly EXIT_LEAK=1
readonly EXIT_VACUOUS=3

scan_tree() {
  local root=$1
  local manifest file index grep_status found=0
  local -a labels patterns

  if [[ ! -d "$root" || ! -r "$root" || ! -x "$root" ]]; then
    printf 'error: scan root is not a readable directory: %s\n' "$root" >&2
    return "$EXIT_VACUOUS"
  fi

  manifest=$(mktemp "${TMPDIR:-/tmp}/no-internal-identifiers.XXXXXX") || return "$EXIT_VACUOUS"
  if ! find "$root" -type f -not -path "$root/.git/*" -print0 >"$manifest"; then
    printf 'error: could not enumerate scan root: %s\n' "$root" >&2
    rm -f "$manifest"
    return "$EXIT_VACUOUS"
  fi
  if [[ ! -s "$manifest" ]]; then
    printf 'error: scan root contains no files: %s\n' "$root" >&2
    rm -f "$manifest"
    return "$EXIT_VACUOUS"
  fi

  labels=(
    'AWS account id'
    'AWS ARN'
    'EC2 instance id'
    'S3 URI'
    'private TLD host'
    'Artifactory or registry host'
    'static AWS key id'
    'private IPv4 address'
    'self-hosted runner label'
  )
  patterns=(
    '\b[0-9]{12}\b'
    'arn:aws[a-z-]*:'
    '\bi-[0-9a-f]{8,}\b'
    's3:/'"/"
    '[a-z0-9-]+\.woven\b'
    '[a-z0-9-]+\.jfrog\.io\b'
    '\b(AKIA|ASIA)[A-Z0-9]{16}\b'
    '\b(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)'
    'runs-'"on:.*self-hosted"
  )

  while IFS= read -r -d '' file; do
    if [[ ! -r "$file" ]]; then
      printf 'error: unreadable file in scan root: %s\n' "$file" >&2
      rm -f "$manifest"
      return "$EXIT_VACUOUS"
    fi
    for ((index = 0; index < ${#patterns[@]}; index++)); do
      LC_ALL=C grep -InaE -- "${patterns[$index]}" "$file" >/dev/null 2>&1
      grep_status=$?
      if [[ $grep_status -eq 0 ]]; then
        printf 'internal identifier (%s): %s\n' "${labels[$index]}" "$file" >&2
        found=1
      elif [[ $grep_status -ne 1 ]]; then
        printf 'error: could not scan file: %s\n' "$file" >&2
        rm -f "$manifest"
        return "$EXIT_VACUOUS"
      fi
    done
  done <"$manifest"

  rm -f "$manifest"
  if ((found)); then
    return "$EXIT_LEAK"
  fi
  printf 'no internal identifiers found in %s\n' "$root"
  return 0
}

self_test() {
  local repository_root=$1
  local fixture output status index
  local -a labels planted

  if ! scan_tree "$repository_root"; then
    printf 'self-test failed: the real repository did not pass (EQUAL)\n' >&2
    return 1
  fi

  fixture=$(mktemp -d "${TMPDIR:-/tmp}/no-internal-identifiers-test.XXXXXX") || return 1
  output="$fixture/output"
  labels=(
    'AWS account id'
    'AWS ARN'
    'EC2 instance id'
    'S3 URI'
    'private TLD host'
    'Artifactory or registry host'
    'static AWS key id'
    'private IPv4 address'
    'self-hosted runner label'
  )
  planted=(
    "123456""789012"
    "arn:""aws:iam:region:role/example"
    "i-""deadbeef"
    "s3:""//example-bucket/object"
    "internal"".woven"
    "example"".jfrog.io"
    "AKIA""0123456789ABCDEF"
    "10"".42.0.1"
    "runs-""on: [self-hosted, linux]"
  )

  for ((index = 0; index < ${#planted[@]}; index++)); do
    rm -rf "$fixture/case"
    mkdir "$fixture/case"
    printf '%s\n' "${planted[$index]}" >"$fixture/case/planted.txt"
    scan_tree "$fixture/case" >"$output" 2>&1
    status=$?
    if [[ $status -ne $EXIT_LEAK ]] || ! grep -Fq -- "${labels[$index]}" "$output"; then
      printf 'self-test failed: planted %s was not detected (DIFFERENT)\n' "${labels[$index]}" >&2
      rm -rf "$fixture"
      return 1
    fi
  done

  rm -rf "$fixture/case"
  mkdir "$fixture/case"
  scan_tree "$fixture/case" >"$output" 2>&1
  status=$?
  if [[ $status -ne $EXIT_VACUOUS ]]; then
    printf 'self-test failed: empty tree exited %s, expected %s (VACUITY)\n' "$status" "$EXIT_VACUOUS" >&2
    rm -rf "$fixture"
    return 1
  fi

  scan_tree "$fixture/missing" >"$output" 2>&1
  status=$?
  if [[ $status -ne $EXIT_VACUOUS ]]; then
    printf 'self-test failed: unavailable tree exited %s, expected %s (VACUITY)\n' "$status" "$EXIT_VACUOUS" >&2
    rm -rf "$fixture"
    return 1
  fi

  mkdir "$fixture/inaccessible"
  printf 'public text\n' >"$fixture/inaccessible/file.txt"
  chmod 000 "$fixture/inaccessible"
  scan_tree "$fixture/inaccessible" >"$output" 2>&1
  status=$?
  chmod 700 "$fixture/inaccessible"
  if [[ $status -ne $EXIT_VACUOUS ]]; then
    printf 'self-test failed: unreadable tree exited %s, expected %s (VACUITY)\n' "$status" "$EXIT_VACUOUS" >&2
    rm -rf "$fixture"
    return 1
  fi

  rm -rf "$fixture"
  printf 'self-test passed: EQUAL, all DIFFERENT classes, and VACUITY controls\n'
}

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case "${1:-}" in
  '')
    scan_tree "$repository_root"
    ;;
  --self-test)
    self_test "$repository_root"
    ;;
  *)
    printf 'usage: %s [--self-test]\n' "$0" >&2
    exit 2
    ;;
esac
