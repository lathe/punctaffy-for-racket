### Figuring out how to transform hypernest brackets into ADT-style hypernest constructors


Suppose we have the following operations:

`(n-ht d bracket ...)`: Constructs a degree-`d` hypertee based on bracket notation.

`(htz)`: Constructs a degree-0 hypertee.

`(hth d data tails-hypertee)`: Constructs a degree-`d` hypertee that begins with a hole.

`(n-hn d bracket ...)`: Constructs a hypernest based on bracket notation.

`(hnz)`: Constructs a degree-0 hypernest which has no bumps.

`(hnh d data tails-hypertee)`: Constructs a degree-`d` hypernest that begins with a hole.

`(hno overall-degree data bump-degree tails-hypernest)`: Constructs a degree-`overall-degree` hypernest that begins with a bump.

As of the time of this writing, we're trying to implement `n-hn` in terms of `htz`, `hth`, `hnz`, `hnh`, and `hno` (with no use of `n-ht` if possible), although we use substantially more verbose notation (such as `(hypernest-plus1 #/hypernest-coil-hole d data tails-hypertee)`).

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
        any
      hn 3
        trivial
        any
        any
read z2:1
  write (hth 2 'p2 'p3) to 'p1

in 3
  pending 'p2 for 0, 1, 2:
    hn 3
      trivial, cascading to 'p3
      any
      any
  pending 'p3, but only for cascading, and 'p2 cascades here for 0:
    ht 1
      ht 2
        hn 3
          any
          any
          any
        hn 3
          trivial
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
          any
        hn 3
          trivial
          any
          any
  pending 'p4 for 0:
    ht 1
      hn 3
        trivial, cascading to 'p3
        any
        any
read z4:0
  write (hth 1 'p5 'p6) to 'p4

in 3
  pending 'p3, but only for cascading, and 'p5 cascades here for 0:
    ht 1
      ht 2
        hn 3
          any
          any
          any
        hn 3
          trivial
          any
          any
  pending 'p5 for 0, 1, 2:
    hn 3
      trivial, cascading to 'p3
      any
      any
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
        any
      hn 3
        trivial
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

---

Aside:

The reason we postpone the `(htz)` writes to the end in the above example is so that we can now ponder the question of whether a degree-0 hypernest should be able to have bumps. If it should, then we can't write an `(hnz)` to it right away, because we don't know if we've yet to encounter its bumps. So we treat `(htz)` that way as well, to keep the option open.

Degree-0 hypernests are almost never used. An `hno` node uses a hypernest of degree equal to the max of its `overall-degree` and its `bump-degree`, so it'll never use a degree-0 hypernest unless both those things are zero. Since `hnz` and `hno` would be the only ways to make degree-0 hypernests, it seems we don't have to care how a degree-0 hypernest works unless we set out to make one in the first place.

Suppose we do. Then we have a bit of a conundrum with regard to the bracket notation: Once we've opened a degree-0 bump in a degree-0 hypernest...

```
(n-hn 0 (list 'open 0 'a) ...)
```

...then we have two degree-0 hypernests in progress. If we have another bump after that, which one of them is it a bump for?

This isn't a problem we have to worry about if we decide by fiat that `hno` cannot construct degree-0 hypernests. On the other hand, it's a problem we don't have to worry about if we don't use bracket notation, so if it turns out to be elegant in an algebraic way, we will have regretted choosing a notation that doesn't support it. All it would take is a little extension to support this -- just another bracket of the form "we're done specifying bumps for the nearest degree-0 bump now."

For now, since hypernests are pretty much entirely motivated by syntactic needs, we will embrace the bracket notation and disallow `hno` from constructing degree-0 hyprnests.

This means that in the above example, we didn't really have to postpone the `(htz)` writes until the end after all. We can write those values immediately, and that means we don't even need to keep track of them in the "pending" information.

---

Hmm, it's not clear how cascading works when there's more than one degree that can cascade at a time; after all, both of their mutable variables should be written eventually, but only one cascade path is actually taken. Let's work through a degree-4 example so we can see this happen.


