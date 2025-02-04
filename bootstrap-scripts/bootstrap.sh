#!/bin/bash
# Shell script to bootstrap a developer workstation
# Inspired by solowizard.com
#
# Usage:
#   Running the script remotely:
#     bash < <(curl -s https://raw.github.com/LyraPhase/sprout-wrap/master/bootstrap-scripts/bootstrap.sh )
#   Running the script if you have downloaded it:
#     ./bootstrap.sh
#
# http://github.com/LyraPhase/sprout-wrap
# Copyright (C) © 🄯  2013-2025 James Cuzella
# This script may be freely distributed under the MIT license.

## Figure out OSX version (source: https://www.opscode.com/chef/install.sh)
function detect_platform_version() {
  # Matching the tab-space with sed is error-prone
  platform_version=$(sw_vers | awk '/^ProductVersion:/ { print $2 }')

  # shellcheck disable=SC2034
  major_version=$(echo "$platform_version" | cut -d. -f1,2)

  # x86_64 Apple hardware often runs 32-bit kernels (see OHAI-63)
  # macOS Monterey + Apple M1 Silicon (arm64) gives empty string for this x86_64 check
  x86_64=$(sysctl -n hw.optional.x86_64)
  arm64=$(sysctl -n hw.optional.arm64)
  if [[ "$x86_64" == '1' ]]; then
    machine="x86_64"
  elif [[ "$arm64" == '1' ]]; then
    machine="arm64"
  fi
}

## Find and return git repo HEAD ref SHA
function get_git_head_ref() {
  if command -v git > /dev/null 2>&1 && [ -d '/Applications/Xcode.app' ]; then
    git rev-parse HEAD
  else
    HASH="ref: HEAD"
    while [[ "${HASH:0:4}" == "ref:" ]]; do
      # Capture the HASH
      REF="${HASH:5}"
      if [[ ! -f ".git/$REF" ]]; then
        echo "Failed to follow reference: '.git/$REF'!  This implies that " >&2
        echo "this Git repository is broken!" >&2
        HASH='UNKNOWN'
      fi
      HASH="$(cat ".git/$REF")"
    done
    echo -n "$HASH"
  fi
}

## Find and return current HEAD symbolic branch ref
function get_git_head_branch() {
  if command -v git > /dev/null 2>&1 && [ -d '/Applications/Xcode.app' ]; then
    git branch --show-current
  else
    awk -F: '{ print $2 }' .git/HEAD | sed -e 's#[[:space:]]*refs/heads/##'
  fi
}

## Apple TCC (Transparency, Consent, and Control) Database entries to enable unattended provisioning
## References:
##   https://www.rainforestqa.com/blog/macos-tcc-db-deep-dive
##   https://stackoverflow.com/a/57259004/645491
bypass_apple_system_tcc() {
  APP_ID="$1"

  TCC_CSREQ_TMP_DIR=$(mktemp -d /tmp/bypass-apple-tcc-csreq.XXXXXXXXXX)
  DATABASE_SYSTEM="/Library/Application Support/com.apple.TCC/TCC.db"
  INPUT_SERVICES=(kTCCServiceSystemPolicyAllFiles kTCCServicePostEvent kTCCServiceAccessibility)

  # Generate codesign request for APP_ID
  REQ_STR=$(codesign -d -r- "${APP_ID}" 2>&1 | awk -F ' => ' '/designated/{print $2}')
  echo "$REQ_STR" | csreq -r- -b "${TCC_CSREQ_TMP_DIR}/csreq.bin"
  REQ_HEX=$(xxd -p "${TCC_CSREQ_TMP_DIR}/csreq.bin" | tr -d '\n')

  APP_CSREQ="X'${REQ_HEX}'"
  for INPUT_SERVICE in "${INPUT_SERVICES[@]}"; do
    sudo sqlite3 "$DATABASE_SYSTEM" "REPLACE INTO access VALUES('$INPUT_SERVICE','$APP_ID',1,2,4,1,${APP_CSREQ},NULL,?,NULL,NULL,0,?);"
  done
  rm -rf "$TCC_CSREQ_TMP_DIR"
}

