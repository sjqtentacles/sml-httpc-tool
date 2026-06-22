(* httpc_tool.sml -- impure TCP socket driver around the pure Httpc core.

   IMPURE / quarantined: opens sockets, blocks on the network, non-deterministic.
   Keep all protocol logic in the pure core; this file is only byte transport. *)

structure HttpcTool :> HTTPC_TOOL =
struct
  exception ToolError of string

  type request =
    { method : string, url : string, headers : (string * string) list, body : string }

  (* string <-> Word8Vector for the socket API (one char per byte, 0-255). *)
  fun toBytes s =
    Word8Vector.tabulate (String.size s, fn i =>
      Word8.fromInt (Char.ord (String.sub (s, i))))

  fun fromBytes v =
    CharVector.tabulate (Word8Vector.length v, fn i =>
      Char.chr (Word8.toInt (Word8Vector.sub (v, i))))

  (* Split "host:port" (port always present -- buildRequest fills the default).
     Handles [ipv6]:port literals. *)
  fun splitHostPort hp =
    let
      fun lastColon s =
        let fun go i = if i < 0 then NONE
                       else if String.sub (s, i) = #":" then SOME i else go (i - 1)
        in go (String.size s - 1) end
    in
      if String.size hp > 0 andalso String.sub (hp, 0) = #"[" then
        (case CharVector.findi (fn (_, c) => c = #"]") hp of
           SOME (j, _) =>
             let val host = String.substring (hp, 1, j - 1) (* strip [ ] *)
                 val rest = String.extract (hp, j + 1, NONE)
                 val port = if String.size rest > 0 andalso String.sub (rest, 0) = #":"
                            then String.extract (rest, 1, NONE) else ""
             in (host, port) end
         | NONE => (hp, ""))
      else
        (case lastColon hp of
           SOME i => (String.substring (hp, 0, i), String.extract (hp, i + 1, NONE))
         | NONE => (hp, ""))
    end

  fun resolve host =
    case NetHostDB.getByName host of
      SOME e => NetHostDB.addr e
    | NONE => raise ToolError ("cannot resolve host: " ^ host)

  (* Send a request's bytes and drive the pure decoder to a complete response. *)
  fun exchange (conn0, hostport, bytes) =
    let
      val (host, portStr) = splitHostPort hostport
      val port = case Int.fromString portStr of
                   SOME p => p
                 | NONE => raise ToolError ("bad port: " ^ portStr)
      val addr = INetSock.toAddr (resolve host, port)
      val sock = INetSock.TCP.socket ()
    in
      let
        val () = Socket.connect (sock, addr)
        val () = ignore (Socket.sendVec (sock, Word8VectorSlice.full (toBytes bytes)))
        fun pump conn =
          let val chunk = Socket.recvVec (sock, 65536)
          in
            if Word8Vector.length chunk = 0 then
              (* peer closed: signal end-of-stream to the pure core *)
              (case Httpc.finish conn of
                 Httpc.Complete r => #response r
               | Httpc.Failed m => raise ToolError ("incomplete response: " ^ m)
               | Httpc.NeedMore _ => raise ToolError "connection closed mid-response")
            else
              (case Httpc.feed conn (fromBytes chunk) of
                 Httpc.Complete r => #response r
               | Httpc.NeedMore cn => pump cn
               | Httpc.Failed m => raise ToolError ("protocol error: " ^ m))
          end
        val resp = pump conn0
      in
        Socket.close sock; resp
      end handle e => (Socket.close sock handle _ => (); raise e)
    end

  fun fetch (req : request) =
    let
      val {hostport, bytes} = Httpc.buildRequest req
      val conn = Httpc.newConnForMethod (#method req)
    in exchange (conn, hostport, bytes) end

  fun fetchFollow maxRedirects (req : request) =
    let
      fun go (req, n) =
        let val resp = fetch req
        in
          if n <= 0 then resp
          else case Httpc.redirectTarget {request = req, response = resp} of
                 NONE => resp
               | SOME url' =>
                   let
                     val toGet = #status resp = 303
                     val method' = if toGet then "GET" else #method req
                     val body' = if toGet then "" else #body req
                   in
                     go ({method = method', url = url', headers = #headers req, body = body'}, n - 1)
                   end
        end
    in go (req, maxRedirects) end
end
