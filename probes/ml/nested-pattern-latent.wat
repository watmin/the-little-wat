;; nested-pattern-latent.wat: nested-pattern-positional.wat, but main only passes a Skewer, so the
;; arm holding the retired positional pattern is never tried. Does the program pass?
;; (If so, the retired form is latent: it ships until some input reaches it.)
;; Expected (if latent): skewer
(:wat::core::defenum :u::Kebab :wat::enum::Pure
  :Skewer []
  :Onion [k <- :u::Kebab]
  :Lamb  [k <- :u::Kebab])
(:wat::core::defn :u::describe [k <- :u::Kebab] -> :wat::core::String
  (:wat::core::match k
    [:u::Kebab.Skewer {} "skewer"]
    [:u::Kebab.Onion {:k (:u::Kebab.Onion inner)} "two-onions"]
    [:u::Kebab.Onion {:k other} "one-onion"]
    [:u::Kebab.Lamb {:k rest} "lamb"]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::describe (:u::Kebab.Skewer {}))))
