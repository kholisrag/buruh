// Copyright 2025 Kholis RA Gumelar or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: AGPL-3.0-only

//go:build linux
// +build linux

package utils

import (
	"embed"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/labz-shell/buruh/pkg/logger"
	"go.uber.org/zap"

	"codeberg.org/msantos/embedexe"
	"codeberg.org/msantos/embedexe/fdexec"
)

//go:embed .bin/*
var bin embed.FS

// ErrBinaryNotFound indicates that the requested binary was not found in the embedded filesystem.
var ErrBinaryNotFound = errors.New("binary not found in embedded filesystem")

// GetBinFS returns the embedded filesystem containing binary files.
func GetBinFS() embed.FS {
	return bin
}

// ExecBinary executes an embedded binary with the given name and arguments.
// It returns any error encountered during execution.
func ExecBinary(name string, args []string) error {
	log := logger.NewProvider()
	log.Debug("executing embedded binary",
		zap.String("binary", name),
		zap.Strings("args", args),
	)

	// Validate binary name to prevent path traversal
	if !isValidBinaryName(name) {
		log.Error("invalid binary name",
			zap.String("binary", name),
		)
		return fmt.Errorf("invalid binary name: %s", name)
	}

	binPath := filepath.Join(".bin", name)
	binData, readErr := bin.ReadFile(binPath)
	if readErr != nil {
		log.Error("failed to read binary from embedded filesystem",
			zap.String("binary", name),
			zap.Error(readErr),
		)
		return fmt.Errorf("reading binary %s: %w", name, ErrBinaryNotFound)
	}

	if !isLinux() {
		log.Error("buruh agent is only supported on Linux",
			zap.String("os", runtime.GOOS),
		)
		return fmt.Errorf("buruh agent is only supported on Linux (current OS: %s)", runtime.GOOS)
	}

	// Create file descriptor using embedexe
	fd, err := embedexe.Open(binData, name)
	if err != nil {
		log.Error("failed to create file descriptor",
			zap.String("binary", name),
			zap.Error(err),
		)
		return fmt.Errorf("creating file descriptor: %w", err)
	}
	defer fd.Close()

	log.Debug("prepared binary for execution",
		zap.String("binary", name),
	)

	// Create command using fdexec
	cmd := fdexec.Command(fd, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()

	// Execute the command
	if runErr := cmd.Run(); runErr != nil {
		log.Error("failed to execute binary",
			zap.String("binary", name),
			zap.Strings("args", args),
			zap.Error(runErr),
		)
		return fmt.Errorf("executing binary %s with args %v: %w", name, args, runErr)
	}

	log.Info("successfully executed binary",
		zap.String("binary", name),
		zap.Strings("args", args),
	)

	return nil
}

// isLinux returns true if running on Linux
func isLinux() bool {
	return runtime.GOOS == "linux"
}

// ListBinaries returns a list of available binary names in the embedded filesystem.
func ListBinaries() ([]string, error) {
	log := logger.NewProvider()
	log.Debug("listing available binaries")

	entries, err := bin.ReadDir(".bin")
	if err != nil {
		log.Error("failed to read bin directory",
			zap.Error(err),
		)
		return nil, fmt.Errorf("reading .bin directory: %w", err)
	}

	var binaries []string
	for _, entry := range entries {
		if !entry.IsDir() {
			binaries = append(binaries, entry.Name())
		}
	}

	log.Info("successfully listed binaries",
		zap.Int("count", len(binaries)),
		zap.Strings("binaries", binaries),
	)

	return binaries, nil
}

// isValidBinaryName checks if a binary name is valid and safe to use
func isValidBinaryName(name string) bool {
	// Basic validation - should not contain path separators or special characters
	if name == "" || strings.ContainsAny(name, `/\:`) {
		return false
	}
	return true
}

// GetBinaryPath returns the full path to a binary in the embedded filesystem.
func GetBinaryPath(name string) string {
	return filepath.Join(".bin", name)
}
