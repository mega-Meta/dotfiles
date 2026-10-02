# 解決 macOS 舊版 Bash 不支援 [[ -v MC_SID ]] 語法的崩潰問題
export MC_SID=""

# 原本的 Oh My Posh 啟動行
eval "$(oh-my-posh init bash)"


[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

if [ -f ~/aliases.zsh ]; then
  source ~/aliases.zsh
fi
