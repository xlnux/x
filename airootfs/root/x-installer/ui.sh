#!/usr/bin/env bash

# UI del instalador x: usa gum si esta disponible y cae a prompts de texto
# simples en caso contrario (TTY sin gum o tests no interactivos).

have_gum() {
    command -v gum >/dev/null 2>&1
}

ask_value() {
    local var="$1" prompt="$2" value
    if have_gum; then
        value="$(gum input --placeholder "$prompt")" || value=""
    else
        printf '%s: ' "$prompt"
        IFS= read -r value
    fi
    printf -v "$var" '%s' "$value"
}

ask_password() {
    local var="$1" prompt="$2" value
    if have_gum; then
        value="$(gum input --password --placeholder "$prompt")" || value=""
    else
        printf '%s: ' "$prompt"
        IFS= read -r -s value
        printf '\n'
    fi
    printf -v "$var" '%s' "$value"
}

select_one() {
    local var="$1" prompt="$2"
    shift 2
    local items=("$@") value
    if have_gum; then
        value="$(printf '%s\n' "${items[@]}" | gum choose --header "$prompt")" || value=""
    else
        local i
        printf '%s\n' "$prompt"
        for i in "${!items[@]}"; do
            printf '  %d) %s\n' "$((i + 1))" "${items[$i]}"
        done
        printf 'elige (1-%d): ' "${#items[@]}"
        IFS= read -r sel
        sel="${sel:-1}"
        if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#items[@]} )); then
            value="${items[$((sel - 1))]}"
        fi
    fi
    printf -v "$var" '%s' "$value"
}

confirm_yes() {
    local prompt="$1" default="${2:-n}"
    if have_gum; then
        gum confirm --default=false "$prompt"
    else
        local resp
        printf '%s [s/N]: ' "$prompt"
        IFS= read -r resp
        [[ "$resp" =~ ^[sSyY] ]]
    fi
}
