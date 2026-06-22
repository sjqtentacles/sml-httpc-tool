(* httpc.sml -- a tiny command-line HTTP/1.1 client built on the impure socket
   driver. Usage:

     httpc URL                 fetch URL (following redirects), print the body
     httpc -i URL              also print the status line and response headers
     httpc METHOD URL          use an explicit method (GET, HEAD, ...)
     httpc -i METHOD URL       both

   Plain HTTP only (no TLS). This is the IMPURE tool: it makes real network
   requests and is not deterministic. *)

fun err s = (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.exit OS.Process.failure)

fun printHead (resp : Http.response) =
  ( print (#version resp ^ " " ^ Int.toString (#status resp) ^ " " ^ #reason resp ^ "\n")
  ; List.app (fn (k, v) => print (k ^ ": " ^ v ^ "\n")) (Headers.toList (#headers resp))
  ; print "\n" )

fun run (showHead, method, url) =
  let
    val resp = HttpcTool.fetchFollow 5
                 {method = method, url = url, headers = [("Accept", "*/*")], body = ""}
  in
    if showHead then printHead resp else ();
    print (#body resp);
    OS.Process.exit OS.Process.success
  end
  handle HttpcTool.ToolError m => err ("httpc: " ^ m)
       | e => err ("httpc: " ^ exnMessage e)

val () =
  case CommandLine.arguments () of
    ["-i", method, url]  => run (true,  method, url)
  | ["-i", url]          => run (true,  "GET",  url)
  | [method, url]        => run (false, method, url)
  | [url]                => run (false, "GET",  url)
  | _ => err "usage: httpc [-i] [METHOD] URL"
