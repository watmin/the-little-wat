(:wat::core::defrecord :co::Order     [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :co::Stock     [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :co::Shippable [id <- :wat::core::i64 qty <- :wat::core::i64])
(:wat::core::defrecord :co::CountT    [n <- :wat::core::i64])

(:wat::rete::defrule :co::shippable
  :when [(:co::Order (?id <- :id) (?part <- :part))
         (:co::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:co::Shippable :id ?id :qty ?qty)])

(:wat::rete::defrule :co::count-rule
  :when [(?n <- (:wat::rete::acc::count) :from (:co::Shippable))]
  :then [(:co::CountT :n ?n)])

(:wat::rete::defquery :co::q-Count :params [] :when [(?f <- :co::CountT)])

(:wat::core::defn :co::seeded [] -> :wat::rete::Session
  (:wat::rete::insert-all
    (:wat::rete::compile-all (:wat::rete::collect-rules :co)
      (:wat::core::PersistentVector (:co::q-Count)))
    (:wat::core::PersistentVector :- [:wat::core::Record]
      (:co::Order :id 1 :part "bolt")
      (:co::Order :id 2 :part "nut")
      (:co::Stock :part "bolt" :qty 10)
      (:co::Stock :part "nut" :qty 5))))

(:wat::core::defn :co::vals [rows <- (:wat::core::PersistentVector :- [:wat::core::PersistentMap])] -> :wat::core::String
  (:wat::string::join "|"
    (:wat::core::sort
      (:wat::core::foldl
        (:wat::core::fn [acc <- (:wat::core::Vector :- [:wat::core::String]) r <- :wat::core::PersistentMap]
          -> (:wat::core::Vector :- [:wat::core::String])
          (:wat::core::conj acc
            (:wat::core::match (:wat::map::get r "?f")
              [:wat::core::Option.Some {:value rec} (:wat::i64::to-string (:co::CountT/n rec))]
              [:wat::core::Option.None {} "?"])))
        (:wat::core::Vector :- [:wat::core::String])
        rows))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::string::concat "count native      : "
      (:co::vals (:wat::rete::query (:wat::rete::fire-rules (:co::seeded)) (:co::q-Count)))))
    (:wat::kernel::println (:wat::string::concat "count SPEC        : "
      (:co::vals (:wat::rete::query (:wat::rete::fire-rules$oracle (:co::seeded)) (:co::q-Count)))))
    (:wat::kernel::println (:wat::string::concat "count fire-fixpoint: "
      (:co::vals (:wat::rete::query (:wat::rete::fire-fixpoint (:co::seeded)) (:co::q-Count)))))))
