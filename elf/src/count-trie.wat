;; Twelve strings force the flat vector into the trie, so node_copy runs on the way.
(wat.core/defn user/add [n :- wat.type/i64 v :- (wat.core/Vector :- [wat.type/String])] :- (wat.core/Vector :- [wat.type/String])
  (wat.core/if (wat.core/= n 0) v
    (user/add (wat.core/- n 1)
      (wat.core/conj v (wat.string/concat "s" (wat.i64/to-string n))))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (user/add 12 (wat.core/Vector :- [wat.type/String]))]
    (wat.kernel/println (wat.core/length v))
    (wat.kernel/println (wat.core/nth v 0))
    (wat.kernel/println (wat.core/nth v 11))))
