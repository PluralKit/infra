package main

import (
	"context"
	"errors"
	"io"
	"os"
	"os/exec"
	"strconv"

	"github.com/jackc/pgconn"
)

func backupMessages() string {
	conn, err := pgconn.Connect(context.Background(), databaseUri)
	if err != nil {
		panic(err)
	}

	lastMessage := fetchLastBackedUpMessage(conn)

	borgCmd := exec.Command("borg", "create", "--compression", "zstd,3", "::messages"+dateStr, "-")
	borgCmd.Env = []string{
		"BORG_REPO=" + borgRepo,
		"BORG_PASSPHRASE=" + borgPassphrase,
	}

	rows := 0
	var lastRow []byte

	borgOutput, _ := borgCmd.StdoutPipe()
	borgStderr, _ := borgCmd.StderrPipe()
	go io.Copy(os.Stdout, borgOutput)
	go io.Copy(os.Stdout, borgStderr)

	borgPipe, _ := borgCmd.StdinPipe()
	borgPipe.Write([]byte("insert into messages values"))

	go func() {
		result := conn.ExecParams(context.Background(), "select * from messages where mid > $1", [][]byte{lastMessage}, nil, nil, nil)
		for result.NextRow() {
			if rows != 0 {
				borgPipe.Write([]byte(", "))
			}
			rows++
			borgPipe.Write([]byte("("))
			values := result.Values()
			for i, v := range values {
				borgPipe.Write(v)
				if i != len(values)-1 {
					borgPipe.Write([]byte(","))
				}
				if i == 0 {
					// kinda expensive, but ensures that `lastRow` will always get set to the mid of the last row processed
					lastRow = v
				}
			}
			borgPipe.Write([]byte(")"))
		}
		result.Close()
		borgPipe.Write([]byte(";"))
		if err = borgPipe.Close(); err != nil {
			panic(err)
		}
	}()

	borgCmd.Run()

	if borgCmd.ProcessState.ExitCode() != 0 {
		panic(errors.New("borg exited with code " + strconv.Itoa(borgCmd.ProcessState.ExitCode())))
	}

	saveLastBackedUpMessage(conn, lastRow)

	return "Backed up " + strconv.Itoa(rows) + " rows, new last message ID: " + string(lastRow)
}

func fetchLastBackedUpMessage(conn *pgconn.PgConn) []byte {
	result := conn.ExecParams(context.Background(), "select last_backup_mid from info", nil, nil, nil, nil)
	defer func() {
		if _, err := result.Close(); err != nil {
			panic(err)
		}
	}()
	result.NextRow()
	return result.Values()[0]
}

func saveLastBackedUpMessage(conn *pgconn.PgConn, lastMessage []byte) {
	result := conn.ExecParams(context.Background(), "update info set last_backup_mid = $1", [][]byte{lastMessage}, nil, nil, nil)
	result.NextRow()
	if _, err := result.Close(); err != nil {
		panic(err)
	}
}
