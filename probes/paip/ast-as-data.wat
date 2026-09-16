;; probes/paip/ast-as-data.wat: can quoted data carry PAIP's patterns without a term enum?
;;
;; NEXT.md §5 says chapters 11-12 are "where quoted data versus typed data gets decided". The
;; Reasoned Schemer already took the typed road: :rs::Term is a four-variant enum and rs/q
;; converts a quoted form into it straight away. PAIP's unifier is the other road — a pattern IS
;; an S-expression, and a variable is the symbol ?x — so this port should walk :wat::WatAST
;; itself. Four things have to hold for that to work, and each is measured here:
;;
;;   1. a symbol's text is reachable (ast-name), and ast-kind gates it — ast-name RAISES on a
;;      node that is not a Symbol/Keyword/StringLit, so ?-detection must test the kind first;
;;   2. a list decomposes to its children and a leaf yields none (ast->children);
;;   3. two structurally equal quoted forms compare equal, nested and all (=);
;;   4. a node prints back to source in a form that can be compared with guile's line
;;      (ast->source) — the oracle prints (2 + 1), so this must too.
;;
;; Run from the repository root: wat probes/paip/ast-as-data.wat

(:wat::core::defn :probe::kind-of [x <- :wat::WatAST] -> :wat::core::String
  (:wat::core::ast-kind x))

;; a variable is a symbol whose text begins with a question mark. The kind test must come
;; first: ast-name raises on a list or an int.
(:wat::core::defn :probe::variable? [x <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::if (:wat::core::= (:wat::core::ast-kind x) "symbol")
    (:wat::string::starts-with? (:wat::core::ast-name x) "?")
    false))

(:wat::core::defn :probe::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :probe::show-bool [label <- :wat::core::String b <- :wat::core::bool] -> :wat::core::nil
  (:probe::show label (:wat::core::if b "true" "false")))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [v   (:wat::core::quote ?x)
                    s   (:wat::core::quote x)
                    n   (:wat::core::quote 42)
                    pat (:wat::core::quote (?x + 1))
                    two (:wat::core::quote (2 + 1))
                    nst (:wat::core::quote (?x (f ?y)))]
    (:wat::core::do
      ;; 1. kinds and names
      (:probe::show "kind of ?x" (:probe::kind-of v))
      (:probe::show "kind of (?x + 1)" (:probe::kind-of pat))
      (:probe::show "kind of 42" (:probe::kind-of n))
      (:probe::show "name of ?x" (:wat::core::ast-name v))
      (:probe::show-bool "?x is a variable" (:probe::variable? v))
      (:probe::show-bool "x is a variable" (:probe::variable? s))
      (:probe::show-bool "42 is a variable" (:probe::variable? n))
      (:probe::show-bool "(?x + 1) is a variable" (:probe::variable? pat))

      ;; 2. decomposition
      (:probe::show "children of (?x + 1)" (:wat::i64::to-string (:wat::core::length (:wat::core::ast->children pat))))
      (:probe::show "children of ?x" (:wat::i64::to-string (:wat::core::length (:wat::core::ast->children v))))
      (:probe::show "first child of (?x + 1)" (:wat::core::ast->source (:wat::core::first (:wat::core::ast->children pat))))

      ;; 3. equality, flat and nested
      (:probe::show-bool "(2 + 1) = (2 + 1)" (:wat::core::= two (:wat::core::quote (2 + 1))))
      (:probe::show-bool "(2 + 1) = (?x + 1)" (:wat::core::= two pat))
      (:probe::show-bool "(?x (f ?y)) = itself" (:wat::core::= nst (:wat::core::quote (?x (f ?y)))))

      ;; 4. printing, which is what gets compared with guile
      (:probe::show "source of (2 + 1)" (:wat::core::ast->source two))
      (:probe::show "source of (?x (f ?y))" (:wat::core::ast->source nst))
      (:probe::show "source of ?x" (:wat::core::ast->source v)))))