```
(n-hn 4
  (list 3 'a)
  2
  (list 2 'a)
  1
  1
  1
  (list 1 'a)
  0
  0
  0
  0
  0
  0
  0
  (list 0 'a))

(hnh 4 'a
  (n-ht 3
    (list 2
      (n-hn 4
        (list 2 'a)
        1
        (list 1 (trivial))
        0
        0
        0
        (list 0 (trivial))))
    1
    (list 1 (n-hn 4 (list 1 'a) 0 (list 0 (trivial))))
    0
    0
    0
    (list 0 (n-hn 4 (list 0 'a)))))

(hnh 4 'a
  (n-ht 3
    (list 2
      (hnh 4 'a
        (n-ht 2
          (list 1 (n-hn 4 (list 1 (trivial)) 0 (list 0 (trivial))))
          0
          (list 0 (n-hn 4 (list 0 (trivial)))))))
    1
    (list 1 (hnh 4 'a (n-ht 1 (list 0 (n-hn 4 (list 0 (trivial)))))))
    0
    0
    0
    (list 0 (hnh 4 'a (htz)))))

(hnh 4 'a
  (n-ht 3
    (list 2
      (hnh 4 'a
        (n-ht 2
          (list 1
            (hnh 4 (trivial)
              (n-ht 1 (list 0 (n-hn 4 (list 0 (trivial)))))))
          0
          (list 0 (hnh 4 (trivial) (htz))))))
    1
    (list 1 (hnh 4 'a (n-ht 1 (list 0 (hnh 4 (trivial) (htz))))))
    0
    0
    0
    (list 0 (hnh 4 'a (htz)))))

(hnh 4 'a
  (n-ht 3
    (list 2
      (hnh 4 'a
        (n-ht 2
          (list 1
            (hnh 4 (trivial)
              (n-ht 1 (list 0 (hnh 4 (trivial) (htz))))))
          0
          (list 0 (hnh 4 (trivial) (htz))))))
    1
    (list 1 (hnh 4 'a (n-ht 1 (list 0 (hnh 4 (trivial) (htz))))))
    0
    0
    0
    (list 0 (hnh 4 'a (htz)))))

(hnh 4 'a
  (n-ht 3
    (list 2
      (hnh 4 'a
        (n-ht 2
          (list 1
            (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz))))
          0
          (list 0 (hnh 4 (trivial) (htz))))))
    1
    (list 1 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz))))
    0
    0
    0
    (list 0 (hnh 4 'a (htz)))))

(hnh 4 'a
  (n-ht 3
    (list 2
      (hnh 4 'a
        (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
          (n-ht 1
            (list 0 (n-ht 2 (list 0 (hnh 4 (trivial) (htz)))))))))
    1
    (list 1 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz))))
    0
    0
    0
    (list 0 (hnh 4 'a (htz)))))

(hnh 4 'a
  (n-ht 3
    (list 2
      (hnh 4 'a
        (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
          (n-ht 1 (list 0 (hth 2 (hnh 4 (trivial) (htz)) (htz)))))))
    1
    (list 1 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz))))
    0
    0
    0
    (list 0 (hnh 4 'a (htz)))))

(hnh 4 'a
  (n-ht 3
    (list 2
      (hnh 4 'a
        (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
          (hth 1 (hth 2 (hnh 4 (trivial) (htz)) (htz)) (htz)))))
    1
    (list 1 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz))))
    0
    0
    0
    (list 0 (hnh 4 'a (htz)))))

(hnh 4 'a
  (hth 3
    (hnh 4 'a
      (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 2 (hnh 4 (trivial) (htz)) (htz)) (htz))))
    (n-ht 2
      (list 1
        (n-ht 3
          (list 1 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz))))
          0
          (list 0 (trivial))))
      0
      (list 0 (n-ht 3 (list 0 (hnh 4 'a (htz))))))))

(hnh 4 'a
  (hth 3
    (hnh 4 'a
      (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 2 (hnh 4 (trivial) (htz)) (htz)) (htz))))
    (n-ht 2
      (list 1
        (hth 3 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz)))
          (n-ht 1 (list 0 (n-ht 3 (list 0 (trivial)))))))
      0
      (list 0 (hth 3 (hnh 4 'a (htz)) (htz))))))

(hnh 4 'a
  (hth 3
    (hnh 4 'a
      (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 2 (hnh 4 (trivial) (htz)) (htz)) (htz))))
    (n-ht 2
      (list 1
        (hth 3 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz)))
          (n-ht 1 (list 0 (hth 3 (trivial) (htz))))))
      0
      (list 0 (hth 3 (hnh 4 'a (htz)) (htz))))))

(hnh 4 'a
  (hth 3
    (hnh 4 'a
      (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 2 (hnh 4 (trivial) (htz)) (htz)) (htz))))
    (n-ht 2
      (list 1
        (hth 3 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz)))
          (hth 1 (hth 3 (trivial) (htz)) (htz))))
      0
      (list 0 (hth 3 (hnh 4 'a (htz)) (htz))))))

(hnh 4 'a
  (hth 3
    (hnh 4 'a
      (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 2 (hnh 4 (trivial) (htz)) (htz)) (htz))))
    (hth 2
      (hth 3 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 3 (trivial) (htz)) (htz)))
      (n-ht 1
        (list 0 (n-ht 2 (list 0 (hth 3 (hnh 4 'a (htz)) (htz)))))))))

(hnh 4 'a
  (hth 3
    (hnh 4 'a
      (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 2 (hnh 4 (trivial) (htz)) (htz)) (htz))))
    (hth 2
      (hth 3 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 3 (trivial) (htz)) (htz)))
      (n-ht 1
        (list 0 (hth 2 (hth 3 (hnh 4 'a (htz)) (htz)) (htz)))))))

(hnh 4 'a
  (hth 3
    (hnh 4 'a
      (hth 2 (hnh 4 (trivial) (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 2 (hnh 4 (trivial) (htz)) (htz)) (htz))))
    (hth 2
      (hth 3 (hnh 4 'a (hth 1 (hnh 4 (trivial) (htz)) (htz)))
        (hth 1 (hth 3 (trivial) (htz)) (htz)))
      (hth 1 (hth 2 (hth 3 (hnh 4 'a (htz)) (htz)) (htz)) (htz)))))
```

