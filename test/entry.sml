(* entry.sml -- runs every deterministic suite and exits with a status code.
   Only the pure part of the tool (port parsing) is covered; the socket driver
   is impure and out of scope for the byte-identical guarantee. *)

fun runAllSuites () =
  ( Harness.reset ()
  ; PortTests.run ()
  ; Harness.run () )

fun main () =
  OS.Process.exit
    (if runAllSuites () then OS.Process.success else OS.Process.failure)
