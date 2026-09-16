;; probes/euler/regex-replace.wat: is there a pattern replace?
;;
;; Replacing by pattern is the other half of text work, and wat has no string replace at all —
;; the registered :wat::string:: surface is twenty verbs and none of them is replace. If there
;; is no regex replace either, then changing text in wat means splitting and rejoining by a
;; literal separator, or walking one character at a time with subs.
;;
;; Its own file because a startup refusal ends the program.
;;
;; Run from the repository root: wat probes/euler/regex-replace.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::regex::replace "[0-9]+" "abc123def" "#")))
