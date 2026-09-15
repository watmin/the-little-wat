;; koans/idiom/08-conditionals.wat: the conditionals koans that don't port literally
;; (koans/literal/08-conditionals.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; An if always has an else, of the same type as its then; a value that may be absent is an
;; Option. There is no case; cond with an :else clause stands in.
;;
;; Run from the repository root: wat koans/idiom/08-conditionals.wat

(:wat::core::defn :koan::speed [way <- :wat::core::keyword] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= way :cycling) "fast")
    ((:wat::core::= way :running) "brisk")
    ((:wat::core::= way :walking) "slow")
    (:else "no way")))

(:wat::core::defn :koan::none? :- [T] [o <- (:wat::core::Option :- [T])] -> :wat::core::bool
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} false]
    [:wat::core::Option.None {} true]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; no false?: not
    (:wat::test::assert-eq (:wat::core::if (:wat::core::not (:wat::core::= 1 2)) :yes :no) :yes) ; row 1
    ;; an if with no else doesn't exist; its else has the then's type
    (:wat::test::assert-eq (:wat::core::if (:wat::core::> 5 3) (:wat::core::Vector :- [:wat::core::i64]) (:wat::core::Vector :- [:wat::core::i64] 0))
                           (:wat::core::Vector :- [:wat::core::i64])) ; row 2
    ;; "nil when not taken" is an Option
    (:wat::test::assert-eq (:koan::none? (:wat::core::if (:wat::core::< 5 3) (:wat::core::Option.Some {:value :yes}) (:wat::core::Option.None {}))) true) ; row 3
    ;; row 4 refused: an i64 is never nil, so (nil? 0) has nothing to decide
    (:wat::test::assert-eq (:wat::core::if (:wat::core::not (:wat::core::empty? (:wat::core::Vector :- [:wat::core::i64]))) :doom :glory) :glory) ; row 5
    (:wat::test::assert-eq
      (:wat::core::let [x 7]
        (:wat::core::cond ((:wat::core::= x 5) :first) ((:wat::core::= x 6) :second) (:else :third)))
      :third) ; row 6
    ;; no if-not or zero?: not, and = 0
    (:wat::test::assert-eq (:wat::core::if (:wat::core::not (:wat::core::= 1 0)) (:wat::core::quote doom) (:wat::core::quote more-doom)) (:wat::core::quote doom)) ; row 7
    (:wat::test::assert-eq (:koan::speed :cycling) "fast") ; row 8
    (:wat::test::assert-eq (:koan::speed :sleeping) "no way") ; row 9
    (:wat::kernel::println "koans idiom 08-conditionals: ok")))
