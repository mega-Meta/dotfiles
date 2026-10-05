# 快速返回上層
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

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
alias tree='eza --tree --icons'

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

alias -- -='cd -'  # -- prevents - being parsed as a flag; cd - jumps to previous directory

lf() { # zsh follow lf navigation
    tmp=$(mktemp)
    command lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir=$(cat "$tmp")
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
    fi
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

alias gh="git"
alias gst="git status"
alias ga="git add"
alias gaa="git add --all"
alias gcmsg="git commit -m"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gb="git branch"
alias gl="git pull"
alias gp="git push"
alias gd="git diff"

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


# 快速重新載入 Shell 設定（免重開終端機）
alias reload="source ~/.zshrc"  # Bash 使用者請改為 ~/.bashrc

# 清理終端機畫面
alias c="clear"

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




