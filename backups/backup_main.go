package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
)

func backupMain() string {
	postgresCmd := exec.Command("pg_dump", databaseUri, "-T", "messages", "-Z0")

	borgCmd := exec.Command("borg", "create", "--compression", "zstd,3", "::maindb"+dateStr, "-")
	borgCmd.Env = []string{
		"BORG_REPO=" + borgRepo,
		"BORG_PASSPHRASE=" + borgPassphrase,
	}

	postgresPipe, _ := postgresCmd.StdoutPipe()
	borgPipe, _ := borgCmd.StdinPipe()

	var bytesBackedUp int64

	postgresStderr, _ := postgresCmd.StderrPipe()
	go io.Copy(os.Stdout, postgresStderr)

	borgOutput, _ := borgCmd.StdoutPipe()
	borgStderr, _ := borgCmd.StderrPipe()
	go io.Copy(os.Stdout, borgOutput)
	go io.Copy(os.Stdout, borgStderr)

	go func() {
		if w, err := io.Copy(borgPipe, postgresPipe); err != nil {
			panic(err)
		} else {
			if err = borgPipe.Close(); err != nil {
				panic(err)
			}
			bytesBackedUp = w
		}
	}()

	go postgresCmd.Run()
	borgCmd.Run()

	if borgCmd.ProcessState.ExitCode() != 0 {
		panic(errors.New("borg exited with code " + strconv.Itoa(borgCmd.ProcessState.ExitCode())))
	}

	if postgresCmd.ProcessState.ExitCode() != 0 {
		panic(errors.New("pg_dump exited with code " + strconv.Itoa(borgCmd.ProcessState.ExitCode())))
	}

	fmt.Println()
	fmt.Println()

	return "Backed up " + strconv.Itoa(int(bytesBackedUp)) + " bytes"
}
