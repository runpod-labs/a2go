package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/runpod-labs/a2go/a2go/internal/config"
)

var restartCmd = &cobra.Command{
	Use:   "restart",
	Short: "Stop then run all services",
	Long: `Restart all services. Uses the last config if no new config is provided.

  a2go restart                                                                    # reuse last config
  a2go restart --agent openclaw --llm mlx-community/Qwen3-30B-A3B-4bit           # use new config
  a2go restart --config '{"agent":"openclaw","llm":"..."}'                        # use new JSON config`,
	Args: cobra.NoArgs,
	RunE: runRestart,
}

func runRestart(cmd *cobra.Command, args []string) error {
	// If no flags/config provided, load last saved config into --config flag
	if flagLLM == "" && flagConfig == "" && os.Getenv("A2GO_CONFIG") == "" {
		raw, err := config.LoadLastRaw()
		if err != nil {
			return fmt.Errorf("no config provided and no previous config found\n\n  a2go restart --agent openclaw --llm mlx-community/Qwen3-30B-A3B-4bit")
		}

		// Validate saved config has agent field
		cfg, err := config.LoadLast()
		if err != nil {
			return err
		}
		if cfg.Agent == "" {
			return fmt.Errorf("saved config missing --agent flag. run: a2go run --agent <openclaw|hermes> --llm <model>")
		}

		flagConfig = raw
		// Carry forward the saved agent so the required flag check passes
		if flagAgent == "" {
			flagAgent = cfg.Agent
		}
	}

	doStop()

	return execRun(cmd, args)
}

func init() {
	// Share flags with run command
	restartCmd.Flags().StringVar(&flagAgent, "agent", "", "Agent framework: openclaw, hermes")
	restartCmd.Flags().StringVar(&flagLLM, "llm", "", "LLM model")
	restartCmd.Flags().StringVar(&flagImage, "image", "", "Image model")
	restartCmd.Flags().StringVar(&flagAudio, "audio", "", "Audio model (set to 'off' to disable)")
	restartCmd.Flags().StringVar(&flagToken, "token", "changeme", "Auth token for gateway")
	restartCmd.Flags().StringVar(&flagConfig, "config", "", "JSON config")
}
