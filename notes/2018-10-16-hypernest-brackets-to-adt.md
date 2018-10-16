### Figuring out how to transform hypernest brackets into ADT-style hypernest constructors


Suppose we have the following operations:

`(n-ht d bracket ...)`: Constructs a degree-`d` hypertee based on bracket notation.

`(htz)`: Constructs a degree-0 hypertee.

`(hth d data tails-hypertee)`: Constructs a degree-`d` hypertee that begins with a hole.

`(n-hn d bracket ...)`: Constructs a hypernest based on bracket notation.

`(hnz)`: Constructs a degree-0 hypernest which has no bumps.

`(hnh d data tails-hypertee)`: Constructs a degree-`d` hypernest that begins with a hole.

`(hnb d data tails-hypernest)`: Constructs a degree-`d` hypernest that begins with a bump.

As of the time of this writing, we're trying to implement `n-hn` in terms of `htz`, `hth`, `hnz`, `hnh`, and `hnb` (with no use of `n-ht` if possible), although we use substantially more verbose notation (such as `(hypernest-plus1 #/hypernest-coil-hole d data tails-hypertee)`).

What do we need to do for a simple degree-2 input like this one?

```
(n-hn 2 (list 1 'a) 0 (list 0 'a))
```

First let's determine the result we want by hand:

```
(n-hn 2 (list 1 'a) 0 (list 0 'a))
(hnh 2 'a (n-ht 1 (list 0 (n-hn 2 (list 0 'a)))))
(hnh 2 'a (n-ht 1 (list 0 (hnh 2 'a (n-ht 0)))))
(hnh 2 'a (n-ht 1 (list 0 (hnh 2 'a (htz)))))
(hnh 2 'a (hth 1 (hnh 2 'a (htz)) (n-ht 0)))
(hnh 2 'a (hth 1 (hnh 2 'a (htz)) (htz)))
```

If we traverse the sequence of brackets and keep a mutable store along the way, these are the steps we might want to take:

```
start with 'p0
write (hnh 2 'a 'p1) to 'p0
write (hth 1 'p2 'p3) to 'p1
write (hnh 2 'a 'p4) to 'p2
write (htz) to 'p3 and 'p4
```

Now how about a degree-3 input? Let's take the input we want and derive the result we want by hand again:

```
(n-hn 3 (list 2 'a) 1 (list 1 'a) 0 0 0 (list 0 'a))

(hnh 3 'a (n-ht 2 (list 1 (n-hn 3 (list 1 'a) 0 (list 0 (trivial)))) 0 (list 0 (n-hn 3 (list 0 'a)))))

(hnh 3 'a (n-ht 2 (list 1 (hnh 3 'a (hth 1 (hnh 3 (trivial) (htz)) (htz)))) 0 (list 0 (hnh 3 'a (htz)))))

(hnh 3 'a (hth 2 (hnh 3 'a (hth 1 (hnh 3 (trivial) (htz)) (htz))) (hth 1 (hth 2 (hnh 3 'a (htz)) (htz)) (htz))))
```

Let's do that again while attempting to keep track of which nodes of the result are likely to be constructed after which input brackets are encountered:

```
(n-hn 3 z1:(list 2 'a) z2:1 z3:(list 1 'a) z4:0 z5:0 z6:0 z7:(list 0 'a))

z1:(hnh 3 'a (n-ht 2 z2:(list 1 (n-hn 3 z3:(list 1 'a) z4:0 z5:(list 0 (trivial)))) z5:0 z6:(list 0 (n-hn 3 z7:(list 0 'a)))))

z1:(hnh 3 'a (n-ht 2 z2:(list 1 z3:(hnh 3 'a (hth 1 z4:(hnh 3 (trivial) z5:(htz)) z5:(htz)))) z5:0 z6:(list 0 z7:(hnh 3 'a (htz)))))

z1:(hnh 3 'a z2:(hth 2 z3:(hnh 3 'a (hth 1 z4:(hnh 3 (trivial) z5:(htz)) z5:(htz))) z5:(hth 1 z6:(hth 2 z7:(hnh 3 'a (htz)) z7:(htz)) z6:(htz))))
```

Let's try to describe the proceduure for computing this result by traversing the brackets with a mutable store:

