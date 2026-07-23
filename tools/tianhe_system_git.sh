#!/usr/bin/env bash

# Tianhe wrapper for the system Git. The interactive scientific environment
# injects Spack/Conda libraries through LD_LIBRARY_PATH; those libraries are
# incompatible with the system libssh used by git-remote-https.
set -Eeuo pipefail

unset LD_LIBRARY_PATH
unset LD_PRELOAD
export PATH=/usr/bin:/bin
exec /usr/bin/git "$@"
