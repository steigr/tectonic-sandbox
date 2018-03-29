#!sh

panic() {
    echo "${@}"
    exit 1
}

_ensure_build() {
    if [[ -d "build" ]]; then
        return
    else
        mkdir -p "build"
    fi
}

_ensure_temp() {
    if [[ -d "$1" ]]; then
        return
    else
        mkdir -p "$1"
        trap 'rm -rf '"$1"'/' EXIT
        trap
    fi
}
