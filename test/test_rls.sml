(* test_rls.sml -- recursive least squares recovers exact coefficients.

   With noise-free data y_k = phi_k . theta_true and a diffuse prior
   (P0 = delta*I, delta large), RLS converges to the ordinary least-squares fit,
   which on consistent exact data is theta_true itself.  We check recovery of:
     1. a 2-coefficient line  y = 3x + 2,
     2. a 3-coefficient linear system theta = [2, -3, 1]. *)

structure RlsTests =
struct
  open Support

  val delta = 1.0E8

  fun feed est pairs =
    List.foldl (fn ((phi, y), e) => K.RLS.update 1.0 e { phi = K.colVec phi, y = y })
      est pairs

  fun run () =
    let
      val () = Harness.section "rls: recover line y = 3x + 2"
      (* phi = [x, 1]; y = 3x + 2 exactly *)
      val linePts =
        List.map (fn x => ([x, 1.0], 3.0 * x + 2.0))
          [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
      val est1 = feed (K.RLS.init 2 delta) linePts
      val c1 = K.RLS.coeffs est1
      val () = checkVec 1E~4 "line coeffs = [3, 2]" ([3.0, 2.0], c1)

      val () = Harness.section "rls: recover 3-coefficient system [2,-3,1]"
      val thetaTrue = [2.0, ~3.0, 1.0]
      fun dot (a, b) = ListPair.foldl (fn (x, y, s) => s + x * y) 0.0 (a, b)
      val phis =
        [ [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]
        , [1.0, 1.0, 1.0], [1.0, 2.0, 3.0], [2.0, ~1.0, 0.5]
        , [0.5, 0.5, 2.0], [3.0, 1.0, ~1.0] ]
      val sys = List.map (fn phi => (phi, dot (phi, thetaTrue))) phis
      val est2 = feed (K.RLS.init 3 delta) sys
      val c2 = K.RLS.coeffs est2
      val () = checkVec 1E~4 "system coeffs = [2,-3,1]" (thetaTrue, c2)

      val () = Harness.section "rls: predictions are exact after recovery"
      (* with theta recovered, prediction phi.theta matches y on a fresh phi *)
      val phiNew = [4.0, ~2.0, 3.0]
      val pred = dot (phiNew, c2)
      val () = checkApproxTol 1E~4 "prediction matches true model"
                 (dot (phiNew, thetaTrue), pred)
    in
      ()
    end
end
