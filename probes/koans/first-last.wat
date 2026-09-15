;; probes/koans/first-last.wat: Clojure's first and last both answer an element (or nil). What
;; do wat's answer, on the same Vector? (koans/literal/04-vectors.tsv: first matches, last not)

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [v (:wat::core::Vector :- [:wat::core::i64] 4 5 6)]
    (:wat::core::do
      (:wat::kernel::println (:wat::edn::write (:wat::core::first v)))
      (:wat::kernel::println (:wat::edn::write (:wat::core::last v))))))
