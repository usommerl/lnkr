__cache_directory() {
  local directory="${XDG_CACHE_HOME:-$HOME/.cache}/lnkr"
  mkdir -p "$directory" &>/dev/null && echo "$directory"
}

__latest_version() {
  local cache="$(__cache_directory)/latest"
  local cache_age="$(($(date +%s) - $(stat -c %Y "$cache" 2>&- || echo '0')))"
  if [ "$cache_age" -le 3600 ] && [ -z "${SKIP_LNKR_CACHE:-}" ]; then
    head -n 1 "$cache" 2>&-
  else
    local url='https://api.github.com/repos/usommerl/lnkr/releases/latest'
    local response="$( (curl -Lfs "$url") 2>&- || echo '' )"
    local tag_name="$(echo "$response" | grep 'tag_name' | cut -d '"' -f 4)"
    echo "$tag_name" | tee "$cache" 2>&-
  fi
}

__bootstrap() {
  local file='lnkr_lib.sh'
  local version="${LNKR_VERSION:-$(__latest_version)}"
  local library="$(__cache_directory)/${file/%.sh/_$version.sh}"
  local url="https://raw.githubusercontent.com/usommerl/lnkr/$version/$file"
  if [ ! -e "$library" ] || [ -n "${SKIP_LNKR_CACHE:-}" ]; then
    (curl -Lfso "$library" "$url") 2>&-
  fi
  [ -e "$library" ] && source "$library" "$@"
  echo 'Bootstrap failed'; exit 1
}

cd "$(dirname "$(readlink -f "$0")")" && __bootstrap "$@"
