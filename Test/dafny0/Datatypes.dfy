// RUN: %dafny /compile:0 /print:"%t.print" /dprint:"%t.dprint" "%s" > "%t"
// RUN: %diff "%s.expect" "%t"

datatype List<T> = Nil | Cons(T, List<T>)

class Node {
  var data: int;
  var next: Node;

  function Repr(list: List<int>): bool
    reads *;
    decreases list;
  { match list
    case Nil =>
      next == null
    case Cons(d,cdr) =>
      data == d && next != null && next.Repr(cdr)
  }

  method Init()
    modifies this;
    ensures Repr(Nil);
  {
    next := null;
  }

  method Add(d: int, L: List<int>) returns (r: Node)
    requires Repr(L);
    ensures r != null && r.Repr(Cons(d, L));
  {
    r := new Node;
    r.data := d;
    r.next := this;
  }
}

class AnotherNode {
  var data: int;
  var next: AnotherNode;

  function Repr(n: AnotherNode, list: List<int>): bool
    reads *;
    decreases list;
  { match list
    case Nil =>
      n == null
    case Cons(d,cdr) =>
      n != null && n.data == d && Repr(n.next, cdr)
  }

  method Create() returns (n: AnotherNode)
    ensures Repr(n, Nil);
  {
    n := null;
  }

  method Add(n: AnotherNode, d: int, L: List<int>) returns (r: AnotherNode)
    requires Repr(n, L);
    ensures Repr(r, Cons(d, L));
  {
    r := new AnotherNode;
    r.data := d;
    r.next := n;
  }
}

method TestAllocatednessAxioms(a: List<Node>, b: List<Node>, c: List<AnotherNode>)
{
  var n := new Node;
  var p := n;
  match a {
    case Nil =>
    case Cons(x, tail) => assert x != n; p := x;
  }
  match b {
    case Nil =>
    case Cons(x, tail) =>
      match tail {
        case Nil =>
        case Cons(y, more) =>
          assert y != n;
          assert y != p;  // error: if p is car(a), then it and y may very well be equal
      }
  }
  match c {
    case Nil =>
    case Cons(x, tail) =>
      match tail {
        case Nil =>
        case Cons(y, more) =>
          var o: object := y;
          assert p != null ==> p != o;  // follows from well-typedness
      }
  }
}

class NestedMatchExpr {
  function Cadr<T>(a: List<T>, Default: T): T
  {
    match a
    case Nil => Default
    case Cons(x,t) =>
      match t
      case Nil => Default
      case Cons(y,tail) => y
  }
  // CadrAlt is the same as Cadr, but it writes its two outer cases in the opposite order
  function CadrAlt<T>(a: List<T>, Default: T): T
  {
    match a
    case Cons(x,t) => (
      match t
      case Nil => Default
      case Cons(y,tail) => y)
    case Nil => Default
  }
  method TestNesting0()
  {
    var x := 5;
    var list := Cons(3, Cons(6, Nil));
    assert Cadr(list, x) == 6;
    match (list) {
      case Nil => assert false;
      case Cons(h,t) => assert Cadr(t, x) == 5;
    }
  }
  method TestNesting1(a: List<NestedMatchExpr>)
    ensures Cadr(a, this) == CadrAlt(a, this);
  {
    match (a) {
      case Nil =>
      case Cons(x,t) =>
        match (t) {
          case Nil =>
          case Cons(y,tail) =>
        }
    }
  }
}

// ------------------- datatype destructors ---------------------------------------

datatype XList = XNil | XCons(Car: int, Cdr: XList)

method Destructors0(d: XList) {
  Lemma_AllCases(d);
  if {
    case d.XNil? =>
      assert d == XNil;
    case d.XCons? =>
      var hd := d.Car;
      var tl := d.Cdr;
      assert d == XCons(hd, tl);
  }
}

method Destructors1(d: XList) {
  match (d) {
    case XNil =>
      assert d.XNil?;
    case XCons(hd,tl) =>
      assert d.XCons?;
  }
}

method Destructors2(d: XList) {
  // this method gets it backwards
  match (d) {
    case XNil =>
      assert d.XCons?;  // error
    case XCons(hd,tl) =>
      assert d.XNil?;  // error
  }
}

ghost method Lemma_AllCases(d: XList)
  ensures d.XNil? || d.XCons?;
{
  match (d) {
    case XNil =>
    case XCons(hd,tl) =>
  }
}

method InjectivityTests(d: XList)
  requires d != XNil;
{
  match (d) {
    case XCons(a,b) =>
      match (d) {
        case XCons(x,y) =>
          assert a == x && b == y;
      }
      assert a == d.Car;
      assert b == d.Cdr;
      assert d == XCons(d.Car, d.Cdr);
  }
}

