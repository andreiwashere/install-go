package main

import (
	"net/http"
	"io"
	"log"
	"encoding/json"
	"runtime"
)


func main(){
	/*

*/

Versions = map[GoVersion]Version{}

mu_Versions = sync.RWMutex{}


log.Printf("versions = %v", ListGoVersions())



}