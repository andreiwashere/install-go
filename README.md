# Welcome to `igo`

The project `install-go` or `igo` is a set of helper scripts written in Bash and Go that assist in developers' everyday interactions with Golang development on Linux. It installs on your user profile and does not require sudo permissions of any kind. The directories that it will download and install will be stored to your home directory in the `~/go` path. These scripts were built to serve all.

With the use of shims, we've enabled you the ability to create local overrides to your `sgo <VERSION>` switching of multiple `igo <VERSION>` installations on your system once you complete the installation of this set of scripts. When multiple versions of Go are installed, you can override a local project's version of Go by populating the `.go_version` file with the version, such as `1.21.0` or `1.20.7`.

# Overview

This project consists of 5 programs, `installgo` aka `igo`, `switchgo` aka `sgo`. 

| Name | Binary | Usage |
|------|--------|-------|
| **Installer** | `igo` | `igo VERSION [ GOOS ] [ GOARCH ]` |
| **Switcher** | `sgo` | `sgo list\|VERSION` |
| **Backups** | `bgo` | `bgo` |
| **Uninstaller** | `rgo` | `rgo list\|VERSION` |
| **Manifester** | `manifestdir` | `manifestdir --manifest-dir="${HOME}/go/manifests" --outpre="igo.txt" "${HOME}/go"` |
| **Go Shim** | `go` | `go ...` |
| **Go FMT Shim** | `gofmt` | `gofmt ...` |

All of of these programs are built upon the following structure:

```bash
$HOME/go
$HOME/go/backups
$HOME/go/bin -> $HOME/go/version/<version>/go/bin
$HOME/go/downloads
$HOME/manifests
$HOME/go/path -> $HOME/go/versions/<version>
$HOME/go/projects -> $HOME/workspace
$HOME/go/root -> $HOME/go/versions/<version>/go
$HOME/go/version
$HOME/go/scripts
$HOME/go/scripts/bgo -> $HOME/go/install-go/backup_go.sh
$HOME/go/scripts/functions.sh -> $HOME/go/install-go/functions.sh
$HOME/go/scripts/igo -> $HOME/go/install-go/install_go.sh
$HOME/go/scripts/manifestdir -> $HOME/go/install-go/manifestdir
$HOME/go/scripts/rgo -> $HOME/go/install-go/remove_go.sh
$HOME/go/scripts/sgo -> $HOME/go/install-go/switch_go.sh
$HOME/go/shims
$HOME/go/shims/go -> $HOME/go/install-go/shim_go.sh
$HOME/go/shims/gofmt -> $HOME/go/install-go/shims_go.sh
$HOME/go/versions
$HOME/go/versions/<version>
$HOME/go/versions/<version>/go
$HOME/go/versions/<version>/installer.lock
$HOME/go/versions/<version>/pkg
```

`igo` or **Install Go** will ensure this basic directory structure exists on your Linux system. 

> This script uses Bash 4 syntax, and will not work with the built-in bash provided on MacOS. You will be required to upgrade your Bash prior to using this script on MacOS. 

`sgo` or **Switch Go** on the other hand is the script that will let you manage multiple installations of Go on the same host. For example, lets say that you're working on a project, and its taking several months to a year or so, and Go keeps getting upgraded... well, with `switchgo` and `installgo` you can keep your system up to date. Let's use this example: 

```bash
# Let's say that you're working on a project...
# It's October 2021...
igo 1.17.3
# You're working on your project...
cd /home/andreiwashere/go/projects/exampleProject
cat go.mod
go mod tidy
go run main.go
go build .
# And now its November 2021... and 1.17.4 comes out...
igo 1.17.4
sgo 1.17.4
go build .
# December rolls around... and 1.17.5 comes out...
igo 1.17.5
sgo 1.17.5
go build .
# Crap... doesn't seem to work just yet... let me go back...
sgo 1.17.4
go build .
# Okay, things work, let me get my stuff committed and safe...
sgo 1.17.5
go build .
# Looks good! Everything builds just fine now.
# Hrmm... will my project build with Go 1.16.12?
igo 1.16.12
sgo 1.16.12
go build .
# Oh cool... nothing works! LOL
sgo 1.17.5
go build .
# Ahh everything works well now!
```

This script was built because this is reality... and being able to switch between Go versions is super useful and the portability of Go is incredible. The mechanisms of how this works could easily allow you to add a cron scheduled job that takes regular backups of your `/go` directory, which could be useful in historical circumstances. Meaning, if you have a snapshot of the `/go` directory taken every single week.

