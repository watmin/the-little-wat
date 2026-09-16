;; probes/paip/dotted-pattern.wat: can quoted data express a pattern with a variable tail?
;;
;; PAIP chapter 12's membership clause is the classic one:
;;
;;   ((member ?i (?i . ?rest)))
;;   ((member ?i (?head . ?rest)) (member ?i ?rest))
;;
;; Both heads carry (?i . ?rest) — a list whose TAIL is a variable. The Reasoned Schemer met
;; exactly this and built :rs::Term because of it: "Quoted lists can't hold a pair with a
;; variable tail, (a . d), so terms are their own enum" (books/reasoned-schemer/lib/
;; ch10-under-the-hood.wat). Chapter 11 got away with quoted data because every pattern there is
;; a proper list. Chapter 12 does not.
;;
;; Two questions, and the answer decides whether chapter 12's Prolog can stay on quoted data:
;;   1. does (:wat::core::quote (?i . ?rest)) even read?
;;   2. if it reads, what does ast->children make of it — is the dot a child, is the tail
;;      recoverable, or is the structure lost?
;;
;; Run from the repository root: wat probes/paip/dotted-pattern.wat

(:wat::core::defn :probe::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :probe::sources [xs <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::core::String
  (:wat::string::join " | " (:wat::core::mapv (:wat::core::fn [x <- :wat::WatAST] -> :wat::core::String (:wat::core::ast->source x)) xs)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [dotted (:wat::core::quote (?i . ?rest))
                    proper (:wat::core::quote (?i ?rest))]
    (:wat::core::do
      (:probe::show "source of (?i . ?rest)" (:wat::core::ast->source dotted))
      (:probe::show "kind of (?i . ?rest)" (:wat::core::ast-kind dotted))
      (:probe::show "children of (?i . ?rest)" (:wat::i64::to-string (:wat::core::length (:wat::core::ast->children dotted))))
      (:probe::show "each child" (:probe::sources (:wat::core::ast->children dotted)))
      (:probe::show "source of (?i ?rest)" (:wat::core::ast->source proper))
      (:probe::show "children of (?i ?rest)" (:wat::i64::to-string (:wat::core::length (:wat::core::ast->children proper))))
      (:probe::show "dotted = proper" (:wat::core::if (:wat::core::= dotted proper) "true" "false")))))