(Legend: The line "in 3" signifies that the traversal of the brackets is currently in a region of degree 3, meaning only holes of degree less than 3 should be encountered.)

```
start with 'p0

in 3
read z1:(list 2 'a)
  write (hnh 3 'a 'p1) to 'p0

in 2
read z2:1
  write (hth 2 'p2 'p3) to 'p1

in 3
read z3:(list 1 'a)
  write (hnh 3 'a 'p4) to 'p2
    write (hth 1 'p5 'p6) to 'p4

in 1
read z4:0
  write (hnh 3 (trivial) 'p7) to 'p5

in 3
read z5:0
  write (htz) to 'p6
  write (htz) to 'p7
  write (hth 1 'p8 'p9) to 'p3

in 2
read z6:0
  write (hth 2 'p10 'p11) to 'p8
  write (htz) to 'p9

in 3
read z7:(list 0 'a)
  write (hnh 3 'a 'p12) to 'p10
    write (htz) to 'p12
  write (htz) to 'p11

in 0
reach end
  write nothing
```

...There aren't many clear patterns in there. We seem to have associated the nodes with steps incorrectly.

After thinking about this some more and rearranging some of the "write" lines to other steps, here's a more elaborate description of the algorithm we need to use here:

(Legend: Now in addition to noting down the current region's degree, we keep track of which mutable variables are "pending," what their expected types are, and which dimensions of encounterable holes will result in writes to them. Note that every time we write an `hnh` or an `hth`, the types of the variables we introduce that way are determined by the current region's degree and the type of the variable we've written to.)

```
start with 'p0

in 3
  pending 'p0 for 0, 1, 2:
    hn 3
      any
      any
      any
read z1:(list 2 'a)
  write (hnh 3 'a 'p1) to 'p0

in 2
  pending 'p1 for 0, 1:
    ht 2
      hn 3
        any
        any
        trivial
      hn 3
        any
        any
        any
read z2:1
  write (hth 2 'p2 'p3) to 'p1

in 3
  pending 'p2 for 0, 1, 2:
    hn 3
      any
      any
      trivial, cascading to 'p3
  pending 'p3, but only for cascading, and 'p2 cascades here for 0:
    ht 1
      ht 2
        hn 3
          any
          any
          trivial
        hn 3
          any
          any
          any
read z3:(list 1 'a)
  write (hnh 3 'a 'p4) to 'p2

in 1
  pending 'p3, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 2
        hn 3
          any
          any
          trivial
        hn 3
          any
          any
          any
  pending 'p4 for 0:
    ht 1
      hn 3
        any
        any
        trivial, cascading to 'p3
read z4:0
  write (hth 1 'p5 'p6) to 'p4

in 3
  pending 'p3, but only for cascading, and 'p5 cascades here for 0:
    ht 1
      ht 2
        hn 3
          any
          any
          trivial
        hn 3
          any
          any
          any
  pending 'p5 for 0, 1, 2:
    hn 3
      any
      any
      trivial, cascading to 'p3
  pending 'p6: ht 0
read z5:0
  write (hnh 3 (trivial) 'p7) to 'p5
  this cascades, so
  write (hth 1 'p8 'p9) to 'p3

in 2
  pending 'p6: ht 0
  pending 'p7: ht 0
  pending 'p8 for 0, 1:
    ht 2
      hn 3
        any
        any
        trivial
      hn 3
        any
        any
        any
  pending 'p9: ht 0
read z6:0
  write (hth 2 'p10 'p11) to 'p8

in 3
  pending 'p6: ht 0
  pending 'p7: ht 0
  pending 'p9: ht 0
  pending 'p10 for 0, 1, 2:
    hn 3
      any
      any
      any
  pending 'p11: ht 0
read z7:(list 0 'a)
  write (hnh 3 'a 'p12) to 'p10

in 0
  pending 'p6: ht 0
  pending 'p7: ht 0
  pending 'p9: ht 0
  pending 'p11: ht 0
  pending 'p12: ht 0
reach end
  write (htz) to 'p6
  write (htz) to 'p7
  write (htz) to 'p9
  write (htz) to 'p11
  write (htz) to 'p12
```