bypass_apple_user_tcc_system_events() {
  APP_ID="$1"

  TCC_CSREQ_TMP_DIR=$(mktemp -d /tmp/bypass-apple-tcc-sysevents-csreq.XXXXXXXXXX)
  DATABASE_USER="${HOME}/Library/Application Support/com.apple.TCC/TCC.db"
  SYSTEM_EVENTS_APP="/System/Library/CoreServices/System Events.app"
  INPUT_SERVICES=(kTCCServiceAppleEvents)
  # Can be detected via: mdls -name kMDItemContentTypeTree "$SYSTEM_EVENTS_APP"
  INDIRECT_OBJECT_ID_TYPE=0 # Bundle Identifier
  INDIRECT_OBJECT_ID=com.apple.systemevents
  SYS_EVENTS_IDENTIFIER=$(codesign -d -r- "$SYSTEM_EVENTS_APP" 2>&1 | awk -F ' => ' '/designated/{print $2}')

  # Generate codesign request for APP_ID
  REQ_STR=$(codesign -d -r- "${APP_ID}" 2>&1 | awk -F ' => ' '/designated/{print $2}')
  echo "$REQ_STR" | csreq -r- -b "${TCC_CSREQ_TMP_DIR}/csreq.bin"
  REQ_HEX=$(xxd -p "${TCC_CSREQ_TMP_DIR}/csreq.bin" | tr -d '\n')

  # Generate codesign request for INDIRECT_OBJECT_CODE_ID (identifier "com.apple.systemevents" and anchor apple)
  echo "$SYS_EVENTS_IDENTIFIER" | csreq -r- -b "${TCC_CSREQ_TMP_DIR}/indirect-object-csreq.bin"
  SYS_EVENTS_REQ_HEX=$(xxd -p "${TCC_CSREQ_TMP_DIR}/indirect-object-csreq.bin" | tr -d '\n')
  INDIRECT_OBJECT_CODE_ID_CSREQ="X'${SYS_EVENTS_REQ_HEX}'"

  APP_CSREQ="X'${REQ_HEX}'"
  for INPUT_SERVICE in "${INPUT_SERVICES[@]}"; do
    sudo sqlite3 "$DATABASE_USER" "REPLACE INTO access VALUES('$INPUT_SERVICE','$APP_ID',1,2,3,1,${APP_CSREQ},NULL,$INDIRECT_OBJECT_ID_TYPE,'$INDIRECT_OBJECT_ID',$INDIRECT_OBJECT_CODE_ID_CSREQ,0,?);"
  done
  rm -rf "$TCC_CSREQ_TMP_DIR"
}

## Spawn sudo in background subshell to refresh the sudo timestamp
prevent_sudo_timeout() {
  # Note: Don't use GNU expect... just a subshell (for some reason expect spawn jacks up readline input)
  echo "Please enter your sudo password to make changes to your machine"
  sudo -v # Asks for passwords
  (while true; do
    sudo -v
    sleep 40
  done) & # update the user's timestamp
  export timeout_loop_PID=$!
}

# Kill sudo timestamp refresh PID and invalidate sudo timestamp
# Don't warn about unreachable commands in this function (triggered by trap)
# shellcheck disable=SC2317 # false-positive koalaman/shellcheck#2660
kill_timeout_loop() {
  echo "Killing $timeout_loop_PID due to trap"
  kill -TERM "$timeout_loop_PID"
  sudo -K
}
trap kill_timeout_loop EXIT HUP TSTP QUIT SEGV TERM INT ABRT # trap all common terminate signals
trap "exit" INT                                              # Run exit when this script receives Ctrl-C

## Drop-In replacement for prevent_sudo_timeout in CI
## CI has sudo, but long-running jobs can timeout
## unless log output is frequent enough
prevent_ci_log_timeout() {
  echo "INFO: CI run detected via \$CI=$CI or \$TEST_KITCHEN=$TEST_KITCHEN env vars"
  echo "INFO: Starting log timeout prevention process..."
  (while true; do
    echo '.'
    sleep 40
  done) & # update STDOUT logs
  export timeout_loop_PID=$!
}

function check_trace_state() {
  if shopt -op 2>&1 | grep -q xtrace; then
    trace_was_on=1
  else
    trace_was_on=0
  fi
}

function init_trace_on() {
  PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }' ## Debugging prompt (for bash -x || set -x)
  set -x
}

function turn_trace_on_if_was_on() {
  [ $trace_was_on -eq 1 ] && set -x ## Turn trace back on
}

function turn_trace_off() {
  set +x ## RVM trace is NOISY!
}

# Check locked versions
# Set vars if unset
function check_sprout_locked_ruby_versions() {
  [ -z "$sprout_ruby_version" ] && sprout_ruby_version=$(tr -d '\n' < "${REPO_BASE}/.ruby-version")
  [ -z "$sprout_ruby_gemset" ] && sprout_ruby_gemset=$(tr -d '\n' < "${REPO_BASE}/.ruby-gemset")
  [ -z "$sprout_rubygems_ver" ] && sprout_rubygems_ver=$(tr -d '\n' < "${REPO_BASE}/.rubygems-version") ## Passed to gem update --system
  [ -z "$sprout_bundler_ver" ] && sprout_bundler_ver=$(grep -A 1 "BUNDLED WITH" "${REPO_BASE}/Gemfile.lock" | tail -n 1 | tr -d '[:blank:]')
}

