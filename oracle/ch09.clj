;; oracle/ch09.clj: the queries of books/reasoned-schemer/ch09-thin-ice.wat, in the oracle.
;; Its output is the wat chapter's expected values.
;; Run: clojure -M oracle/ch09.clj
(load-file "oracle/mk.clj")
(in-ns 'mk)
(load-file "oracle/rels.clj")

(println "== ch09")
(show "conda-olive" (run* q (conda ((== 'olive q) succeed) ((== 'oil q) succeed))))
(show "conda-virgin" (run* q (conda ((== 'virgin q) fail) ((== 'olive q) succeed) ((== 'oil q) succeed))))
(show "conda-split" (run* q (fresh (x y) (== 'split x) (== 'pea y) (conda ((== 'split x) (== x y)) (succeed succeed)))))
(show "conda-split-swapped" (run* q (fresh (x y) (== 'split x) (== 'pea y) (conda ((== x y) (== 'split x)) (succeed succeed)))))
(show "not-pastao" (run* x (conda ((not-pastao x) fail) ((== 'spaghetti x) succeed))))
(show "not-pastao-bound" (run* x (== 'spaghetti x) (conda ((not-pastao x) fail) ((== 'spaghetti x) succeed))))
(show "conda-teacupo" (run* x (conda ((teacupo x) succeed) ((== false x) succeed))))
(show "condu-teacupo" (run* x (condu ((teacupo x) succeed) ((== false x) succeed))))
(show "conde-teacupo" (run* x (conde ((teacupo x) succeed) ((== false x) succeed))))
(show "condu-alwayso" (run* q (condu ((alwayso) succeed) (fail)) (== true q)))
(show "onceo-teacupo" (run* x (onceo (teacupo x))))
(show "onceo-then-cup" (run* x (onceo (teacupo x)) (== 'cup x)))
(show "cup-then-onceo" (run* x (== 'cup x) (onceo (teacupo x))))
(show "conda-xy" (run* (x y) (conda ((teacupo x) (teacupo y)) ((== false x)))))
