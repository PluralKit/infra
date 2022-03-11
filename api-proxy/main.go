package main

import (
	"errors"
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/go-redis/redis_rate/v9"
)

var proxy *httputil.ReverseProxy

var limiter *redis_rate.Limiter

var token2 string

// todo: be able to raise ratelimits for >1 consumers

func init() {
	if val, ok := os.LookupEnv("REMOTE_ADDR"); !ok {
		panic(errors.New("missing `REMOTE_ADDR` in environment"))
	} else {
		remote, err := url.Parse(val)
		if err != nil {
			panic(err)
		}
		proxy = httputil.NewSingleHostReverseProxy(remote)
	}

	if val2, ok := os.LookupEnv("REDIS_ADDR"); !ok {
		panic(errors.New("missing `REDIS_ADDR` in environment"))
	} else {
		rdb := redis.NewClient(&redis.Options{Addr: val2})
		limiter = redis_rate.NewLimiter(rdb)
	}

	if val3, ok := os.LookupEnv("TOKEN2"); !ok {
		panic(errors.New("missing `TOKEN2` in environment"))
	} else {
		token2 = val3
	}
}

type ProxyHandler struct{}

func (p ProxyHandler) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	var limit int
	var key string

	if r.Header.Get("X-PluralKit-App") == token2 {
		limit = 20
		key = "token2"
	} else {
		limit = 2
		// proxy_set_header X-Real-IP $remote_addr;
		key = r.Header.Get("X-Real-IP")
	}

	res, err := limiter.Allow(r.Context(), "ratelimit:"+key, redis_rate.Limit{
		Period: time.Second,
		Rate:   limit,
		Burst:  5,
	})
	if err != nil {
		panic(err)
	}

	rw.Header().Set("X-RateLimit-Limit", fmt.Sprint(limit))
	rw.Header().Set("X-RateLimit-Remaining", fmt.Sprint(res.Remaining))
	rw.Header().Set("X-RateLimit-Reset", fmt.Sprint(time.Now().Add(res.ResetAfter).UnixNano()/1_000_000))

	if res.Allowed < 1 {
		// CORS headers
		rw.Header().Add("Access-Control-Allow-Credentials", "true")
		rw.Header().Add("Access-Control-Request-Method", r.Method)
		rw.Header().Add("Access-Control-Allow-Origin", "*")

		rw.WriteHeader(429)
		rw.Write([]byte(`{"message":"429: too many requests","retry_after":` + fmt.Sprint(res.RetryAfter.Milliseconds()) + `,"code":0}`))
		return
	}

	proxy.ServeHTTP(rw, r)
}

func main() {
	http.ListenAndServe(":8080", ProxyHandler{})
}
