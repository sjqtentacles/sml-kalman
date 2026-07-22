# sml-kalman

[![CI](https://github.com/sjqtentacles/sml-kalman/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-kalman/actions/workflows/ci.yml)

The linear (discrete-time) **Kalman filter** and a **recursive least-squares**
estimator in pure Standard ML, built on
[`sml-matrix`](https://github.com/sjqtentacles/sml-matrix) for dense real
linear algebra. States, covariances, and model matrices are `Matrix.t` values;
column vectors are `n x 1` matrices. No FFI, no RNG, no external dependencies,
and **deterministic**, byte-identically under both
[MLton](http://mlton.org/) and [Poly/ML](https://www.polyml.org/).

## Status

- 14 assertions, green on MLton and Poly/ML.
- Basis-library + vendored `sml-matrix` only (Layout B), so the repo builds
  standalone. Real-arithmetic heavy => CI Variant B (Poly/ML 5.9.1 from source).
- Vendors `sml-matrix` byte-identically under
  `lib/github.com/sjqtentacles/sml-matrix`.

## Install

With [`smlpkg`](https://github.com/diku-dk/smlpkg):

```
smlpkg add github.com/sjqtentacles/sml-kalman
smlpkg sync
```

Include the MLB from your own (it pulls in the vendored `sml-matrix`):

```
local
  $(SML_LIB)/basis/basis.mlb
  lib/github.com/sjqtentacles/sml-kalman/... (via smlpkg)
in
  ...
end
```

This brings `structure Kalman` (and the vendored `Matrix`) into scope.

## Quick start

```sml
structure K = Kalman

(* 2-D constant-velocity model: state = [position, velocity], dt = 1. *)
val model : K.model =
  { f = Matrix.fromRows [[1.0, 1.0], [0.0, 1.0]]   (* x <- F x        *)
  , b = Matrix.fromRows [[0.0], [0.0]]             (* no control       *)
  , q = Matrix.fromRows [[0.0, 0.0], [0.0, 0.0]]   (* process noise    *)
  , h = Matrix.fromRows [[1.0, 0.0]]               (* measure position *)
  , r = Matrix.fromRows [[0.25]] }                 (* measurement noise *)

val s0 : K.state =
  { x = K.colVec [0.0, 0.0]
  , p = Matrix.fromRows [[10.0, 0.0], [0.0, 10.0]] }

(* one predict + update with control u and measurement z *)
val s1 = K.step model { u = K.colVec [0.0], z = K.colVec [2.5] } s0
val pos = Matrix.sub (#x s1, 0, 0)
val vel = Matrix.sub (#x s1, 1, 0)

(* recursive least squares: recover theta of  y = phi . theta *)
val rls0 = K.RLS.init 2 1.0E8                       (* 2 coeffs, diffuse prior *)
val rls1 =
  List.foldl
    (fn ((x, y), e) => K.RLS.update 1.0 e { phi = K.colVec [x, 1.0], y = y })
    rls0
    [(1.0, 5.0), (2.0, 8.0), (3.0, 11.0)]           (* y = 3x + 2 *)
val coeffs = K.RLS.coeffs rls1                      (* ~ [3.0, 2.0] *)
```

## API (`signature KALMAN`)

```sml
type state = { x : Matrix.t, p : Matrix.t }
type model = { f : Matrix.t, b : Matrix.t, q : Matrix.t
             , h : Matrix.t, r : Matrix.t }

val colVec : real list -> Matrix.t
val toList : Matrix.t -> real list

val predict : model -> Matrix.t -> state -> state          (* arg: control u *)
val update  : model -> Matrix.t -> state -> state          (* arg: measurement z *)
val step    : model -> { u : Matrix.t, z : Matrix.t } -> state -> state

structure RLS :
  sig
    type estimator = { theta : Matrix.t, p : Matrix.t }
    val init   : int -> real -> estimator                  (* dim, delta *)
    val update : real -> estimator -> { phi : Matrix.t, y : real } -> estimator
    val coeffs : estimator -> real list
  end
```

### Conventions

- The model is `x_k = F x_{k-1} + B u_k + w` (process, covariance `Q`) and
  `z_k = H x_k + v` (measurement, covariance `R`).
- `predict` applies `x <- F x + B u`, `P <- F P F^T + Q`. Pass a zero control
  vector when there is no input.
- `update` computes the innovation `y = z - H x`, the innovation covariance
  `S = H P H^T + R`, the Kalman gain `K = P H^T S^-1`, then
  `x <- x + K y`, `P <- (I - K H) P`.
- `RLS.init n delta` starts at zero coefficients with `P = delta * I`; a large
  `delta` is a diffuse (weak) prior. `update lambda` folds in one
  (regressor, response) pair with forgetting factor `lambda` (use `1.0` for
  ordinary RLS).
- All arithmetic is deterministic — there is no RNG. Real comparisons in the
  test suite use an explicit epsilon.

## Build & test

```
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make example     # build + run examples/demo.sml (writes assets/filter-track.txt)
make clean
```

Both compilers run the same strict-TDD suite, pinned to closed-form targets:
a 1-D constant-position filter that reduces to the running **mean** of the
measurements (estimate -> mean, variance -> `R/n`), a 2-D constant-velocity
model whose estimate **converges to the true** `(position, velocity)` under
noise-free measurements, and RLS that **recovers exact coefficients**
(`y = 3x + 2` and a 3-coefficient system `[2, -3, 1]`) from consistent data.

## Example

`make example` runs a 2-D constant-velocity filter on a fixed, deterministic
scenario (true `pos(t) = 2t` plus a baked-in offset sequence) and prints a
tracking table -- byte-identical under MLton and Poly/ML, also written to
`assets/filter-track.txt`:

```
=== sml-kalman demo ==========================================

Constant-velocity tracking: true pos(t) = 2t, dt = 1,
  measurement = true + fixed offset, R = 0.25, Q = 0.

   t |      true |      meas |   est_pos |   est_vel |   var_pos
------------------------------------------------------------------
   1 |    2.0000 |    2.5000 |    2.4691 |    1.2346 |    0.2469
   2 |    4.0000 |    3.6000 |    3.6045 |    1.1419 |    0.2392
   3 |    6.0000 |    6.3000 |    6.0158 |    1.8854 |    0.2043
   4 |    8.0000 |    7.8000 |    7.8312 |    1.8558 |    0.1730
   5 |   10.0000 |   10.6000 |   10.2304 |    2.0353 |    0.1488
   6 |   12.0000 |   11.5000 |   11.8671 |    1.9273 |    0.1301
   7 |   14.0000 |   14.1000 |   13.9356 |    1.9597 |    0.1155
   8 |   16.0000 |   15.7000 |   15.8143 |    1.9436 |    0.1037
   9 |   18.0000 |   18.4000 |   17.9996 |    1.9861 |    0.0941
  10 |   20.0000 |   19.9000 |   19.9562 |    1.9815 |    0.0861
  11 |   22.0000 |   22.2000 |   22.0209 |    1.9933 |    0.0793
  12 |   24.0000 |   23.4000 |   23.8335 |    1.9698 |    0.0735

===============================================================
```

The velocity estimate converges toward the true `2.0` and the position
variance shrinks as more measurements arrive.

### Poly/ML note

CI builds Poly/ML 5.9.1 from source rather than using the Ubuntu package
(Poly/ML 5.7.1), whose X86 code generator crashes (`asGenReg raised while
compiling`) on heavy real-arithmetic code. See `.github/workflows/ci.yml`.

## License

MIT — see [LICENSE](LICENSE).
