;; probes/fix/keyword-conversions.wat: which half of F-092 is broken, the conversion or the choice?
;;
;; fix-seq (wat/fix.wat) decides what to do with each item of a sequence:
;;
;;   prev-arrow? and a keyword      -> :wat::keyword::to-type-form
;;   "type-shaped" keyword          -> :wat::keyword::to-type-form   (name contains `<` or `(`)
;;   an arrow                       -> :-
;;   a head keyword                 -> :wat::keyword::to-symbol
;;   otherwise                      -> recurse
;;
;; The first element of a sequence has no preceding arrow. In a CALL form `( … )` that element is
;; a head and `to-symbol` is right. In a TYPE bracket `[ … ]` it is a type and `to-symbol` is
;; wrong -- and fix-seq cannot tell the two apart, because it is handed items, not the bracket
;; they came from.
;;
;; So this asks the two conversion verbs directly, to find out whether F-092 is a broken
;; conversion or a mis-dispatch.
;;
;; Run: wat probes/fix/keyword-conversions.wat

(:wat::core::defn :kc::show [label <- :wat::core::String node <- :wat::WatAST] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    label "  ->  " (:wat::core::ast->source node)))))

(:wat::core::defn :kc::both [kw <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let [node (:wat::core::keyword-node kw)]
    (:wat::core::do
      (:kc::show (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] "to-symbol    " kw))
        (:wat::keyword::to-symbol node))
      (:kc::show (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] "to-type-form " kw))
        (:wat::keyword::to-type-form node)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:kc::both ":wat::WatAST")
    (:kc::both ":wat::core::i64")
    (:kc::both ":wat::core::Result::try")
    (:kc::both ":u::Veg")))
