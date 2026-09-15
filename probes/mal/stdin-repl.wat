;; probes/mal/stdin-repl.wat: a REPL loop on stdin, the shape Make-a-Lisp's runtest.py drives:
;; print a prompt, read a line, answer, repeat until end of input. A main takes no arguments
;; now (a 3-argument main is refused at freeze, arc 170), so stdin and stdout come from their
;; file descriptors. USER-GUIDE.md §2's stdin echo, the other route, is refused as written
;; (probes/mal/user-guide-stdin-echo.wat).
;;
;; Run: printf 'abc\n(+ 1 2)\n' | wat probes/mal/stdin-repl.wat

(:wat::core::defn :probe::repl [in <- :wat::io::IOReader out <- :wat::io::IOWriter] -> :wat::core::nil
  (:wat::core::do
    (:wat::io::IOWriter/print out "user> ")
    (:wat::io::IOWriter/flush out)
    (:wat::core::match (:wat::io::IOReader/read-line in)
      [:wat::core::Option.Some {:value line}
        (:wat::core::do
          (:wat::io::IOWriter/print out (:wat::string::concat line "\n"))
          (:probe::repl in out))]
      [:wat::core::Option.None {} nil])))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:probe::repl (:wat::io::IOReader/from-fd 0) (:wat::io::IOWriter/from-fd 1)))
