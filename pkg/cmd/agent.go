// Copyright 2025 Kholis RA Gumelar
// SPDX-License-Identifier: AGPL-3.0-only

package cmd

import (
	"github.com/spf13/cobra"

	"github.com/labz-shell/buruh/pkg/logger"
)

type AgentCommand struct {
	serveCmd *cobra.Command
	logger   *logger.Provider
}

func NewAgentCommand(log *logger.Provider) *AgentCommand {
	ac := &AgentCommand{
		logger: log,
		serveCmd: &cobra.Command{
			Use:   "agent",
			Short: "Run agent to connect to labz-shell control plane",
			Run: func(_ *cobra.Command, _ []string) {
				log.Info("agent command executed - implementation pending")
			},
		},
	}

	return ac
}

// RegisterAgentCommand adds the agent command to the root command.
func (ac *AgentCommand) RegisterAgentCommand(rootCmd *cobra.Command) {
	rootCmd.AddCommand(ac.serveCmd)
}
