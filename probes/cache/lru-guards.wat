;; probes/cache/lru-guards.wat: the two guards wat/cache.wat says PANIC, and what they say.
;;
;; The header is explicit that this primitive's failure surface is unlike sqlite's:
;;
;;   "Unlike `:wat::sqlite::*` (every verb errors-as-values), the two guards on this primitive
;;    PANIC: a non-positive `capacity` and a non-hashable (opaque-handle) key. That is deliberate
;;    behaviour-parity with the oracle for this stone."
;;
;; So this checks that they do panic, that the message is useful, and -- the part a caller
;; actually cares about -- that they are RECOVERABLE at all. :wat::test::run-thread is wat's only
;; general catch (F-063), so a panicking constructor is catchable only by spawning a thread.
;;
;; Run: wat probes/cache/lru-guards.wat

(:wat::core::defn :lg::verdict [n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::match (:wat::test::run-thread
                       (:wat::cache::Lru::new :- [:wat::core::String :wat::core::i64] n))
    [:wat::kernel::RunResult.Passed {} "accepted"]
    [:wat::kernel::RunResult.Failed {:failure f} (:wat::kernel::Failure/message f)]))

(:wat::core::defn :lg::try [label <- :wat::core::String n <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label (:wat::string::concat "  ->  " (:lg::verdict n)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:lg::try "capacity  1 (control)" 1)
    (:lg::try "capacity  0          " 0)
    (:lg::try "capacity -1          " -1)))