method MatchingDestructor(d: XList) returns (r: XList)
  ensures r.Car == 5;  // error: specification is not well-formed (since r might not be an XCons)
{
  if (*) {
    var x0 := d.Car;  // error: d might not be an XCons
  } else if (d.XCons?) {
    var x1 := d.Car;
  }
  r := XCons(5, XNil);
}

datatype Triple = T(a: int, b: int, c: int)  // just one constructor
datatype TripleAndMore = T'(a: int, b: int, c: int) | NotATriple

method Rotate0(t: Triple) returns (u: Triple)
{
  u := T(t.c, t.a, t.b);
}

method Rotate1(t: TripleAndMore) returns (u: TripleAndMore)
{
  if {
    case t.T'? =>
      u := T'(t.c, t.a, t.b);
    case true =>
      u := T'(t.c, t.a, t.b);  // error: t may be NotATriple
  }
}

// -------------

method FwdBug(f: Fwd, initialized: bool)
  requires !f.FwdCons?;
{
  match (f) {
    case FwdNil =>
    // Syntactically, there is a missing case here, but the verifier checks that this is still cool.
    // There was once a bug in Dafny, where this had caused an ill-defined Boogie program.
  }
  if (!initialized) {  // There was once a Dafny parsing bug with this line
  }
}

function FwdBugFunction(f: Fwd): bool
  requires !f.FwdCons?;
{
  match f
  case FwdNil => true
  // Syntactically, there is a missing case here, but the verifier checks that this is still cool.
  // There was once a bug in Dafny, where this had caused an ill-defined Boogie program.
}

datatype Fwd = FwdNil | FwdCons(k: int, w: Fwd)

method TestAllCases(f: Fwd)
{
  assert f.FwdNil? || f.FwdCons?;
}

method TestAllCases_Inside(f: Fwd)
{
  if f.FwdCons? {
    assert f.w.FwdNil? || f.w.FwdCons?;
  }
}

class ContainsFwd {
  var fwd: Fwd;
  method TestCases()
  {
    assert fwd.FwdNil? || fwd.FwdCons?;
  }
}

function foo(f: Fwd): int
{
  if f.FwdNil? then 0 else f.k
}

// -- regression test --

predicate F(xs: List, vs: map<int,int>)
{
  match xs
  case Nil => true
  case Cons(_, tail) => forall vsi :: F(tail, vsi)
}

// -- match expressions in arbitrary positions --

module MatchExpressionsInArbitraryPositions {
  datatype List<T> = Nil | Cons(head: T, tail: List)
  datatype AList<T> = ANil | ACons(head: T, tail: AList) | Appendix(b: bool)

  method M(xs: AList<int>) returns (y: int)
    ensures 0 <= y;
  {
    if * {
      y := match xs  // error: missing case Appendix
           case ANil => 0
           case ACons(x, _) => x;  // error: might be negative
    } else {
      y := 0;
      ghost var b := forall tl ::
                       match ACons(8, tl)
                       case ACons(w, _) => w <= 16;
      assert b;
    }
  }

  function F(xs: List<int>, ys: List<int>): int
  {
    match xs
    case Cons(x, _) =>
      (match ys
       case Nil => x
       case Cons(y, _) => x + y)
    case Nil =>
      (match ys
       case Nil => 0
       case Cons(y, _) => y)
  }

  function G(xs: List<int>, ys: List<int>, k: int): int
  {
    match xs
    case Cons(x, _) =>
      (if k == 0 then 3 else
        match ys
        case Nil => x
        case Cons(y, _) => x + y)
    case Nil =>
      (if k == 0 then 3 else
        match ys
        case Nil => 3
        case Cons(y, _) => 3 + y)
  }

  function H(xs: List<int>, ys: List<int>, k: int): int
  {
    if 0 <= k then
      (if k < 10 then 0 else 3) + (if k < 100 then 2 else 5)
    else
      if k < -17 then 10 else
        (if k < -110 then 0 else 3) + (if k < -200 then 2 else 5)
  }

  function J(xs: List<int>): int
  {
    match xs  // error: missing cases
  }

  function K(xs: List<int>): int
  {
    match xs
    case Cons(_, ys) =>
      (match ys)  // error: missing cases
    case Nil => 0
  }
}

// -- match expressions in arbitrary positions --

module LetPatterns {
  datatype MyDt = AAA(x: int) | BBB(y: int)

  function M(m: MyDt): int
    requires m.AAA?
  {
    var AAA(u) := m;  // u: int
    u
  }

  method P()
  {
    var v;  // v: int
    var m;  // m: MyDt
    var w := v + var AAA(u) := m; u;  // error: m may not be an AAA
  }
}
