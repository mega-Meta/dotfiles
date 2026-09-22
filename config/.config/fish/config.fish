#config.fish
if status is-interactive
   set -U fish_greeting
   starship init fish | source
   #load fzf
   fzf --fish | source
   set -gx FZF_CTRL_T_OPTS " --walker-skip .git,node_modules,target"
   # zoxide
   zoxide init fish | source
   
   # 别名
   #alias ll "ls -lh"
   #alias la "ls -lAh"
   alias lsa "ls -A"
   # eza replace alias ls "eza"
   alias ll "eza -lh --git"
   alias la "eza -lAh --git"
   alias tree "eza --tree"
   alias br "brew"
   alias bri "brew install"
   alias brs "brew search"
   alias brr "brew uninstall"
   alias bru "brew upgrade"
   alias brl "brew list"
   alias bro "brew outdated"
   alias dkr "docker"
   alias py "python3"

   alias fish-load "source ~/.config/fish/config.fish"
   alias fish-def "open -t ~/.config/fish/config.fish"

   function cd
      builtin cd $argv; and ls
   end
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