function rvm_set_compile_opts() {
  turn_trace_on_if_was_on
  local opt_dir rvm_patch_args
  export PKG_CONFIG_PATH # Always export for pkg-config to work properly

  # Disable installing RI docs for speed
  cat > "${HOME}/.gemrc" <<- EOF
	install: --no-document
	update: --no-document
	EOF

  if [[ "$RVM_ENABLE_YJIT" == "1" ]]; then
    CONFIGURE_ARGS="${CONFIGURE_ARGS} --enable-yjit"
    rustup default "stable-${machine}-apple-darwin"
  fi
  if [[ "$RVM_WITH_JEMALLOC" == "1" ]]; then
    CONFIGURE_ARGS="${CONFIGURE_ARGS} --with-jemalloc"
    PKG_CONFIG_PATH="${_HOMEBREW_OPT}/jemalloc/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    opt_dir="$(pkg-config --variable=prefix jemalloc)${opt_dir:+:${opt_dir}}"
  fi
  if [[ "$RVM_COMPILE_OPTS_OPENSSL3" == "1" ]]; then
    PKG_CONFIG_PATH="${_HOMEBREW_OPT}/openssl@3/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    CONFIGURE_ARGS="${CONFIGURE_ARGS} --with-openssl-dir=$(brew --prefix openssl@3)"
    opt_dir="$(pkg-config --variable=prefix openssl)${opt_dir:+:${opt_dir}}"
  fi
  if [[ "$RVM_COMPILE_OPTS_M1_LIBFFI" == "1" ]]; then
    if [[ "$BREW_INSTALL_PKG_CONFIG" == "1" ]]; then
      # Print all pkg-config variables in scriptable form with prefix: LIBFFI_
      eval "$(PKG_CONFIG_PATH=${_HOMEBREW_OPT}/libffi/lib/pkgconfig pkg-config --print-variables --env=LIBFFI libffi)"
    else
      LIBFFI_PCFILEDIR="${_HOMEBREW_OPT}/libffi/lib/pkgconfig"
      LIBFFI_INCLUDEDIR="${_HOMEBREW_OPT}/libffi/include"
      LIBFFI_LIBDIR="${_HOMEBREW_OPT}/libffi/lib"
    fi
    export optflags="-Wno-error=implicit-function-declaration"
    export LDFLAGS="-L${LIBFFI_LIBDIR}"
    export DLDFLAGS="-L${LIBFFI_LIBDIR}"
    export CPPFLAGS="-I${LIBFFI_INCLUDEDIR}"
    export PKG_CONFIG_PATH="${LIBFFI_PCFILEDIR}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    # Escape from current Gemfile.lock bundler version restriction for bootstrap
    # NOTE: This could cause problems in the future, b/c
    #       we depend on system bundler to write ~/.bundle/config here
    #       Let's hope they don't break config file API version
    bash -c "cd /tmp/ && bundle config build.ffi -- --with-libffi-dir=$(pkg-config --variable=prefix libffi)"
  fi

  if [[ "$RVM_COMPILE_OPTS_M1_NOKOGIRI" == "1" && "$machine" == "arm64" ]]; then
    bash -c 'cd /tmp/ && bundle config build.nokogiri --platform=ruby -- --use-system-libraries'
  elif [[ "$RVM_COMPILE_OPTS_NOKOGIRI_DEPS" == "1" ]]; then
    PKG_CONFIG_PATH="${_HOMEBREW_OPT}/libxslt/lib/pkgconfig:${_HOMEBREW_OPT}/libxml2/lib/pkgconfig:${_HOMEBREW_OPT}/zlib/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    local nokogiri_dep_configure_flags=(
      "--with-xslt-dir=$(pkg-config --variable=prefix libxslt)"
      "--with-iconv-dir=$(brew --prefix libiconv)"
      "--with-xml2-dir=$(pkg-config --variable=prefix libxml-2.0)"
      "--with-zlib-dir=$(pkg-config --variable=prefix zlib)"
    )
    # Run in forked subshell to avoid sprout-wrap's project Gemfile.lock context
    (
      cd /tmp/ && bundle config build.nokogiri --platform=ruby -- "${nokogiri_dep_configure_flags[@]}"
    )
  fi

  if [[ "$RVM_COMPILE_OPTS_READLINE" ]]; then
    PKG_CONFIG_PATH="${_HOMEBREW_OPT}/readline/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    CONFIGURE_ARGS="${CONFIGURE_ARGS} --with-readline-dir=$(pkg-config --variable=prefix readline)"
    opt_dir="$(pkg-config --variable=prefix readline):${opt_dir}"
  fi

  if [[ "$RVM_COMPILE_OPTS_NCURSES" ]]; then
    PKG_CONFIG_PATH="${_HOMEBREW_OPT}/ncurses/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    CONFIGURE_ARGS="${CONFIGURE_ARGS} --with-ncurses-dir=$(pkg-config --variable=prefix ncurses)"
  fi

  if [[ "$RVM_COMPILE_OPTS_LIBYAML" ]]; then
    PKG_CONFIG_PATH="${_HOMEBREW_OPT}/libyaml/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    # Note: The pkg-config .pc file is named: yaml-0.1.pc
    # This may be a Homebrew packaging error, so if it changes, we could switch to using: brew --prefix libyaml
    CONFIGURE_ARGS="${CONFIGURE_ARGS} --with-libyaml-dir=$(pkg-config --variable=prefix yaml-0.1)"
    opt_dir="$(pkg-config --variable=prefix yaml-0.1):${opt_dir}"
  fi
  if [[ "$RVM_COMPILE_OPTS_LIBKSBA" ]]; then
    PKG_CONFIG_PATH="${_HOMEBREW_OPT}/libksba/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    # Note: This pkg-config .pc file is named: ksba.pc
    CONFIGURE_ARGS="${CONFIGURE_ARGS} --with-libksba-dir=$(pkg-config --variable=prefix ksba)"
  fi
  # Optional Ruby Std-lib dependency
  # See: https://ruby-doc.org/stdlib-1.9.3/libdoc/gdbm/rdoc/GDBM.html
  if [[ "$RVM_COMPILE_OPTS_GDBM" ]]; then
    opt_dir="$(brew --prefix gdbm):${opt_dir}"
  fi

  if [[ "$RVM_COMPILE_OPTS_PATCH_AUTOCONF_FUNC_NAME_STRING" == "1" ]]; then
    rvm_patch_args="--patch ${REPO_BASE}/bootstrap-scripts/patches/ruby-3.1.2-configure.ac.patch"
  fi

  if [ -n "$opt_dir" ]; then
    CONFIGURE_ARGS="${CONFIGURE_ARGS} --with-opt-dir=${opt_dir}"
  fi

  if [ -n "$CONFIGURE_ARGS" ]; then
    CONFIGURE_ARGS="${rvm_patch_args} -C ${CONFIGURE_ARGS}"
  fi

  for _var in PKG_CONFIG_PATH CONFIGURE_ARGS LDFLAGS DLDFLAGS CPPFLAGS optflags; do
    [ -n "$(eval echo -n \$"$_var")" ] && export "${_var?}"
  done

  turn_trace_off
}

