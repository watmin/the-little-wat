;; probes/lox/value-equality.wat
;;
;; Q: can two values of one `defenum` be compared with `:wat::core::=`?
;;
;; F-019 says a variant constructor keeps its NARROWED type, so `(= (Fish.Anchovy {})
;; (Fish.Tuna {}))` is refused -- parameter #2 expects the first variant's type. Crafting
;; Interpreters chapter 18 needs exactly this comparison (`valuesEqual`), so before writing it by
;; hand: does the refusal apply to values typed as the ENUM?
;;
;; It does not, and F-019 already said so in its own update ("helpers whose declared return type
;; is the enum widen, and then both work"). This probe is the positive control that belongs
;; beside it, plus the case Lox actually cares about: NaN.
;;
;; Run: wat probes/lox/value-equality.wat

(:wat::core::defenum :p::V :wat::enum::Pure
  :Nil [] :Bool [b <- :wat::core::bool] :Num [n <- :wat::core::f64])

;; both parameters declared as the enum -- the widening F-019's update names
(:wat::core::defn :p::same? [a <- :p::V b <- :p::V] -> :wat::core::bool (:wat::core::= a b))

(:wat::core::defn :p::yn [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "true" "false"))

(:wat::core::defn :p::row [label <- :wat::core::String b <- :wat::core::bool] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label " => " (:p::yn b))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [z 0.0
     nan (:wat::core::/ z z)
     n1 (:p::V.Num {:n 1.0})
     n1b (:p::V.Num {:n 1.0})
     n2 (:p::V.Num {:n 2.0})
     nil1 (:p::V.Nil {})
     t (:p::V.Bool {:b true})
     na (:p::V.Num {:n nan})
     nb (:p::V.Num {:n nan})]
    (:wat::core::do
      (:p::row "1 == 1, same variant          " (:p::same? n1 n1b))
      (:p::row "1 == 2                        " (:p::same? n1 n2))
      (:p::row "nil == nil                    " (:p::same? nil1 (:p::V.Nil {})))
      (:p::row "nil == true, across variants  " (:p::same? nil1 t))
      (:p::row "1 == true, across variants    " (:p::same? n1 t))
      (:wat::kernel::println "")
      (:p::row "f64:  NaN = NaN               " (:wat::core::= nan nan))
      (:p::row "enum: Num(NaN) = Num(NaN)     " (:p::same? na nb))
      (:wat::kernel::println "")
      (:wat::kernel::println "So `=` on an enum-typed pair IS valuesEqual: tags first, payload after,")
      (:wat::kernel::println "and the f64 payload compares as an f64 rather than bitwise -- which is")
      (:wat::kernel::println "what Lox needs, and what a bit-pattern comparison would have got wrong.")
      (:wat::kernel::println "F-019's refusal is about NARROWED variant types, not about this."))))
