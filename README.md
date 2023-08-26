# Overview

| Script | Link | Info |
|--------|------|------|
| `install_go.sh` | [Source Code for install_go.sh](https://raw.githubusercontent.com/andreiwashere/install-go/main/install_go.sh) | Install `/go` on your system |
| `switch_go.sh` | [Source Code for switch_go.sh](https://raw.githubusercontent.com/andreiwashere/install-go/main/switch_go.sh) | Modifies `/go` active versions |

This project consists of two programs, `installgo` and `switchgo`. Both of these programs are built upon the following structure:

```bash
/go
/go/version
/go/root -> /go/versions/<version>/src
/go/path -> /go/versions/<version>
/go/bin -> /go/version/<version>/src/bin
/go/versions
/go/versions/<version>
/go/versions/<version>/src
/go/versions/<version>/pkg
```

`installgo` will ensure this basic directory structure exists on your Linux system. 

> This script uses Bash 4 syntax, and will not work with the built-in bash provided on MacOS. You will be required to upgrade your Bash prior to using this script on MacOS. While its unconventional to put a directory in the root volume of the system, and the root user is typically not used, this script may be modified to work without sudo, and instead just do a local install instead.

Go will be downloaded, extracted, and the proper symlinks will be applied to your host. The script will look inside your `/etc/profile`, `/root/.bashrc`, `/home/<any-user>/.bashrc` files for the `export GOOS=` or `export GOARCH=` or `export GOPATH=` or `export GOBIN-` or `export GOROOT=` to the active version of the install. Currently the script does not support `.zshrc`, even though `ZSH` is totally a better shell than `Bash`... but that's neither here nor there...

When running `installgo` for the first time, the version of Go you install with it will be the version the symlinks are bound to and will be the contents of the `/go/version` file. This version file is different from `go version` since this one is technically `cat /go/version`. 

To confirm that everything is working, the script installs 3 packages that are highly recommended. `go-password-generator` is a great resource for generating secure passwords on the command-line. Another useful tool is the `gotop` tool, which provides a really useful dashboard of information about the host. Finally the `bombardier` program is installed, which is a Go alternative to `ab`, an HTTP load testing content generator. Useful for testing an application under load. 

`switchgo` on the other hand is the script that will let you manage multiple installations of Go on the same host. For example, lets say that you're working on a project, and its taking several months to a year or so, and Go keeps getting upgraded... well, with `switchgo` and `installgo` you can keep your system up to date. Let's use this example: 

```bash
# Let's say that you're working on a project...
# It's October 2021...
sudo installgo 1.17.3
# You're working on your project...
cd /home/andreiwashere/workspace/project
cat go.mod
go mod tidy
go run apario.go
go build .
# And now its November 2021... and 1.17.4 comes out...
sudo installgo 1.17.4
sudo switchgo 1.17.4
go build .
# December rolls around... and 1.17.5 comes out...
sudo installgo 1.17.5
sudo switchgo 1.17.5
go build .
# Crap... doesn't seem to work just yet... let me go back...
sudo switchgo 1.17.4
go build .
# Okay, things work, let me get my stuff committed and safe...
sudo switchgo 1.17.5
go build .
# Looks good! Everything builds just fine now.
# Hrmm... will my project build with Go 1.16.12?
sudo installgo 1.16.12
sudo switchgo 1.16.12
go build .
# Oh cool... nothing works! LOL
sudo switchgo 1.17.5
go build .
# Ahh everything works well now!
```

This script was built because this is reality... and being able to switch between Go versions is super useful and the portability of Go is incredible. The mechanisms of how this works could easily allow you to add a cron scheduled job that takes regular backups of your `/go` directory, which could be useful in historical circumstances. Meaning, if you have a snapshot of the `/go` directory taken every single week.

# Usage

## `installgo` Examples

To install the latest (1.21.0) version of Go: 

```bash
sudo installgo 1.21.0 linux amd64
```

To install the previous (1.20.5) version of Go: 

```bash
sudo installgo 1.20.5 linux amd64
```

## `switchgo` Examples

To switch from Go 1.21.0 to Go 1.20.5:

```bash
sudo switchgo 1.20.5
```

To switch from Go 1.20.5 to Go 1.21.0:

 ```bash
 sudo switchgo 1.21.0
 ```

# Installation 

## Go Installer

**Usage**: `sudo installgo VERSION GOOS GOARCH`

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/install_go.sh < /dev/null > /dev/null 2>&1
[ -f install_go.sh ] && chmod +x install_go.sh || echo "Failed to download install_go.sh"
[ ! -f /usr/bin/installgo ] && sudo mv install_go.sh /usr/bin/installgo || echo "Already installed!"
source ~/.bashrc
sudo installgo
```

This installs Go to `/go/versions/<VERSION>/src` and sets up your ENV to: 

| ENV | Value | 
|-----|-------|
| `GOROOT` | `/go/root` |
| `GOPATH` | `/go/path` |
| `GOBIN` | `/go/bin` |
| `GOOS` | argument 2 `GOOS` |
| `GOARCH` | argument 3 `GOARCH` |

## Go Version Switcher

**Usage**: `sudo switchgo [ list | <version> ]`

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/switch_go.sh < /dev/null > /dev/null 2>&1
[ -f switch_go.sh ] && chmod +x switch_go.sh || echo "Failed to download switch_go.sh"
[ ! -f /usr/bin/switchgo ] && sudo mv switch_go.sh /usr/bin/switchgo || echo "Already installed!"
sudo switchgo list
```

Since this script installs your ENV vars in your `/etc/profile` and all `/home/*/.bashrc` and `/root/.bashrc` to the `/go/root`, `/go/path`, and `/go/bin` symlinks, we can use the `switchgo` command to update these symlinks and quickly switch between versions of Go.

## Backup Go

**Usage**: `sudo backupgo`

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/backup_go.sh < /dev/null > /dev/null 2>&1
[ -f backup_go.sh ] && chmod +x backup_go.sh || echo "Failed to download backup_go.sh"
[ ! -f /usr/bin/backupgo ] && sudo mv backup_go.sh /usr/bin/backupgo || echo "Already installed!"
sudo backupgo
```

This script will create the `/go/backups` directory and exclude itself, plus the symlinks during the backup process. The resuling file will be `/go/backups/go.YYYY.MM.DD.tar.gz` and it will contain everything installed through the `installgo` installations of Go. This can be extremely useful if you need to routinely keep a backup of your `GOROOT`, `GOPATH`, `GOBIN` with respect to time and your build automation expectations. Being able to "go back in time" (no pun intended - or was it?), meaning take your project, recover an old backup, and build the source code from that era of time with that era of packages... genius huh? 

# License

This project is Open Source under the MIT License.
