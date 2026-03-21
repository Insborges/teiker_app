#!/bin/sh
set -euo pipefail

"$(cd "$(dirname "$0")/../.." && pwd)/ci_scripts/bootstrap_flutter.sh" ios