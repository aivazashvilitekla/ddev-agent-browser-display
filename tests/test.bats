#!/usr/bin/env bats

# The DDEV add-on test convention (ddev/ddev-addon-template): a real project is
# configured, the add-on is installed from this directory, and health checks
# run against the live containers. Needs bats-core + bats-assert/-file/-support
# on the host, plus ddev. Run: bats ./tests/test.bats --filter-tags '!release'

setup() {
  set -eu -o pipefail

  export GITHUB_REPO=aivazashvilitekla/ddev-agent-browser-display

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  # Right after a restart the daemons can still be STARTING (supervisord's
  # startsecs=3, and x11vnc retries until :99 exists), so give them up to 30 s.
  local i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    ddev exec supervisorctl status webextradaemons:xvfb webextradaemons:x11vnc webextradaemons:novnc >/dev/null 2>&1 && break
    sleep 2
  done

  # All three daemons up: supervisorctl exits non-zero if any is not RUNNING.
  run ddev exec supervisorctl status webextradaemons:xvfb webextradaemons:x11vnc webextradaemons:novnc
  assert_success
  assert_output --partial "webextradaemons:xvfb"
  assert_output --partial "RUNNING"

  # The display is advertised to every process in the container.
  run ddev exec bash -c 'printf %s "$DISPLAY"'
  assert_output ":99"

  # The noVNC page is served through the router on 6080.
  run curl -sfk "https://${PROJNAME}.ddev.site:6080/vnc.html"
  assert_success
  assert_output --partial "noVNC"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}
