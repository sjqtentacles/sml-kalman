(* demo.sml

   Runs a 2-D constant-velocity Kalman filter on a fixed, deterministic
   scenario: a true trajectory pos(t) = 2t corrupted by a baked-in (non-random)
   measurement-noise sequence.  Prints a table of true position, measurement,
   filtered position/velocity, and the position variance at each step.  Output
   is byte-identical across MLton and Poly/ML (fixed-decimal fmtD, no RNG).

   Build and run with `make example`. *)

structure K = Kalman
structure M = Matrix

fun fmt k x = Real.fmt (StringCvt.FIX (SOME k)) x
fun fmtD k x =
  let val s = fmt k x
  in if String.isPrefix "~" s then "-" ^ String.extract (s, 1, NONE) else s end
fun line s = print (s ^ "\n")
fun pad w s = StringCvt.padLeft #" " w s

val dt = 1.0
val vtrue = 2.0
fun truePos t = vtrue * t

(* a fixed deterministic "noise" sequence -- no RNG, fully reproducible *)
val noise = [0.5, ~0.4, 0.3, ~0.2, 0.6, ~0.5, 0.1, ~0.3, 0.4, ~0.1, 0.2, ~0.6]

val model : K.model =
  { f = M.fromRows [[1.0, dt], [0.0, 1.0]]
  , b = M.fromRows [[0.0], [0.0]]
  , q = M.fromRows [[0.0, 0.0], [0.0, 0.0]]
  , h = M.fromRows [[1.0, 0.0]]
  , r = M.fromRows [[0.25]] }

val init : K.state =
  { x = K.colVec [0.0, 0.0], p = M.fromRows [[10.0, 0.0], [0.0, 10.0]] }
val u = K.colVec [0.0]

val () = line "=== sml-kalman demo =========================================="
val () = line ""
val () = line "Constant-velocity tracking: true pos(t) = 2t, dt = 1,"
val () = line "  measurement = true + fixed offset, R = 0.25, Q = 0."
val () = line ""
val () = line (pad 4 "t" ^ " | " ^ pad 9 "true" ^ " | " ^ pad 9 "meas"
               ^ " | " ^ pad 9 "est_pos" ^ " | " ^ pad 9 "est_vel"
               ^ " | " ^ pad 9 "var_pos")
val () = line (CharVector.tabulate (66, fn _ => #"-"))

fun go (_, [], _) = ()
  | go (t, w :: ws, st) =
      let
        val tp = truePos (real t)
        val z = tp + w
        val st' = K.step model { u = u, z = K.colVec [z] } st
        val ep = M.sub (#x st', 0, 0)
        val ev = M.sub (#x st', 1, 0)
        val vp = M.sub (#p st', 0, 0)
      in
        line (pad 4 (Int.toString t) ^ " | " ^ pad 9 (fmtD 4 tp)
              ^ " | " ^ pad 9 (fmtD 4 z) ^ " | " ^ pad 9 (fmtD 4 ep)
              ^ " | " ^ pad 9 (fmtD 4 ev) ^ " | " ^ pad 9 (fmtD 4 vp));
        go (t + 1, ws, st')
      end

val () = go (1, noise, init)
val () = line ""
val () = line "==============================================================="
