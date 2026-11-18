#!/data/data/com.termux/files/usr/bin/bash
# Android/bionic-compatible substitute for util-linux prlimit.
#
# REA launches external providers (binwalk, tshark, sigrok, WASM workers) as:
#   prlimit --as=<n>: --fsize=<n>: --core=0: --cpu=<n>: -- <command> <args...>
# On Android, bionic's CFI shadow mapping fails when an address-space cap is
# applied (linker_cfi.cpp: MapShadow CHECK 'p != MAP_FAILED'). This shim drops
# the resource-limit flags and execs the requested command directly.
#
# Trade-off: the hard CPU/address-space ceilings are NOT enforced here. Only
# use this for tools you trust, on files you trust. The REA operation's own
# size/coverage limits and Evidence limits still apply.
set -eu
args=()
saw_separator=0
for arg in "$@"; do
  if [ "$saw_separator" -eq 1 ]; then
    args+=("$arg")
    continue
  fi
  case "$arg" in
    --) saw_separator=1 ;;
    --as=*|--fsize=*|--core=*|--cpu=*|--nproc=*|--nofile=*|--stack=*|--data=*|--rss=*)
      ;; # intentionally dropped on Android/bionic
    *) args+=("$arg") ;;
  esac
done
if [ "${#args[@]}" -eq 0 ]; then
  echo "rea-android-prlimit: no command to execute" >&2
  exit 2
fi
exec "${args[@]}"
