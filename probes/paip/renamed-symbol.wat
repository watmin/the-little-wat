;; probes/paip/renamed-symbol.wat: can a renamed Prolog variable be built and read back?
;;
;; PAIP chapter 12 renames a clause's variables apart before each attempt, or a rule used twice
;; in one proof collides with itself. The oracle spells the renamed variable ?x.1 — the original
;; name, a separator, and a counter.
;;
;; paip/lib/unify.wat keys its substitution on a variable's NAME, so a renamed variable must be
;; a real Symbol node whose ast-name reads back exactly as written, and which
;; :paip::variable? still recognises (it must still begin with "?").
;;
;; The question is whether "." is safe in a wat symbol — wat's own names use :: and the reader
;; has opinions about dots. If it isn't, the separator has to be something else, and that is
;; worth knowing before the renaming is written rather than after.
;;
;; Run from the repository root: wat probes/paip/renamed-symbol.wat

(:wat::core::defn :probe::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :probe::variable? [x <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::if (:wat::core::= (:wat::core::ast-kind x) "symbol")
    (:wat::string::starts-with? (:wat::core::ast-name x) "?")
    false))

(:wat::core::defn :probe::try [sep <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let [n (:wat::core::symbol-node (:wat::string::concat "?x" sep "1"))]
    (:wat::core::do
      (:probe::show (:wat::string::concat "separator \"" sep "\" — ast-name") (:wat::core::ast-name n))
      (:probe::show (:wat::string::concat "separator \"" sep "\" — ast-kind") (:wat::core::ast-kind n))
      (:probe::show (:wat::string::concat "separator \"" sep "\" — source") (:wat::core::ast->source n))
      (:probe::show (:wat::string::concat "separator \"" sep "\" — still a variable")
                    (:wat::core::if (:probe::variable? n) "true" "false")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:probe::try ".")
    (:probe::try "-")
    ;; and the round trip that matters: two renamings of one variable must differ
    (:wat::core::let [a (:wat::core::symbol-node "?x-1")
                      b (:wat::core::symbol-node "?x-2")]
      (:probe::show "?x-1 = ?x-2" (:wat::core::if (:wat::core::= a b) "true" "false")))))
