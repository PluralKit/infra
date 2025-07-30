package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime/debug"
	"strings"
	"time"
)

var stateFile = "/run/server-checks.json"
var checkId, checkToken string

func main() {
	switch len(os.Args) {
	case 1:
		break
	case 2:
		switch os.Args[1] {
		case "agent":
			checkId = os.Getenv("NODEPING_CHECK_ID")
			checkToken = os.Getenv("NODEPING_CHECK_TOKEN")
			if len(checkId) == 0 || len(checkToken) == 0 {
				log.Fatalf("missing nodeping id/token!")
			}
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

	checkAge := time.Now().UTC().Unix() - d.Ts

	if checkAge > 60 {
		log.Printf("warn: last check too old (%v seconds ago)!\n", checkAge)
	}

	if len(d.Errors) > 0 {
		log.Printf("last check (%v seconds ago) was failing:\n", checkAge)
		log.Fatalf("failing checks:\n - %v\n", strings.Join(d.Errors, "\n - "))
	}

	log.Printf("all checks ok! last check was %v seconds ago\n", checkAge)
}

func runAgent() {
	log.Println("starting server-checks agent")
	wait_until_next(60 * time.Second)
	go doforever(time.Second*60, withtime("server-checks", task_main))
	time.Sleep(30 * time.Second)
	doforever(time.Second*60, nodepingHeartbeat)
}

type NodePingPayload struct {
	Data struct {
		CheckAge  int64 `json:"check_age"`
		NumFailed int   `json:"num_failed"`
	} `json:"data"`
}

func nodepingHeartbeat() {
	stateRaw, err := os.ReadFile(stateFile)
	if err != nil {
		log.Printf("read err: %v", err)
		return
	}
	var state runfile
	err = json.Unmarshal(stateRaw, &state)
	if err != nil {
		log.Printf("json parse err: %v", err)
		return
	}

	payloadData := NodePingPayload{}
	payloadData.Data.CheckAge = time.Now().Unix() - state.Ts
	payloadData.Data.NumFailed = len(state.Errors)
	payload, err := json.Marshal(payloadData)
	if err != nil {
		log.Printf("json marshal err: %v", err)
		return
	}

	resp, err := http.Post(fmt.Sprintf("https://push.nodeping.com/v1?id=%s&checktoken=%s", checkId, checkToken), "application/json", bytes.NewBuffer(payload))
	if err != nil {
		log.Printf("http err: %v", err)
		return
	}
	defer resp.Body.Close()
}

func wait_until_next(period time.Duration) {
	if period <= 0 {
		log.Fatalf("invalid time period of %v", period)
	}
	now := time.Now().UTC()
	next := now.Truncate(period).Add(period)
	time.Sleep(next.Sub(now))
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
