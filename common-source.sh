# SOURCE ME - DO NOT RUN


# == IMPORTANT ==
# Require Environmental Variables
# WORKDIR  -- working directory where all the temporary files created duing the build will be.
# DISTDIR  -- distribution directory where all the result files are stored after the building is completed.
# BUILDLOG -- the build log.

# Create working and distribution directories
mkdir -p "$WORKDIR" "$DISTDIR"

# Create the directory for the build log if needed
mkdir -p "$(dirname "$BUILDLOG")"
touch "$BUILDLOG"



# == Common Initialize FUMCTION ==

common-init() {
  # Load version information
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$SCRIPT_DIR/versions.env"


  QUICK_BUILD=${QUICK_BUILD:-false}

  # Default all build targets to false
  LINUX_32=false
  LINUX_64=false
  WINDOWS_32=false
  WINDOWS_64=false
  MACOSX86=false
  MACOSARM64=false
  WASM32=false
  WASM64=false
  LLVMIR32=false
  LLVMIR64=false
  BUILD_CLANG=false
  BUILD_WINDOWS=false
  BUILD_WASM=false
  BUILD_LLVMIR=false

  UNAME_S=$(uname -s)
  UNAME_M=$(uname -m)

  if [[ $QUICK_BUILD == true ]]; then
    case "$UNAME_S" in
      Linux)
        BUILD_CLANG=true
        case "$UNAME_M" in
          x86_64)      LINUX_64=true ;;
          i686 | i386) LINUX_32=true ;;
          *)           echo "Unsupported Linux architecture: $UNAME_M"; exit 1 ;;
        esac ;;
      Darwin)
        BUILD_CLANG=true
        case "$UNAME_M" in
          x86_64) MACOSX86=true    ; LINUX_64=true ;;
          arm64)  MACOSARM64=true  ; LINUX_64=true ;;
          *)      echo "Unsupported macOS architecture: $UNAME_M"; exit 1 ;;
        esac ;;
      MINGW*|MSYS*|CYGWIN*)
        BUILD_CLANG=true
        BUILD_WINDOWS=true
        case "$UNAME_M" in
          x86_64)      WINDOWS_64=true ; LINUX_64=true ;;
          i686 | i386) WINDOWS_32=true ; LINUX_32=true ;;
          *)           echo "Unsupported Windows architecture: $UNAME_M"; exit 1 ;;
        esac ;;
      *) echo "Unsupported OS: $UNAME_S"; exit 1 ;;
    esac
  else
    # Full build: enable all targets
    LINUX_32=true
    LINUX_64=true
    WINDOWS_32=true
    WINDOWS_64=true
    MACOSX86=true
    MACOSARM64=true
    WASM32=true
    WASM64=true
    LLVMIR32=true
    LLVMIR64=true
    BUILD_CLANG=true
    BUILD_WINDOWS=true
    BUILD_WASM=true
    BUILD_LLVMIR=true
  fi
}



# == PRITNING FUNCTIONS ==

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


print() {
  echo "$@" | tee -a "$BUILDLOG"
}

print_section() {
  echo -e "\n${YELLOW}=== $1 ===${NC}\n"
  echo ""           >> "$BUILDLOG"
  echo "=== $1 ===" >> "$BUILDLOG"
  echo ""           >> "$BUILDLOG"
}

print_status() {
  echo -e "\n${BLUE}$1${NC}"
  echo ""   >> "$BUILDLOG"
  echo "$1" >> "$BUILDLOG"
}
exit_with_error() {
  echo -e "${RED}ERROR: $1${NC}"
  echo "ERROR: $1" >> "$BUILDLOG"
  exit 1
}



# == BUILD FUNCTIONS ==

