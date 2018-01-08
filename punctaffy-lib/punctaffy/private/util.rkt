#lang parendown racket/base

; util.rkt
;
; Miscellaneous utilities

(require #/for-meta 1 racket/base)

; NOTE: Just in case we want to switch back to `eq?` hashes, we refer
; to `equal?` hashes more explicitly.
(require #/only-in racket/base
  [make-immutable-hash make-immutable-hashequal])

(require racket/contract/base)
(require racket/list)
(require racket/match)
(require #/only-in racket/struct make-constructor-style-printer)

(require #/for-meta 1 #/only-in lathe next nextlet w-)
(require #/only-in lathe dissect dissectfn expect next nextlet w-)

(provide #/all-defined-out)


(define (nat-pred-maybe n)
  (unless (exact-nonnegative-integer? n)
    (error "Expected n to be an exact nonnegative integer"))
  (if (= n 0)
    (list)
    (list #/sub1 n)))


(define (list-foldl state lst func)
  (foldl (lambda (elem state) #/func state elem) state lst))

(define (list-kv-map lst func)
  (map func (range #/length lst) lst))

(define (list-fmap lst func)
  (map func lst))

(define (list-bind lst func)
  (append-map func lst))

(define (list-each lst body)
  (for-each body lst))

(define (list-kv-all lst func)
  (andmap func (range #/length lst) lst))

(define (list-all lst func)
  (andmap func lst))

(define (list-zip-map a b func)
  (list-fmap (map list a b) #/dissectfn (list a b) #/func a b))

(define (list-zip-all a b func)
  (list-all (map list a b) #/dissectfn (list a b) #/func a b))

(define (list-zip-each a b body)
  (list-each (map list a b) #/dissectfn (list a b) #/body a b))

(define (length-lte lst n)
  (if (< n 0)
    #f
  #/expect lst (cons first rest) #t
  #/length-lte rest #/sub1 n))

(define (lt-length n lst)
  (not #/length-lte lst n))


(define (hashequal-immutable? x)
  ((and/c hash? hash-equal? immutable?) x))

(define (hashequal-kv-map-maybe-kv hash func)
  (make-immutable-hashequal #/list-bind (hash->list hash)
  #/dissectfn (cons k v)
    (match (func k v)
      [(list) (list)]
      [(list #/list k v) (list #/cons k v)]
      [_ (error "Expected the func result to be a maybe of a two-element list")])))

(define (hashequal-kv-map-maybe hash func)
  (make-immutable-hashequal #/list-bind (hash->list hash)
  #/dissectfn (cons k v)
    (match (func k v)
      [(list) (list)]
      [(list v) (list #/cons k v)]
      [_ (error "Expected the func result to be a maybe")])))

(define (hashequal-kv-map hash func)
  (hashequal-kv-map-maybe hash #/lambda (k v) #/list #/func k v))

(define (hashequal-kv-map-kv hash func)
  (hashequal-kv-map-maybe-kv hash #/lambda (k v)
    (expect (func k v) (list k v)
      (error "Expected the func result to be a two-element list")
    #/list #/list k v)))

(define (hashequal-fmap hash func)
  (hashequal-kv-map hash #/lambda (k v) #/func v))

(define (hash-keys-same? a b)
  (and (= (hash-count a) (hash-count b)) #/hash-keys-subset? a b))

(define (hashequal-restrict original example)
  (hashequal-kv-map-maybe original #/lambda (k v)
    (if (hash-has-key? example k)
      (list v)
      (list))))

(define (hash-kv-each hash body)
  (list-each (hash->list hash) #/dissectfn (cons k v)
    (body k v)))

(define (hash-kv-map-sorted key<? hash body)
  (list-fmap (sort (hash->list hash) key<? #:key car)
  #/dissectfn (cons k v)
    (body k v)))

(define (hash-kv-all hash func)
  ; NOTE: We go to all this trouble just so that when we exit early,
  ; we avoid the cost of a full `hash->list`.
  (nextlet cursor (hash-iterate-first hash)
    (if (eq? #f cursor) #t
    #/dissect (hash-iterate-pair hash cursor) (cons k v)
    #/w- result (func k v)
    #/if result
      (next #/hash-iterate-next hash cursor)
      result)))


(define (guard-easy guard)
  (lambda slots-and-name
    (expect (reverse slots-and-name) (cons name rev-slots)
      (error "Expected a guard procedure to be called with at least a struct name argument")
    #/w- slots (reverse rev-slots)
      (apply guard slots)
      (apply values slots))))

(define-syntax (struct-easy stx)
  (syntax-case stx () #/ (_ phrase (name slot ...) rest ...)
  #/nextlet rest #'(rest ...) has-write #f options #'()
    (w- next
      (lambda (rest has-write-now options-suffix)
        (next rest (or has-write has-write-now)
        #`#/#,@options #,@options-suffix))
    #/syntax-case rest ()
      
      [()
      #/if has-write
        #`(struct name (slot ...) #,@options)
        (next
          #'(#:write #/lambda (this) #/list slot ...)
          #f
          #'())]
      
      [(#:other rest ...) #/next #'() #f #'#/rest ...]
      
      [(#:write writefn rest ...)
      #/next #'(rest ...) #t #'#/#:methods gen:custom-write #/
        (define write-proc
          (make-constructor-style-printer
            (lambda (this) 'name)
            (lambda (this)
              (expect this (name slot ...)
                (error #/string-append "Expected this to be " phrase)
              #/writefn this))))]
      
      [(#:equal rest ...)
      #/next #'(rest ...) #f #'#/#:methods gen:equal+hash #/
        (define (equal-proc a b recursive-equal?)
          (expect a (name slot ...)
            (error #/string-append "Expected a to be " phrase)
          #/w- a-slots (list slot ...)
          #/expect b (name slot ...)
            (error #/string-append "Expected b to be " phrase)
          #/w- b-slots (list slot ...)
          #/list-all (map list a-slots b-slots)
          #/dissectfn (list a-slot b-slot)
            (recursive-equal? a-slot b-slot)))
        (define (hash-proc this recursive-equal-hash-code)
          (expect this (name slot ...)
            (error #/string-append "Expected this to be " phrase)
          #/recursive-equal-hash-code #/list slot ...))
        (define (hash2-proc this recursive-equal-secondary-hash-code)
          (expect this (name slot ...)
            (error #/string-append "Expected this to be " phrase)
          #/recursive-equal-secondary-hash-code #/list slot ...))]
      
      [((#:guard-easy body ...) rest ...)
      #/next #'(rest ...) #f #'#/#:guard
      #/guard-easy #/lambda (slot ...) body ...])))

(define (syntax-local-maybe identifier)
  (if (identifier? identifier)
    (w-
      dummy (list #/list)
      local (syntax-local-value identifier #/lambda () dummy)
    #/if (eq? local dummy)
      (list)
      (list local))
    (list)))


(define (debug-log label result)
  (displayln label)
  (writeln result)
  result)


(define-syntax-rule (while condition body ...)
  (let next () #/when condition
    body ...
    (next)))
