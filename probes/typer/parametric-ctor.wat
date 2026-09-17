;; probes/typer/parametric-ctor.wat: is a parametric enum's constructor checked against its
;; instantiated type parameter?
;;
;; It is not. `(:u::Box.B :- [:wat::core::i64] {:v "I am a String"})` is accepted, and if the value
;; never crosses a typed boundary the String is read straight back out of a Box<i64>.
;;
;; The hole is CONSTRUCTION ONLY, which is why it is easy to miss. Every downstream use is checked:
;;
;;   builtin parametric type at a function boundary   REFUSED
;;   user parametric enum at a function boundary      REFUSED
;;   reading the field through a typed accessor fn    REFUSED
;;   the constructor itself                           ACCEPTED   <- the hole
;;
;; Found by trying to verify a claim rather than repeat it: C-059 says wat takes polymorphic
;; recursion, and the minimal demonstration I first wrote only CONSTRUCTED nested values without
;; passing them through a typed function -- so it would have passed even if nothing were checked.
;; The real structures (okasaki/lib/bootstrap.wat) are genuinely checked: deliberately breaking
;; the nesting there produces 5 type-check errors naming the exact mismatch.
;;
;; Expected: the String prints, from a Box<i64>, exit 0.

(:wat::core::defenum :u::Box :- [A] :wat::enum::Pure :B [v <- :A])

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:u::Box.B :- [:wat::core::i64] {:v "I am a String"})
    [:u::Box.B {:v v}
      (:wat::kernel::println (:wat::string::concat "read out of a Box<i64>: " (:wat::edn::write v)))]))
