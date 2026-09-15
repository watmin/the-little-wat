;; wat/main.wat
(:wat::core::define (:user::main
                     (stdin  :wat::io::IOReader)
                     (stdout :wat::io::IOWriter)
                     (stderr :wat::io::IOWriter)
                     -> :())
  (:wat::core::match (:wat::io::IOReader/read-line stdin) -> :()
    ((Some line)
      (:wat::io::IOWriter/print stdout line))
    (:None
      (:wat::io::IOWriter/print stderr "no input\n"))))
