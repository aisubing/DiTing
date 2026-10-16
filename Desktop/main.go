//go:build windows

package main

import (
	"flag"
	"fmt"
)

// Version 信息
var (
	Version   = "1.3.8"
	BuildTime = "dev"
	GitCommit = "dev"
)

func main() {
	showVersion := flag.Bool("v", false, "显示 GUI 版本号并退出")
	flag.BoolVar(showVersion, "version", false, "显示 GUI 版本号并退出")
	minimized := flag.Bool("minimized", false, "以最小化方式启动（当前无托盘常驻形态，暂不生效）")
	flag.BoolVar(minimized, "m", false, "以最小化方式启动（当前无托盘常驻形态，暂不生效）")
	flag.Parse()

	if *showVersion {
		fmt.Printf("diting-gui version %s (built: %s, commit: %s)\n", Version, BuildTime, GitCommit)
		return
	}

	app := NewApp()
	runGUI(app, *minimized)
}
