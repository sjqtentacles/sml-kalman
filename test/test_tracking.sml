(* test_tracking.sml -- 2-D constant-velocity model tracks a linear trajectory.

   State is [position, velocity]; F = [[1, dt],[0, 1]], H measures position
   only.  With Q = 0 and exact (noise-free) position measurements drawn from a
   true constant-velocity trajectory pos(t) = p0 + v*t, the filter's estimate
   converges to the true state: position tracks the trajectory and the velocity
   estimate approaches the true v. *)

structure TrackingTests =
struct
  open Support

  val dt = 1.0
  val p0true = 0.0
  val vtrue = 2.0
  fun truePos t = p0true + vtrue * t

  val model : K.model =
    { f = M.fromRows [[1.0, dt], [0.0, 1.0]]
    , b = M.fromRows [[0.0], [0.0]]
    , q = M.fromRows [[0.0, 0.0], [0.0, 0.0]]
    , h = M.fromRows [[1.0, 0.0]]
    , r = M.fromRows [[1.0]] }

  val steps = 30

  fun run () =
    let
      val init : K.state =
        { x = K.colVec [0.0, 0.0]
        , p = M.fromRows [[100.0, 0.0], [0.0, 100.0]] }
      val u = K.colVec [0.0]

      fun go (k, st) =
        if k > steps then st
        else
          let
            val z = K.colVec [truePos (real k)]
            val st' = K.step model { u = u, z = z } st
          in go (k + 1, st') end
      val final = go (1, init)

      val estPos = M.sub (#x final, 0, 0)
      val estVel = M.sub (#x final, 1, 0)

      val () = Harness.section "tracking: constant-velocity converges to truth"
      val () = checkApproxTol 1E~2 "velocity estimate -> true 2.0" (vtrue, estVel)
      val () = checkApproxTol 1E~2 "position estimate -> true pos"
                 (truePos (real steps), estPos)

      val () = Harness.section "tracking: covariance shrinks from diffuse prior"
      val varPos = M.sub (#p final, 0, 0)
      val varVel = M.sub (#p final, 1, 1)
      val () = Harness.check "position variance shrank below prior" (varPos < 100.0)
      val () = Harness.check "velocity variance shrank below prior" (varVel < 100.0)
      val () = Harness.check "variances positive" (varPos > 0.0 andalso varVel > 0.0)

      (* one-step prediction of position is consistent with the model *)
      val () = Harness.section "tracking: predict advances position by v*dt"
      val predState = K.predict model u final
      val () = checkApproxTol 1E~9 "x_pred = pos + vel*dt"
                 (estPos + estVel * dt, M.sub (#x predState, 0, 0))
    in
      ()
    end
end
