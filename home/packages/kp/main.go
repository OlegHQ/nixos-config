package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
)

const version = "1.0.0"

const helpText = `kp - Kill processes by port number (v%s)

USAGE:
    kp <port> [port...]      Kill process(es) on specified port(s)
    kp <port,port,...>       Kill processes on comma-separated ports
    kp --help, -h            Show this help message
    kp --version, -v         Show version

EXAMPLES:
    kp 3000                  Kill process on port 3000
    kp 3000 8080 9000        Kill processes on ports 3000, 8080, and 9000
    kp 3000,8080,9000        Kill processes (comma-separated)
    sudo kp 80               Kill process on privileged port (requires sudo)

EXIT CODES:
    0    All processes killed successfully
    1    Some processes failed to kill (partial success)
    2    No ports specified or invalid arguments

OUTPUT FORMAT (AI-FRIENDLY):
    [SUCCESS] Killed process <pid> (<name>) on port <port>
    [ERROR] <error message>
    Suggestion: <actionable suggestion>

TROUBLESHOOTING:
    - Permission denied: Run with sudo for privileged ports or other users' processes
    - No process found: The port may not be in use, verify with 'lsof -i :<port>'
    - Multiple processes: All processes on the port will be killed

NOTES:
    - Uses SIGTERM first for graceful shutdown
    - Falls back to SIGKILL if process doesn't terminate
    - Works on macOS and Linux
`

func main() {
	if len(os.Args) < 2 {
		printHelp()
		os.Exit(2)
	}

	arg := os.Args[1]
	if arg == "--help" || arg == "-h" {
		printHelp()
		os.Exit(0)
	}
	if arg == "--version" || arg == "-v" {
		fmt.Printf("kp version %s\n", version)
		os.Exit(0)
	}

	// Collect all ports from arguments
	var ports []string
	for _, arg := range os.Args[1:] {
		// Handle comma-separated ports
		if strings.Contains(arg, ",") {
			ports = append(ports, strings.Split(arg, ",")...)
		} else {
			ports = append(ports, arg)
		}
	}

	// Validate all ports are numbers
	for _, port := range ports {
		port = strings.TrimSpace(port)
		if port == "" {
			continue
		}
		if _, err := strconv.Atoi(port); err != nil {
			fmt.Printf("[ERROR] Invalid port number: %s\n", port)
			fmt.Println("Suggestion: Port must be a number between 1-65535")
			os.Exit(2)
		}
	}

	// Track results
	var killed []string
	var failed []string
	exitCode := 0

	// Process each port
	for _, port := range ports {
		port = strings.TrimSpace(port)
		if port == "" {
			continue
		}

		result := killPort(port)
		if result.success {
			killed = append(killed, port)
		} else {
			failed = append(failed, fmt.Sprintf("%s (%s)", port, result.reason))
			exitCode = 1
		}
	}

	// Print summary if multiple ports
	if len(ports) > 1 {
		fmt.Println()
		fmt.Println("[SUMMARY]")
		if len(killed) > 0 {
			fmt.Printf("  Ports killed: %s\n", strings.Join(killed, ", "))
		}
		if len(failed) > 0 {
			fmt.Printf("  Ports failed: %s\n", strings.Join(failed, ", "))
		}
	}

	// Print next steps
	if len(killed) > 0 {
		fmt.Println()
		fmt.Println("[NEXT STEPS]")
		for _, port := range killed {
			fmt.Printf("  - Verify port %s is free: lsof -i :%s\n", port, port)
		}
	}

	os.Exit(exitCode)
}

type killResult struct {
	success bool
	reason  string
}

func killPort(port string) killResult {
	// Find PIDs using the port
	cmd := exec.Command("lsof", "-t", "-i", ":"+port)
	output, err := cmd.Output()

	if err != nil {
		// No process found
		fmt.Printf("[ERROR] No process found on port %s\n", port)
		fmt.Printf("Suggestion: Run 'lsof -i :%s' to verify the port status\n", port)
		return killResult{success: false, reason: "no process found"}
	}

	// Parse PIDs
	pidStrings := strings.Fields(strings.TrimSpace(string(output)))
	if len(pidStrings) == 0 {
		fmt.Printf("[ERROR] No process found on port %s\n", port)
		fmt.Printf("Suggestion: Run 'lsof -i :%s' to verify the port status\n", port)
		return killResult{success: false, reason: "no process found"}
	}

	allKilled := true
	for _, pidStr := range pidStrings {
		pid, err := strconv.Atoi(pidStr)
		if err != nil {
			continue
		}

		// Get process name for better output
		processName := getProcessName(pid)

		// Try SIGTERM first
		err = syscall.Kill(pid, syscall.SIGTERM)
		if err != nil {
			if os.IsPermission(err) {
				fmt.Printf("[ERROR] Permission denied killing process %d (%s) on port %s\n", pid, processName, port)
				fmt.Printf("Suggestion: Try 'sudo kp %s' to kill with elevated privileges\n", port)
				allKilled = false
				continue
			}
			fmt.Printf("[ERROR] Failed to kill process %d (%s) on port %s: %v\n", pid, processName, port, err)
			allKilled = false
			continue
		}

		fmt.Printf("[SUCCESS] Killed process %d (%s) on port %s\n", pid, processName, port)
	}

	if allKilled {
		return killResult{success: true, reason: ""}
	}
	return killResult{success: false, reason: "permission denied"}
}

func getProcessName(pid int) string {
	// Try to get process name using ps
	cmd := exec.Command("ps", "-p", strconv.Itoa(pid), "-o", "comm=")
	output, err := cmd.Output()
	if err != nil {
		return "unknown"
	}
	name := strings.TrimSpace(string(output))
	if name == "" {
		return "unknown"
	}
	return name
}

func printHelp() {
	fmt.Printf(helpText, version)
}
