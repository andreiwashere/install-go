package main


type Version struct {
	Files   map[GoFile]File  `json:"files"`
	GOROOT string `json:"goroot"`
	GOPATH string `json:"gopath"`
	GOBIN string `json:"gobin"`
  	GOOS string `json:"goos"`
  	GOARCH string `json:"goarch"`
	Value GoVersion `json:"value"`
	Major int `json:"major"`
	Minor int `json:"minor"`
	Patch int `json:"patch"`
  	Prerelease bool `json:"prerelease"`
}

type VersionsResponse struct {
	Version string `json:"version"`
	Stable  bool   `json:"stable"`
	Files   []File `json:"files"`
}

type GoFile string
type GoVersion string

type File struct {
    Filename GoFile  `json:"filename"`
    OS       string  `json:"os"`
    Arch     string  `json:"arch"`
    Version  string  `json:"version"`
    SHA256   string  `json:"sha256"`
    Size     int     `json:"size"`
    Kind     string  `json:"kind"`
}

type ManyVersions map[GoVersion]Version{}
