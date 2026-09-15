// oracle/java/ch07-oh-my.java: A Little Java, A Few Patterns, chapter 7 (Oh My!). Our own Java
// on the chapter's topics: trees of fruit, and visitors whose answers are of different types
// (a boolean, an int, a tree). One visitor interface for them all answers Object, so every
// use casts its answer back: the "oh my". books/little-java/ch07-oh-my.wat must print the
// same, in order.

abstract class FruitD {
  public boolean equals(Object o) { return o != null && getClass() == o.getClass(); }
  public int hashCode() { return getClass().hashCode(); }
}
class Peach extends FruitD { public String toString() { return "(Peach)"; } }
class Apple extends FruitD { public String toString() { return "(Apple)"; } }
class Pear extends FruitD { public String toString() { return "(Pear)"; } }
class Fig extends FruitD { public String toString() { return "(Fig)"; } }

interface TreeVisitorI {
  Object forBud();
  Object forFlat(FruitD f, TreeD t);
  Object forSplit(TreeD l, TreeD r);
}
abstract class TreeD { abstract Object accept(TreeVisitorI ask); }
class Bud extends TreeD {
  Object accept(TreeVisitorI ask) { return ask.forBud(); }
  public String toString() { return "(Bud)"; }
}
class Flat extends TreeD {
  FruitD f; TreeD t; Flat(FruitD f, TreeD t) { this.f = f; this.t = t; }
  Object accept(TreeVisitorI ask) { return ask.forFlat(f, t); }
  public String toString() { return "(Flat " + f + " " + t + ")"; }
}
class Split extends TreeD {
  TreeD l; TreeD r; Split(TreeD l, TreeD r) { this.l = l; this.r = r; }
  Object accept(TreeVisitorI ask) { return ask.forSplit(l, r); }
  public String toString() { return "(Split " + l + " " + r + ")"; }
}

class IsFlatV implements TreeVisitorI {
  public Object forBud() { return true; }
  public Object forFlat(FruitD f, TreeD t) { return t.accept(this); }
  public Object forSplit(TreeD l, TreeD r) { return false; }
}
class IsSplitV implements TreeVisitorI {
  public Object forBud() { return true; }
  public Object forFlat(FruitD f, TreeD t) { return false; }
  public Object forSplit(TreeD l, TreeD r) {
    return ((Boolean) l.accept(this)).booleanValue() && ((Boolean) r.accept(this)).booleanValue();
  }
}
class HasFruitV implements TreeVisitorI {
  public Object forBud() { return false; }
  public Object forFlat(FruitD f, TreeD t) { return true; }
  public Object forSplit(TreeD l, TreeD r) {
    return ((Boolean) l.accept(this)).booleanValue() || ((Boolean) r.accept(this)).booleanValue();
  }
}
class HeightV implements TreeVisitorI {
  public Object forBud() { return 0; }
  public Object forFlat(FruitD f, TreeD t) { return 1 + ((Integer) t.accept(this)).intValue(); }
  public Object forSplit(TreeD l, TreeD r) {
    return 1 + Math.max(((Integer) l.accept(this)).intValue(), ((Integer) r.accept(this)).intValue());
  }
}
class OccursV implements TreeVisitorI {
  FruitD a; OccursV(FruitD a) { this.a = a; }
  public Object forBud() { return 0; }
  public Object forFlat(FruitD f, TreeD t) {
    int rest = ((Integer) t.accept(this)).intValue();
    return a.equals(f) ? 1 + rest : rest;
  }
  public Object forSplit(TreeD l, TreeD r) {
    return ((Integer) l.accept(this)).intValue() + ((Integer) r.accept(this)).intValue();
  }
}
class SubstV implements TreeVisitorI {
  FruitD n; FruitD o; SubstV(FruitD n, FruitD o) { this.n = n; this.o = o; }
  public Object forBud() { return new Bud(); }
  public Object forFlat(FruitD f, TreeD t) {
    return new Flat(o.equals(f) ? n : f, (TreeD) t.accept(this));
  }
  public Object forSplit(TreeD l, TreeD r) {
    return new Split((TreeD) l.accept(this), (TreeD) r.accept(this));
  }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    TreeD flat = new Flat(new Apple(), new Flat(new Peach(), new Bud()));
    TreeD split = new Split(new Split(new Bud(), new Bud()), new Split(new Bud(), new Split(new Bud(), new Bud())));
    TreeD mixed = new Split(new Flat(new Fig(), new Flat(new Apple(), new Bud())),
                            new Split(new Flat(new Fig(), new Bud()), new Bud()));
    show(flat.accept(new IsFlatV()));
    show(split.accept(new IsFlatV()));
    show(split.accept(new IsSplitV()));
    show(mixed.accept(new IsSplitV()));
    show(split.accept(new HasFruitV()));
    show(mixed.accept(new HasFruitV()));
    show(flat.accept(new HeightV()));
    show(split.accept(new HeightV()));
    show(mixed.accept(new HeightV()));
    show(mixed.accept(new OccursV(new Fig())));
    show(mixed.accept(new OccursV(new Pear())));
    show(mixed.accept(new SubstV(new Pear(), new Fig())));
    show(((TreeD) mixed.accept(new SubstV(new Pear(), new Fig()))).accept(new OccursV(new Pear())));
  }
}
