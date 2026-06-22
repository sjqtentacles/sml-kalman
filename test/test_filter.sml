(* test_filter.sml -- 1-D constant-position filter.

   With F = [1], Q = 0, H = [1], constant R, and a diffuse prior, the Kalman
   filter reduces to the running mean of the measurements, and its variance
   reduces toward R/n.  We feed a fixed list of measurements whose mean is
   exactly 5.0 and check that:
     - the estimate converges to the measurement mean,
     - the posterior variance shrinks (P_final << P_0), approaching R/n. *)

structure FilterTests =
struct
  open Support

  val measurements = [4.8, 5.2, 4.9, 5.1, 5.0, 4.7, 5.3, 5.0]   (* mean = 5.0 *)
  val n = length measurements

  val model : K.model =
    { f = M.fromRows [[1.0]]
    , b = M.fromRows [[0.0]]
    , q = M.fromRows [[0.0]]
    , h = M.fromRows [[1.0]]
    , r = M.fromRows [[1.0]] }

  val p0 = 1.0E6

  fun run () =
    let
      val init : K.state = { x = K.colVec [0.0], p = M.fromRows [[p0]] }
      val final =
        List.foldl (fn (z, st) => K.update model (K.colVec [z]) st) init measurements
      val estimate = head (#x final)
      val variance = at (#p final, 0, 0)

      val () = Harness.section "filter: constant-position -> measurement mean"
      val () = checkApproxTol 1E~3 "estimate converges to mean 5.0" (5.0, estimate)

      val () = Harness.section "filter: variance reduction"
      val () = Harness.check "posterior variance << prior" (variance < p0)
      val () = checkApproxTol 1E~3 "posterior variance ~ R/n = 1/8"
                 (1.0 / real n, variance)
      val () = Harness.check "posterior variance positive" (variance > 0.0)

      (* monotone decrease step by step *)
      val () = Harness.section "filter: monotone variance decrease"
      val seq =
        let
          fun go ([], st, acc) = List.rev (at (#p st, 0, 0) :: acc)
            | go (z :: zs, st, acc) =
                go (zs, K.update model (K.colVec [z]) st, at (#p st, 0, 0) :: acc)
        in go (measurements, init, []) end
      fun nonIncreasing (a :: b :: rest) = a >= b andalso nonIncreasing (b :: rest)
        | nonIncreasing _ = true
      val () = Harness.check "variance is non-increasing across steps"
                 (nonIncreasing seq)
    in
      ()
    end
end
