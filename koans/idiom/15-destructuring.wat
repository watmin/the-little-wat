;; koans/idiom/15-destructuring.wat: the destructuring koans that don't port literally
;; (koans/literal/15-destructuring.tsv), each said the way wat says it, or marked as having no
;; wat route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; A map of a street, a city and a country is a record, and let destructures a record by
;; :keys. A Vector is taken apart by nth.
;;
;; Run from the repository root: wat koans/idiom/15-destructuring.wat

(:wat::core::defrecord :koan::Address [street <- :wat::core::String  city <- :wat::core::String  country <- :wat::core::String])

(:wat::core::defn :koan::address [] -> :koan::Address
  (:koan::Address :street "9 Elm Row" :city "Leith" :country "UK"))

(:wat::core::typealias :koan::Strings (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq ((:wat::core::fn [v <- :koan::Strings] -> :wat::core::String (:wat::string::concat (:wat::core::nth v 1) (:wat::core::nth v 0))) ["a" "b"]) "ba") ; row 1
    (:wat::test::assert-eq ((:wat::core::fn [v <- :koan::Strings] -> :wat::core::String
                              (:wat::string::concat (:wat::core::nth v 0) ", " (:wat::core::nth v 1) " and " (:wat::core::nth v 2)))
                            ["x" "y" "z"])
                           "x, y and z") ; row 2
    (:wat::test::assert-eq (:wat::core::let [v ["Ada" "Lovelace" "Countess" "Analyst"]]
                             (:wat::string::concat (:wat::core::first v) " " (:wat::core::nth v 1) ": " (:wat::string::join ", " (:wat::core::drop v 2))))
                           "Ada Lovelace: Countess, Analyst") ; row 3
    ;; :as: the whole is the binding itself; a pair of a Vector and a String is a Tuple
    (:wat::test::assert-eq (:wat::core::let [whole ["Ada" "Lovelace"]] (:wat::core::Tuple whole (:wat::core::first whole)))
                           (:wat::core::Tuple ["Ada" "Lovelace"] "Ada")) ; row 4
    (:wat::test::assert-eq (:wat::core::let [a (:koan::address)]
                             (:wat::string::concat (:koan::Address/street a) ", " (:koan::Address/city a) ", " (:koan::Address/country a)))
                           "9 Elm Row, Leith, UK") ; row 5
    (:wat::test::assert-eq (:wat::core::let [{:keys [street city country]} (:koan::address)] (:wat::string::concat street ", " city ", " country))
                           "9 Elm Row, Leith, UK") ; row 6
    (:wat::test::assert-eq ((:wat::core::fn [name <- :koan::Strings a <- :koan::Address] -> :wat::core::String
                              (:wat::core::let [{:keys [street city country]} a]
                                (:wat::string::concat (:wat::core::first name) " " (:wat::string::subs (:wat::core::nth name 1) 0 1) "., " street ", " city ", " country)))
                            ["Ada" "Lovelace"] (:koan::address))
                           "Ada L., 9 Elm Row, Leith, UK") ; row 7
    (:wat::kernel::println "koans idiom 15-destructuring: ok")))
