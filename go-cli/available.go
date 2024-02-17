package main

func GetAvailableVersions() ManyVersions {
  mu_AvailableVersions.RLock()
  defer mu_AvailableVersions.RUnlock()

  return m_AvailableVersions
}

func GetAvailableVersion(version GoVersion) Version {
  mu_AvailableVersions.RLock()
  defer mu_AvailableVersions.RUnlock()

  return AvailableVersions[version]
}

func NewAvailableVersion(version GoVersion) Version {
  mu_AvailableVersions.Lock()
  defer mu_AvailableVersions.Unlock()

  m_AvailableVersions[version] = Versions[version]

  return m_AvailableVersions[version]
}