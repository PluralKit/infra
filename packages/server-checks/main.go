package main

import (
	"os"
	"log"
	"fmt"
	"time"
	"encoding/json"
	"strings"
	"runtime/debug"
	"net/http"
)

var stateFile = "/run/server-checks.json"

func main() {
	switch len(os.Args) {
	case 1:
		break
	case 2:
		switch os.Args[1] {
		case "agent":
			runAgent()
			return
		case "check-now":
			task_main()
		default:
			log.Fatalf("unknown command %v, try `check-now` or `agent`\n", os.Args[1])
		}
	default:
		log.Fatalln("too many arguments")
	}

	log.Println("getting latest check status")

	f, err := os.ReadFile(stateFile)
	if err != nil {
		log.Fatalln(err)
	}

	var d runfile
	if err := json.Unmarshal(f, &d); err != nil {
		log.Fatalln(err)
	}

	checkAge := int(time.Now().UTC().Unix()) - d.Ts

	if checkAge > 60 {
		log.Println("warn: last check too old (%v seconds ago)!\n", checkAge)
	}

	if len(d.Errors) > 0 {
		log.Printf("last check (%v seconds ago) was failing:\n", checkAge)
		log.Fatalf("failing checks:\n - %v\n", strings.Join(d.Errors, "\n - "))
	}

	log.Printf("all checks ok! last check was %v seconds ago\n", checkAge)
}

func runAgent() {
	log.Println("starting server-checks agent")
	go runAgentWebserver()
	wait_until_next_minute()
	doforever(time.Minute, withtime("server-checks", task_main))
}

func runAgentWebserver() {
	http.HandleFunc("/checks", func(rw http.ResponseWriter, _ *http.Request) {
		d, err := os.ReadFile(stateFile)
		if err != nil {
			log.Println(fmt.Sprintf("serve http: %v", err))
			rw.WriteHeader(500)
		} else {
			rw.Write(d)
		}
	})
	log.Fatal(http.ListenAndServe(":19999", nil))
}

func wait_until_next_minute() {
	now := time.Now().UTC().Add(time.Minute)
	after := time.Date(now.Year(), now.Month(), now.Day(), now.Hour(), now.Minute(), 0, 0, time.UTC)
	time.Sleep(after.Sub(time.Now().UTC()))
}

func withtime(name string, todo func()) func() {
	return func() {
		timeBefore := time.Now()
		todo()
		timeAfter := time.Now()
		log.Println("ran", name, "in", timeAfter.Sub(timeBefore).String())
	}
}

func doforever(dur time.Duration, todo func()) {
	for {
		go wrapRecover(todo)
		time.Sleep(dur)
	}
}

func wrapRecover(todo func()) {
	defer func() {
		if err := recover(); err != nil {
			// no sentry here

			stack := strings.Split(string(debug.Stack()), "\n")
			stack = stack[7:]
			log.Printf("error running tasks: %v\n", err)
			fmt.Println(strings.Join(stack, "\n"))
		}
	}()

	todo()
}
