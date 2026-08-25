# rpc-backend-sse

SSE JSON-RPC transport for rpc-protocol.

Part of [cl-stack](https://github.com/egao1980/cl-stack) agent-wire ([brief](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/agent-wire.md)).

```lisp
(asdf:load-system "rpc-backend-sse")

;; POST JSON-RPC, reply is one SSE data: event
(rpc-protocol:rpc-call "echo" "hi"
  :transport (rpc-backend-sse:make-sse-rpc-transport
              :url "http://127.0.0.1:8080/rpc"))
```

`sbcl --load scripts/live-sse-rpc.lisp`

CI: canned [`cl-repository`](https://github.com/egao1980/cl-repository) (`test-system.yml` / `setup-client` + `ci`). Deps from `ghcr.io/egao1980/cl-systems`.

## License

MIT
