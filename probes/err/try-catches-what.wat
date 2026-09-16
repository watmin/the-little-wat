;; probes/err/try-catches-what.wat: does Result/try catch a real failure, or only an escape?
;;
;; The Seasoned Schemer used :wat::core::Result/try for the book's letcc — an escape the program
;; itself chooses to take (C-006, C-013). That is not the same as recovering from something
;; going wrong. A program that wants to survive a failure needs to know which of these
;; Result/try answers an Err for:
;;
;;   1. an explicit (:wat::core::Result.Err …) returned by the body      -- surely
;;   2. a :wat::kernel::assertion-failed! raised inside the body          -- ?
;;   3. a runtime fault the body did not ask for (out-of-range subs)      -- ?
;;
;; If only the first, then Result/try is a plumbing verb and :wat::test::run-thread — a TEST
;; verb — is the only way to survive a fault. That is worth knowing before anything is built on
;; it.
;;
;; Each case is its own file, because a death that is NOT caught ends the program:
;;   probes/err/try-catches-assertion.wat  -- case 2
;;   probes/err/try-catches-fault.wat      -- case 3
;; This file does case 1, the one that must work.
;;
;; Run from the repository root: wat probes/err/try-catches-what.wat

(:wat::core::typealias :probe::R (:wat::core::Result :- [:wat::core::i64 :wat::core::String]))

(:wat::core::defn :probe::ok [] -> :probe::R (:wat::core::Result.Ok {:value 7}))
(:wat::core::defn :probe::err [] -> :probe::R (:wat::core::Result.Err {:error "declared"}))

(:wat::core::defn :probe::show [label <- :wat::core::String r <- :probe::R] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label ": "
      (:wat::core::match r
        [:wat::core::Result.Ok {:value v} (:wat::string::concat "Ok " (:wat::i64::to-string v))]
        [:wat::core::Result.Err {:error e} (:wat::string::concat "Err " e)]))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:probe::show "a declared Ok" (:probe::ok))
    (:probe::show "a declared Err" (:probe::err))))
