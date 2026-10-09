# 快速返回上層
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

alias -- -='cd -'
alias home='cd "${HOME}"'
alias root='cd /'

# 讓 ls 預設帶有顏色、人性化檔案大小與詳細資訊
#alias ls="ls --color=auto"
#alias ll="ls -lh --color=auto"
#alias la="ls -A --color=auto"
#alias lla="ls -lah --color=auto"

# 安全防護（刪除、搬移檔案時跳出確認提示）
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# 自動建立多層目錄
alias mkdir="mkdir -pv"

alias gohome='cd ~'
#alias cd..='cd ..'
alias .file='cd ~/.dotfiles'

# Better ls
alias ls='eza -la --icons --git --color=auto'

# Detailed listing
alias ll='eza -lh --icons --git --color=auto'

# Detailed listing including hidden files
alias la='eza -lAh --icons --git --color=auto'

# Detailed listing including hidden files by tree
alias lat='eza -lah --icons --git --tree -L 2 --ignore-glob=".git|.cache|node_modules|.orbstack"'
alias lt='lat' #'eza -lah --icons --git --tree -L 2'

# Tree view
alias tree='eza --tree --icons -L 1'
alias ld='ls -ld -- */ 2>/dev/null'
alias tree2='eza -lah --icons --git --tree -L 2'
alias tree3='eza -lah --icons --git --tree -L 3'

# Reuse ls completions for eza (avoids defining a separate completion function)
# Only run compdef if we are currently inside Zsh
if [ -n "$ZSH_VERSION" ]; then
    compdef eza=ls
fi

# tldr
alias manx='tldr'
#alias manz="tldr --list | fzf --no-sort --preview 'tldr {}'"
alias manz='(echo -e "git\ncurl\ntar\ngrep\nfind\nssh\ndocker\ncat\nls\nmv"; tldr --list) | awk "!awk_built[\$0]++" | fzf --no-sort --preview "tldr {}"'

brewinfo() {
    brew ls | fzf --preview 'brew info {}; echo -e "\n================ DEPENDENCIES ================\n"; HOMEBREW_NO_ENV_HINTS=1 brew deps --tree {}' --preview-window=right:60%
}


# Better cat
alias cat='bat'

# =========================================================
# Core utilities
# =========================================================

alias grep='rg --color=auto'
alias diff='diff --color=auto'
#alias df='df -h'

# =========================================================
# Navigation
# =========================================================

lf() { # zsh follow lf navigation
    tmp=$(mktemp)
    command lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir=$(cat "$tmp")
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
    fi
}

mkcd() {
    if [ "$#" -ne 1 ]; then
        printf 'Usage: mkcd <directory>\n' >&2
        return 2
    fi

    mkdir -p -- "$1" && cd -- "$1"
}

croot() {
    local root

    root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        printf 'Not inside a Git repository.\n' >&2
        return 1
    }

    cd -- "$root"
}

up() {
    local levels="${1:-1}"
    local destination=""

    case "$levels" in
        ''|*[!0-9]*)
            printf 'Usage: up [positive-integer]\n' >&2
            return 2
            ;;
    esac

    while [ "$levels" -gt 0 ]; do
        destination="../${destination}"
        levels=$((levels - 1))
    done

    cd -- "$destination"
}

# =========================================================
# Editor
# =========================================================

alias vim='nvim'

# =========================================================
# Git
# =========================================================

alias glog='PAGER="less -F -X" git log'
# -F quit if one screen, -X no clear on exit
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
alias gh.='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

#alias gh="git"
alias gh="git status"
alias gs='git status --short --branch'
alias ghad="git add"
alias ghaa="git add --all"
alias ghcm="git commit -m"
alias ghco="git checkout"
alias ghcb="git checkout -b"
alias ghbr="git branch"
alias ghpl="git pull"
alias ghph="git push"
alias ghdf="git diff"

# 漂亮的圖表化 Git Log
alias glog="git log --oneline --decorate --graph --color"


# =========================================================
# Video
# =========================================================

alias stream='mpv av://v4l2:/dev/video4 --fullscreen --demuxer-lavf-o=input_format=mjpeg,framerate=30 --profile=low-latency --untimed'

alias df='duf'

# 全文字即時模糊搜尋，Enter 直接用 nvim 開啟
fif() {
  rm -f /tmp/fzf.rg
  # 利用 ripgrep 搜尋，並用 fzf 互動篩選
  local file_line=$(rg --color=always --line-number --no-heading --smart-case "${*:-}" | \
    fzf --ansi \
        --color "hl:-1:underline,hl+:-1:underline:reverse" \
        --delimiter : \
        --preview 'bat --color=always --highlight-line {2} --style=numbers,changes {1}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3')
  
  # 如果有選中檔案，直接用 nvim 開啟並跳到該行數
  if [ -n "$file_line" ]; then
    local file=$(echo "$file_line" | cut -d: -f1)
    local line=$(echo "$file_line" | cut -d: -f2)
    nvim "+$line" "$file"
  fi
}

# 智慧跳轉 + eza 目錄結構即時預覽
alias cx='zoxide query -l | fzf --reverse --height 50% --prompt="Go To  : " \
  --preview "eza --tree --level=2 --color=always --icons=always {}" \
  --preview-window "right:50%:border-left" \
  --bind "enter:accept"'


# 打 killpro，打字搜尋進程名稱，按下 Enter 直接強制結束 (kill -9)
alias killpro="ps -ef | fzf --header '選擇要強制結束的進程' --height 40% --reverse | awk '{print \$2}' | xargs kill -9"

