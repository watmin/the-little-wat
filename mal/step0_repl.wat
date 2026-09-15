;; mal/step0_repl.wat: Make-a-Lisp step 0, the REPL that prints back what it reads.
;;
;; Driven by mal's own runner through tools/mal-shim.py (tools/mal-test.sh step0_repl): each
;; input line arrives as one EDN string, and each output line goes back as one, then :mal/done.
;; A wat program can't print raw text or a prompt, and can't read an unbalanced line alone
;; (FINDINGS F-049, F-050), so the shim is the terminal.
;;
;; Keyword spelling throughout.

(:wat::core::defn :mal::read [s <- :wat::core::String] -> :wat::core::String s)
(:wat::core::defn :mal::eval [s <- :wat::core::String] -> :wat::core::String s)
(:wat::core::defn :mal::print [s <- :wat::core::String] -> :wat::core::String s)

(:wat::core::defn :mal::rep [s <- :wat::core::String] -> :wat::core::String
  (:mal::print (:mal::eval (:mal::read s))))

(:wat::core::defn :mal::line [text <- :wat::core::String] -> :wat::core::String
  (:wat::edn::read text))

(:wat::core::defn :mal::repl [] -> :wat::core::nil
  (:wat::core::match (:wat::kernel::read-frame)
    [:wat::kernel::ReadFrameOutcome.Frame {:text t}
      (:wat::core::do
        (:wat::kernel::println (:mal::rep (:mal::line t)))
        (:wat::kernel::println :mal/done)
        (:mal::repl))]
    [:wat::kernel::ReadFrameOutcome.Eof {} nil]
    [:wat::kernel::ReadFrameOutcome.Stopped {} nil]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:mal::repl))
