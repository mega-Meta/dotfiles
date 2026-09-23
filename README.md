# Managing dotfiles using GNU Stow on your macOS

## Usage

0. Install stow (`brew install stow`)
0. Clone this repo with git
0. cd into this repo
0. Go through `git_setup.sh`
0. Go through `setup.sh`


## Resources

0. [Using GNU Stow to manage your dotfiles - Brandon Invergo](http://brandon.invergo.net/news/2012-05-26-using-gnu-stow-to-manage-your-dotfiles.html)
0. Some example dotfiles:
  0. https://github.com/xero/dotfiles
  1. https://github.com/omerxx/dotfiles

## Backstory
As part of my journey with various stacks and technologies, I've encountered a common challenge: managing numerous configuration scripts and "dotfiles" in my home directory. This can be frustrating, as we often find ourselves resorting to the cp and mv commands more frequently than necessary.

Though I had my own personal dotfiles repository before, I essentially followed the conventional practice of "copy-paste," similar to many others. For instance, if I needed to update my .zshrc file for some reason, I would first update my configuration on GitHub using the following commands:

### # opening dotfiles folder
$ cd ~/Developer/dotfiles 

# modify the .zshrc file
$ code .zshrc

# copy the new configuration to home directory
$ cp .zshrc ~/.zshrc

# finally, push the changes to main branch
$ git commit -a -m "modified .zshrc" && git push origin main
As you can see, this is a lot of commands for doing so little. However, there's a great workaround to all of this.

stow to the rescue!
In order to install GNU Stow on your Mac, you need to have Homebrew first. Install Homebrew and all of its dependencies using the following command:

$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
Once installed properly, we can install Stow using the following command:

$ brew install stow
That's it! You now have stow on your machine. Now let's set things up for maintenance.

Using stow:
First let's create a new .dotfiles folder in our home directory. This is where we'll start moving all of our preexisting configuration to. To do this, simply use:

$ mkdir .dotfiles && cd .dotfiles
This will create the directory and change your current working directory to it. Now, the primary way the stow command works is by using symbolic links so that you don't have to create them yourself. Let's start by moving a file and seeing how stow works.

Let's move the .bashrc file that I have in my home directory into the dotfiles folder:

# move to current folder
$ mv ~/.bashrc ~/.dotfiles/.bashrc
After executing these, we can use the stow command like this:

# symlink all files in current directory
$ stow .
Now if you open Finder and look at your .bashrc file, you'll notice that it has a little "shortcut" icon next to it, which means that macOS has successfully recognized it as a symbolic link to your file and it'll redirect to it.

 

You can manually move all of your needed files into the .dotfiles and once everything is in place, run stow . again to reflect your changes in the home directory.

Removing stowed files:
If you want to, for whatever reason, undo the actions done by executing the stow command, simply cd into the .dotfiles directory using your terminal and run this command:

# deleting all symlinks
$ stow -D .
This will clear up all the symlinks which were previously created by the program.

Managing and preserving dotfiles
The best thing about stow is that, it can be used alongside a .git folder, as well as the typical Git configuration you'd do on a repository. Which means, a stowed folder acts exactly like a Git repository and a mirror of your home directory if you want it to.

First, we'll create a new .stow-local-ignore file and open it in Vim (you can use your favorite text editor for this):

# create the file
$ touch .stow-local-ignore

# open it in vim
$ vi .stow-local-ignore
Now, paste the following content into the file:

\.DS_Store
Often times, macOS creates these .DS_Store files for indexing (e.g. for use in Spotlight Search), and these will keep popping up in your folders. In order to circumvent this situation, we can use the file Stow uses to identify locally ignored files in order to avoid unexpected symlinks.

Now that we've done some basic cleaning, it's time to create a Git repository to commit your changes for preservation:

# create new repository and branch
$ git init && git branch -M main

# commit your changes
$ git add --all && git commit -m "stowed!"
Later on, you can create a Git repository on your preferred version control platform (GitHub / GitLab) and add a remote to this local repository in order to backup the files.

## macOS 自動掃描家目錄（Home Directory）並將現有的設定檔轉換為符合 GNU Stow 格式的 .dotfiles 架構
在 macOS 上，要自動掃描家目錄（Home Directory）並將現有的設定檔轉換為符合 GNU Stow 格式的 .dotfiles 架構，你可以利用一個聰明的技巧：使用 GNU Stow 的 --adopt（收養）模式搭配簡單的 Shell 腳本。這樣做最安全且省時，因為你不需要自己寫複雜的 mv 搬移邏輯。Stow 會自動幫你把家目錄現有的實體檔案「吸進」.dotfiles 資料夾中，並在原處建立符號連結（Symbolic Links）。以下是完整的自動化實作步驟：
### 步驟一：
  建立 .dotfiles 目錄結構GNU Stow 是依據**子資料夾（套件包）**來決定對應結構的。首先，建立你想要管理的工具目錄（例如 zsh、git、config）：
```
bash
mkdir -p ~/.dotfiles/zsh ~/.dotfiles/git ~/.dotfiles/config/.config
```
  接著，在這些子資料夾中建立空白的目標檔案。這是因為 --adopt 必須在 .dotfiles 內看到同名檔案時，才會去「收養」家目錄下的實體檔案。bashtouch ~/.dotfiles/zsh/.zshrc   
```    
touch ~/.dotfiles/git/.gitconfig
```
  #如果你想管理整個 ~/.config/nvim 夾：
```
mkdir -p ~/.dotfiles/config/.config/nvim
```

### 步驟二：
  執行自動掃描與收養（--adopt）切換到你的 .dotfiles 目錄，並對指定的套件包執行 stow --adopt：bashcd ~/.dotfiles
```
# 讓 Stow 自動將家目錄的 .zshrc 和 .gitconfig 移入並建立連結
stow --adopt zsh git config
```
  💡 這步發生了什麼事？Stow 發現 ~/.dotfiles/zsh/.zshrc 是空的，而 ~/.zshrc 有內容。它會自動把你的實體 ~/.zshrc 剪下並貼上到 ~/.dotfiles/zsh/.zshrc，然後在 ~/.zshrc 原處生成一個指向 .dotfiles 的軟連結。

### 步驟三：
  用一鍵腳本自動化（進階全自動掃描）如果你有大量的設定檔，不想手動一個個 touch 建立空檔案，可以使用以下這段 自動掃描與搬移腳本。它可以幫你掃描家目錄下常見的設定檔，自動建立 Stow 目錄並搬移：請在家目錄建立一個 *$ ``` migrate_dotfiles.sh ``` $*，並貼上以下內容：
```
bash#!/usr/bin/env bash
  
# 定義你的 dotfiles 倉庫路徑
DOTFILES_DIR="$HOME/.dotfiles"
mkdir -p "$DOTFILES_DIR"

# 定義你想從家目錄自動掃描並轉移的檔案/資料夾清單
TARGETS=(
        ".zshrc"
        ".gitconfig"
        ".p10k.zsh"
        ".config/nvim"
        ".config/kitty"
    )

echo "🚀 開始自動掃描並轉換設定檔至 Stow 格式..."

for item in "${TARGETS[@]}"; do
  SRC="$HOME/$item"

# 檢查家目錄是否存在該檔案或資料夾，且目前還不是軟連結
if [ -e "$SRC" ] && [ ! -L "$SRC" ]; then
    echo "Found: $item"
    
    # 根據是通用家目錄檔案還是 .config 內的檔案來決定分組
    if [[ "$item" == .config/* ]]; then
        # 放入 config 套件包，並維持其內部目錄結構
        DEST_DIR="$DOTFILES_DIR/config/$(dirname "$item")"
        mkdir -p "$DEST_DIR"
        mv "$SRC" "$DEST_DIR/"
    else
        # 獨立打包，例如 .zshrc 放入 ~/.dotfiles/zsh/.zshrc
        # 這裡去除點號作為資料夾名稱（.zshrc -> zsh）
        PKG_NAME=$(echo "$item" | sed 's/^\.//')
        mkdir -p "$DOTFILES_DIR/$PKG_NAME"
        mv "$SRC" "$DOTFILES_DIR/$PKG_NAME/"
    fi
fi
done

echo "🔗 正在透過 GNU Stow 重新建立全域符號連結..."
cd "$DOTFILES_DIR" || exit
# 執行 stow，將所  有子資料夾（套件）連結回 $HOME
stow -v *

echo "✅ 轉換完成！現在你的設定檔已由 Stow 統一管理。"
```

如何執行：賦予執行權限：chmod +x migrate_dotfiles.sh執行腳本：./migrate_dotfiles.sh

## 步驟四：
  使用 Git 進行版本控制當 Stow 幫你把所有檔案集中到 .dotfiles 後，你就可以用 Git 將它上傳到 GitHub：bashcd ~/.dotfiles
```
git init
git add .
git commit -m "feat: initial backup of macos dotfiles via stow"
```

  未來如果你換了新 Mac，只需要在新電腦上安裝好 stow，複製你的倉庫並一鍵還原：
```      
bashbrew install stow
git clone <你的GitHub倉庫網址> ~/.dotfiles
cd ~/.dotfiles
stow *
```

