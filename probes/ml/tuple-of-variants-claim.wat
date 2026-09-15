;; tuple-of-variants-claim.wat: "Is (Shrimp, Steak) a meza * main?" as a checkable claim, a
;; zero-argument defn with a keyword-headed body under the declared type. I predicted a
;; refusal from F-019 (a narrowed variant inside a Vector's or Stream's type argument is not
;; widened). Observed 2026-09-14: ACCEPTED, and it runs. A Tuple's element types widen where
;; a Vector's and a Stream's do not. The prediction was wrong; F-019 is narrower than I
;; assumed. Expected: Shrimp's value printed, exit 0.
(:wat::load-file! "../../books/little-mler/lib/ch04-look-to-the-stars.wat")

(:wat::core::defn :mlx::steak-plate [] -> (:wat::core::Tuple :- [:ml::Meza :ml::Main])
  (:wat::core::Tuple (:ml::Meza.Shrimp {}) (:ml::Main.Steak {})))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::first (:mlx::steak-plate))))
