# =========================================================
# 1. 歷史紀錄基本設定
# =========================================================
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000

function clear_zsh_history { local HISTSIZE=0; }
function gitall {
    git add .
    if [ "$1" != "" ]
    then
        git commit -m "$1"
    else
        git commit -m update
    fi
    git push
}

# =========================================================
# 2. 環境變數與路徑 (Path)
# =========================================================
export PATH="/Users/user/.config/herd-lite/bin:$PATH"
export PHP_INI_SCAN_DIR="/Users/user/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"

# =========================================================
# 3. 補全系統初始化 (必須在載入別名與外掛之前)
# =========================================================
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# =========================================================
# 4. 第三方工具與外掛載入
# =========================================================
# 啟動 x-cmd
[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X"

# 啟動 Oh My Posh 提示字元
#eval "$(oh-my-posh init zsh)"
eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/mytheme.omp.json)"


# 載入自動建議外掛 (推薦改用 Homebrew 版本)
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# =========================================================
# zoxide (智慧 cd) 配置
# =========================================================
eval "$(zoxide init zsh)"
# 額外小技巧：把 cd 換成 zx (用 fzf 互動式挑選去過的資料夾)
alias cx='zi' 

# =========================================================
# fzf (模糊搜尋) 與 fd/bat 的聯動配置
# =========================================================
# 讓 fzf 預設使用超快的 fd 來找檔案，並自動忽略 .git 檔案
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# 🌟 超炫預覽功能：按下 Ctrl + T 找檔案時，右側會用 bat 自動秀出彩色檔案內容！
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,.cache
  --preview 'bat --style=numbers --color=always --line-range :500 {}'
  --bind 'ctrl-/:toggle-preview'"

# 🌟 歷史指令預覽：按下 Ctrl + R 找舊指令時，會用小視窗精美呈現
export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window down:3:wrap
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'" # Ctrl+Y 可以直接複製該指令


# 載入自訂別名檔案
source ~/aliases.zsh

# 強制讓輸入 bash 時，直接在當前視窗載入 Homebrew 最新版 Bash
bash() {
    if [ -f "/usr/local/bin/bash" ]; then
        exec /usr/local/bin/bash "$@"
    else
        exec /bin/bash "$@"
    fi
}

