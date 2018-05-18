#lang parendown racket/base


(require #/only-in racket/contract/base
  -> ->* ->i any any/c contract? parameter/c struct/c)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts dissect expect fn mat w- w-loop)
(require #/only-in lathe-comforts/hash hash-ref-maybe)
(require #/only-in lathe-comforts/maybe
  just maybe? maybe/c maybe-map nothing nothing?)
(require #/only-in lathe-comforts/struct struct-easy)

; TODO: Stop relying on `.../private/...` modules like this.
(require #/only-in
  lathe-morphisms/private/ordinals/below-epsilon-zero/onum
  onum? onum<? onum-drop onumext? onumext<? onumext-drop onum-one
  onum-plus onum-zero)
(require #/only-in
  lathe-morphisms/private/ordinals/below-epsilon-zero/olist
  olist? olist-build olist-drop olist-length olist-map olist-tails
  olist-update-thunk olist-plus-binary olist-ref-and-call
  olist-zip-map olist-zero)

; TODO: Once we implement this concretely in terms of the operations
; of `.../below-epsilon-zero/olist`, implement it instead in terms of
; algebras which those can be a special case of.

;(provide #/all-defined-out)


; TODO: See if this should go into the olist library.
(define/contract (olist-plus-build-const a minimum-length elem)
  (-> olist? onumext? (-> onum? any/c) olist?)
  (expect (olist-length a) (just an) a
  #/olist-plus-binary a
  #/olist-build (onumext-drop an minimum-length) #/fn _ elem))

; TODO: See if this should go into the olist library.
; TODO: See if we'll ever use this.
(define/contract (olist-unaligned-zip-map a b func)
  (-> olist? olist? (-> maybe? maybe? any/c) olist?)
  (w- an (olist-length a)
  #/w- bn (olist-length b)
  #/olist-zip-map
    (olist-plus-build-const (olist-map a #/fn elem #/just elem) bn
      (nothing))
    (olist-plus-build-const (olist-map b #/fn elem #/just elem) an
      (nothing))
    func))

; TODO: See if this should go into Lathe Comforts.
(define/contract (list-ref-maybe lst i)
  (-> list? natural? maybe?)
  (expect (< i #/length lst) #t (nothing)
  #/just #/list-ref lst i))


(struct-easy (hyperparameterization escapes))

(define/contract (make-empty-hyperparameterization)
  (-> hyperparameterization?)
  (hyperparameterization #/olist-build (nothing) #/fn _
    (list (make-immutable-hasheq) (make-immutable-hasheq))))

(define/contract (hyperparameterization-get-maybe hp dimension key)
  (-> hyperparameterization? onum? any/c maybe?)
  (dissect hp (hyperparameterization escapes)
  #/dissect (olist-ref-and-call escapes dimension)
    (list locals escapes)
  #/hash-ref-maybe locals key))

(define/contract (hyperparameterization-set hp dimension key value)
  (-> hyperparameterization? onum? any/c any/c hyperparameterization?)
  (dissect hp (hyperparameterization escapes)
  #/hyperparameterization #/olist-update-thunk escapes dimension
  #/fn get-escape
    (dissect (get-escape) (list locals escapes)
    #/w- escape (list (hash-set locals key value) escapes)
    #/fn escape)))

; TODO: See if this should go in olist.rkt.
(define/contract (olist-unbounded? x)
  (-> any/c boolean?)
  (and (olist? x) (nothing? #/olist-length x)))

(define/contract
  (make-hyperparameterization-for-push-or-pop
    dimension escape-key
    nonlocal-escapes low-local-escapes high-local-escapes)
  (-> onum? any/c olist-unbounded? olist? olist-unbounded?
    hyperparameterization?)
  (dissect (olist-drop dimension #/olist-tails nonlocal-escapes)
    (just #/list low-tails _)
  #/hyperparameterization #/olist-plus-binary
    (olist-zip-map low-local-escapes low-tails #/fn escape tail
      (dissect escape (list locals escapes)
      #/list locals (hash-set escapes escape-key tail)))
    high-local-escapes))

(define/contract
  (hyperparameterization-push hp dimension local-key value escape-key)
  (-> hyperparameterization? onum? any/c any/c any/c
    hyperparameterization?)
  (dissect hp (hyperparameterization escapes)
  #/dissect
    (olist-drop dimension
    #/olist-update-thunk escapes dimension #/fn get-escape
      (dissect (get-escape) (list locals escapes)
      #/w- escape (list (hash-set locals local-key value) escapes)
      #/fn escape))
    (just #/list low-local-escapes high-local-escapes)
  #/make-hyperparameterization-for-push-or-pop
    dimension escape-key
    escapes low-local-escapes high-local-escapes))

(define/contract
  (hyperparameterization-pop-maybe
    hp dimension escape-now-key escape-later-key)
  (-> hyperparameterization? onum? any/c any/c
    (maybe/c hyperparameterization?))
  (dissect hp (hyperparameterization escapes)
  #/dissect (olist-ref-and-call escapes dimension)
    (list e-locals e-escapes)
  #/maybe-map (list-ref-maybe e-escapes escape-now-key)
  #/fn high-local-escapes
    (w- low-local-escapes
      (olist-build (just dimension) #/fn _
        (list (make-immutable-hasheq) (make-immutable-hasheq)))
    #/make-hyperparameterization-for-push-or-pop
      dimension escape-later-key
      escapes low-local-escapes high-local-escapes)))


(struct-easy (token))

(define/contract current-hyperparameterization
  (parameter/c hyperparameterization?)
  (make-parameter #/make-empty-hyperparameterization))

(struct-easy (hyperparameter dimension key default-value guard wrap)
  #:other
  #:property prop:procedure
  (case-lambda
    [ (this)
      (expect this
        (hyperparameter dimension key default-value guard wrap)
        (error "Expected this to be a hyperparameter")
      #/wrap
      #/expect
        (hyperparameterization-get-maybe
          (get-current-hyperparameterization)
          dimension key)
        (just value)
        default-value
        value)]
    [ (this incoming)
      (expect this
        (hyperparameter dimension key default-value guard wrap)
        (error "Expected this to be a hyperparameter")
      #/current-hyperparameterization #/hyperparameterization-set
        (get-current-hyperparameterization)
        dimension key #/guard incoming)]))

; NOTE: This corresponds to `make-parameter`.
(define/contract
  (make-hyperparameter dimension value [guard (fn incoming incoming)])
  (->* (onum? any/c) ((-> any/c any/c)) hyperparameter?)
  (hyperparameter dimension (token) value
    guard
    (fn outgoing outgoing)))

(define/contract (-hyperparameter-dimension hp)
  (-> hyperparameter? onum?)
  (dissect hp (hyperparameter dimension key default-value guard wrap)
    dimension))

; NOTE: This corresponds to `parameterize` and `parameterize*`.
;
; TODO: Define syntaxes closer to `parameterize` and `parameterize*`
; for this.
;
(define/contract
  (call-with-hyperparameterization-binding hp value body)
  (->i
    (
      [hp hyperparameter?]
      [value any/c]
      [body (hp)
        (->i ([escapes olist?])
          
          #:pre (escapes)
          (equal?
            (just #/-hyperparameter-dimension hp)
            (olist-length escapes))
          
          any)])
    any)
  (dissect hp (hyperparameter dimension key default-value guard wrap)
  #/w- id (token)
  #/w-loop loop
    dimension dimension
    id id
    hpn
    (hyperparameterization-push (get-current-hyperparameterization)
      dimension key (guard value) id)
    body body
  #/parameterize ([current-hyperparameterization hpn])
    (body #/olist-build (just dimension) #/fn d
      (fn body
        (w- sub-id (token)
        #/expect
          (hyperparameterization-pop-maybe
            (get-current-hyperparameterization)
            d id sub-id)
          (just hpn)
          (error "Used a hyperameterize hole for a dynamic extent that wasn't currently in progress")
        #/loop d sub-id hpn body)))))

; NOTE: This corresponds to `make-derived-parameter`.
(define/contract (make-derived-hyperparameter hp guard wrap)
  (-> hyperparameter? (-> any/c any/c) (-> any/c any/c)
    hyperparameter?)
  ; NOTE: The "o" stands for "original."
  (dissect hp
    (hyperparameter o-dimension o-key o-default-value o-guard o-wrap)
  #/hyperparameter o-dimension o-key o-default-value
    (fn incoming #/o-guard #/guard incoming)
    (fn outgoing #/wrap #/o-wrap outgoing)))

; NOTE: This corresponds to `parameter?`.
(define/contract (-hyperparameter? x)
  (-> any/c boolean?)
  (hyperparameter? x))

; TODO: See if we can make something that corresponds to
; `parameter-procedure=?`.

; NOTE: This corresponds to `current-parameterization`.
;
; TODO: See if we should rename this to
; `current-hyperparameterization` and rename the parameter of that
; name to something else.
;
; TODO: See if we really need this, or if we'll just export the
; parameter directly.
;
(define/contract (get-current-hyperparameterization)
  (-> hyperparameterization?)
  (current-hyperparameterization))

; NOTE: This corresponds to `call-with-parameterization`.
(define/contract (call-with-hyperparameterization hp thunk)
  (-> hyperparameterization? (-> any) any)
  (parameterize ([current-hyperparameterization hp]) #/thunk))

; NOTE: This corresponds to `parameterization?`.
(define/contract (-hyperparameterization? x)
  (-> any/c boolean?)
  (hyperparameterization? x))

; NOTE: This corresponds to `parameter/c`.
(define/contract (hyperparameter/c dimension/c in/c [out/c in/c])
  (->* (contract? contract?) (contract?) contract?)
  (struct/c hyperparameter dimension/c any/c any/c
    (-> in/c any/c)
    (-> any/c out/c)))
