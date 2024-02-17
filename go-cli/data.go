package main

var Versions ManyVersions
var mu_Versions sync.RWMutex

var (
  m_InstalledVersions = make(ManyVersions, 0)
  m_AvailableVersions = make(ManyVersions, 0)

  mu_InstalledVersions = sync.RWMutex{}
  mu_AvailableVersions = sync.RWMutex{}
)

