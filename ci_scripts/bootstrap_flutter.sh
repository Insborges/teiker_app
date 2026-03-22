#!/bin/sh
set -euo pipefail

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.2}"
FLUTTER_DIR="${HOME}/flutter"

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    flutter config --no-analytics
    return
  fi

  if [ ! -d "${FLUTTER_DIR}" ]; then
    git clone https://github.com/flutter/flutter.git --depth 1 --branch "${FLUTTER_VERSION}" "${FLUTTER_DIR}"
  fi

  export PATH="${FLUTTER_DIR}/bin:${PATH}"
  flutter config --no-analytics
}

prepare_ios() {
  flutter precache --ios
  cd "${REPO_ROOT}"
  flutter pub get
  flutter build ios --release --no-codesign --config-only
  # Garante que o Profile.xcconfig está incluído no Release.xcconfig
  grep -qF 'Pods-Runner.profile.xcconfig' ios/Flutter/Release.xcconfig || \
    sed -i '' '1s/^/#include? "Pods\/Target Support Files\/Pods-Runner\/Pods-Runner.profile.xcconfig"\n/' ios/Flutter/Release.xcconfig
  cd ios
  pod install
}

prepare_macos() {
  flutter precache --macos
  cd "${REPO_ROOT}"
  flutter pub get
  flutter build macos --release --config-only
  # Garante que o Profile.xcconfig está incluído
  grep -qF 'Pods-Runner.profile.xcconfig' macos/Flutter/Flutter-Release.xcconfig || \
    sed -i '' '1s/^/#include? "Pods\/Target Support Files\/Pods-Runner\/Pods-Runner.profile.xcconfig"\n/' macos/Flutter/Flutter-Release.xcconfig
  cd macos
  pod install
}

main() {
  ensure_flutter

  case "${1:-all}" in
    ios)
      prepare_ios
      ;;
    macos)
      prepare_macos
      ;;
    all)
      prepare_ios
      prepare_macos
      ;;
    *)
      echo "Unknown target: ${1:-}" >&2
      exit 1
      ;;
  esac
}

main "$@"
