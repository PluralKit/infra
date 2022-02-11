package main

import (
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/hako/durafmt"
)

// config
var (
	databaseUri          string // "postgresql://pluralkit:password@172.17.0.1:5432/pluralkit"
	borgRepo             string //  "root@127.0.0.1:/mnt/pluralkit"
	borgPassphrase       string // "averysecuresecret"
	notificationsWebhook string // "https://discord.com/api/v9/webhooks/id/token"

	// databaseUri          = "postgresql://postgres:postgres@127.0.0.1:5432/pluralkitdev"
	// borgRepo             = "/tmp/test"
	// borgPassphrase       = "h"
	// notificationsWebhook = "https://discord.com/api/webhooks/883887734761091093/e5TQt_FW-bz6QG84qftvQV7krTWcWzKYZjBnU3oT000a5NXgiSccSnZ-5hVWtGwGxvCE"
)

var dateStr string

func init() {
	databaseUri = loadEnvOrPanic("DATABASE_URI")
	borgRepo = loadEnvOrPanic("BORG_REPO")
	borgPassphrase = loadEnvOrPanic("BORG_PASSPHRASE")
	notificationsWebhook = loadEnvOrPanic("WEBHOOK_URL")

	date := time.Now()
	dateStr = strings.Join([]string{
		strconv.Itoa(date.Year()),
		strconv.Itoa(int(date.Month())),
		strconv.Itoa(date.Day()),
	}, "-")
}

func loadEnvOrPanic(name string) string {
	if val, ok := os.LookupEnv(name); !ok || val == "" {
		panic("Failed to load env key '" + name + "', is it present?")
	} else {
		return val
	}
}

func log(text string) {
	if len(text) > 2000 {
		text = text[:1990] + " (...)"
	}

	http.PostForm(notificationsWebhook, url.Values{
		"content":  {text},
		"username": {"backup logs"},
	})
}

func runner(name string, fn func() string) {
	var output string

	timeBegin := time.Now()

	defer func() {
		duration := time.Since(timeBegin)
		durStr := durafmt.Parse(duration).String()

		if err := recover(); err != nil {
			log("<@840806601957965864>, Job \"" + name + "\" threw error (in " + durStr + "): " + (err.(error)).Error())
			panic(err)
		} else {
			log("Job \"" + name + "\" successful (in " + durStr + "), output: " + output)
		}
	}()

	output = fn()
}

func main() {
	log("Starting backup job for " + dateStr)
	runner("main backup", backupMain)
	runner("messages backup", backupMessages)
}
