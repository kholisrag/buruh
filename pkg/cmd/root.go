// Copyright 2025 Kholis RA Gumelar
// SPDX-License-Identifier: AGPL-3.0-only

package cmd

import (
	"fmt"

	"github.com/knadh/koanf/parsers/yaml"
	"github.com/knadh/koanf/providers/file"
	"github.com/knadh/koanf/v2"
	"github.com/spf13/cobra"
	"go.uber.org/zap"

	"github.com/labz-shell/buruh/pkg/config"
	"github.com/labz-shell/buruh/pkg/logger"
)

// CommandConfig is a configuration for the command.
type CommandConfig struct {
	k       *koanf.Koanf
	konfig  config.Config
	cfgPath string
	rootCmd *cobra.Command
	logger  *logger.Provider
}

// NewCommandConfig creates a new command configuration.
func NewCommandConfig() *CommandConfig {
	cc := &CommandConfig{
		k:      koanf.New("."),
		logger: logger.NewProvider(),
		rootCmd: &cobra.Command{
			Use:   "buruh",
			Short: "buruh is an Agent that connect to labz-shell control plane",
			Long: `
buruh is an Agent that connect to labz-shell control plane,
the agent included with embedded apps that need for it to be run and integrate with labz-shell control plane.
`,
		},
	}

	cc.rootCmd.PersistentFlags().StringVar(&cc.cfgPath, "config", ".buruh.yaml", "config file path")
	cc.rootCmd.PersistentFlags().StringVar(&cc.konfig.LogLevel, "log-level", "info", "log level")
	cobra.OnInitialize(cc.initConfig)

	return cc
}

// NewCmdRoot creates a new root command.
func (cc *CommandConfig) NewCmdRoot(version string, commit string, buildTime string) error {
	cc.rootCmd.Version = fmt.Sprintf("%s, commit %s, build at %s", version, commit, buildTime)
	if err := cc.rootCmd.Execute(); err != nil {
		cc.logger.GetLogger().Fatal("error executing the root command", zap.Error(err))
		return err
	}

	return nil
}

// initConfig reads in config file.
func (cc *CommandConfig) initConfig() {
	// Load the configuration
	if err := cc.k.Load(file.Provider(cc.cfgPath), yaml.Parser()); err != nil {
		cc.logger.GetLogger().Warn("error loading the configuration", zap.Error(err))
	}
	cc.logger.GetLogger().Info("log level", zap.String("level", cc.konfig.LogLevel))

	// Override with flags if specified
	if cc.rootCmd.PersistentFlags().Changed("log-level") {
		logLevel, _ := cc.rootCmd.PersistentFlags().GetString("log-level")
		cc.konfig.LogLevel = logLevel
	}

	// Initialize logger with final configuration
	err := cc.logger.Init(logger.Config{
		Level:       cc.konfig.LogLevel,
		OutputPath:  "stdout",
		Encoding:    "json",
		Development: false,
	})
	if err != nil {
		cc.logger.GetLogger().Fatal("error initializing logger", zap.Error(err))
	}

	cc.logger.GetLogger().Debug("loaded configuration", zap.Any("config", cc.konfig))
}

// RootCmd returns the root command.
func (cc *CommandConfig) RootCmd() *cobra.Command {
	return cc.rootCmd
}
