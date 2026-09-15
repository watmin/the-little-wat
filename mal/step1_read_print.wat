;; mal/step1_read_print.wat: Make-a-Lisp step 1, a REPL that reads a form and prints it back.
;;
;; Driven by mal's own runner through tools/mal-shim.py (tools/mal-test.sh step1_read_print): each
;; input line arrives as one EDN string, and each output line goes back as one, then :mal/done
;; (FINDINGS F-049, F-050). Keyword spelling throughout.

(:wat::load-file! "lib/types.wat")
(:wat::load-file! "lib/reader.wat")
(:wat::load-file! "lib/printer.wat")

(:wat::core::defn :mal::eval [v <- :mal::Val] -> :mal::Val v)

;; the lines a form prints: its value, or the reader's complaint, or nothing for a blank line
(:wat::core::defn :mal::rep [line <- :wat::core::String] -> :mal::Strs
  (:wat::core::match (:mal::read-str line)
    [:mal::Read.Got {:v v :next j} (:wat::core::Vector :- [:wat::core::String] (:mal::pr-str (:mal::eval v) true))]
    [:mal::Read.Failed {:msg m} (:wat::core::Vector :- [:wat::core::String] m)]
    [:mal::Read.Empty {} (:wat::core::Vector :- [:wat::core::String])]))

(:wat::core::defn :mal::print-lines [lines <- :mal::Strs] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? lines)
    nil
    (:wat::core::do
      (:wat::kernel::println (:wat::core::first lines))
      (:mal::print-lines (:wat::core::rest lines)))))

(:wat::core::defn :mal::repl [] -> :wat::core::nil
  (:wat::core::match (:wat::kernel::read-frame)
    [:wat::kernel::ReadFrameOutcome.Frame {:text t}
      (:wat::core::do
        (:mal::print-lines (:mal::rep (:wat::edn::read t)))
        (:wat::kernel::println :mal/done)
        (:mal::repl))]
    [:wat::kernel::ReadFrameOutcome.Eof {} nil]
    [:wat::kernel::ReadFrameOutcome.Stopped {} nil]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:mal::repl))
