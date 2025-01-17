// Copyright 2025 Kholis RA Gumelar or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: AGPL-3.0-only

package logger

import (
	"fmt"
	"os"
	"strings"
	"sync"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

const (
	// (user: read/write, group: read, others: none).
	DefaultFilePermissions = 0o420
)

// Logger wraps with uber-go/zap logger.
type Logger struct {
	*zap.Logger
	level zapcore.Level
}

type Provider struct {
	instance *Logger
	once     sync.Once
}

// Config holds logger configuration.
type Config struct {
	Level       string // debug, info, warn, error, dpanic, panic, fatal
	OutputPath  string // stdout, stderr, or file path
	Encoding    string // json or console
	Development bool   // if true, enables development mode
}

// DefaultConfig returns default logger configuration.
func DefaultConfig() Config {
	return Config{
		Level:       "info",
		OutputPath:  "stdout",
		Encoding:    "json",
		Development: false,
	}
}

// NewProvider creates a new Provider instance.
func NewProvider() *Provider {
	return &Provider{}
}

// Init initializes the logger with given configuration.
func (p *Provider) Init(cfg Config) error {
	// Parse log level
	level, err := parseLogLevel(cfg.Level)
	if err != nil {
		return fmt.Errorf("invalid log level: %w", err)
	}

	// Use production encoder config
	encoderCfg := zap.NewProductionEncoderConfig()

	// Configure output path
	var output zapcore.WriteSyncer
	switch strings.ToLower(cfg.OutputPath) {
	case "stdout":
		output = zapcore.AddSync(os.Stdout)
	case "stderr":
		output = zapcore.AddSync(os.Stderr)
	default:
		file, openErr := os.OpenFile(
			cfg.OutputPath,
			os.O_APPEND|os.O_CREATE|os.O_WRONLY,
			DefaultFilePermissions,
		)
		if openErr != nil {
			return fmt.Errorf("failed to open log file: %w", openErr)
		}
		output = zapcore.AddSync(file)
	}

	// Configure encoder type
	var encoder zapcore.Encoder
	switch strings.ToLower(cfg.Encoding) {
	case "json":
		encoder = zapcore.NewJSONEncoder(encoderCfg)
	case "console":
		encoder = zapcore.NewConsoleEncoder(encoderCfg)
	default:
		return fmt.Errorf("unsupported encoding: %s", cfg.Encoding)
	}

	// Create core
	core := zapcore.NewCore(
		encoder,
		output,
		zap.NewAtomicLevelAt(level),
	)

	// Create logger
	zapLogger := zap.New(
		core,
		zap.AddCaller(),
		zap.AddCallerSkip(1),
		zap.AddStacktrace(zapcore.ErrorLevel),
	)

	if cfg.Development {
		zapLogger = zapLogger.WithOptions(zap.Development())
	}

	p.instance = &Logger{
		Logger: zapLogger,
		level:  level,
	}

	return nil
}

// GetLogger returns the logger instance, initializing it if necessary.
func (p *Provider) GetLogger() *Logger {
	p.once.Do(func() {
		// Initialize with default config if not initialized
		cfg := DefaultConfig()
		if err := p.Init(cfg); err != nil {
			panic(err)
		}
	})
	return p.instance
}

// SetLevel dynamically changes the log level.
func (l *Logger) SetLevel(level string) error {
	newLevel, err := parseLogLevel(level)
	if err != nil {
		return err
	}

	if newLevel != l.level {
		l.Info("changing log level",
			zap.String("from", l.level.String()),
			zap.String("to", newLevel.String()),
		)
		l.level = newLevel
	}
	return nil
}

// Helper methods for structured logging.
func (l *Logger) WithFields(fields map[string]interface{}) *zap.Logger {
	zapFields := make([]zap.Field, 0, len(fields))
	for k, v := range fields {
		zapFields = append(zapFields, zap.Any(k, v))
	}
	return l.Logger.With(zapFields...)
}

// parseLogLevel converts a string level to zapcore.Level.
func parseLogLevel(level string) (zapcore.Level, error) {
	switch strings.ToLower(level) {
	case "debug":
		return zapcore.DebugLevel, nil
	case "info":
		return zapcore.InfoLevel, nil
	case "warn", "warning":
		return zapcore.WarnLevel, nil
	case "error":
		return zapcore.ErrorLevel, nil
	case "dpanic":
		return zapcore.DPanicLevel, nil
	case "panic":
		return zapcore.PanicLevel, nil
	case "fatal":
		return zapcore.FatalLevel, nil
	default:
		return zapcore.InfoLevel, fmt.Errorf("unknown log level: %s", level)
	}
}

// WithFields creates a new logger with the specified fields.
func (p *Provider) WithFields(fields map[string]interface{}) *zap.Logger {
	return p.GetLogger().WithFields(fields)
}

// Info logs a message at InfoLevel.
func (p *Provider) Info(msg string, fields ...zap.Field) { p.GetLogger().Info(msg, fields...) }

// Error logs a message at ErrorLevel.
func (p *Provider) Error(msg string, fields ...zap.Field) { p.GetLogger().Error(msg, fields...) }

// Debug logs a message at DebugLevel.
func (p *Provider) Debug(msg string, fields ...zap.Field) { p.GetLogger().Debug(msg, fields...) }

// Warn logs a message at WarnLevel.
func (p *Provider) Warn(msg string, fields ...zap.Field) { p.GetLogger().Warn(msg, fields...) }

// Fatal logs a message at FatalLevel.
func (p *Provider) Fatal(msg string, fields ...zap.Field) { p.GetLogger().Fatal(msg, fields...) }

// Panic logs a message at PanicLevel.
func (p *Provider) Panic(msg string, fields ...zap.Field) { p.GetLogger().Panic(msg, fields...) }

// Infof logs a formatted message at InfoLevel.
func (p *Provider) Infof(template string, args ...interface{}) {
	p.GetLogger().Sugar().Infof(template, args...)
}

// Errorf logs a formatted message at ErrorLevel.
func (p *Provider) Errorf(template string, args ...interface{}) {
	p.GetLogger().Sugar().Errorf(template, args...)
}

// Debugf logs a formatted message at DebugLevel.
func (p *Provider) Debugf(template string, args ...interface{}) {
	p.GetLogger().Sugar().Debugf(template, args...)
}

// Warnf logs a formatted message at WarnLevel.
func (p *Provider) Warnf(template string, args ...interface{}) {
	p.GetLogger().Sugar().Warnf(template, args...)
}

// Fatalf logs a formatted message at FatalLevel.
func (p *Provider) Fatalf(template string, args ...interface{}) {
	p.GetLogger().Sugar().Fatalf(template, args...)
}

// Panicf logs a formatted message at PanicLevel.
func (p *Provider) Panicf(template string, args ...interface{}) {
	p.GetLogger().Sugar().Panicf(template, args...)
}
