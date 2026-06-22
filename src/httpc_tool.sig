(* httpc_tool.sig

   The IMPURE, quarantined socket driver for the pure sml-httpc state machine.

   This is a TOOL, not a pure library. It opens real TCP sockets (Basis
   Socket / INetSock / NetHostDB), performs blocking network I/O, and is
   therefore:
     - NOT deterministic (its result depends on a live network and remote host);
     - NOT part of the dual-compiler byte-identical purity guarantee;
     - tested only by smoke / integration, never in the deterministic suite.

   All of the protocol logic -- request building, response framing, chunked
   reassembly, keep-alive and redirect decisions -- lives in the pure
   `sml-httpc` core. This module is only the thin byte-pump that connects it to
   a socket. TLS is out of scope (plain HTTP only) until an `sml-tls` exists. *)

signature HTTPC_TOOL =
sig
  exception ToolError of string

  type request =
    { method : string, url : string, headers : (string * string) list, body : string }

  (* Open a TCP connection to the URL's host, send the request, drive the pure
     decoder over the received bytes, and return the decoded response. Plain
     HTTP only (no TLS). Does NOT follow redirects. Raises ToolError on a DNS,
     connect, or protocol failure. *)
  val fetch : request -> Http.response

  (* As `fetch`, but follow up to `maxRedirects` 3xx redirects (a 303 switches
     to GET and drops the body; other redirects keep the method). *)
  val fetchFollow : int -> request -> Http.response
end