check_versions_match_changelog() {
  local changelog="$SCRIPT_DIR/CHANGELOG.md"

  if [[ ! -f "$changelog" ]]; then
    echo "❌ CHANGELOG.md not found!"
    exit 1
  fi

  # Extract latest version block (assumes newest is at top)
  local block
  block=$(awk '
    /^## \[/ { if (found) exit; found=1 }
    found { print }
  ' "$changelog")

  # Extract version values
  local log_clang log_icu log_emsdk
  log_clang=$(echo "$block" | grep 'CLANG_VERSION=' | cut -d '=' -f2)
  log_icu=$(  echo "$block" | grep 'ICU_VERSION='   | cut -d '=' -f2)
  log_emsdk=$(echo "$block" | grep 'ENSDK_VERSION=' | cut -d '=' -f2)

  # Validate
  local fail=0
  [[ "$log_clang" != "$CLANG_VERSION" ]] && { echo "❌ CLANG_VERSION mismatch (CHANGELOG=$log_clang, env=$CLANG_VERSION)"; fail=1; }
  [[ "$log_icu" != "$ICU_VERSION" ]]     && { echo "❌ ICU_VERSION mismatch (CHANGELOG=$log_icu, env=$ICU_VERSION)"; fail=1; }
  [[ "$log_emsdk" != "$ENSDK_VERSION" ]] && { echo "❌ ENSDK_VERSION mismatch (CHANGELOG=$log_emsdk, env=$ENSDK_VERSION)"; fail=1; }

  [[ $fail -eq 1 ]] && {
    echo "❌ Version mismatch detected. Please update CHANGELOG.md or versions.env"
    exit 1
  }

  echo "✅ Versions match CHANGELOG.md"
}

show-build-matrix() {
  VERBOSE=${VERBOSE:-true}
  if [[ $VERBOSE == true ]]; then
    row() {
      NAME="$1"
      VALUE32="$2"
      VALUE64="$3"
      local ICON32 ICON64
      if [[ $VALUE32 == true ]]; then
          ICON32_RAW='✅'
          ICON32_CLR='\033[0;32m✅\033[0m'
      else
          ICON32_RAW='❌'
          ICON32_CLR='\033[0;31m❌\033[0m'
      fi
      if [[ $VALUE64 == true ]]; then
          ICON64_RAW='✅'
          ICON64_CLR='\033[0;32m✅\033[0m'
      else
          ICON64_RAW='❌'
          ICON64_CLR='\033[0;31m❌\033[0m'
      fi
      # Print aligned (raw) to log
      printf '%-10s %-2s  %-2s\n' "$NAME" "$ICON32_RAW" "$ICON64_RAW" | tee -a "$BUILDLOG"
      # If interactive terminal, overwrite with colored for terminal only
      if [ -t 1 ]; then
          tput cuu1; tput el
          printf '%-10s %-2b  %-2b\n' "$NAME" "$ICON32_CLR" "$ICON64_CLR"
      fi
    }

    # Print build matrix as a table with three columns: Target, 32, 64
    printf "\n\033[1m%-10s %-3s %-3s\033[0m\n" "Target" "32" "64" | tee -a "$BUILDLOG"
    row "LINUX"     "$LINUX_32"   "$LINUX_64"   | tee -a "$BUILDLOG"
    row "WINDOWS"   "$WINDOWS_32" "$WINDOWS_64" | tee -a "$BUILDLOG"
    row "MACOS"     "$MACOSX86"   "$MACOSARM64" | tee -a "$BUILDLOG"
    row "WASM"      "$WASM32"     "$WASM64"     | tee -a "$BUILDLOG"
    row "LLVMIR"    "$LLVMIR32"   "$LLVMIR64"   | tee -a "$BUILDLOG"
    print "" | tee -a "$BUILDLOG"
    
    # Print summary with colored check/cross
    summary_icon() {
      if [[ $1 == true ]]; then
        echo -e '\033[0;32m✅\033[0m'
      else
        echo -e '\033[0;31m❌\033[0m'
      fi
    }

    printf "%-13s %b\n" "BUILD_CLANG"   "$(summary_icon $BUILD_CLANG)"   | tee -a "$BUILDLOG"
    printf "%-13s %b\n" "BUILD_WINDOWS" "$(summary_icon $BUILD_WINDOWS)" | tee -a "$BUILDLOG"
    printf "%-13s %b\n" "BUILD_WASM"    "$(summary_icon $BUILD_WASM)"    | tee -a "$BUILDLOG"
    printf "%-13s %b\n" "BUILD_LLVMIR"  "$(summary_icon $BUILD_LLVMIR)"  | tee -a "$BUILDLOG"
    print "" | tee -a "$BUILDLOG"
  fi
}
