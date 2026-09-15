// oracle/java/ch09-be-a-good-visitor.java: A Little Java, A Few Patterns, chapter 9 (Be a Good
// Visitor). Our own Java on the chapter's topics: shapes with a point-in-shape visitor, and then
// the datatype extended after the fact with a new variant (Union), a visitor interface that
// extends the old one, and a visitor that extends the old visitor. A visitor that makes new
// visitors must make ones of its own kind, or a Union reached through a translation fails at
// runtime (a ClassCastException): hence UnionHasPtV overrides the factory, newHasPt.
// books/little-java/ch09-be-a-good-visitor.wat must print the same, in order.

class CartesianPt {
  int x; int y; CartesianPt(int x, int y) { this.x = x; this.y = y; }
  int distanceToO() { return (int) Math.sqrt(x * x + y * y); }
  CartesianPt minus(CartesianPt p) { return new CartesianPt(x - p.x, y - p.y); }
}

interface ShapeVisitorI {
  boolean forCircle(int r);
  boolean forSquare(int s);
  boolean forTrans(CartesianPt q, ShapeD s);
}
abstract class ShapeD { abstract boolean accept(ShapeVisitorI ask); }
class Circle extends ShapeD {
  int r; Circle(int r) { this.r = r; }
  boolean accept(ShapeVisitorI ask) { return ask.forCircle(r); }
}
class Square extends ShapeD {
  int s; Square(int s) { this.s = s; }
  boolean accept(ShapeVisitorI ask) { return ask.forSquare(s); }
}
class Trans extends ShapeD {
  CartesianPt q; ShapeD s; Trans(CartesianPt q, ShapeD s) { this.q = q; this.s = s; }
  boolean accept(ShapeVisitorI ask) { return ask.forTrans(q, s); }
}

// is the point p inside the shape? (a circle about the origin, a square from the origin)
class HasPtV implements ShapeVisitorI {
  CartesianPt p; HasPtV(CartesianPt p) { this.p = p; }
  ShapeVisitorI newHasPt(CartesianPt p) { return new HasPtV(p); }
  public boolean forCircle(int r) { return p.distanceToO() <= r; }
  public boolean forSquare(int s) { return p.x >= 0 && p.y >= 0 && p.x <= s && p.y <= s; }
  public boolean forTrans(CartesianPt q, ShapeD s) { return s.accept(newHasPt(p.minus(q))); }
}

// the extension: a new variant, and visitors that know it
interface UnionVisitorI extends ShapeVisitorI { boolean forUnion(ShapeD s, ShapeD t); }
class Union extends ShapeD {
  ShapeD s; ShapeD t; Union(ShapeD s, ShapeD t) { this.s = s; this.t = t; }
  boolean accept(ShapeVisitorI ask) { return ((UnionVisitorI) ask).forUnion(s, t); }
}
class UnionHasPtV extends HasPtV implements UnionVisitorI {
  UnionHasPtV(CartesianPt p) { super(p); }
  ShapeVisitorI newHasPt(CartesianPt p) { return new UnionHasPtV(p); }
  public boolean forUnion(ShapeD s, ShapeD t) { return s.accept(this) || t.accept(this); }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    show(new Circle(10).accept(new HasPtV(new CartesianPt(3, 4))));
    show(new Circle(4).accept(new HasPtV(new CartesianPt(3, 4))));
    show(new Square(5).accept(new HasPtV(new CartesianPt(3, 4))));
    show(new Square(2).accept(new HasPtV(new CartesianPt(3, 4))));
    show(new Trans(new CartesianPt(5, 6), new Circle(10)).accept(new HasPtV(new CartesianPt(10, 10))));
    show(new Trans(new CartesianPt(5, 6), new Square(3)).accept(new HasPtV(new CartesianPt(10, 10))));
    ShapeD u = new Union(new Square(2), new Trans(new CartesianPt(10, 0), new Circle(3)));
    show(u.accept(new UnionHasPtV(new CartesianPt(1, 1))));
    show(u.accept(new UnionHasPtV(new CartesianPt(12, 1))));
    show(u.accept(new UnionHasPtV(new CartesianPt(6, 6))));
    ShapeD tu = new Trans(new CartesianPt(1, 1), new Union(new Circle(1), new Square(1)));
    show(tu.accept(new UnionHasPtV(new CartesianPt(2, 2))));
    // A visitor that isn't "good" fails only when a Union is reached, at runtime:
    //   tu.accept(new HasPtV(new CartesianPt(2, 2)))  throws ClassCastException.
    // The wat side can't write that program at all: the old visitor is refused, at check time,
    // where the extended shape's accept expects the new protocol
    // (probes/java/old-visitor-on-new-shape.wat). So it is not a result compared here.
  }
}
