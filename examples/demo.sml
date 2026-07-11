(* demo.sml - build and decode HTTP messages entirely in memory using the pure
   sml-uri/sml-http/sml-httpc core that sml-httpc-tool wraps with a socket
   driver. No sockets are opened here; parsePort is the tool's own pure,
   unit-testable surface. Deterministic: identical output on every run and
   under both compilers. *)

val () = print "HttpcTool.parsePort on sample authorities:\n"
val () = List.app
           (fn s => print ("  " ^ s ^ " -> "
                          ^ (case HttpcTool.parsePort s of
                                 SOME p => Int.toString p
                               | NONE => "NONE") ^ "\n"))
           ["8080", "443", "", "99999999999999999999"]

val req = { method = "GET", url = "http://example.com/status?fast=1"
          , headers = [("Accept", "text/plain")], body = "" }
val built = Httpc.buildRequest req
val () = print ("\nHttpc.buildRequest for GET " ^ #url req ^ ":\n")
val () = print ("  hostport = " ^ #hostport built ^ "\n")
val () = print ("  bytes    =\n" ^ #bytes built)

val raw = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhello"
val () = print "\nDecoding a canned response with Httpc.newConn/feed:\n"
val () =
  case Httpc.feed (Httpc.newConn ()) raw of
      Httpc.Complete {response, keepAlive, leftover = _} =>
        print ("  status    = " ^ Int.toString (#status response) ^ " " ^ #reason response
              ^ "\n  body      = " ^ #body response
              ^ "\n  keepAlive = " ^ Bool.toString keepAlive ^ "\n")
    | Httpc.NeedMore _ => print "  need more bytes\n"
    | Httpc.Failed msg => print ("  failed: " ^ msg ^ "\n")

val redirectResp = Http.redirectWith 302 "/new-place"
val target = Httpc.redirectTarget { request = req, response = redirectResp }
val () = print ("\nHttpc.redirectTarget for a 302 to \"/new-place\": "
               ^ (case target of SOME u => u | NONE => "NONE") ^ "\n")
