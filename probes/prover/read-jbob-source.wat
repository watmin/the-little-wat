;; read-jbob-source.wat: can wat's reader parse J-Bob's Scheme source whole? Reads each file
;; with :wat::io::read-file and :wat::core::read-string and counts the top-level forms.
;; The path is the scratch clone of github.com/the-little-prover/j-bob. Expected: ~140 and ~49
(:wat::core::defn :u::count-forms [path <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::core::read-string (:wat::io::read-file path))
    [:wat::core::ReadOutcome.Forms {:forms fs} (:wat::core::length fs)]
    [:wat::core::ReadOutcome.Malformed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::core::Error/message c))]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::count-forms "/tmp/claude-1000/-home-watmin-Work-holon/5373d366-7a52-4a05-a9b4-198d0c5a4a95/scratchpad/j-bob/scheme/j-bob.scm"))
    (:wat::kernel::println (:u::count-forms "/tmp/claude-1000/-home-watmin-Work-holon/5373d366-7a52-4a05-a9b4-198d0c5a4a95/scratchpad/j-bob/scheme/little-prover.scm"))))
