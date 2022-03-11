package main

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi"
)

func main() {
	webhook, ok := os.LookupEnv("WEBHOOK")
	if !ok {
		panic("Failed to get webhook from environment")
	}

	r := chi.NewRouter()

	r.Get("/config", func(rw http.ResponseWriter, r *http.Request) {
		http.ServeFile(rw, r, "pluralkit.conf")
	})

	r.Post("/notify", func(rw http.ResponseWriter, r *http.Request) {
		h, _ := ioutil.ReadAll(r.Body)

		go func() {
			json, _ := json.Marshal(map[string]string{"content": "[" + time.Now().Format("15:04:05") + "] " + string(h)})
			http.Post(webhook, "application/json", bytes.NewBuffer(json))
		}()
	})

	http.ListenAndServe(":8881", r)
}
