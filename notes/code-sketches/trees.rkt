#lang parendown racket/base

; trees.rkt
;
; Data structures for encoding the kind of higher-order structure that
; occurs in higher quasiquotation.

;   Copyright 2017-2018 The Lathe Authors
;
;   Licensed under the Apache License, Version 2.0 (the "License");
;   you may not use this file except in compliance with the License.
;   You may obtain a copy of the License at
;
;       http://www.apache.org/licenses/LICENSE-2.0
;
;   Unless required by applicable law or agreed to in writing,
;   software distributed under the License is distributed on an
;   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
;   either express or implied. See the License for the specific
;   language governing permissions and limitations under the License.


(require #/only-in racket/generic define-generics)
(require #/only-in racket/match match)

(require #/only-in lathe-comforts dissect expect mat w-)
(require #/only-in lathe-comforts/list nat->maybe)
(require #/only-in lathe-comforts/maybe just)
(require #/only-in lathe-comforts/struct struct-easy)

(provide #/all-defined-out)




; ===== Higher quasiquotation data ===================================

; Our definition of higher-quasiquotation-shaped data is corecursive
; with our definition of the kinds of syntax they're built out of,
; "mediums."
;
; A medium represents something that has a certain innate degree to
; it; a certain "edge" medium of degree N if it's of degree N+1; and a
; certain kind of "content" value it can validate for a given tower of
; degree N (the content's edge) if it's of degree N+1 or no tower if
; it's of degree 0. (Content values with no tower at the edge are
; nicknamed "readable values" because they're syntax with no end.)
; When validating a content value with a medium, the content edge
; tower provided to the validator must be of that diminished degree
; and must use that edge medium, or the validation request is not
; valid.
;
; A tower actually uses two mediums: An "island" medium and a "lake"
; medium, both of the same degree as the tower itself. The lake medium
; describes the syntax of all the highest-degree holes in the tower.
; There are also lower-degree holes, but the next-lower ones are
; described by the island's edge medium, and the ones a degree below
; that are described by the edge of that edge, and so ono.
;
; It turns out we only need to model two constructors for towers:
; `hoqq-tower-readable` for the degree-0 case, and
; `hoqq-tower-content` for everything else. These make use of
; `null-medium` and `subtower-medium`. (In fact, the trivial
; `null-medium` is rather pervasive because the lake medium of
; every edge tower used for validating mediums' content values must be
; a `null-medium`.)
;
; We keep track of the arrangement of islands and lakes in a tower by
; use of "free variables" that name them. "Free variable" makes a
; little more sense as terminology if you consider that the free
; variables of a tower are a combination of the free variables of its
; subtowers. (TODO: It doesn't make that much sense. See if we can
; find new terminology.) Something exotic about these free variables
; is that they can have free variables of their own, representing the
; islands on the far side of a lake or the lakes on the far side of an
; island. They basically capture all the structure of a tower except
; for the syntactic content it contains and the spatial juxtaposition
; of that content along various degrees of nested syntax, which is
; what we use the rest of the tower data to represent.

(struct-easy (medium-unpacked degree maybe-edge-medium verify-content)
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degreee to be an exact nonnegative integer"))
    (expect (nat->maybe degree) (just lower-degree)
      (expect maybe-edge-medium (list)
        (error "Expected maybe-edge-medium to be an empty list for degree zero")
      #/void)
    #/expect maybe-edge-medium (list edge-medium)
      (error "Expected maybe-edge-medium to be a singleton list for degree nonzero")
    #/begin
      (unless (medium? edge-medium)
        (error "Expected edge-medium to be a medium"))
      (unless (= lower-degree #/medium-degree edge-medium)
        (error "Expected degree to be one greater than the degree of edge-medium")))))

(define-generics medium
  (medium-unpack medium))

(define (medium-degree medium)
  (expect (medium-unpack medium)
    (medium-unpacked degree maybe-edge-medium verify-content)
    (error "Expected the result of medium-unpack to be a medium-unpacked")
    degree))

(define (medium-edge-maybe medium)
  (expect (medium-unpack medium)
    (medium-unpacked degree maybe-edge-medium verify-content)
    (error "Expected the result of medium-unpack to be a medium-unpacked")
    maybe-edge-medium))

(define (medium-edge medium)
  (expect (medium-edge-maybe medium) edge
    (error "Expected medium to have degree at least one")
    edge))



; This is a medium where the degree N is `degree` and the edge (if N
; is nonzero) is `maybe-edge-medium`. The content values are empty
; lists.
(struct-easy (null-medium degree maybe-edge-medium)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (expect (nat->maybe degree) (just lower-degree)
      (expect maybe-edge-medium (list)
        (error "Expected maybe-edge-medium to be an empty list for degree zero")
      #/void)
    #/expect maybe-edge-medium (list edge-medium)
      (error "Expected maybe-edge-medium to be a singleton list for degree nonzero")
    #/begin
      (unless (medium? edge-medium)
        (error "Expected edge-medium to be a medium"))
      (unless (= lower-degree #/medium-degree edge-medium)
        (error "Expected degree to be one greater than the degree of edge-medium"))))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this (null-medium degree maybe-edge-medium)
      (error "Expected this to be a null-medium")
    #/medium-unpacked degree maybe-edge-medium
    #/lambda (maybe-content-edge content)
      (expect content (list)
        (error "Expected content to be an empty list")
      #/void))]
)

; The degree N is the natural number `degree`.
;
; The edge of each of the components must be the same. This medium's
; edge is that edge.
;
; A content value is a cons cell consisting of the content values of
; the components.
;
(struct-easy (cons-medium degree a b) #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (unless (medium? a)
      (error "Expected a to be a medium"))
    (unless (medium? b)
      (error "Expected b to be a medium"))
    (unless (eq? degree #/medium-degree a)
      (error "Expected degree and the degree of a to match"))
    (unless (eq? degree #/medium-degree b)
      (error "Expected degree and the degree of b to match"))
    (unless (equal? (medium-edge-maybe a) (medium-edge-maybe b))
      (error "Expected a and b to have equal adges")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this (cons-medium degree a b)
      (error "Expected this to be a cons-medium")
    #/expect (medium-unpack a)
      (medium-unpacked degree-a maybe-edge-a verify-content-a)
      (error "Expected the unpacked a to be a medium-unpacked")
    #/expect (medium-unpack b)
      (medium-unpacked degree-b maybe-edge-b verify-content-b)
      (error "Expected the unpacked b to be a medium-unpacked")
    #/medium-unpacked
      (merge-asserted = degree
      #/merge-asserted = degree-a degree-b)
      (merge-asserted equal? maybe-edge-a maybe-edge-b)
    #/lambda (maybe-content-edge content)
      (expect content (cons content-a content-b)
        (error "Expected content to be a cons cell")
      #/begin
        (verify-content-a maybe-content-edge content-a)
        (verify-content-b maybe-content-edge content-b)))]
)

(define (tower-degree tower)
  (match tower
    [ (hoqq-tower-readable island-medium lake-medium island-readable)
      0]
    [
      (hoqq-tower-content
        degree island-medium lake-medium lake-sig root-content
        tower-of-subtowers)
      degree]
    [_ #/error "Expected tower to be a hoqq-tower"]))

(define (tower-island-medium tower)
  (match tower
    [ (hoqq-tower-readable island-medium lake-medium island-readable)
      island-medium]
    [
      (hoqq-tower-content
        degree island-medium lake-medium lake-sig root-content
        tower-of-subtowers)
      island-medium]
    [_ #/error "Expected tower to be a hoqq-tower"]))

(define (tower-lake-medium tower)
  (match tower
    [ (hoqq-tower-readable island-medium lake-medium island-readable)
      lake-medium]
    [
      (hoqq-tower-content
        degree island-medium lake-medium lake-sig root-content
        tower-of-subtowers)
      lake-medium]
    [_ #/error "Expected tower to be a hoqq-tower"]))

(define
  (tower-verify-degree-and-mediums
    tower expected-degree expected-island-medium expected-lake-medium)
  (unless (exact-nonnegative-integer? expected-degree)
    (error "Expected expected-degree to be an exact nonnegative integer"))
  (unless (medium? expected-island-medium)
    (error "Expected expected-island-medium to be a medium"))
  (unless (medium? expected-lake-medium)
    (error "Expected expected-lake-medium to be a medium"))
  (unless (= expected-degree #/tower-degree tower)
    (error "Expected tower to have degree expected-degree"))
  (unless (equal? expected-island-medium #/tower-island-medium tower)
    (error "Expected tower to have island medium expected-island-medium"))
  (unless (equal? expected-lake-medium #/tower-lake-medium tower)
    (error "Expected tower to have lake medium expected-lake-medium")))

(define
  (tower-map-highest tower new-island-medium new-lake-medium
    island-func lake-func)
  (unless (= (tower-degree tower) (medium-degree new-island-medium))
    (error "Expected tower and new-island-medium to have the same degree"))
  (unless
    (equal?
      (medium-edge-maybe #/tower-island-medium tower)
      (medium-edge-maybe new-island-medium))
    (error "Expected new-island-medium to have the same edge as the old one"))
  (unless (= (tower-degree tower) (medium-degree new-lake-medium))
    (error "Expected tower and new-lake-medium to have the same degree"))
  (unless
    (equal?
      (medium-edge-maybe #/tower-lake-medium tower)
      (medium-edge-maybe new-lake-medium))
    (error "Expected new-lake-medium to have the same edge as the old one"))
  (match tower
    [(hoqq-tower-readable island-medium lake-medium island-readable)
    #/hoqq-tower-readable new-island-medium new-lake-medium
    #/island-func island-readable]
    [
      (hoqq-tower-content
        degree island-medium lake-medium lake-sig root-content
        tower-of-subtowers)
    #/hoqq-tower-content degree new-island-medium new-lake-medium
      lake-sig
      (island-func root-content)
    #/dissect (tower-island-medium tower-of-subtowers)
      (subtower-medium
        degree main-medium subtower-island-medium
        subtower-lake-medium)
    #/tower-map-highest tower-of-subtowers
      (tower-island-medium tower-of-subtowers)
      (subtower-medium
        degree main-medium new-lake-medium new-island-medium)
      (lambda (edge-island)
        edge-island)
      (lambda (edge-lake)
        (match edge-lake
          [(subtower-medium-continue edge-content)
          #/subtower-medium-continue edge-content]
          [(subtower-medium-subtower tower)
          #/subtower-medium-subtower
          #/tower-map-highest tower new-lake-medium new-island-medium
            lake-func island-func ]
          [_ #/error "Internal error"]))]))

; TODO: See if we'll use this.
(define (merge-unasserted a b)
  a)

(define (merge-asserted compare? a b)
  (unless (compare? a b)
    (error "Internal error"))
  a)

(define (tower-cons-highest a b)
  (unless (= (tower-degree a) (tower-degree b))
    (error "Expected towers a and b to have equal degrees"))
  (unless
    (equal?
      (medium-edge-maybe #/tower-island-medium a)
      (medium-edge-maybe #/tower-island-medium b))
    (error "Expected towers a and b to have island mediums with the same edge"))
  (unless
    (equal?
      (medium-edge-maybe #/tower-lake-medium a)
      (medium-edge-maybe #/tower-lake-medium b))
    (error "Expected towers a and b to have lake mediums with the same edge"))
  (match a
    [
      (hoqq-tower-readable
        island-medium-a lake-medium-a island-readable-a)
    #/dissect b
      (hoqq-tower-readable
        island-medium-b lake-medium-b island-readable-b)
    #/hoqq-tower-readable
      (cons-medium island-medium-a island-medium-b)
      (cons-medium lake-medium-a lake-medium-b)
    #/cons island-readable-a island-readable-b]
    [
      (hoqq-tower-content
        degree-a island-medium-a lake-medium-a lake-sig-a
        root-content-a tower-of-subtowers-a)
    #/dissect b
      (hoqq-tower-content
        degree-b island-medium-b lake-medium-b lake-sig-b
        root-content-b tower-of-subtowers-b)
    #/w- island-medium-consed
      (cons-medium island-medium-a island-medium-b)
    #/w- lake-medium-consed (cons-medium lake-medium-a lake-medium-b)
    ; NOTE: The `sta` and `stb` stand for "subtowers a" and
    ; "subtowers b."
    #/dissect (tower-lake-medium tower-of-subtowers-a)
      (subtower-medium
        sta-degree sta-main-medium sta-subtower-island-medium
        sta-subtower-lake-medium)
    #/dissect (tower-lake-medium tower-of-subtowers-b)
      (subtower-medium
        stb-degree stb-main-medium stb-subtower-island-medium
        stb-subtower-lake-medium)
    #/hoqq-tower-content
      (merge-asserted = degree-a degree-b)
      island-medium-consed
      lake-medium-consed
      (merge-asserted equal? lake-sig-a lake-sig-b)
      (cons root-content-a root-content-b)
    #/tower-map-highest
      (tower-cons-highest tower-of-subtowers-a tower-of-subtowers-b)
      (merge-asserted equal?
        (tower-island-medium tower-of-subtowers-a)
        (tower-island-medium tower-of-subtowers-b))
      (subtower-medium
        (merge-asserted = sta-degree stb-degree)
        ; TODO: Make sure this `medium-edge` doesn't need to be a
        ; `medium-edge-maybe`.
        (merge-asserted equal? (medium-edge lake-medium-consed)
        #/merge-asserted equal? sta-main-medium stb-main-medium)
        ; Yes, we switch lakes and islands for the subtowers.
        lake-medium-consed
        island-medium-consed)
      (lambda (island-content)
        (dissect island-content (cons a b)
          ; TODO: See how we should merge `a` and `b`. Should we
          ; require them to be equal, and if so, what kind of equality
          ; check should we make here? Should we combine them using a
          ; cons cell or a custom merge function, and if so, what
          ; ramifications should that have for the final tower's edge
          ; mediums (or even the design of `cons-medium` itself)?
          a))
      (lambda (lake-content)
        (mat lake-content
          (cons
            (subtower-medium-continue a)
            (subtower-medium-continue b))
          (subtower-medium-continue #/cons a b)
        #/mat lake-content
          (cons
            (subtower-medium-subtower a)
            (subtower-medium-subtower b))
          (subtower-medium-subtower #/tower-cons-highest a b)
        #/error "Expected towers a and b to be compatible"))]))

(define (tower-all? tower island? lake?)
  (mat tower (hoqq-tower-readable island-medium lake-medium readable)
    (island? (list) readable)
  #/expect tower
    (hoqq-tower-content degree island-medium lake-medium lake-sig
      root-content tower-of-subtowers)
    (error "Expected tower to be a hoqq-tower-readable or a hoqq-tower-content")
  #/w- root-content-edge
    (tower-map-highest tower-of-subtowers
      (tower-island-medium tower-of-subtowers)
      (null-medium (tower-degree tower-of-subtowers)
      ; TODO: Make sure this `medium-edge` doesn't need to be a
      ; `medium-edge-maybe`.
      #/medium-edge #/tower-lake-medium tower-of-subtowers)
      (lambda (island-content) island-content)
      (lambda (lake-content) #/list))
  #/and (island? (list root-content-edge) root-content)
  #/tower-all-lakes? tower-of-subtowers
  #/lambda (maybe-content-edge content)
    (expect content (subtower-medium-subtower tower) #t
    ; Yes, we flip the lakes and islands for the subtowers.
    #/tower-all? tower lake? island?)))

(define (tower-all-lakes? tower lake?)
  (tower-all? tower
    (lambda (maybe-content-edge island-content) #t)
    lake?))

(define (tower-compatible? a b)
  (if (hoqq-tower-readable? a)
    (hoqq-tower-readable? b)
  #/expect a
    (hoqq-tower-content
      degree-a island-medium-a lake-medium-a lake-sig-a root-content-a
      tower-of-subtowers-a)
    (error "Expected a to be a hoqq-tower-readable or a hoqq-tower-content")
  #/expect b
    (hoqq-tower-content
      degree-b island-medium-b lake-medium-b lake-sig-b root-content-b
      tower-of-subtowers-b)
    #f
  #/and (tower-compatible? tower-of-subtowers-a tower-of-subtowers-b)
  #/tower-all-lakes?
    (tower-cons-highest tower-of-subtowers-a tower-of-subtowers-b)
  #/lambda (maybe-content-edge content)
    (dissect content (cons content-a content-b)
      (if (subtower-medium-continue? content-a)
        (subtower-medium-continue? content-b)
      #/expect content-a (subtower-medium-subtower content-tower-a)
        (error "Expected content-a to be a subtower-medium-continue or a subtower-medium-subtower")
      #/expect content-b (subtower-medium-subtower content-tower-b)
        #f
      #/tower-compatible? content-tower-a content-tower-b))))

(define (tower-edge-maybe tower)
  (if (hoqq-tower-readable? tower) (list)
  #/list
  #/expect tower
    (hoqq-tower-content
      degree island-medium lake-medium lake-sig root-content
      tower-of-subtowers)
    (error "Expected tower to be a hoqq-tower-readable or a hoqq-tower-content")
  #/mat tower-of-subtowers
    (hoqq-tower-readable island-medium lake-medium island-readable)
    (hoqq-tower-readable (null-medium 0 #/list) lake-medium
    ; TODO: Incorporate the original `island-readable` into this value
    ; somehow.
    #/list)
  #/expect tower-of-subtowers
    (hoqq-tower-content
      degree island-medium lake-medium lake-sig root-content
      tower-of-subtowers)
    (error "Expected tower-of-subtowers to be a hoqq-tower-readable or a hoqq-tower-content")
  #/dissect lake-medium
    (subtower-medium
      degree main-medium subtower-island-medium subtower-lake-medium)
  ; TODO: Finish implementing this from here.
  #/hoqq-tower-content degree
    ; TODO: Make sure this `medium-edge` doesn't need to be a
    ; `medium-edge-maybe`.
    (null-medium degree #/medium-edge island-medium)
    lake-medium
    ; TODO: Update the lake-sig appropriately.
    lake-sig
    ; TODO: Incorporate the original `root-content` into this value
    ; somehow.
    (list)
    ; TODO: Compute the tower-of-subtowers appropriately.
    'TODO))

(define (tower-edge tower)
  (expect (tower-edge-maybe tower) (list edge)
    (error "Expected tower to be of degree at least one")
    edge))

; This is a medium that acts just like the medium `main-medium` in
; most cases, while allowing certain highest-degree content values
; to contain towers whose mediums are of degree one higher than this
; medium. The point of this step upward in degree is to help with
; representing a tower: We can represent it with a lower-degree tower
; containing all the low-degree lakes and the "near" low-degree side
; of every highest-degree lake, where in each of those truncated lakes
; we have another tower of what's beyond it. The tower beyond is equal
; in degree to the one we're modeling, so we can model it the same way
; recursively, ending up with a representation comprised only of
; lower-degree towers.
;
; The degree N is the natural number `degree`.
;
; The edge is the edge of `main-medium`.
;
; A content value for some degree-N-1 content edge is expected to be
; a sum type of either (`subtower-medium-continue`) a `main-medium`
; content value or (`subtower-medium-subtower`) a tower of degree N+1
; where the degree-N-2-or-less free variables match the given ones.
; The `island-medium` and `lake-medium` of the tower must be the given
; `subtower-island-medium` and `subtower-lake-medium`.
;
(struct-easy (subtower-medium-continue content))
(struct-easy (subtower-medium-subtower tower))
(struct-easy
  (subtower-medium
    degree main-medium subtower-island-medium subtower-lake-medium)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (unless (medium? main-medium)
      (error "Expected main-medium to be a medium"))
    (unless (medium? subtower-island-medium)
      (error "Expected subtower-island-medium to be a medium"))
    (unless (medium? subtower-lake-medium)
      (error "Expected subtower-lake-medium to be a medium"))
    (unless (= degree #/medium-degree main-medium)
      (error "Expected degree and the degree of main-medium to match"))
    (unless (= (+ 1 degree) #/medium-degree subtower-island-medium)
      (error "Expected degree to be 1 less than the degree of subtower-island-medium"))
    (unless (= (+ 1 degree) #/medium-degree subtower-lake-medium)
      (error "Expected degree to be 1 less than the degree of subtower-lake-medium")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this
      (subtower-medium
        degree main-medium subtower-island-medium
        subtower-lake-medium)
      (error "Expected this to be a subtower-medium")
    #/expect (medium-unpack main-medium)
      (medium-unpacked
        degree-main maybe-medium-edge-main verify-content-main)
      (error "Expected the result of unpacking main-medium to be a medium-unpacked")
    #/medium-unpacked (merge-asserted = degree degree-main)
      maybe-medium-edge-main
    #/lambda (maybe-content-edge content)
      (mat content (subtower-medium-continue content)
        (verify-content-main maybe-content-edge content)
      #/mat content (subtower-medium-subtower tower)
        ; Where N is `degree`, we verify that `tower` is a tower of
        ; degree N+1 where the degree-N-2-or-less free variables match
        ; the given `content-edge`. The `island-medium` and
        ; `lake-medium` of the tower must be the given
        ; `subtower-island-medium` and `subtower-lake-medium`.
        (begin
          (tower-verify-degree-and-mediums tower (add1 degree)
            subtower-island-medium subtower-lake-medium)
        #/expect maybe-content-edge (list content-edge)
          ; If there is no content edge (or in other words there would
          ; be a content edge of degree -1), then there's nothing to
          ; verify the tower's degree-N-2-or-less free variables
          ; against, so anything goes.
          (void)
        #/unless
          (tower-compatible? content-edge
          #/tower-edge #/tower-edge tower)
          (error "Expected the edge of the edge of tower to be compatible with content-edge"))
        #/error "Expected content to be a subtower-medium-continue or a subtower-medium-subtower"))]
)

; TODO: Refactor `hoqq-tower-readable` and `hoqq-tower-content` like
; so: Give `hoqq-tower-readable` a slot for a degree and a slot for
; the edge of the content. Remove `lake-sig`.
;
; TODO: Finish implementing `tower-edge-maybe`. To find the edge of
; `(A `(B ,(C ,(...D) ,(...E) F) ,(G ,(...H) I) J) K ,(...L) M), which
; is the same as the edge of
; `(A C ,(...D) ,(...E) F G ,(...H) I K ,(...L) M), we need to do some
; specific things. We need to concatenate the lower-degree data
; (C ,(...D) ,(...E) F) and (G ,(...H) I), and this concatenation is
; just what would come in handy a higher degree do do edge-finding, so
; we should probably be trying to do concatenation in the first place,
; making this a recursive call. Furthermore, we need to concatenate
; that data onto the tail "K ,(...L) M", which means we need to pass
; tails of various degrees throughout the recursive concatenation.
; Finally, since in higher degrees the things being concatenated are
; not simply in a list (but in a tree or even higher-degree
; structure), we need to distribute this tail information across all
; the branches that use it, so we'll likely want each concatenation
; call to return an output tail representing the unused portion of the
; input tail. (Note that the tail has two dimensions of "tail" at play
; here; the concatenation operation consumes the tail from side to
; side, allowing each encountered branch to consume its own slice of
; the tail from base to tip.)

(struct-easy (carry extra val))

(define (tower? x)
  (or (hoqq-tower-readable? x) (hoqq-tower-content? x)))

#|
(define (tower-squash towers-and-extra)
  (expect towers-and-extra (carry extra tower-of-towers)
    (error "Expected towers-and-extra to be a carry")
  #/expect (tower? extra) #t
    (error "Expected extra to be a tower")
  #/expect (tower? tower-of-towers) #t
    (error "Expected tower-of-towers to be a tower")
  #/expect (tower-lake-medium tower-of-towers)
    ; NOTE: The "v" stands for "val."
    (subtower-medium
      degree-v main-medium-v subtower-island-medium-v
      subtower-lake-medium-v)
    (error "Expected the lake medium of tower-of-towers to be a subtower-medium")
  #/expect
    ; TODO: This seems sloppy. There's probably something we have to
    ; do to finesse these to be equal.
    (equal?
      ; The `tower-of-towers` tower represents a bunch of lakes and
      ; the areas beyond, just like `hoqq-tower-content`. Thus, once
      ; we squash all the lakes out of it, we're left with only the
      ; islands, which correspond with the lakes of the subtowers. But
      ; we don't get those lakes at the same degree they were
      ; originally in the subtowers; we get their edges. (TODO: Do we
      ; really get their *edges* or something else?)
      (medium-edge subtower-lake-medium-v)
      ; The `extra` tower represents a collection of already-squashed
      ; pieces. The elements of this collection exist at the tower's
      ; lakes.
      (tower-lake-medium extra))
    #t
    (error "Expected tower-of-towers and extra to have compatible mediums")
  #/mat tower-of-towers
    (hoqq-tower-readable island-medium lake-medium island-readable)
    ; TODO: Verify that `extra` is empty (i.e. just a
    ; `hoqq-tower-readable` itself), and return a
    ; `hoqq-tower-readable` with an edge that's squashed from this
    ; one's edge.
    'TODO
  #/expect tower-of-towers
    (hoqq-tower-content
      degree island-medium lake-medium lake-sig root-content
      tower-of-subtowers)
    (error "Expected tower-of-towers to be a hoqq-tower-readable or a hoqq-tower-content")
  
  ; NOTE: This `root-content` is a content value for
  ; `(tower-island-medium tower-of-towers)`.
  
  ; NOTE: We don't want to recur on `tower-of-subtowers` because we
  ; would squash out all the islands if we did that, rather than
  ; squashing out all the lakes. So we match on it again.
  ;
  ; If we were to recur on `tower-of-subtowers` here anyway, what kind
  ; of `extra` would we need to pass in? Well, the lake medium of this
  ; `tower-of-subtowers` is a `subtower-medium` whose
  ; `subtower-lake-medium` is `(tower-island-medium tower-of-towers)`,
  ; so we would need the lake medium of our new `extra` to match the
  ; edge of that.
  
  #/mat tower-of-subtowers
    (hoqq-tower-readable island-medium lake-medium island-readable)
    ; TODO: If the `root-content` is a `subtower-medum-continue`,
    ; consume exactly one lake of `extra`, and return the value
    ; from there.
    'TODO
  #/expect tower-of-subtowers
    (hoqq-tower-content
      degree island-medium lake-medium lake-sig root-content
      tower-of-subtowers)
    (error "Expected tower-of-subtowers to be a hoqq-tower-readable or a hoqq-tower-content")
  
  ; NOTE: This `root-content` is a content value for the edge of the
  ; lake medium for `tower-of-towers`. That lake medium was what we
  ; deconstructed above, so `root-content` is a content value for
  ; `(medium-edge main-medium-v)`.
  
  ; NOTE: If we were to recur on `tower-of-subtowers` here, what kind
  ; of `extra` would we need to pass in? Well, the lake medium of this
  ; `tower-of-subtowers` is a `subtower-medium` whose
  ; `subtower-lake-medium` is the island medium of the previous
  ; `tower-of-towers`, which was the edge of
  ; `(tower-island-medium tower-of-towers)`, so we would need the lake
  ; medium of our new `extra` to match the edge of that, namely
  ; `(medium-edge #/medium-edge
  ; #/tower-island-medium tower-of-towers)`.
  ;
  ; TODO: That seems rather difficult to satisfy. Perhaps we do need squashing that removes islands.
  
  #/expect (tower-lake-medium extra)
    ; NOTE: The "e" stands for "extra."
    (subtower-medium
      degree-e main-medium-e subtower-island-medium-e
      subtower-lake-medium-e)
    (error "Expected the lake medium of extra to be a subtower-medium")
  
  #/mat tower
    (hoqq-tower-readable island-medium lake-medium island-readable)
    (carry extra
    #/hoqq-tower-readable (null-medium 0 #/list) lake-medium #/list)
  #/expect tower
    (hoqq-tower-content
      degree island-medium lake-medium lake-sig root-content
      tower-of-subtowers)
    (error "Expected tower to be a hoqq-tower-readable or a hoqq-tower-content")
|#

; This has degree 0 and no island free variables or lake free
; variables. The given `island-medium` and `lake-medium` must be
; mediums of degree 0, and the given `island-readable` must be a valid
; content value for `island-medium`.
(struct-easy
  (hoqq-tower-readable island-medium lake-medium island-readable)
  #:equal)

; Let N be the degree of the tower `tower-of-subtowers`.
;
; The degree of this tower is N+1. The value of `degree` must match.
;
; The tower `tower-of-subtowers` must have an island medium that's the
; edge of this `island-medium`, and it must have a lake medium that's
; a `subtower-medium` with a `degree` of N, a `main-medium` matching
; the edge of this `lake-medium`, a `subtower-island-medium` matching
; this `lake-medium`, and a `subtower-lake-medium` matching this
; `island-medium`. Yes, we switch the lakes and the islands for the
; subtowers.
;
; The `root-content` must be a valid `island-medium` content value for
; the redaction of `tower-of-subtowers` after all the degree-N lakes
; are replaced with a `null-medium` of degree N, with an edge equal to
; original lake medium's edge.
;
; Because of the fact that the lakes are `subtower-medium` trees, some
; of the degree-N-1 lakes are towers of degree N+1. We'll call those
; the subtowers, and we'll call the rest of `tower-of-subtowers` the
; root tower.
;
; This tower has lake free variables from multiple sources:
;
;   - This has every lake free variable from the root tower. The ones
;     that correspond to subtowers are degree N instead of N-1 in this
;     tower, and they now have degree-N-1 free variables matching the
;     degree-N-1 lake free variables of their subtowers.
;
;   - This has a degree-N lake free variable corresponding to every
;     island free variable of the subtowers.
;
; These must be mutually exclusive.
;
; These lake free variables are summarized in `lake-sig`, which must
; be a sig. A sig is a list from degrees to tables from variables to
; sigs, representing the fact that these free variables have free
; variables of their own, of various degrees. A variable occurring in
; a valid sig will never have free variables of degree equal to or
; greater than its own degree.
;
; This has island free variables corresponding to the degree-N lake
; free variables of the subtowers. This is computed each time, not
; summarized anywhere.
;
(struct-easy
  (hoqq-tower-content
    degree island-medium lake-medium lake-sig root-content
    tower-of-subtowers)
  #:equal)



; To represent a bunch of matched brackets with a degree-N-tower
; flattened shape, we use a degree-N tower where the island medium is
; the syntax that appears between the brackets and the lake medium is
; a medium built out of `cons-medium`, `const-medium`, and
; `fill-medium` which bundles bracket information together with
; another bunch of matched brackets with a degree-N-tower flattened
; shape, with its lakes of degree N-2 and less matching up and its
; lakes of degree N-1 shining through.
;
;   (TODO: Bracket information we need to track for that: Arbitrary
;   data, the perimiter of expressions to construct the raw bracket
;   syntax, the expressions to construct the raw content syntax, and
;   the expanded content. Figure out how we'll represent perimiters.
;   It might be as simple as pairing a prefix with a tower where the
;   holes are perimiters, but this will probably require at least a
;   new medium struct to express the recursion.)
;
;
; To represent a bunch of matched brackets with a degree-N-tower
; flattened shape alongside a bunch of unmatched closing brackets
; closing off degree-N-tower-shaped content in some of the degree-N-1
; holes, we use a degree-N tower where the lake medium is built out of
; `cons-medium`, `const-medium`, and `tail-medium` where the main
; tower is the matched brackets and all the tails are the unmatched
; closing brackets.
;
;   (TODO: Bracket information we need to track for that: Arbitrary
;   data and the perimiter of expressions to construct the raw closing
;   bracket syntax.)
;
;
; (TODO: See how we'll represent a bunch of matched brackets that have
; been simplified to remove syntactic residue, so that they're clean
; enough to pass through a macroexpander like s-expressions again.)



; This is a medium that acts just like the medium `main-medium` in
; most cases, while allowing certain highest-degree content values
; to contain towers of the same medium as this one. The point of
; keeping it at the same degree is to represent one tower meshing up
; with another layer of towers without any holes in between. The point
; of reusing this medium for the fills is so that the fills can have
; their own fills, and so on. The combined shape of the tower and all
; the nested towers within it is the same degree as the original.
;
; The degree N is the natural number `degree`.
;
; The edge is the edge of `main-medium`.
;
; A content value of degree N-1 for some free variables is expected to
; be a sum type of either (`fill-medium-continue`) a `main-medium`
; content value or (`fill-medium-fill`) a tower of degree N where the
; degree-N-2-or-less free variables match the given content edge. The
; `island-medium` and `lake-medium` of the tower must be the overall
; `fill-medium` and the given `fill-lake-medium`.
;
(struct-easy (fill-medium-continue content))
(struct-easy (fill-medium-fill tower))
(struct-easy
  (fill-medium degree main-medium fill-lake-medium)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (unless (medium? main-medium)
      (error "Expected main-medium to be a medium"))
    (unless (medium? fill-lake-medium)
      (error "Expected fill-lake-medium to be a medium"))
    (unless (= degree #/medium-degree main-medium)
      (error "Expected degree and the degree of main-medium to match"))
    (unless (= degree #/medium-degree fill-lake-medium)
      (error "Expected degree and the degree of fill-lake-medium to match")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this (fill-medium degree main-medium fill-lake-medium)
      (error "Expected this to be a fill-medium")
    #/expect (medium-unpack main-medium)
      (medium-unpacked
        degree-main maybe-medium-edge-main verify-content-main)
      (error "Expected the result of unpacking main-medium to be a medium-unpacked")
    #/medium-unpacked (merge-asserted = degree degree-main)
      maybe-medium-edge-main
    #/lambda (maybe-content-edge content)
      (mat content (fill-medium-continue content)
        (verify-content-main maybe-content-edge content)
      #/mat content (fill-medium-fill tower)
        ; Where N is `degree`, we verify that `tower` is a tower of
        ; degree N where the degree-N-2-or-less free variables match
        ; the given `content-edge`. The `island-medium` and
        ; `lake-medium` of the tower must be the overall `fill-medium`
        ; and the given `fill-lake-medium`.
        (begin
          (tower-verify-degree-and-mediums tower degree
            this fill-lake-medium)
        #/expect maybe-content-edge (list content-edge)
          ; If there is no content edge (or in other words there would
          ; be a content edge of degree -1), then there's nothing to
          ; verify the tower's degree-N-2-or-less free variables
          ; against, so anything goes.
          (void)
        #/unless (tower-compatible? content-edge #/tower-edge tower)
          (error "Expected the edge of tower to be compatible with content-edge"))
        #/error "Expected content to be a fill-medium-continue or a fill-medium-fill"))]
)

; This is a medium that acts just like the medium `main-medium` in
; most cases, while allowing certain highest-degree content values
; to contain towers of the same degree as this medium. The point of
; keeping the degree the same is to represent a stretch of content
; starting on the other side of a tower's highest-degree holes and
; continuing all the way from there to its own holes. The combined
; shape of the tower and the area beyond is of the same degree as the
; tower itself.
;
; The degree N is the natural number `degree`.
;
; The edge is the edge of `main-medium`.
;
; A content value of degree N-1 for some free variables is expected to
; be a sum type of either an `island-medium` content value or a tower
; of degree N where the degree-N-2-or-less free variables match the
; given ones. The `island-medium` and `lake-medium` of the tower must
; be the given `tail-island-medium` and `tail-lake-medium`.
;
(struct-easy (tail-medium-continue content))
(struct-easy (tail-medium-tail tower))
(struct-easy
  (tail-medium degree main-medium tail-island-medium tail-lake-medium)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (unless (medium? main-medium)
      (error "Expected main-medium to be a medium"))
    (unless (medium? tail-island-medium)
      (error "Expected tail-island-medium to be a medium"))
    (unless (medium? tail-lake-medium)
      (error "Expected tail-lake-medium to be a medium"))
    (unless (= degree #/medium-degree main-medium)
      (error "Expected degree and the degree of main-medium to match"))
    (unless (= degree #/medium-degree tail-island-medium)
      (error "Expected degree and the degree of tail-island-medium to match"))
    (unless (= degree #/medium-degree tail-lake-medium)
      (error "Expected degree and the degree of tail-lake-medium to match")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this
      (tail-medium
        degree main-medium tail-island-medium tail-lake-medium)
      (error "Expected this to be a tail-medium")
    #/expect (medium-unpack main-medium)
      (medium-unpacked
        degree-main maybe-medium-edge-main verify-content-main)
      (error "Expected the result of unpacking main-medium to be a medium-unpacked")
    #/medium-unpacked (merge-asserted = degree degree-main)
      maybe-medium-edge-main
    #/lambda (maybe-content-edge content)
      (mat content (tail-medium-continue content)
        (verify-content-main maybe-content-edge content)
      #/mat content (tail-medium-tail tower)
        ; Where N is `degree`, we verify that `tower` is a tower of
        ; degree N where the degree-N-2-or-less free variables match
        ; the given `content-edge`. The `island-medium` and
        ; `lake-medium` of the tower must be the given
        ; `tail-island-medium` and `tail-lake-medium`.
        (begin
          (tower-verify-degree-and-mediums tower degree
            tail-island-medium tail-lake-medium)
        #/expect maybe-content-edge (list content-edge)
          ; If there is no content edge (or in other words there would
          ; be a content edge of degree -1), then there's nothing to
          ; verify the tower's degree-N-2-or-less free variables
          ; against, so anything goes.
          (void)
        #/unless (tower-compatible? content-edge #/tower-edge tower)
          (error "Expected the edge of tower to be compatible with content-edge"))
        #/error "Expected content to be a tail-medium-continue or a tail-medium-tail"))]
)

; TODO: See if we can represent something like `tail-medium` as a
; combination of `fill-medium` with some kind of fixed point. The
; challenge here is that if we make a lazy medium which is equal to
; another lazy medium if their thunks return equal values, the thunks
; may nevertheless have different side effects. Is there an idiomatic
; way we can prohibit or discourage side effects in Racket?

; The value of `readable-medium` must be a medium of degree 0.
;
; The degree N is the natural number `degree`.
;
; The edge (if N is nonzero) is the given `maybe-edge-medium`, which
; must have degree N-1.
;
; A content value is also like a `readable-medium` content value,
; ignoring the tower edge altogether.
;
(struct-easy
  (const-medium degree maybe-edge-medium readable-medium)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (expect (nat->maybe degree) (just lower-degree)
      (expect maybe-edge-medium (list)
        (error "Expected maybe-edge-medium to be an empty list for degree zero")
      #/void)
    #/expect maybe-edge-medium (list edge-medium)
      (error "Expected maybe-edge-medium to be a singleton list for degree nonzero")
    #/begin
      (unless (medium? edge-medium)
        (error "Expected edge-medium to be a medium"))
      (unless (= lower-degree #/medium-degree edge-medium)
        (error "Expected degree to be one greater than the degree of edge-medium")))
    (unless (medium? readable-medium)
      (error "Expected readable-medium to be a medium"))
    (unless (= 0 #/medium-degree readable-medium)
      (error "Expected readable-medium to have a degree of 0")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this
      (const-medium degree maybe-edge-medium readable-medium)
      (error "Expected this to be a const-medium")
    #/expect (medium-unpack readable-medium)
      (medium-unpacked 0 (list) verify-readable)
      (error "Expected the result of unpacking readable-medium to be a medium-unpacked of degree zero")
    #/medium-unpacked degree maybe-edge-medium
    #/lambda (maybe-content-edge content)
      (verify-readable (list) content))]
)
