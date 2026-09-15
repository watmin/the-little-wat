// oracle/java/ch01-modern-toys.java: A Little Java, A Few Patterns, chapter 1 (Modern Toys).
// Our own Java on the chapter's topics: its datatypes, an abstract class per type and a
// concrete class per variant. Each toString prints the value as an S-expression, and main
// prints each result after "=> " (tools/java-oracle.sh); books/little-java/ch01-modern-toys.wat
// must print the same, in order.

abstract class SeasoningD {}
class Salt extends SeasoningD { public String toString() { return "(Salt)"; } }
class Pepper extends SeasoningD { public String toString() { return "(Pepper)"; } }
class Thyme extends SeasoningD { public String toString() { return "(Thyme)"; } }
class Sage extends SeasoningD { public String toString() { return "(Sage)"; } }

abstract class PointD {}
class CartesianPt extends PointD {
  int x; int y;
  CartesianPt(int x, int y) { this.x = x; this.y = y; }
  public String toString() { return "(CartesianPt " + x + " " + y + ")"; }
}
class ManhattanPt extends PointD {
  int x; int y;
  ManhattanPt(int x, int y) { this.x = x; this.y = y; }
  public String toString() { return "(ManhattanPt " + x + " " + y + ")"; }
}

abstract class NumD {}
class Zero extends NumD { public String toString() { return "(Zero)"; } }
class OneMoreThan extends NumD {
  NumD predecessor;
  OneMoreThan(NumD p) { predecessor = p; }
  public String toString() { return "(OneMoreThan " + predecessor + ")"; }
}

// A layer's base can be any object at all.
abstract class LayerD {}
class Base extends LayerD {
  Object o;
  Base(Object o) { this.o = o; }
  public String toString() { return "(Base " + o + ")"; }
}
class Slice extends LayerD {
  LayerD l;
  Slice(LayerD l) { this.l = l; }
  public String toString() { return "(Slice " + l + ")"; }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    show(new Salt());
    show(new Pepper());
    show(new Thyme());
    show(new Sage());
    show(new CartesianPt(2, 3));
    show(new ManhattanPt(2, 3));
    show(new CartesianPt(-1, 0));
    show(new Zero());
    show(new OneMoreThan(new Zero()));
    show(new OneMoreThan(new OneMoreThan(new OneMoreThan(new Zero()))));
    show(new Base(new Zero()));
    show(new Base(new Salt()));
    show(new Base(5));
    show(new Base(true));
    show(new Slice(new Base(new CartesianPt(1, 2))));
    show(new Slice(new Slice(new Base(new OneMoreThan(new Zero())))));
    // every value of a variant is a value of its type
    show(new OneMoreThan(new Zero()) instanceof NumD);
    show((Object) new Salt() instanceof NumD);
  }
}