# 找目前目錄下大於 50MB 的檔案並線上檢視
alias findbig="fd --type f --size +50M | fzf --preview 'bat --color=always --line-range :100 {}' --header '選中的檔案路徑會直接印在命令列'"

# 找目前目錄下大於 1GB 的檔案並線上檢視
alias findbigger="fd --type f --size +1G | fzf --preview 'bat --color=always --line-range :100 {}' --header '選中的檔案路徑會直接印在命令列'"

#alias findbig="fd --type f --size +50M --exec ls -lh {} \; | fzf --delimiter='(?<=\d:\d\d) ' --with-nth=2 --preview 'bat --color=always --line-range :100 {2}' --header '選中的檔案路徑會直接印在命令列' | awk '{print substr(\$0, index(\$0, \$2))}'"

#alias findbig="fd --type f --size +50M --exec stat -f '%z%t%N' {} \; | awk -F'\t' '{ size=\$1; gb=1024*1024*1024; mb=1024*1024; if (size>=gb) printf \"%dG\t%s\n\", size/gb, \$2; else printf \"%dM\t%s\n\", size/mb, \$2 }' | fzf --delimiter='\t' --nth=1.. --preview 'bat --color=always --line-range :100 {2}' --header '提示：輸入 [5-9][0-9]M 找 50-99M；輸入 [1-9]G 找 1G以上' | cut -f2-"


findgt() {
    # 如果使用者沒有輸入參數（直接打 findbig），預設帶入 50M
    local size="${1:-50M}"

    # 執行 fd 並呼叫 stat 格式化輸出檔案大小與路徑 (以 Tab 鍵分隔)
    fd --type f --size "+$size" --exec stat -f '%z%t%N' {} \; 2>/dev/null |
    awk -F'\t' '{
        size=$1; gb=1024*1024*1024; mb=1024*1024;
        if (size>=gb) printf "%.1fG\t%s\n", size/gb, $2;
        else printf "%.0fM\t%s\n", size/mb, $2
    }' |
    fzf --delimiter='\t' \
        --with-nth=1.. \
        --preview 'bat --color=always --line-range :100 {2}' \
        --header "目前篩選大於 $size 的檔案。選中的檔案路徑會直接印在命令列" \
        | cut -f2-
}



# 快速重新載入 Shell 設定（免重開終端機）
alias reload="source ~/.zshrc"  # Bash 使用者請改為 ~/.bashrc

# 清理終端機畫面
alias c="clear"
alias cls='clear; ls'
alias reload='source "${HOME}/.${SHELL##*/}rc"'
alias path='printf "%s\n" "${PATH//:/$'\''\n'\''}"'
alias now='date "+%Y-%m-%d %H:%M:%S"'
alias week='date "+%V"'
alias shellinfo='printf "Shell: %s\nVersion: %s\n" "$SHELL" "$BASH_VERSION"'

reload-sh() {
    local config

    case "${SHELL##*/}" in
        bash) config="${HOME}/.bashrc" ;;
        zsh)  config="${HOME}/.zshrc" ;;
        *)
            printf 'Unsupported shell: %s\n' "$SHELL" >&2
            return 1
            ;;
    esac

    if [ ! -f "$config" ]; then
        printf 'Configuration file not found: %s\n' "$config" >&2
        return 1
    fi

    # shellcheck disable=SC1090
    source "$config"
}

# 便捷查看公開 IP
alias myip="curl icanhazip.com"

# 快速編輯設定檔（請自行替換成 code, vim, nano 等編輯器）
alias zshconfig="cot ~/.zshrc"
alias bashconfig="cot ~/.bashrc"

#Docker
alias d="docker"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
alias dimages="docker images"
alias ddc="docker-compose"

# Return success when a command is installed.
has() {
    command -v "$1" >/dev/null 2>&1
}

# Operating-system detection.
case "$(uname -s)" in
    Darwin)
        export AWESOME_ALIAS_OS="macos"
        ;;
    Linux)
        export AWESOME_ALIAS_OS="linux"
        ;;
    *)
        export AWESOME_ALIAS_OS="other"
        ;;
esac

extract() {
    if [ "$#" -ne 1 ]; then
        printf 'Usage: extract <archive>\n' >&2
        return 2
    fi

    local archive="$1"

    if [ ! -f "$archive" ]; then
        printf 'File not found: %s\n' "$archive" >&2
        return 1
    fi

    case "$archive" in
        *.tar.bz2|*.tbz2) tar -xjf "$archive" ;;
        *.tar.gz|*.tgz)   tar -xzf "$archive" ;;
        *.tar.xz|*.txz)   tar -xJf "$archive" ;;
        *.tar.zst)        tar --zstd -xf "$archive" ;;
        *.tar)            tar -xf "$archive" ;;
        *.bz2)            bunzip2 "$archive" ;;
        *.gz)             gunzip "$archive" ;;
        *.xz)             unxz "$archive" ;;
        *.zip)            unzip "$archive" ;;
        *.7z)             7z x "$archive" ;;
        *.rar)            unrar x "$archive" ;;
        *)
            printf 'Unsupported archive format: %s\n' "$archive" >&2
            return 1
            ;;
    esac
}

#Calculator and Encoding
alias calc='bc -l'
alias sha256='sha256sum'
alias b64e='base64'
alias urlencode='python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))"'
sha256file() {
    if [ "$#" -ne 1 ]; then
        printf 'Usage: sha256file <file>\n' >&2
        return 2
    fi

    if has sha256sum; then
        sha256sum -- "$1"
    elif has shasum; then
        shasum -a 256 -- "$1"
    else
        printf 'Neither sha256sum nor shasum is installed.\n' >&2
        return 1
    fi
}






