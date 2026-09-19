;; Shadowing, and the three values that are not integers or strings.
;;
;; The `let` binds `x` to a string the body never uses, and then the FUNCTION's `x` is the value.
;; A compiler gets that right by not carrying the let's environment back out past its body --
;; which is one line in `:c::let-form`, and is the whole of lexical scope.
;;
;; Also here because they would otherwise diverge silently: `(println (> 3 2))` prints `true` in
;; wat, not `1`, and `(println nil)` prints `nil`, not `0`. The compiler's type pass is the only
;; thing that knows the difference, so all four printable types are exercised in one file.

(wat.core/defn u/fn [x :- wat.type/String] :- wat.type/String
  (wat.core/do
    (wat.core/let [x "useless"] nil)
    x))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/fn "not-useless"))
  (wat.kernel/println (wat.core/> 3 2))
  (wat.kernel/println (wat.core/> 2 3))
  (wat.kernel/println (wat.core/= 7 7))
  (wat.kernel/println nil)
  (wat.kernel/println true)
  (wat.kernel/println false)
  (wat.kernel/println 42))
