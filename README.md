# Overview

| Script | Link | Info |
|--------|------|------|
| `install_go.sh` | [Github Gist install_go.sh](https://raw.githubusercontent.com/andreiwashere/install-go/main/install_go.sh) | Install `/go` on your system |
| `switch_go.sh` | [Github Gist switch_go.sh](https://raw.githubusercontent.com/andreiwashere/install-go/main/switch_go.sh) | Modifies `/go` active versions |


# Usage

To install the latest (1.21.0) version of Go: 

```bash
sudo installgo 1.21.0 linux amd64
```

To install the previous (1.20.5) version of Go: 

```bash
sudo installgo 1.20.5 linux amd64
```

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
curl -L -s -O https://raw.githubusercontent.com/andreiwashere/install-go/main/install_go.sh
chmod +x install_go.sh
sudo cp install_go.sh /usr/bin/installgo
sudo installgo 1.21.0 linux amd64
source ~/.bashrc
go version
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

```bash
curl -L -s -O https://raw.githubusercontent.com/andreiwashere/install-go/main/switch_go.sh
chmod +x switch_go.sh
sudo cp switch_go.sh /usr/bin/switchgo
sudo switchgo list
```
Since this script installs your ENV vars in your `/etc/profile` and all `/home/*/.bashrc` and `/root/.bashrc` to the `/go/root`, `/go/path`, and `/go/bin` symlinks, we can use the `switchgo` command to update these symlinks and quickly switch between versions of Go.



