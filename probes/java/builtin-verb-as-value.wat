;; probes/java/builtin-verb-as-value.wat: can a builtin verb (one implemented in wat-rs's Rust,
;; not a defn) be used as a function value? A user defn can (:ll::num, :lj::show-bool). Each
;; attempt runs in its own thread, so each one's fate is reported.
;; (Passing :wat::core::+ straight to foldl is refused by the checker, at the call:
;;  ":wat::core::foldl: parameter #1 expects [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64];
;;  got :wat::core::keyword". A let-bound builtin, called through its local name, is not.)

(:wat::core::defn :probe::report [label <- :wat::core::String r <- :wat::kernel::RunResult] -> :wat::core::nil
  (:wat::core::match r
    [:wat::kernel::RunResult.Passed {} (:wat::kernel::println (:wat::string::concat label ": worked"))]
    [:wat::kernel::RunResult.Failed {:failure f} (:wat::kernel::println (:wat::string::concat label ": " (:wat::kernel::Failure/message f)))]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:probe::report "let-bound :wat::i64::to-string, called"
      (:wat::test::run-thread
        (:wat::core::let [f :wat::i64::to-string]
          (:wat::kernel::println (f 5)))))
    (:probe::report ":wat::i64::to-string passed to mapv"
      (:wat::test::run-thread
        (:wat::kernel::println (:wat::string::join "," (:wat::core::mapv :wat::i64::to-string [1 2 3])))))))