All right, now we know what we're aiming for. To make it easier to
follow along with the following step-by-step construction, here's the
same structure with all the nodes labeled according to the mutable
variables they're going to be written to. This is something I
maintained while I was working through the steps, so it's not
something we could easily derive at this point in the document.

```
(p0:hnh 4 'a
  (p1:hth 3
    (p2:hnh 4 'a
      (p4:hth 2
        (p5:hnh 4 (trivial)
          (p7:hth 1 (p19:hnh 4 (trivial) (p23:htz)) (p20:htz)))
        (p6:hth 1
          (p24:hth 2 (p26:hnh 4 (trivial) (p28:htz)) (p27:htz))
          (p25:htz))))
    (p3:hth 2
      (p8:hth 3
        (p10:hnh 4 'a
          (p12:hth 1 (p13:hnh 4 (trivial) (p15:htz)) (p14:htz)))
        (p11:hth 1 (p16:hth 3 (trivial) (p18:htz)) (p17:htz)))
      (p9:hth 1
        (p21:hth 2 (p29:hth 3 (p31:hnh 4 'a (p33:htz)) (p32:htz))
          (p30:htz))
        (p22:htz)))))
```

Now to start the stepp-by-step algorithm, processing one bracket at a
time and writing to a mutable store:

```
start with 'p0

in 4
  pending 'p0 for 0, 1, 2, 3:
    hn 4: a,a,a,a
read (list 3 'a)
  write (hnh 4 'a 'p1) to 'p0

in 3
  pending 'p1 for 0, 1, 2:
    ht 3
      hn 4: a,a,a,a
      hn 4: t,a,a,a
      hn 4: t,t,a,a
read 2
  write (hth 3 'p2 'p3) to 'p1

in 4
  pending 'p2 for 0, 1, 2, 3:
    hn 4
      trivial, cascading to 'p3
      trivial, cascading to 'p3
      any
      any
  pending 'p3, but only for cascading, and 'p2 cascades here for 0, 1:
    ht 2
      ht 3
        hn 4: a,a,a,a
        hn 4: t,a,a,a
        hn 4: t,t,a,a
      ht 3
        trivial
        hn 4: t,a,a,a
        hn 4: t,t,a,a
read (list 2 'a)
  write (hnh 4 'a 'p4) to 'p2

in 2
  pending 'p3, but only for cascading, and nothing cascades here yet:
    ht 2
      ht 3
        hn 4: a,a,a,a
        hn 4: t,a,a,a
        hn 4: t,t,a,a
      ht 3
        trivial
        hn 4: t,a,a,a
        hn 4: t,t,a,a
  pending 'p4 for 0, 1:
    ht 2
      hn 4
        trivial, cascading to 'p3
        trivial, cascading to 'p3
        any
        any
      hn 4
        trivial
        trivial, cascading to 'p3
        any
        any
read 1
  write (hth 2 'p5 'p6) to 'p4

in 4
  pending 'p3, but only for cascading, and 'p5 cascades here for 1:
    ht 2
      ht 3
        hn 4: a,a,a,a
        hn 4: t,a,a,a
        hn 4: t,t,a,a
      ht 3
        trivial
        hn 4: t,a,a,a
        hn 4: t,t,a,a
  pending 'p5 for 0, 1, 2, 3:
    hn 4
      trivial, cascading to 'p6
      trivial, cascading to 'p3
      any
      any
  pending 'p6, but only for cascading, and 'p5 cascades here for 0:
    ht 1
      ht 2
        hn 4
          trivial, cascading to 'p3
          trivial, cascading to 'p3
          any
          any
        hn 4
          trivial
          trivial, cascading to 'p3
          any
          any
read 1
  write (hnh 4 (trivial) 'p7) to 'p5
  this cascades, so
  write (hth 2 'p8 'p9) to 'p3
```

