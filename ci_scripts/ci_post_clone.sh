#!/bin/sh
set -euo pipefail

"$(cd "$(dirname "$0")" && pwd)/bootstrap_flutter.sh" all
