package main

func (v *Version) String() string {
  return string(v.Value)
}


// ListGoVersions fetches available Go versions for the current OS and Arch, including SHA256 checksums.
func ListGoVersions() ([]GoVersion, error) {
    url := "https://go.dev/dl/?mode=json&include=all"
    resp, err := http.Get(url)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return nil, err
    }

    var rawVersions []VersionsResponse

    if err := json.Unmarshal(body, &rawVersions); err != nil {
        return nil, err
    }

    var versions []GoVersion
    for _, rawVersion := range rawVersions {
        filesMap := make(map[GoFile]File)
        for _, file := range rawVersion.Files {
            filesMap[file.Filename] = file
        }

        version := GoVersion{
            Version: rawVersion.Version,
            Stable:  rawVersion.Stable,
            Files:   filesMap,
        }
        versions = append(versions, version)
    }

    // Filter the versions based on the current OS and architecture
    filteredVersions := make([]GoVersion, 0)
    for _, version := range versions {
        for _, file := range version.Files {
            fileVersion, ok := Retrieve(file.Filename)
            if ok && fileVersion.OS == runtime.GOOS && fileVersion.Arch == runtime.GOARCH {
                // Include this version if it matches the OS and architecture
                // filteredVersions = append(filteredVersions, version)
				NewAvailableVersion(version.Version, Version)
                break // Found a match, no need to check the rest of the files
            }
        }
    }

    return GetAvailableVersions(), nil
}