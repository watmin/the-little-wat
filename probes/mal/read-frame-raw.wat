;; probes/mal/read-frame-raw.wat: can a wat program read raw lines from stdin, as a
;; Make-a-Lisp REPL must? IOReader/from-fd is restricted to :wat::kernel:: and a main takes no
;; arguments, so user code has readln (one EDN value, decoded) and read-frame (one EDN frame's
;; raw text). Here: what read-frame answers for mal's step 0 inputs, and how println writes a
;; String back.
;;
;; Run: printf 'abc\nhello mal world\n[]{}"%s* ;:()\n(+ 1 2)\n' "'" | wat probes/mal/read-frame-raw.wat

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
