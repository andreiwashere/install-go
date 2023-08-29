# Welcome to `igo`

The project `install-go` or `igo` is a set of helper scripts written in Bash and Go that assist in developers' everyday interactions with Golang development on Linux. It installs on your user profile and does not require sudo permissions of any kind. The directories that it will download and install will be stored to your home directory in the `~/go` path. These scripts were built to serve all.

# Overview

| Script | Link | Info |
|--------|------|------|
| `install_go.sh` | [Source Code for install_go.sh](https://raw.githubusercontent.com/andreiwashere/install-go/main/install_go.sh) | Install `/go` on your system |
| `switch_go.sh` | [Source Code for switch_go.sh](https://raw.githubusercontent.com/andreiwashere/install-go/main/switch_go.sh) | Modifies `/go` active versions |
| `backup_go.sh` | [Source Code for backup_go.sh](https://raw.githubusercontent.com/andreiwashere/install-go/main/backup_go.sh) | Archives `/go` for CI/CD purposes |
| `analyze_dir.go` | [Source Code for analyze_dir.go](https://raw.githubusercontent.com/andreiwashere/install-go/main/analyze_dir.go) | Generates manifest metadata analysis for directories |

This project consists of two programs, `installgo` and `switchgo`. Both of these programs are built upon the following structure:

```bash
~/go
~/go/version
~/go/root -> /go/versions/<version>/go
~/go/path -> /go/versions/<version>
~/go/bin -> /go/version/<version>/src/bin
~/go/versions
~/go/versions/<version>
~/go/versions/<version>/go
~/go/versions/<version>/pkg
```

`igo` or **Install Go** will ensure this basic directory structure exists on your Linux system. 

> This script uses Bash 4 syntax, and will not work with the built-in bash provided on MacOS. You will be required to upgrade your Bash prior to using this script on MacOS. While its unconventional to put a directory in the root volume of the system, and the root user is typically not used, this script may be modified to work without sudo, and instead just do a local install instead.

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

# Installation 

## All In One

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
[ ! -f /usr/bin/igo ] && sudo mv install_go.sh /usr/bin/igo || echo "Already installed!"
source ~/.bashrc
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

### `sgo`

**Usage**: `sgo [ list | <version> ]`

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/switch_go.sh < /dev/null > /dev/null 2>&1
[ -f switch_go.sh ] && chmod +x switch_go.sh || echo "Failed to download switch_go.sh"
[ ! -f /usr/bin/sgo ] && sudo mv switch_go.sh /usr/bin/sgo || echo "Already installed!"
sgo list
```

This updates the symlinks inside of `!/go` for `GOBIN`, `GOPATH`, and `GOROOT` automatically and supports `~/.bashrc` and `~/.zshrc` shells for export control of the environment variables.

### `bgo`

**Usage**: `bgo`

```bash
wget --no-cache https://raw.githubusercontent.com/andreiwashere/install-go/main/backup_go.sh < /dev/null > /dev/null 2>&1
[ -f backup_go.sh ] && chmod +x backup_go.sh || echo "Failed to download backup_go.sh"
[ ! -f /usr/bin/bgo ] && sudo mv backup_go.sh /usr/bin/bgo || echo "Already installed!"
```

This script will create a backup of the `~/go` directory and save the backup inside of `~/go/backups`. 

**NOTE**: _The backups stored inside `~/go/backups` will be omitted from future `bgo` backups created._

# License

This project is Open Source under the MIT License.
