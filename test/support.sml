(* support.sml -- shared helpers for the sml-kalman tests.

   Filter estimates, covariances, and RLS coefficients are floating point, so
   the suite compares against analytic targets through an explicit epsilon
   rather than string/structural equality (`Real.toString` differs between
   MLton and Poly/ML). A tight `eps` (1e-9) pins exact recoveries (RLS on
   noise-free data); convergence checks pass their own looser tolerance. *)

structure Support =
struct
  structure M = Matrix
  structure K = Kalman

  val eps = 1E~9

  fun approx (a, b) = Real.abs (a - b) <= eps
  fun approxTol tol (a, b) = Real.abs (a - b) <= tol

  fun checkApprox name (expected, actual) =
    Harness.check name (approx (expected, actual))

  fun checkApproxTol tol name (expected, actual) =
    Harness.check name (approxTol tol (expected, actual))

  (* scalar entry of a 1x1 (or addressed) matrix *)
  fun at (m, i, j) = M.sub (m, i, j)

  (* first component of a column vector *)
  fun head v = M.sub (v, 0, 0)

  fun checkVec tol name (expected, actual) =
    Harness.check name
      (length expected = length actual
       andalso ListPair.all (fn (a, b) => Real.abs (a - b) <= tol) (expected, actual))
end