function brew_install_rvm_libs() {
  # Refer to Ruby dependency list from ruby-install to keep this updated
  # https://github.com/postmodern/ruby-install/blob/master/share/ruby-install/ruby/dependencies.txt#L5
  if [[ "$RVM_ENABLE_YJIT" == "1" ]]; then
    grep -q 'rust' Brewfile || echo "brew 'rust'" >> Brewfile
    grep -q 'rustup-init' Brewfile || echo "brew 'rustup-init'" >> Brewfile
  fi
  if [[ "$RVM_WITH_JEMALLOC" == "1" ]]; then
    grep -q 'jemalloc' Brewfile || echo "brew 'jemalloc'" >> Brewfile
  fi
  # Note: Beware of CVE-2024-3094
  # Cannot lock version due to https://github.com/Homebrew/homebrew-bundle/issues/547#issuecomment-525443604
  # So, we must rely on the Homebrew community to not push the new versions until it's been vetted
  if [[ "$BREW_INSTALL_XZ" == "1" ]]; then
    grep -q 'xz' Brewfile || echo "brew 'xz'" >> Brewfile
  fi
  if [[ "$BREW_INSTALL_BISON" == "1" ]]; then
    grep -q 'bison' Brewfile || echo "brew 'bison'" >> Brewfile
  fi
  if [[ "$BREW_INSTALL_GDBM" == "1" ]]; then
    grep -q 'gdbm' Brewfile || echo "brew 'gdbm'" >> Brewfile
  fi
  if [[ "$BREW_INSTALL_OPENSSL3" == "1" ]]; then
    grep -q 'openssl@3' Brewfile || echo "brew 'openssl@3'" >> Brewfile
  fi
  if [[ "$BREW_INSTALL_READLINE" == "1" ]]; then
    grep -q 'readline' Brewfile || echo "brew 'readline'" >> Brewfile
  fi
  if [[ "$BREW_INSTALL_NCURSES" == "1" ]]; then
    grep -q 'ncurses' Brewfile || echo "brew 'ncurses'" >> Brewfile
  fi
  if [[ "$BREW_INSTALL_LIBYAML" == "1" ]]; then
    grep -q 'libyaml' Brewfile || echo "brew 'libyaml'" >> Brewfile
  fi
  if [[ "$BREW_INSTALL_LIBKSBA" == "1" ]]; then
    grep -q 'libksba' Brewfile || echo "brew 'libksba'" >> Brewfile
  fi
  if [[ "$CI" != 'true' ]]; then
    if [[ "$BREW_INSTALL_PKG_CONFIG" == "1" ]]; then
      grep -q 'pkg-config' Brewfile || echo "brew 'pkg-config'" >> Brewfile
    fi
    if [[ "$BREW_INSTALL_LIBFFI" == "1" ]]; then
      grep -q 'libffi' Brewfile || echo "brew 'libffi'" >> Brewfile
    fi
    if [[ "$BREW_INSTALL_NOKOGIRI_LIBS" == "1" ]]; then
      grep -q 'libxml2' Brewfile || echo "brew 'libxml2'" >> Brewfile
      grep -q 'libxslt' Brewfile || echo "brew 'libxslt'" >> Brewfile
      grep -q 'libiconv' Brewfile || echo "brew 'libiconv'" >> Brewfile
      grep -q 'zlib' Brewfile || echo "brew 'zlib'" >> Brewfile
    fi
  fi
}

# Install RVM if not already installed
function install_rvm() {
  if ! command -v rvm && ! type rvm 2>&1 | grep -q 'rvm is a function'; then
    export rvm_user_install_flag=1
    export rvm_prefix="$HOME"
    export rvm_path="${rvm_prefix}/.rvm"

    echo "Installing RVM..." >&2

    bash -c "${REPO_BASE}/bootstrap-scripts/bootstrap-rvm.sh $USER"

    # RVM trace is NOISY!
    check_trace_state
    turn_trace_off

    # Install .ruby-version @ .ruby-gemset
    rvm_install_ruby_and_gemset

    debug_pkg_config_path

    rvm_install_bundler

    rvm_debug_gems

    turn_trace_on_if_was_on
  else
    echo 'RVM already installed... skipping installation' >&2
  fi
}