We take a break here to note that we're doing something new in this step (and hence something with a high likelihood of incorrectness we've yet to uncover). After this step, there's one more step that's tricky later on, but we'll describe it here.

The new thing here is that we're writing a degree-1 hole in a way that cascades. Before, the only times we cascaded were when we wrote a degree-0 hole.

This time, `'p9` is not a `(htz)`, so we actually have to worry about when its value will be written -- that is, we have to worry about how `'p8` will (perhaps indirectly) cascade to it.

In fact, since we're introducing three variables -- `'p7`, `'p8`, and `'p9` -- we really need a cascading scheme that will make its way through all three of them.

For the most part, the types of `'p7`, `'p8`, and `'p9` will be just like the types we get from writing non-cascading degree-1 holes. Only the "cascading to" parts are going to be different here.

We're writing to `'p3`, so after this, all the places we *would* cascade to `'p3`, we have to cascade to somewhere else. We'll even have to update the places `'p6` says "`cascading to 'p3`", even though `'p6` is not otherwise related to the variables we're writing here.

It turns out the order we want to cascade through these new variables is `'p8`, `'p7`, `'p9`. After all, `'p9` in this example doesn't cascade to anything else, so it must be last; and we need `'p8` to be first because it's the one variable that has the dimension that corresponds to the dimension of the region we've arrived at.

So what we do is this: To make `'p7` lead to `'p9`, we deeply replace "`cascading to 'p3`" in the type of every variable (including in the type of `'p6`) with "`cascading to whatever 'p9 becomes`". To make `'p8` lead to `'p7`, we use "`cascading to 'p7 while updating 'p9`" in the appropriate place in the type of `'p8` (where we would usually use "`cascading to 'p9`" if this write hadn't come from a cascade).

Well, that describes the notation we use, but what do the phrases "`cascading to whatever 'p9 becomes`" and "`cascading to 'p7 while updating 'p9`" actually mean?

Later on, when we reach the moment where we need to cascade "`to 'p7 while updating 'p9`", what happens is that we advance **both** `'p7` and `'p9`. When we advance `'p9` this way, we create the variable that we really wanted the "`cascading to whatever 'p9 becomes`" pieces to cascade to in the first place, so we replace those phrases to use the new variable (namely "`cascading to 'p21`").

Now back to following the step-by-step algorithm.

