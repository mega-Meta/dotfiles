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


未來如果你換了新 Mac，只需要在新電腦上安裝好 stow，複製你的倉庫並一鍵還原：bashbrew install stow
git clone <你的GitHub倉庫網址> ~/.dotfiles
cd ~/.dotfiles
stow *