# Usage

## `igo` Examples

To install the latest (1.21.0) version of Go: 

```bash
igo 1.21.0 linux amd64
```

To install the previous (1.20.5) version of Go: 

```bash
igo 1.20.5 linux amd64
```

## `switchgo` Examples

To switch from Go 1.21.0 to Go 1.20.5:

```bash
sgo 1.20.5
```

To switch from Go 1.20.5 to Go 1.21.0:

 ```bash
sgo 1.21.0
 ```

## `rgo` Examples

To uninstall Go 1.17.12 from your system:

```bash
rgo 1.17.12
```

# Installation 

## All In One

```bash
sh <(curl https://raw.githubusercontent.com/andreiwashere/install-go/main/install.sh -L)
```

OR

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/install.sh < /dev/null > /dev/null 2>&1
[ -f install.sh ] && chmod +x install.sh || echo "Failed to download install.sh"
./install.sh
```

## Individual Components

### `igo`

**Usage**: `igo VERSION GOOS GOARCH`

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/install_go.sh < /dev/null > /dev/null 2>&1
[ -f install_go.sh ] && chmod +x install_go.sh || echo "Failed to download install_go.sh"
[ -f "${HOME}/bin/igo" ] && echo "Already installed!" || { mkdir -p "${HOME}/bin" && [ -d "${HOME}/bin" ] && mv install_go.sh "${HOME}/bin/igo" && [ -f "${HOME}/bin/igo" ] && echo "igo installed at ${HOME}/bin/igo" || echo "Installation of igo failed"; }
igo
```

This installs Go to `${HOME}/go/versions/<VERSION>/go` and sets up your ENV to: 

| ENV | Value | 
|-----|-------|
| `GOROOT` | `~/go/root` |
| `GOPATH` | `~/go/path` |
| `GOBIN` | `~/go/bin` |
| `GOOS` | argument 2 `GOOS` |
| `GOARCH` | argument 3 `GOARCH` |
| `GOSCRIPTS` | `~/go/scripts` |
| `GOSHIMS` | `~/go/shims` |

### `sgo`

**Usage**: `sgo [ list | <version> ]`

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/switch_go.sh < /dev/null > /dev/null 2>&1
[ -f switch_go.sh ] && chmod +x switch_go.sh || echo "Failed to download switch_go.sh"
[ -f "${HOME}/bin/sgo" ] && echo "Already installed!" || { mkdir -p "${HOME}/bin" && [ -d "${HOME}/bin" ] && mv switch_go.sh "${HOME}/bin/sgo" && [ -f "${HOME}/bin/sgo" ] && echo "sgo installed at ${HOME}/bin/sgo" || echo "Installation of sgo failed"; }
sgo list
```

This updates the symlinks inside of `$HOME/go` for `GOBIN`, `GOPATH`, and `GOROOT` automatically and supports `$HOME/.bashrc` and `$HOME/.zshrc` shells for export control of the environment variables.

### `bgo`

**Usage**: `bgo`

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/backup_go.sh < /dev/null > /dev/null 2>&1
[ -f backup_go.sh ] && chmod +x backup_go.sh || echo "Failed to download backup_go.sh"
[ -f "${HOME}/bin/bgo" ] && echo "Already installed!" || { mkdir -p "${HOME}/bin" && [ -d "${HOME}/bin" ] && mv backup_go.sh "${HOME}/bin/bgo" && [ -f "${HOME}/bin/bgo" ] && echo "bgo installed at ${HOME}/bin/bgo" || echo "Installation of bgo failed"; }
```

## `rgo`

**Usage**: `rgo [ list | VERSION ]`

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/remove_go.sh < /dev/null > /dev/null 2>&1
[ -f remove_go.sh ] && chmod +x remove_go.sh || echo "Failed to download remove_go.sh"
[ -f "${HOME}/bin/rgo" ] && echo "Already installed!" || { mkdir -p "${HOME}/bin" && [ -d "${HOME}/bin" ] && mv remove_go.sh "${HOME}/bin/rgo" && [ -f "${HOME}/bin/rgo" ] && echo "rgo installed at ${HOME}/bin/rgo" || echo "Installation of rgo failed"; }
```

This script will create a backup of the `$HOME/go` directory and save the backup inside of `$HOME/go/backups`. 

**NOTE**: _The backups stored inside `$HOME/go/backups` will be omitted from future `bgo` backups created._

# License

This project is Open Source under the MIT License.
