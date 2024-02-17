package main


func GetInstalledVersions() ManyVersions {
  mu_InstalledVersions.RLock()
  defer mu_InstalledVersions.RUnlock()

  return m_InstalledVersions
}

func GetInstalledVersion(version GoVersion) Version {
  mu_InstalledVersions.RLock()
  defer mu_InstalledVersions.RUnlock()

  return m_InstalledVersions[version]
}

// InsertInstalledVersion sets Version.Value inside m_InstalledVersions threadsafely
// 
func InsertInstalledVersion(version Version) Version {
  mu_InstalledVersions.Lock()
  defer mu_InstalledVersions.Unlock()

  m_InstalledVersions[version.Value] = version

  return m_InstalledVersions[version.Value]
}
