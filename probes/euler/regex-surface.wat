;; probes/euler/regex-surface.wat: what regex does wat actually expose?
;;
;; wat-rs depends on the full regex crate (Cargo.toml:111, `regex = "1"`), and the user guide
;; documents exactly one entry (USER-GUIDE.md:3684):
;;
;;   :wat::regex::matches?  pattern haystack  ->  :bool -- unanchored
;;
;; If that really is the whole surface, then wat can ask WHETHER a string matches and can never
;; ask WHAT matched: no capture groups, no position of a match, no replace, no split on a
;; pattern. Nothing in FINDINGS.md mentions regex at all, so this is unrecorded either way.
;;
;; This file exercises the one verb that exists, and the spellings a user would reach for are
;; asked in their own files (a startup refusal ends the program):
;;   probes/euler/regex-find.wat     -- is there a find/captures?
;;   probes/euler/regex-replace.wat  -- is there a replace?
;;
;; Run from the repository root: wat probes/euler/regex-surface.wat

(:wat::core::defn :probe::show [label <- :wat::core::String b <- :wat::core::bool] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " (:wat::core::if b "true" "false"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; pattern first, haystack second, unanchored
    (:probe::show "matches? \"wor\" in \"hello world\"" (:wat::regex::matches? "wor" "hello world"))
    (:probe::show "matches? \"^wor\" in \"hello world\"" (:wat::regex::matches? "^wor" "hello world"))
    (:probe::show "matches? \"^hello\" in \"hello world\"" (:wat::regex::matches? "^hello" "hello world"))
    ;; a real pattern: does it take the usual syntax?
    (:probe::show "matches? \"[0-9]+\" in \"abc123\"" (:wat::regex::matches? "[0-9]+" "abc123"))
    (:probe::show "matches? \"^[A-Z][a-z]+$\" in \"Mary\"" (:wat::regex::matches? "^[A-Z][a-z]+$" "Mary"))
    (:probe::show "matches? \"\\\\d{3}-\\\\d{4}\" in \"call 555-1234\"" (:wat::regex::matches? "\\d{3}-\\d{4}" "call 555-1234"))
    ;; a group can be written — but nothing can be done with what it captured
    (:probe::show "matches? \"(foo|bar)baz\" in \"barbaz\"" (:wat::regex::matches? "(foo|bar)baz" "barbaz"))))
