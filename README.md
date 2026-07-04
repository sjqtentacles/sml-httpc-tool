# sml-httpc-tool

> **Status: IMPURE TOOL — not part of the dual-compiler purity guarantee.**

The quarantined **TCP socket driver** for the pure
[`sml-httpc`](https://github.com/sjqtentacles/sml-httpc) HTTP/1.1 client state
machine. This is the one place where the HTTP client touches the outside world:
it opens real sockets, resolves DNS, and blocks on the network. Everything that
can be pure — request building, response framing, chunked reassembly,
keep-alive and redirect decisions — stays in the pure `sml-httpc` core; this
repo is only the thin byte-pump that connects that core to a socket.

This mirrors the established sjqtentacles convention (the `sml-readline`
pure-core / future-driver split, and `sml-serve` as the impure edge of the web
stack): **the portable, tested, deterministic artifact is the pure state
machine; the IO tool is a thin, compiler-specific, unguaranteed driver.**

## What "impure / not guaranteed" means here

- **Non-deterministic.** `fetch` talks to a live remote host; its result
  depends on the network, not just its inputs. It is therefore **not** part of
  the byte-identical dual-compiler test suite.
- **Almost no deterministic tests.** The protocol logic is fully tested in the
  pure `sml-httpc` core against captured fixtures. The socket driver itself is
  checked only by **compile** (CI builds the CLI under MLton and compile-checks
  the sources under Poly/ML) and an optional manual `make smoke` (network). The
  one genuinely pure part of the tool — `parsePort`, which parses a TCP port
  from an untrusted URL authority — **is** covered by a small byte-identical
  suite (`make test` / `make test-poly`). It range-checks the port via `IntInf`,
  bounded to a fixed 32-bit signed range, so an oversized value (past 2^31, or a
  12-digit number) returns `NONE` instead of raising `Overflow`. That matters
  because on this toolchain MLton's `Int` is 32-bit and Poly/ML's is 63-bit
  (both fixed width; only `IntInf` is arbitrary precision), so an unchecked
  parse would crash on MLton and diverge from Poly/ML.
- **Plain HTTP only.** No TLS. HTTPS support waits for a future `sml-tls`; for
  now `https://` URLs would connect on port 443 in cleartext and fail. Use
  `http://` URLs.

## Build

```
make build       # build bin/httpc with MLton
make test        # run the deterministic parsePort suite under MLton
make test-poly   # run the deterministic parsePort suite under Poly/ML
make all-tests   # both (byte-identical output)
make poly-check  # compile-check all sources under Poly/ML (no network)
make smoke       # build, then GET http://example.com (REQUIRES NETWORK)
make clean
```

## CLI usage

```
httpc URL                 # GET URL (following redirects), print the body
httpc -i URL              # also print the status line + response headers
httpc METHOD URL          # explicit method (GET, HEAD, ...)
httpc -i METHOD URL       # both
```

Example:

```
$ ./bin/httpc -i http://example.com/
HTTP/1.1 200 OK
Content-Type: text/html
Transfer-Encoding: chunked
Connection: keep-alive
...

<!doctype html><html ...>...</html>
```

## Library API

```sml
exception ToolError of string

type request =
  { method : string, url : string, headers : (string * string) list, body : string }

val fetch       : request -> Http.response          (* one request, no redirects *)
val fetchFollow : int -> request -> Http.response   (* follow up to N 3xx hops *)
val parsePort   : string -> int option              (* pure; NONE if out of range *)
```

`fetch` builds the request with `Httpc.buildRequest`, connects, sends the bytes,
and drives `Httpc.feed`/`Httpc.finish` over the received bytes until the pure
core reports a complete response — then returns that `Http.response`.
`fetchFollow` chases 3xx redirects via `Httpc.redirectTarget` (a 303 switches to
`GET` and drops the body; other redirects keep the method), up to the given
limit.

## Layout

Layout B. Vendors the pure `sml-httpc` core (and its `sml-http` + `sml-uri`
dependencies) under `lib/`. The socket code is the only impure part:
`src/httpc_tool.sml` (Basis `Socket` / `INetSock` / `NetHostDB`).

## License

MIT — see [LICENSE](LICENSE).
