// oracle/java/ch08-like-father-like-son.java: A Little Java, A Few Patterns, chapter 8 (Like
// Father, Like Son). Our own Java on the chapter's topics: an evaluator visitor for expressions,
// IntEvalV, owns the traversal and leaves the arithmetic to methods a subclass may override;
// SetEvalV extends it, overrides only those, and evaluates the same kind of expression over
// sets. books/little-java/ch08-like-father-like-son.wat must print the same, in order.

abstract class SetD {
  SetD add(int i) { return mem(i) ? this : new Add(i, this); }
  abstract boolean mem(int i);
  abstract SetD plus(SetD s);   // union
  abstract SetD diff(SetD s);   // difference
  abstract SetD prod(SetD s);   // intersection
}
class Empty extends SetD {
  boolean mem(int i) { return false; }
  SetD plus(SetD s) { return s; }
  SetD diff(SetD s) { return new Empty(); }
  SetD prod(SetD s) { return new Empty(); }
  public String toString() { return "(Empty)"; }
}
class Add extends SetD {
  int i; SetD s; Add(int i, SetD s) { this.i = i; this.s = s; }
  boolean mem(int n) { return i == n || s.mem(n); }
  SetD plus(SetD t) { return s.plus(t.add(i)); }
  SetD diff(SetD t) { return t.mem(i) ? s.diff(t) : s.diff(t).add(i); }
  SetD prod(SetD t) { return t.mem(i) ? s.prod(t).add(i) : s.prod(t); }
  public String toString() { return "(Add " + i + " " + s + ")"; }
}

interface ExprVisitorI {
  Object forPlus(ExprD l, ExprD r);
  Object forDiff(ExprD l, ExprD r);
  Object forProd(ExprD l, ExprD r);
  Object forConst(Object c);
}
abstract class ExprD { abstract Object accept(ExprVisitorI ask); }
class Plus extends ExprD {
  ExprD l; ExprD r; Plus(ExprD l, ExprD r) { this.l = l; this.r = r; }
  Object accept(ExprVisitorI ask) { return ask.forPlus(l, r); }
}
class Diff extends ExprD {
  ExprD l; ExprD r; Diff(ExprD l, ExprD r) { this.l = l; this.r = r; }
  Object accept(ExprVisitorI ask) { return ask.forDiff(l, r); }
}
class Prod extends ExprD {
  ExprD l; ExprD r; Prod(ExprD l, ExprD r) { this.l = l; this.r = r; }
  Object accept(ExprVisitorI ask) { return ask.forProd(l, r); }
}
class Const extends ExprD {
  Object c; Const(Object c) { this.c = c; }
  Object accept(ExprVisitorI ask) { return ask.forConst(c); }
}

// the father: the traversal, and integer arithmetic
class IntEvalV implements ExprVisitorI {
  public Object forPlus(ExprD l, ExprD r) { return plus(l.accept(this), r.accept(this)); }
  public Object forDiff(ExprD l, ExprD r) { return diff(l.accept(this), r.accept(this)); }
  public Object forProd(ExprD l, ExprD r) { return prod(l.accept(this), r.accept(this)); }
  public Object forConst(Object c) { return c; }
  Object plus(Object l, Object r) { return ((Integer) l).intValue() + ((Integer) r).intValue(); }
  Object diff(Object l, Object r) { return ((Integer) l).intValue() - ((Integer) r).intValue(); }
  Object prod(Object l, Object r) { return ((Integer) l).intValue() * ((Integer) r).intValue(); }
}
// the son: the same traversal, inherited; only the arithmetic, overridden
class SetEvalV extends IntEvalV {
  Object plus(Object l, Object r) { return ((SetD) l).plus((SetD) r); }
  Object diff(Object l, Object r) { return ((SetD) l).diff((SetD) r); }
  Object prod(Object l, Object r) { return ((SetD) l).prod((SetD) r); }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    SetD s123 = new Empty().add(3).add(2).add(1);
    SetD s24 = new Empty().add(4).add(2);
    show(s123);
    show(s123.add(2));
    show(s123.mem(2));
    show(s123.mem(5));
    show(s123.plus(s24));
    show(s123.diff(s24));
    show(s123.prod(s24));
    show(new Plus(new Const(7), new Prod(new Const(4), new Const(5))).accept(new IntEvalV()));
    show(new Diff(new Const(10), new Plus(new Const(2), new Const(3))).accept(new IntEvalV()));
    show(new Plus(new Const(s123), new Const(s24)).accept(new SetEvalV()));
    show(new Diff(new Const(s123), new Prod(new Const(s24), new Const(new Empty().add(2)))).accept(new SetEvalV()));
    show(new Prod(new Plus(new Const(s24), new Const(new Empty().add(9))), new Const(s123)).accept(new SetEvalV()));
  }
}