# Use rvm as a function within each subshell
# This is necessary to do per-subshell because it overrides built-in commands
# like `cd`, and the rvm __zsh_like_cd() function triggers our traps via EXIT
function source_rvm() {
  if ! type rvm 2>&1 | grep -q 'rvm is a function'; then
    # Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
    export PATH="$PATH:$HOME/.rvm/bin"

    # shellcheck disable=SC1091
    [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
  fi
}

function rvm_install_ruby_and_gemset() {
  check_sprout_locked_ruby_versions

  check_trace_state
  turn_trace_off
  rvm_set_compile_opts
  # N.B.: Use a subshell for rvm functions, so that our kill_timeout_loop is not inherited
  (
    turn_trace_off
    source_rvm
    # shellcheck disable=SC2086
    rvm install "ruby-${sprout_ruby_version}" ${CONFIGURE_ARGS}
    rvm use "ruby-${sprout_ruby_version}"
    rvm gemset create "$sprout_ruby_gemset"
  )
  turn_trace_on_if_was_on
}

# Only use this function inside a subshell with trace off!
function rvm_use_locked_ruby_version@gemset() {
  check_sprout_locked_ruby_versions
  rvm use "ruby-${sprout_ruby_version}@${sprout_ruby_gemset}"
}

# shellcheck disable=SC1010
function rvm_install_bundler() {
  check_sprout_locked_ruby_versions
  check_trace_state
  turn_trace_off

  # Install bundler + rubygems in RVM path
  echo "rvm ${sprout_ruby_version} do gem update --system ${sprout_rubygems_ver}"
  (
    turn_trace_off
    source_rvm
    rvm "${sprout_ruby_version}" do gem update --system "${sprout_rubygems_ver}"
  )

  # Install same version of bundler as Gemfile.lock
  echo "rvm ${sprout_ruby_version} do gem install --default bundler:${sprout_bundler_ver}"
  (
    turn_trace_off
    source_rvm
    rvm "${sprout_ruby_version}" do gem install --default "bundler:${sprout_bundler_ver}"
  )
  turn_trace_on_if_was_on
}

function debug_pkg_config_path() {
  if [ "$trace_was_on" -eq 1 ]; then
    check_trace_state
    turn_trace_off
    echo "======= DEBUG ============"
    echo "------- PKG_CONFIG_PATH -----"
    local _path _pkg_config_path_array
    printf '%s' "$PKG_CONFIG_PATH" | tr ':' '\n' \
      | while IFS='' read -r _path; do
        if [ -d "$_path" ]; then
          echo "$_path" >&2
          ls -l "$_path" >&2
        fi
      done
    echo "======= DEBUG ============"
  fi
}

function debug_ruby_bundler_cmds() {
  type rvm | head -1
  printf "ruby is: "
  command -v ruby
  printf "bundler is: "
  command -v bundler
}

# shellcheck disable=SC1010
function rvm_debug_gems() {
  if [ "$trace_was_on" -eq 1 ]; then
    check_trace_state
    turn_trace_off
    echo "======= DEBUG ============"
    echo "------- bootstrap.sh -----"
    debug_ruby_bundler_cmds
    (
      turn_trace_off
      echo "------- RVM Subshell ---"
      source_rvm
      debug_ruby_bundler_cmds
      rvm_use_locked_ruby_version@gemset
      rvm info
      echo "------- END Subshell ---"
    )
    echo "GEMS IN SHELL ENV:"
    gem list
    check_sprout_locked_ruby_versions
    echo "GEMS IN ${sprout_ruby_version}@${sprout_ruby_gemset}:"
    (
      turn_trace_off
      echo "------- RVM Subshell ---"
      source_rvm
      rvm "${sprout_ruby_version}"@"${sprout_ruby_gemset}" do gem list
      echo "------- END Subshell ---"
    )
    echo "======= DEBUG ============"
  fi
}

if [[ "$SOLOIST_DEBUG" == 'true' ]]; then
  init_trace_on
fi

# CI setup
if [[ "$CI" == 'true' ]]; then
  init_trace_on
  SOLOIST_DIR="${GITHUB_WORKSPACE}/.."
  SPROUT_WRAP_BRANCH="$GITHUB_REF_NAME"
elif [[ "$TEST_KITCHEN" == '1' ]]; then
  init_trace_on
  SOLOIST_DIR="/tmp/kitchen/soloist"
  SPROUT_WRAP_BRANCH=$(get_git_head_branch)
fi

use_system_ruby=0
SOLOISTRC=${SOLOISTRC:-soloistrc}
SOLOIST_DIR=${SOLOIST_DIR:-"${HOME}/src/pub/soloist"}
#XCODE_DMG='XCode-4.6.3-4H1503.dmg'
SPROUT_WRAP_URL='https://github.com/LyraPhase/sprout-wrap.git'
SPROUT_WRAP_BRANCH=${SPROUT_WRAP_BRANCH:-'master'}
HOMEBREW_INSTALLER_URL='https://raw.githubusercontent.com/Homebrew/install/master/install.sh'
USER_AGENT="Chef Bootstrap/$(get_git_head_ref) ($(curl --version | head -n1); $(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')$(uname -r); +https://lyraphase.com)"

if [[ "${BASH_SOURCE[0]}" != '' ]]; then
  # Running from checked out script
  REPO_BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
else
  # Running via curl | bash (piped)
  REPO_BASE=${SOLOIST_DIR}/sprout-wrap
fi

detect_platform_version

# Determine which XCode version to use based on platform version
# https://developer.apple.com/downloads/index.action
case $platform_version in
  15.* | 14.* | 13.* | 12.*)
    # First set version-specific XCODE_DMT
    case $platform_version in
      15.*) XCODE_DMG='Xcode_16.2.xip' ;;
      14.*) XCODE_DMG='Xcode_15.1.xip' ;;
      13.*) XCODE_DMG='Xcode_15.1.xip' ;;
      12.*) XCODE_DMG='Xcode_14.3.1.xip' ;;
    esac

    # Set common configuration for all modern versions
    TRY_XCI_OSASCRIPT_FIRST=1
    BREW_INSTALL_PKG_CONFIG=1
    BREW_INSTALL_LIBFFI=1
    RVM_COMPILE_OPTS_M1_LIBFFI=1
    BREW_INSTALL_OPENSSL3=1
    RVM_COMPILE_OPTS_OPENSSL3=1
    RVM_ENABLE_YJIT=1
    RVM_WITH_JEMALLOC=1
    BREW_INSTALL_READLINE=1
    RVM_COMPILE_OPTS_READLINE=1
    BREW_INSTALL_NCURSES=1
    RVM_COMPILE_OPTS_NCURSES=1
    BREW_INSTALL_LIBYAML=1
    RVM_COMPILE_OPTS_LIBYAML=1
    BREW_INSTALL_LIBKSBA=1
    RVM_COMPILE_OPTS_LIBKSBA=1
    BREW_INSTALL_XZ=1
    BREW_INSTALL_GDBM=1
    RVM_COMPILE_OPTS_GDBM=1
    RVM_COMPILE_OPTS_PATCH_AUTOCONF_FUNC_NAME_STRING=1
    RVM_COMPILE_OPTS_NOKOGIRI_DEPS=1
    BYPASS_APPLE_TCC="1"
    BREW_INSTALL_NOKOGIRI_LIBS="1"
    RVM_COMPILE_OPTS_M1_NOKOGIRI=1
    ;;

  11.6*)
    XCODE_DMG='Xcode_13.1.xip'
    export TRY_XCI_OSASCRIPT_FIRST=1
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
    BYPASS_APPLE_TCC="1"
    ;;
  10.15*)
    XCODE_DMG='Xcode_12.4.xip'
    export INSTALL_SDK_HEADERS=1
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
    ;;
  10.14*)
    XCODE_DMG='Xcode_11_GM_Seed.xip'
    export INSTALL_SDK_HEADERS=1
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
    ;;
  10.12*) XCODE_DMG='Xcode_8.1.xip' ;;
  10.11*) XCODE_DMG='Xcode_7.3.1.dmg' ;;
  10.10*) XCODE_DMG='Xcode_6.3.2.dmg' ;;
  "10.9") XCODE_DMG='XCode-5.0.2-5A3005.dmg' ;;
  *) XCODE_DMG='XCode-5.0.1-5A2053.dmg' ;;

