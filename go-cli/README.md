# `ingo` Manages Complex Multi-Version Go Environments
 
 
## Installation 

```bash
go install github.com/andreiwashere/install-go/go-cli@latest
```

## Usage

```bash
$ ingo
[in]side [go] == ingo | HELP MENU

Available Commands:
 ingo --l|list                              Lists installed versions of Go

 ingo --a|all                               Lists available versions of Go
                                               to install

 ingo --info <version>                      Returns metadata about version 
                                               if available

 ingo --i|install <version>                 Installs a specific version of 
                                               go inside ~/go

 ingo --un|uninstall <version>              Installs inside ~/go/<version> 
                                               [keeps project files]

 ingo --re|remove <version>                 Alias of uninstall

 ingo --up|upgrade <version>                Safely ~/go/versions/<cur-ver>/* 
                                               -> ~/go/versions/<lat-ver>/*

 ingo --kill <version>                      Safely removes ~/go/versions/<ver>/*

 ingo --obliterate <version>                Safely removes ~/go/versions/<ver>/* 
                                               and ~/go/backups/<version>.*.tar.gz

 ingo --ild|illd|installed                  Lists installed versions of go inside 
                                               ~/go/versions/

 ingo --s|sw|switch <version>               Safely switches your local workspace's 
                                               Go version context to new version

 ingo --flush-cache                         Flush the cache of the application 
                                               and effectively restart

 ingo --set-projects-dir <dir>              Assigns a GOPROJECTS environment variable 
                                               within ingo

 ingo --projects --upgrade                  Safely iterates over ~/go/projects/<ver>/* 
                                               and upgrades mod.go `go <ex-ver>` 
                                               to `go <active-version>` 
                                               [active version is output of `go version`]

 ingo --project <name> --upgrade            Safely upgrades the mod.go `go <ex-ver>` 
                                               to `go <ac-ver>` 
                                               [active version is output of `go version`]

 ingo --project <name> --backup             STDOUT gz file output of compressed of:
                                               ~/go/versions/<proj-ver>/* 
                                                  -> go.<ver>.tar.gz
                                               ~/go/projects/<name>/* 
                                                  -> project-<proj-ver>.go-<go-ver>.tar.gz

 ingo --backup                              STDOUT gz file output of compressed of: 
                                               ~/go/projects/* 
                                               -> ~/go/backups/ \
                                               go-projects.YYYY.MM.DD.HH.MM.UTC.tar.gz

 ingo --clean [--days=#]                    Analyzes the ~/go/backups/* directory for
                                               *.tar.gz files that are older than days
                                      
 ingo --status                              Performs a basic analysis of the system 
                                               installation of installed go versions

 ingo --suicide                             Commit suicide. Analyzes ~/go/* and asks for
                                                confirmation for next step

 ingo --suicide --yeshua                    1st Verification for suicide
 
 ingo --suicide --yeshua --saves            2nd Verification for suicide
 
 ingo --suicide --yeshua --saves --me       3rd Verification for suicide. Deletes
                                               ~/go/* including backups and 
                                               scheduled cronjob / task
                
```

> **NOTE**: If you are struggling with suicidal thoughts, we encourage you to reach out for help regardless of your religious affiliation. Seek help. However, when uninstalling your projects and your versioned data... its a big deal. But the CICD that this offers is powerful. With great power comes great responsibility.

`ingo` is designed to help you manage a complex environment of Go. 

Here is an example workflow: 

```bash
$ ingo --install latest
Go 1.22.0 Installed

$ go version
go 1.22.0 linux/amd64

$ ls ~/go
GOOS GOPATH GOBIN GOSCRIPTS GOSHIMS Backups Projects Versions Version [.locked]
```

> **NOTE**: The `.locked` file will only be present while performing actions by the application. This creates a singleton of execution.

```bash
$ ingo versions
Go 1.22.0 *current* *latest*
Go 1.21.7 
Go 1.21.6

$ ingo switch 1.21.7
Switched to go 1.21.7

$ go version
go 1.21.7 linux/amd64

$ cat ~/go/Version
1.21.7

$ ingo switch latest
Switched to go 1.22.0 *latest*

$ ingo switch 1.21.6
Switched to go 1.21.6

$ ingo remove 1.21.6
Switching you to *latest* go 1.22.0 after uninstall. [O|Okay*|<version>]: 1.21.7
Will switch to go 1.21.7 after removing go 1.21.6.
Are you sure? [y|n*]: y
Removed go 1.21.6 via: 
- rm -rf ~/go/Versions/1.21.6/*
Switched to go 1.21.7

$ go version
go 1.21.7 linux/amd64

$ cd ~/go/projects

$ mkdir my-project

$ cd my-project

$ go mod init github.com/andreimerlescu/go-my-project-demo-1776-369-2024-02-17

$ touch main.go

$ ingo backup my-project

$ ingo cleanup 180 # crap ran out of disk space... lets fix that by lowering this value

$ ingo cleanup 120 # oops need more disk space... 

$ ingo cleanup 30  # oops need moar disk space...

$ ingo cleanup 17
Are you sure you want to keep less than 42 backups? [y|n*]: y
Deleted 369MB of data from ~/go/Backups/*.tar.gz by removing 17 files that were older than 17 days old.

$ ingo status
Current Version: 1.21.7
Available Versions: 1.22 *latest*, 1.21.7 *current*
Total Projects: 17 [1.2TB] ~/go/projects
Total Backups: 33 [1.7TB] ~/go/backups
Using Shim? Yes
GOPATH: ~/go/path
GOROOT: ~/go/root
GOBIN: ~/go/bin
Installed Programs:
 - go-top
 - wails
 - go-generate-password
 - ingo
PATH: /usr/bin:/home/user/go/shims:/home/user/go/scripts:/home/user/go/bin:/home/user/go/projects

```








