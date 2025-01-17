// Copyright 2025 Kholis RA Gumelar
// SPDX-License-Identifier: AGPL-3.0-only

package config

type Config struct {
	LogLevel string `default:"info" koanf:"log_level"`
	Server   Server `koanf:"server"`
}

type Server struct {
	API       string `default:"https://api.labz.sh" koanf:"api"`
	Websocket string `default:"wss://ws.labz.sh"    koanf:"websocket"`
}

func NewDefaultConfig() *Config {
	return &Config{}
}
