// Copyright 2025 Kholis RA Gumelar or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: AGPL-3.0-only

package main

import (
	"github.com/labz-shell/buruh/pkg/cmd"
	"github.com/labz-shell/buruh/pkg/logger"
)

// BuildInfo holds the `buruh` application build information.
type BuildInfo struct {
	Version   string
	Commit    string
	BuildTime string
}

const (
	unknown = "unknown"
)

// These variables are set during build time.
var (
	//nolint:gochecknoglobals // These variables are set during build time.
	buildTime = unknown
	//nolint:gochecknoglobals // These variables are set during build time.
	commit  = unknown
	version = unknown
)

// newBuildInfo creates a BuildInfo instance with build-time values.
func newBuildInfo() BuildInfo {
	return BuildInfo{
		Version:   version,
		Commit:    commit,
		BuildTime: buildTime,
	}
}

func main() {
	// Create logger instance
	log := logger.NewProvider()

	// Get build information
	buildInfo := newBuildInfo()

	// Validate required build info
	if buildInfo.Version == unknown {
		log.Debug("version must be set at build time")
	}
	if buildInfo.Commit == unknown {
		log.Debug("commit must be set at build time")
	}
	if buildInfo.BuildTime == unknown {
		log.Debug("build time must be set at build time")
	}

	cmdConfig := cmd.NewCommandConfig()

	// Initialize and register agent command
	agentCmd := cmd.NewAgentCommand(log)
	agentCmd.RegisterAgentCommand(cmdConfig.RootCmd())

	// Execute root command
	err := cmdConfig.NewCmdRoot(buildInfo.Version, buildInfo.Commit, buildInfo.BuildTime)
	if err != nil {
		log.Fatalf("error executing the root command: %v", err)
	}
}
