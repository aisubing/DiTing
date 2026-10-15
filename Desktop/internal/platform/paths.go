package platform

import (
	"os"
	"path/filepath"
)

// 默认文件名与目录名常量。
const (
	// DefaultStateFileName 默认接管状态持久化文件名。
	DefaultStateFileName = "dns_state.json"
	// DefaultConfigFileName 默认配置文件名称。
	DefaultConfigFileName = "config.json"
	// DefaultFilterDirName 默认规则源缓存目录名。
	DefaultFilterDirName = "filters"
	// DefaultQueryLogDirName 默认查询日志落盘目录名。
	DefaultQueryLogDirName = "querylog"
	// DefaultCertDirName 默认加密 DNS 服务证书目录名。
	DefaultCertDirName = "certs"
)

// EnvDataDir 覆盖数据目录的环境变量名。
//
// 设置后默认配置目录与数据目录全部收敛至 ${EnvDataDir}/DITING，
// 便于在非 root 环境（如 WSL 调试）下运行而无需写入系统目录。
const EnvDataDir = "DITING_DATA_DIR"

// DefaultDataDir 返回当前平台的可变数据根目录。
//
// 该目录用于存放接管状态文件与规则源缓存等运行时数据，
// 由 DefaultStateFilePath / DefaultFilterDir 派生。
func DefaultDataDir() string {
	if custom := os.Getenv(EnvDataDir); custom != "" {
		return filepath.Join(custom, "DITING")
	}
	return defaultDataDir()
}

// DefaultConfigDir 返回当前平台的配置目录。
//
// Windows 与数据目录一致（%ProgramData%\DITING）；类 Unix 平台遵循 FHS
// 独立为 /etc/diting。设置 DITING_DATA_DIR 时统一回落到数据目录。
func DefaultConfigDir() string {
	if custom := os.Getenv(EnvDataDir); custom != "" {
		return filepath.Join(custom, "DITING")
	}
	return defaultConfigDir()
}

// DefaultConfigPath 返回默认配置文件绝对路径。
func DefaultConfigPath() string {
	return filepath.Join(DefaultConfigDir(), DefaultConfigFileName)
}

// DefaultStateFilePath 返回默认接管状态文件绝对路径。
func DefaultStateFilePath() string {
	return filepath.Join(DefaultDataDir(), DefaultStateFileName)
}

// DefaultFilterDir 返回默认规则源缓存目录绝对路径。
func DefaultFilterDir() string {
	return filepath.Join(DefaultDataDir(), DefaultFilterDirName)
}

// DefaultQueryLogDir 返回默认查询日志落盘目录绝对路径。
//
// 该目录存放按天滚动的 JSON-Lines 查询历史文件，受 DITING_DATA_DIR 整体覆盖；
// 目录不可写时由调用方降级为纯内存模式，不影响服务启动。
func DefaultQueryLogDir() string {
	return filepath.Join(DefaultDataDir(), DefaultQueryLogDirName)
}

// DefaultCertDir 返回默认证书目录绝对路径。
//
// 与配置目录分开而落在数据目录下：私钥是数据而非配置，它不该随
// 配置文件一起被复制、备份或提交到版本库。
func DefaultCertDir() string {
	return filepath.Join(DefaultDataDir(), DefaultCertDirName)
}
