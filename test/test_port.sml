(* test_port.sml -- deterministic tests for the one pure, unit-testable part of
   the otherwise impure socket tool: parsing a TCP port from a "host:port"
   authority. Everything else in HttpcTool opens real sockets and is not part of
   the byte-identical purity guarantee, so it is not exercised here.

   The port comes from the request URL (untrusted input). On this toolchain
   MLton's Int is 32-bit and Poly/ML's is 63-bit (both fixed width; only IntInf
   is arbitrary), so an unchecked Int.fromString raises Overflow on MLton for a
   value past 2^31 while Poly/ML would accept it -- a crash and a cross-compiler
   divergence. parsePort must instead return NONE for any out-of-range value. *)

structure PortTests =
struct
  open Harness

  (* Evaluate parsePort but turn a raise into a sentinel so a crash surfaces as
     a clean FAIL rather than aborting the binary. *)
  fun safePort s = (case HttpcTool.parsePort s of
                        SOME p => SOME p | NONE => NONE) handle _ => SOME ~999

  fun run () =
    let
      val () = section "parsePort: normal ports"
      val () = checkBool "80 parses"    (true, safePort "80" = SOME 80)
      val () = checkBool "443 parses"   (true, safePort "443" = SOME 443)
      val () = checkBool "8080 parses"  (true, safePort "8080" = SOME 8080)
      val () = checkBool "65535 parses" (true, safePort "65535" = SOME 65535)

      val () = section "parsePort: rejected without raising"
      val () = checkBool "empty -> NONE"       (true, safePort "" = NONE)
      val () = checkBool "non-numeric -> NONE" (true, safePort "http" = NONE)

      val () = section "parsePort: oversized (untrusted numeric input)"
      (* Just past 2^31: raises Overflow on MLton with an unchecked parse. *)
      val () = checkBool "2147483648 (2^31) -> NONE" (true, safePort "2147483648" = NONE)
      (* A 12-digit value: far past any fixed-width Int on MLton. *)
      val () = checkBool "999999999999 (12 digits) -> NONE" (true, safePort "999999999999" = NONE)
      (* Past 2^63 as well, so Poly/ML's wider Int would also overflow. *)
      val () = checkBool "99999999999999999999 (20 digits) -> NONE"
                 (true, safePort "99999999999999999999" = NONE)
    in () end
end