esac

errorout() {
  echo -e "\x1b[31;1mERROR:\x1b[0m ${1}"
  exit 1
}

pushd "$(pwd)" || exit

# TODO: Figure out if Xcodes CLI tool will work?
#       https://github.com/RobotsAndPencils/Xcodes
# Bootstrap XCode from dmg
if [ ! -d "/Applications/Xcode.app" ]; then
  echo "INFO: XCode.app not found. Installing XCode..."
  if [ ! -e "$XCODE_DMG" ]; then
    if [[ "$XCODE_DMG" =~ ^.*\.dmg$ ]]; then
      curl --fail --user-agent "$USER_AGENT" -L -O "http://lyraphase.com/doc/installers/mac/${XCODE_DMG}" || curl --fail -L -O "http://adcdownload.apple.com/Developer_Tools/${XCODE_DMG%%.xip}/${XCODE_DMG}"
    else
      curl --fail --user-agent "$USER_AGENT" -L -O "http://lyraphase.com/doc/installers/mac/${XCODE_DMG}" || curl --fail -L -O "http://adcdownload.apple.com/Developer_Tools/${XCODE_DMG%%.dmg}/${XCODE_DMG}"
    fi
  fi

  # Why does Apple have to make everything more difficult?
  if [[ "$XCODE_DMG" =~ ^.*\.xip$ ]]; then
    pkgutil --check-signature "$XCODE_DMG"
    TMP_DIR=$(mktemp -d /tmp/xcode-installer.XXXXXXXXXX)

    if [[ -x "$(command -v xip)" ]]; then
      xip -x "${REPO_BASE}/${XCODE_DMG}"
      sudo mv ./Xcode.app /Applications/
    else
      xar -C "${TMP_DIR}/" -xf "$XCODE_DMG"
      pushd "$TMP_DIR" || exit
      curl -O https://gist.githubusercontent.com/pudquick/ff412bcb29c9c1fa4b8d/raw/24b25538ea8df8d0634a2a6189aa581ccc6a5b4b/parse_pbzx2.py
      python parse_pbzx2.py Content
      xz -d Content.part*.cpio.xz
      sudo /bin/sh -c 'cat ./Content.part*.cpio' | sudo cpio -idm
      sudo mv ./Xcode.app /Applications/
      popd || exit
    fi
    [ -d "$TMP_DIR" ] && rm -rf "${TMP_DIR:?}/"
  else
    hdiutil attach "$XCODE_DMG"
    export __CFPREFERENCES_AVOID_DAEMON=1
    if [ -e '/Volumes/XCode/XCode.pkg' ]; then
      sudo installer -pkg '/Volumes/XCode/XCode.pkg' -target /
    elif [ -e '/Volumes/XCode.app' ]; then
      sudo cp -r '/Volumes/XCode.app' '/Applications/'
    fi
    hdiutil detach '/Volumes/XCode'
  fi
