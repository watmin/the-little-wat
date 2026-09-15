;; probes/mal/read-frame-unbalanced.wat: Make-a-Lisp's step 1 sends lines that open more than
;; they close, "(+ 1 2", and expects an "unbalanced" error for that line alone. read-frame reads
;; stdin by EDN frame (probes/mal/read-frame-raw.wat reads balanced lines one per frame). What
;; does it answer for an unbalanced line followed by balanced ones, and then end of input?
;;
;; Run: printf '(+ 1 2\nabc\n(x\n' | wat probes/mal/read-frame-unbalanced.wat

(:wat::core::defn :probe::loop [n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::match (:wat::kernel::read-frame)
    [:wat::kernel::ReadFrameOutcome.Frame {:text t}
      (:wat::core::do
        (:wat::kernel::println (:wat::string::concat "frame " (:wat::i64::to-string n) ": " t))
        (:probe::loop (:wat::core::+ n 1)))]
    [:wat::kernel::ReadFrameOutcome.Eof {} (:wat::kernel::println "eof")]
    [:wat::kernel::ReadFrameOutcome.Stopped {} (:wat::kernel::println "stopped")]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:probe::loop 1))