```
in 3
  pending 'p6, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 2
        hn 4
          trivial, cascading to whatever 'p9 becomes
          trivial, cascading to whatever 'p9 becomes
          any
          any
        hn 4
          trivial
          trivial, cascading to whatever 'p9 becomes
          any
          any
  pending 'p7, but only for cascading, and 'p8 cascades here for 0:
    ht 1
      hn 4
        trivial, cascading to 'p6
        trivial, cascading to whatever 'p9 becomes
        any
        any
  pending 'p8 for 0, 1, 2:
    ht 3
      trivial, cascading to 'p7 while updating 'p9
      hn 4: t,a,a,a
      hn 4: t,t,a,a
  pending 'p9, but only for cascading, and 'p8 updates this for 0:
    ht 1
      ht 2
        ht 3
          hn 4: a,a,a,a
          hn 4: t,a,a,a
          hn 4: t,t,a,a
        ht 3
          trivial
          hn 4: t,a,a,a
          hn 4: t,t,a,a
read 1
  write (hth 3 'p10 'p11) to 'p8

in 4
  pending 'p6, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 2
        hn 4
          trivial, cascading to whatever 'p9 becomes
          trivial, cascading to whatever 'p9 becomes
          any
          any
        hn 4
          trivial
          trivial, cascading to whatever 'p9 becomes
          any
          any
  pending 'p7, but only for cascading, and nothing cascades here yet:
    ht 1
      hn 4
        trivial, cascading to 'p6
        trivial, cascading to whatever 'p9 becomes
        any
        any
  pending 'p9, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 2
        ht 3
          hn 4: a,a,a,a
          hn 4: t,a,a,a
          hn 4: t,t,a,a
        ht 3
          trivial
          hn 4: t,a,a,a
          hn 4: t,t,a,a
  pending 'p10 for 0, 1, 2, 3:
    hn 4
      trivial, cascading to 'p11
      any
      any
      any
  pending 'p11, but only for cascading, and 'p10 cascades here for 0:
    ht 1
      ht 3
        trivial, cascading to 'p7 while updating 'p9
        hn 4: t,a,a,a
        hn 4: t,t,a,a
read (list 1 'a)
  write (hnh 4 'a 'p12) to 'p10

in 1
  pending 'p6, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 2
        hn 4
          trivial, cascading to whatever 'p9 becomes
          trivial, cascading to whatever 'p9 becomes
          any
          any
        hn 4
          trivial
          trivial, cascading to whatever 'p9 becomes
          any
          any
  pending 'p7, but only for cascading, and nothing cascades here yet:
    ht 1
      hn 4
        trivial, cascading to 'p6
        trivial, cascading to whatever 'p9 becomes
        any
        any
  pending 'p9, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 2
        ht 3
          hn 4: a,a,a,a
          hn 4: t,a,a,a
          hn 4: t,t,a,a
        ht 3
          trivial
          hn 4: t,a,a,a
          hn 4: t,t,a,a
  pending 'p11, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 3
        trivial, cascading to 'p7 while updating 'p9
        hn 4: t,a,a,a
        hn 4: t,t,a,a
  pending 'p12 for 0:
    ht 1
      hn 4
        trivial, cascading to 'p11
        any
        any
        any
read 0
  write (hth 1 'p13 'p14) to 'p12
    write (htz) to 'p14

in 4
  pending 'p6, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 2
        hn 4
          trivial, cascading to whatever 'p9 becomes
          trivial, cascading to whatever 'p9 becomes
          any
          any
        hn 4
          trivial
          trivial, cascading to whatever 'p9 becomes
          any
          any
  pending 'p7, but only for cascading, and nothing cascades here yet:
    ht 1
      hn 4
        trivial, cascading to 'p6
        trivial, cascading to whatever 'p9 becomes
        any
        any
  pending 'p9, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 2
        ht 3
          hn 4: a,a,a,a
          hn 4: t,a,a,a
          hn 4: t,t,a,a
        ht 3
          trivial
          hn 4: t,a,a,a
          hn 4: t,t,a,a
  pending 'p11, but only for cascading, and 'p13 cascades here for 0:
    ht 1
      ht 3
        trivial, cascading to 'p7 while updating 'p9
        hn 4: t,a,a,a
        hn 4: t,t,a,a
  pending 'p13 for 0, 1, 2, 3:
    hn 4
      trivial, cascading to 'p11
      any
      any
      any
read 0
  write (hnh 4 (trivial) 'p15) to 'p13
    write (htz) to 'p15
  this cascades, so
  write (hth 1 'p16 'p17) to 'p11
    write (htz) to 'p17

in 3
  pending 'p6, but only for cascading, and nothing cascades here yet:
    ht 1
      ht 2
        hn 4
          trivial, cascading to whatever 'p9 becomes
          trivial, cascading to whatever 'p9 becomes
          any
          any
        hn 4
          trivial
          trivial, cascading to whatever 'p9 becomes
          any
          any
  pending 'p7, but only for cascading, and 'p16 cascades here for 0:
    ht 1
      hn 4
        trivial, cascading to 'p6
        trivial, cascading to whatever 'p9 becomes
        any
        any
  pending 'p9, but only for cascading, and 'p16 updates this for 0:
    ht 1
      ht 2
        ht 3
          hn 4: a,a,a,a
          hn 4: t,a,a,a
          hn 4: t,t,a,a
        ht 3
          trivial
          hn 4: t,a,a,a
          hn 4: t,t,a,a
  pending 'p16 for 0, 1, 2:
    ht 3
      trivial, cascading to 'p7 while updating 'p9
      hn 4: t,a,a,a
      hn 4: t,t,a,a
read 0
  write (hth 3 (trivial) 'p18) to 'p16
    write (htz) to 'p18
  this cascades, so
  write (hth 1 'p19 'p20) to 'p7
    write (htz) to 'p20
  write (hth 1 'p21 'p22) to 'p9
    write (htz) to 'p22

in 4
  pending 'p6, but only for cascading, and 'p19 cascades here for 0:
    ht 1
      ht 2
        hn 4
          trivial, cascading to 'p21
          trivial, cascading to 'p21
          any
          any
        hn 4
          trivial
          trivial, cascading to 'p21
          any
          any
  pending 'p19 for 0, 1, 2, 3:
    hn 4
      trivial, cascading to 'p6
      trivial, cascading to 'p21
      any
      any
  pending 'p21, but only for cascading, and 'p19 cascades here for 1:
    ht 2
      ht 3
        hn 4: a,a,a,a
        hn 4: t,a,a,a
        hn 4: t,t,a,a
      ht 3
        trivial
        hn 4: t,a,a,a
        hn 4: t,t,a,a
read 0
  write (hnh 4 (trivial) 'p23) to 'p19
    write (htz) to 'p23
  this cascades, so
  write (hth 1 'p24 'p25) to 'p6
    write (htz) to 'p25

in 2
  pending 'p21, but only for cascading, and nothing cascades here yet:
    ht 2
      ht 3
        hn 4: a,a,a,a
        hn 4: t,a,a,a
        hn 4: t,t,a,a
      ht 3
        trivial
        hn 4: t,a,a,a
        hn 4: t,t,a,a
  pending 'p24 for 0, 1:
    ht 2
      hn 4
        trivial, cascading to 'p21
        trivial, cascading to 'p21
        any
        any
      hn 4
        trivial
        trivial, cascading to 'p21
        any
        any
read 0
  write (hth 2 'p26 'p27) to 'p24
    write (htz) to 'p27

in 4
  pending 'p21, but only for cascading, and nothing cascades here yet:
    ht 2
      ht 3
        hn 4: a,a,a,a
        hn 4: t,a,a,a
        hn 4: t,t,a,a
      ht 3
        trivial
        hn 4: t,a,a,a
        hn 4: t,t,a,a
  pending 'p26 for 0, 1:
    hn 4
      trivial, cascading to 'p21
      trivial, cascading to 'p21
      any
      any
read 0
  write (hnh 4 (trivial) 'p28) to 'p26
    write (htz) to 'p28
  this cascades, so
  write (hth 2 'p29 'p30) to 'p21
    write (htz) to 'p30

in 3
  pending 'p29 for 0, 1, 2:
    ht 3
      hn 4: a,a,a,a
      hn 4: t,a,a,a
      hn 4: t,t,a,a
read 0
  write (hth 3 'p31 'p32) to 'p29
    write (htz) to 'p32

in 4
  pending 'p31 for 0, 1, 2, 3:
    hn 4: a,a,a,a
read (list 0 'a)
  write (hnh 4 'a 'p33) to 'p31
    write (htz) to 'p33

in 0
reach end
  write nothing
```

---

All right, but that doesn't clarify every situation.

In particular, what happens when the "`cascading to 'p7 while updating 'p9`" step itself writes a hole of degree greater than 0? In that case we'll have five variables we need to cascade in order, right? And then we'll need to use the three-way phrase "`cascading to <var> while updating <var> and <var>`", right?

It seems like there's too much bookkeeping here. With this amount of bookkeeping, we could more easily implement a version of `degree-and-brackets->hypernest` which collects several lists of brackets and then makes recursive calls to itself to process those brackets. So that's the approach we're pursuing instead.