fi

# Hack to make sure sudo caches sudo password correctly...
# And so it stays available for the duration of the Chef run
if [[ "$CI" == 'true' || "$TEST_KITCHEN" == '1' ]]; then
  set +x
  prevent_ci_log_timeout
  set -x
else
  prevent_sudo_timeout
fi
readonly timeout_loop_PID # Make PID readonly for security ;-)

# Bypass TCC
if [[ "$BYPASS_APPLE_TCC" == '1' ]]; then
  if [[ "$TEST_KITCHEN" == '1' ]]; then
    bypass_apple_system_tcc '/usr/libexec/sshd-keygen-wrapper'
    bypass_apple_user_tcc_system_events '/usr/libexec/sshd-keygen-wrapper'
    bypass_apple_system_tcc '/usr/bin/osascript'
    bypass_apple_user_tcc_system_events '/usr/bin/osascript'
  fi
fi

# Try xcode-select --install first
if [[ "$TRY_XCI_OSASCRIPT_FIRST" == '1' ]]; then
  # Try the AppleScript automation method rather than relying on manual .xip / .dmg download & mirroring
  # Note: Apple broke automated Xcode installer downloads.  Now requires manual Apple ID sign-in.
  # Source: https://web.archive.org/web/20211210020829/https://techviewleo.com/install-xcode-command-line-tools-macos/
  if [ ! -d /Library/Developer/CommandLineTools ]; then
    xcode-select --install
    # Wait for CLT Installer App starts & grab PID
    while ! clt_pid=$(pgrep -f 'Install Command Line Developer Tools.app' 2> /dev/null | head -n1); do
      sleep 1
    done
    osascript <<- EOD
  	  tell application "System Events"
  	    tell process "Install Command Line Developer Tools"
  	      keystroke return
  	      click button "Agree" of window "License Agreement"
  	    end tell
  	  end tell
EOD
    # Wait for CLT to be fully installed before continuing
    # wait for non-child PID (Darwin)
    lsof -p "$clt_pid" +r 1 &> /dev/null
  else
    echo "INFO: Found /Library/Developer/CommandLineTools already existing. skipping..."
  fi
else
  # !! This script is no longer supported !!
  #  Apple broke all direct downloads without logging with an Apple ID first.
  #   The number of hoops that a script would need to jump through to login,
  #   store cookies, and download is prohibitive.
  #   Now we all must manually download and mirror the files for this to work at all :'-(
  curl -Ls https://gist.githubusercontent.com/trinitronx/6217746/raw/d0c12be945f1984fc7c40501f5235ff4b93e71d6/xcode-cli-tools.sh | sudo bash
fi

# We need to accept the xcodebuild license agreement before building anything works
# Evil Apple...
if [ -x "$(command -v expect)" ]; then
  echo "INFO: GNU expect found! By using this script, you automatically accept the XCode License agreement found here: http://www.apple.com/legal/sla/docs/xcode.pdf"
  # Git.io short URL to: ./bootstrap-scripts/accept-xcodebuild-license.exp
  #curl -Ls 'https://git.io/viaLD' | sudo expect -
  sudo expect "${REPO_BASE}/bootstrap-scripts/accept-xcodebuild-license.exp"
else
  echo -e "\x1b[31;1mERROR:\x1b[0m Could not find expect utility (is '$(command -v expect)' executable?)"
  echo -e "\x1b[31;1mWarning:\x1b[0m You have not agreed to the Xcode license.\nBuilds will fail! Agree to the license by opening Xcode.app or running:\n
    xcodebuild -license\n\nOR for system-wide acceptance\n
    sudo xcodebuild -license"
  exit 1
fi

if [[ "$INSTALL_SDK_HEADERS" == '1' ]]; then
  # Reference: https://github.com/Homebrew/homebrew-core/issues/18533#issuecomment-332501316
  # shellcheck disable=SC2016
  if ruby_mkmf_output="$(ruby -r mkmf -e 'print $hdrdir + "\n"')" && [ -d "$ruby_mkmf_output" ]; then
    echo "INFO: Ruby header files successfully found!"
  else
    # This requires user interaction... but Mojave XCode CLT is broken!
    # Reference: https://donatstudios.com/MojaveMissingHeaderFiles
    sudo rm -rf /Library/Developer/CommandLineTools
    sudo xcode-select --install
    # shellcheck disable=SC2009
    xcode_clt_pid=$(ps auxww | grep -i 'Install Command Line Developer Tools' | grep -v grep | awk '{ print $2 }')
    # wait for non-child PID of CLT installer dialog UI
    while ps -p "$xcode_clt_pid" > /dev/null; do sleep 1; done

    sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /
  fi
fi

