;; oracle/rels.clj: the relations of books/reasoned-schemer/lib/, defined identically in the
;; oracle. Load after oracle/mk.clj, inside (in-ns 'mk). Keep each definition the same shape
;; as its wat twin (same conde lines, same goal order), or the answer order may differ.

;; ch 1
(defrel (teacupo t) (disj2 (== 'tea t) (== 'cup t)))

;; ch 2
(defrel (caro p a) (fresh (d) (== (kons a d) p)))
(defrel (cdro p d) (fresh (a) (== (kons a d) p)))
(defrel (conso a d p) (== (kons a d) p))
(defrel (nullo x) (== () x))
(defrel (pairo p) (fresh (a d) (conso a d p)))
(defrel (singletono l) (fresh (a) (== (lst a) l)))

;; ch 3
(defrel (listo l)
  (conde ((nullo l))
         ((fresh (d) (cdro l d) (listo d)))))

(defrel (lolo l)
  (conde ((nullo l))
         ((fresh (a) (caro l a) (listo a))
          (fresh (d) (cdro l d) (lolo d)))))

(defrel (loso l)
  (conde ((nullo l))
         ((fresh (a) (caro l a) (singletono a))
          (fresh (d) (cdro l d) (loso d)))))

(defrel (membero x l)
  (conde ((caro l x))
         ((fresh (d) (cdro l d) (membero x d)))))

(defrel (proper-membero x l)
  (conde ((caro l x) (fresh (d) (cdro l d) (listo d)))
         ((fresh (d) (cdro l d) (proper-membero x d)))))
