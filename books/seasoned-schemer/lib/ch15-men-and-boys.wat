;; The Seasoned Schemer, ch 15 (The Difference Between Men and Boys...): the definitions.
;; set! changes what a name means. wat has no set!: mutable state lives on services, and a
;; Cell (lib/cell.wat) is the smallest one, holding one S-expression. So:
;;   - the book's global x and food are Cells, passed in explicitly, because wat has no
;;     mutable global name;
;;   - a closure's private x (omnivore, gobbler) is a Cell the closure owns;
;;   - nibbler's per-call x is a Cell made on each call.
;; A Cell's service closes when its Handle is dropped, so a CellRef keeps both.
;;
;; Needs lib/cell.wat loaded first. No main here.

;; gourmet reads the shared x.
(wat.core/defn ss/gourmet [x :- :ss::CellRef food :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [xv (ss/cell-get x)]
    (wat.core/quasiquote (~food ~xv))))

;; gourmand sets the shared x to food, then answers (food x).
(wat.core/defn ss/gourmand [x :- :ss::CellRef food :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [_put (ss/cell-put! x food)
                 xv   (ss/cell-get x)]
    (wat.core/quasiquote (~food ~xv))))

;; dinerR sets the shared x to food, and answers (milkshake food).
(wat.core/defn ss/dinerR [x :- :ss::CellRef food :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [_put (ss/cell-put! x food)]
    (wat.core/quasiquote (milkshake ~food))))

;; omnivore: a closure with its OWN x, starting as minestrone. Setting it touches no one else.
(wat.core/defn ss/make-omnivore [] :- [:wat::WatAST :-> :wat::WatAST]
  (wat.core/let [x (ss/new-cell 'minestrone)]
    (wat.core/fn [food :- :wat::WatAST] :- :wat::WatAST
      (wat.core/let [_put (ss/cell-put! x food)
                     xv   (ss/cell-get x)]
        (wat.core/quasiquote (~food ~xv))))))

;; gobbler: the same shape, its own x starting as minestrone too, separate from omnivore's.
(wat.core/defn ss/make-gobbler [] :- [:wat::WatAST :-> :wat::WatAST]
  (wat.core/let [x (ss/new-cell 'minestrone)]
    (wat.core/fn [food :- :wat::WatAST] :- :wat::WatAST
      (wat.core/let [_put (ss/cell-put! x food)
                     xv   (ss/cell-get x)]
        (wat.core/quasiquote (~food ~xv))))))

;; nibbler: its x is made fresh on EVERY call (a let inside the lambda), so nothing persists.
(wat.core/defn ss/nibbler [food :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [x    (ss/new-cell 'donut)
                 _put (ss/cell-put! x food)
                 xv   (ss/cell-get x)]
    (wat.core/quasiquote (~food ~xv))))

;; Our own illustration (not the book's): a closure answering (food previous-food), so the
;; persistence of its private Cell between calls is visible in its answers.
(wat.core/defn ss/make-remembering-diner [start :- :wat::WatAST] :- [:wat::WatAST :-> :wat::WatAST]
  (wat.core/let [x (ss/new-cell start)]
    (wat.core/fn [food :- :wat::WatAST] :- :wat::WatAST
      (wat.core/let [old  (ss/cell-get x)
                     _put (ss/cell-put! x food)]
        (wat.core/quasiquote (~food ~old))))))

;; glutton sets the shared food, and answers (more x more x) for its argument x.
(wat.core/defn ss/glutton [food :- :ss::CellRef x :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [_put (ss/cell-put! food x)]
    (wat.core/quasiquote (more ~x more ~x))))

;; chez-nous swaps the shared x and food.
(wat.core/defn ss/chez-nous [x :- :ss::CellRef food :- :ss::CellRef] :- :wat::WatAST
  (wat.core/let [a    (ss/cell-get food)
                 _one (ss/cell-put! food (ss/cell-get x))]
    (ss/cell-put! x a)))