if [[ "$CI" == 'true' || "$TEST_KITCHEN" == '1' ]]; then
  echo "INFO: CI run detected via \$CI=$CI env var"
  echo "INFO: NOT checking out git repo"
  echo "INFO: Running soloist from ${REPO_BASE}/test/fixtures"
  # Must use pushd to keep dir stack 2 items deep
  pushd "${REPO_BASE}/test/fixtures" || exit
else
  # Checkout sprout-wrap after XCode CLI tools, because we need it for git now
  mkdir -p "$SOLOIST_DIR"
  cd "$SOLOIST_DIR/" || exit

  echo "INFO: Checking out sprout-wrap..."
  if [ -d sprout-wrap ]; then
    pushd sprout-wrap && git pull
  else
    git clone "$SPROUT_WRAP_URL"
    pushd sprout-wrap || exit
    git checkout "$SPROUT_WRAP_BRANCH"
  fi
fi

# Non-Chef Homebrew install
check_trace_state
turn_trace_off

export HOMEBREW_NO_INSTALL_FROM_API=1

if [ -x "$(command -v brew)" ] && brew --version; then
  :
else
  echo | /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALLER_URL")"
fi
turn_trace_on_if_was_on

if [ "$machine" == "arm64" ]; then
  export _HOMEBREW_PREFIX=/opt/homebrew
  export _HOMEBREW_OPT=${_HOMEBREW_PREFIX}/opt ## TODO: Verify which path the Cellar symlinks live in
  export PATH="/opt/homebrew/bin:${PATH}"
else
  ## TODO: What have they changed it to now?
  export _HOMEBREW_PREFIX=/usr/local
  # export _HOMEBREW_PREFIX=/usr/local/homebrew
  export _HOMEBREW_OPT=/usr/local/opt
  #export PATH="/usr/local/homebrew/bin:${PATH}"
  export PATH="/usr/local/bin:${PATH}"
fi

brew_install_rvm_libs
# Install Chef Workstation SDK via Brewfile
[ -x "$(command -v brew)" ] && brew tap --force homebrew/cask
[ -x "$(command -v brew)" ] && brew bundle install

if [[ $use_system_ruby == "1" ]]; then
  # We should never get here unless script has been edited by hand
  # User probably knows what they're doing but warn anyway
  echo "WARN: Using macOS system Ruby is not recommended!" >&2
  echo "WARN: Updating system bundler gem will modify stock macOS system files!" >&2
  if [[ "${override_use_system_ruby_prompt:-0}" != '1' ]]; then
    # shellcheck disable=SC2162
    read -p 'Are you sure you want to continue and use macOS System Ruby? [y/N]: ' -d $'\n' use_system_ruby_answer
    use_system_ruby_answer="$(echo -n "$use_system_ruby_answer" | tr '[:upper:]' '[:lower:]')"
    if [[ "$use_system_ruby_answer" != 'y' ]]; then
      errorout "Abort modifying System Ruby! Exiting..."
    else
      USE_SUDO='sudo'
    fi
  fi

  echo "INFO: Updating system bundler gem!" >&2
  [ -x "/usr/local/bin/bundle" ] || $USE_SUDO gem install -n /usr/local/bin bundler
  $USE_SUDO gem update -n /usr/local/bin --system

elif [[ "$CI" != 'true' ]]; then
  USE_SUDO=''
  install_rvm
else
  install_rvm
  # Just update bundler in CI
  gem update --system
fi

# Use rvm as a function within subshell
# Same as above: avoids EXIT trap from `cd` override, and to ensure bundler
# installs to locked Ruby + gemset.
(
  turn_trace_off
  source_rvm
  # We need bundler in vendor path too
  # check_sprout_locked_ruby_versions && rvm use "ruby-${sprout_ruby_version}"@"${sprout_ruby_gemset}"
  rvm_use_locked_ruby_version@gemset
  turn_trace_on_if_was_on
  if ! bundle list | grep -q "bundler.*${sprout_bundler_ver}"; then
    bundle exec gem install --default "bundler:${sprout_bundler_ver}"
  fi

  # TODO: Fix last chicken-egg issues
  echo "WARN: Please set up github SSH / HTTPS credentials for Chef Homebrew recipes to work!"

  # Bundle install soloist + gems
  if ! bundle check > /dev/null 2>&1; then
    bundle config set --local path 'vendor/bundle'
    bundle config set --local without 'development'
    export BUNDLER_WITHOUT="development" # Redundant, but could be useful for CI
    bundle install
  fi

  if [[ -n "$SOLOISTRC" && "$SOLOISTRC" != 'soloistrc' ]]; then
    echo "INFO: Custom $SOLOISTRC passed: $SOLOISTRC"
    if [[ -f "$SOLOISTRC" && "$(readlink soloistrc)" != "$SOLOISTRC" ]]; then
      echo "WARN: default soloistrc file is NOT symlinked to $SOLOISTRC"
      echo "WARN: Forcing re-link: soloistrc -> $SOLOISTRC"
      ln -sf "$SOLOISTRC" soloistrc
    fi
  fi

  # Auto-accept Chef license for non-interactive automation
  export CHEF_LICENSE=accept
  # Now we provision with chef, et voilá!
  # Node, it's time you grew up to who you want to be
  caffeinate -dimsu bundle exec soloist || errorout "Soloist provisioning failed!"
)

turn_trace_off ## RVM noisy on builtin: popd
# shellcheck disable=SC2164
popd && popd

exit
