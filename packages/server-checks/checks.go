package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/coreos/go-systemd/v22/dbus"
)

type runfile struct {
	Ts     int64    `json:"ts"`
	Errors []string `json:"errors"`
}

type check struct {
	Type  string `json:"type"`
	Value string `json:"value"`
	any   `json:"data"`
}

// main check runner function
// this is wrapped in wrapRecover but checks SHOULD NOT PANIC
// instead, print it and add it to the errors array
func task_main() {
	// load checks from /etc/server-check/checks.json
	// this is an implicit basic check that reading a file works
	f, err := os.ReadFile("/etc/server-checks/checks.json")
	if err != nil {
		panic(fmt.Sprintf("failed to read checks file: %v", err))
	}

	var checks []check
	if err := json.Unmarshal(f, &checks); err != nil {
		panic(fmt.Sprintf("failed to unmarshal checks file: %v", err))
	}

	// sanity checks (pun not intended)
	if len(checks) < 1 {
		panic("no checks to run!")
	}

	// fetch systemd unit state (this is used in multiple checks)
	conn, err := dbus.NewSystemConnection()
	if err != nil {
		panic(fmt.Sprintf("failed to connect to systemd: %v", err))
	}
	defer conn.Close()

	units, err := conn.ListUnits()
	if err != nil {
		panic(fmt.Sprintf("failed to list systemd units: %v", err))
	}

	errors := []string{}

	// run checks
	for _, c := range checks {
		if err := do_check_run(units, c); err != "" {
			key := fmt.Sprintf("%v %v", c.Type, c.Value)
			errors = append(errors, fmt.Sprintf("%v: %v", key, err))
			fmt.Printf("check %v FAIL: %v\n", key, err)
		}
	}

	d := runfile{
		Ts:     time.Now().UTC().Unix(),
		Errors: errors,
	}

	out, err := json.Marshal(d)
	if err != nil {
		panic("failed to marshal output")
	}

	if err := os.WriteFile(stateFile, out, 0644); err != nil {
		panic("failed to write to state file")
	}
}

func do_check_run(units []dbus.UnitStatus, c check) string {
	switch c.Type {
	case "systemd_no_failing_services":
		failing_units := []string{}
		for _, u := range units {
			if u.ActiveState == "failed" {
				failing_units = append(failing_units, u.Name)
			}
		}
		if len(failing_units) > 0 {
			return strings.Join(failing_units, ", ")
		} else {
			log.Println("no systemd units failing")
		}
	case "systemd_service_running":
		name := c.Value
		if !strings.HasSuffix(name, ".service") {
			name += ".service"
		}
		found := false
		for _, u := range units {
			if name == u.Name {
				found = true
				if u.ActiveState == "active" && u.SubState == "running" {
					log.Printf("systemd service %v is running", c.Value)
				} else {
					return fmt.Sprintf("service is in unexpected state %v (%v)", u.ActiveState, u.SubState)
				}
			}
		}
		if !found {
			return "could not find service"
		}
	case "script":
		scriptName := c.Value
		cmd := exec.Command("/run/wrappers/bin/sudo", "-u", "nobody", scriptName)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			if exitError, ok := err.(*exec.ExitError); ok {
				code := exitError.ExitCode()
				return fmt.Sprintf("script exited with code %v", code)
			} else {
				return fmt.Sprintf("failed to run script: %v", err)
			}
		} else {
			log.Printf("successfully ran script %s", scriptName)
		}
	default:
		return fmt.Sprintf("unknown check type %v", c.Type)
	}

	return ""
}
