;; koans/idiom/19-datatypes.wat: the datatypes koans that don't port literally
;; (koans/literal/19-datatypes.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; defrecord is wat's defrecord, and deftype its defstruct. A protocol is a surface, and a type
;; implements it with extend-type (C-029). Fields are read by accessor.
;;
;; Run from the repository root: wat koans/idiom/19-datatypes.wat

(:wat::core::defrecord :koan::Medal [metal <- :wat::core::String])

(:wat::core::defstruct :koan::Trophy [sport <- :wat::core::String])

(:wat::core::defsurface :koan::Honor :nature :wat::core::Struct
  :features [(announce [self <- :koan::Honor who <- :wat::core::String] -> :wat::core::String)])

(:wat::core::defstruct :koan::Gold [event <- :wat::core::String])
(:wat::core::extend-type :koan::Gold :koan::Honor
  (announce [self who] -> :wat::core::String (:wat::string::concat who " wins gold in " (:koan::Gold/event self) ".")))

(:wat::core::defstruct :koan::Bronze [event <- :wat::core::String])
(:wat::core::extend-type :koan::Bronze :koan::Honor
  (announce [self who] -> :wat::core::String (:wat::string::concat who " takes bronze in " (:koan::Bronze/event self) ".")))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:koan::Medal/metal (:koan::Medal :metal "gold")) "gold") ; row 1
    (:wat::test::assert-eq (:koan::Trophy/sport (:koan::Trophy :sport "golf")) "golf") ; row 2
    (:wat::test::assert-eq (:koan::Medal/metal (:koan::Medal :metal "silver")) "silver") ; row 3
    ;; row 4 refused: a struct is not a map, and its fields are read by accessor, so the koan's nil has no counterpart
    ;; row 5 refused: a Vector of a record and a struct mixes two types, and map? has nothing to decide
    (:wat::test::assert-eq (:koan::Honor/announce (:koan::Gold :event "chess") "Ada") "Ada wins gold in chess.") ; row 6
    (:wat::test::assert-eq (:koan::Honor/announce (:koan::Bronze :event "golf") "Bob") "Bob takes bronze in golf.") ; row 7
    (:wat::kernel::println "koans idiom 19-datatypes: ok")))
