// oracle/java/ch02-methods-to-our-madness.java: A Little Java, A Few Patterns, chapter 2
// (Methods to Our Madness). Our own Java on the chapter's topics: methods on the datatypes, one
// per variant, and a method the abstract class defines once for all its variants.
// books/little-java/ch02-methods-to-our-madness.wat must print the same results, in order.

abstract class PointD {
  int x; int y;
  PointD(int x, int y) { this.x = x; this.y = y; }
  abstract int distanceToO();
  // defined once, here, and inherited by every kind of point
  boolean closerToO(PointD p) { return distanceToO() <= p.distanceToO(); }
  PointD minus(PointD p) { return new CartesianPt(x - p.x, y - p.y); }
}
class CartesianPt extends PointD {
  CartesianPt(int x, int y) { super(x, y); }
  int distanceToO() { return (int) Math.sqrt(x * x + y * y); }
  public String toString() { return "(CartesianPt " + x + " " + y + ")"; }
}
class ManhattanPt extends PointD {
  ManhattanPt(int x, int y) { super(x, y); }
  int distanceToO() { return x + y; }
  public String toString() { return "(ManhattanPt " + x + " " + y + ")"; }
}

abstract class ShishD {
  abstract boolean onlyOnions();
  abstract boolean isVegetarian();
}
class Skewer extends ShishD {
  boolean onlyOnions() { return true; }
  boolean isVegetarian() { return true; }
}
class Onion extends ShishD {
  ShishD s; Onion(ShishD s) { this.s = s; }
  boolean onlyOnions() { return s.onlyOnions(); }
  boolean isVegetarian() { return s.isVegetarian(); }
}
class Lamb extends ShishD {
  ShishD s; Lamb(ShishD s) { this.s = s; }
  boolean onlyOnions() { return false; }
  boolean isVegetarian() { return false; }
}
class Tomato extends ShishD {
  ShishD s; Tomato(ShishD s) { this.s = s; }
  boolean onlyOnions() { return false; }
  boolean isVegetarian() { return s.isVegetarian(); }
}

// what a kebab's holder can be: a rod or a plate
abstract class RodD {}
class Dagger extends RodD { public String toString() { return "(Dagger)"; } }
class Sabre extends RodD { public String toString() { return "(Sabre)"; } }
abstract class PlateD {}
class Gold extends PlateD { public String toString() { return "(Gold)"; } }
class Wood extends PlateD { public String toString() { return "(Wood)"; } }

abstract class KebabD {
  abstract boolean isVeggie();
  abstract Object whatHolder();
}
class Holder extends KebabD {
  Object o; Holder(Object o) { this.o = o; }
  boolean isVeggie() { return true; }
  Object whatHolder() { return o; }
}
class Shallot extends KebabD {
  KebabD k; Shallot(KebabD k) { this.k = k; }
  boolean isVeggie() { return k.isVeggie(); }
  Object whatHolder() { return k.whatHolder(); }
}
class Shrimp extends KebabD {
  KebabD k; Shrimp(KebabD k) { this.k = k; }
  boolean isVeggie() { return false; }
  Object whatHolder() { return k.whatHolder(); }
}
class Radish extends KebabD {
  KebabD k; Radish(KebabD k) { this.k = k; }
  boolean isVeggie() { return k.isVeggie(); }
  Object whatHolder() { return k.whatHolder(); }
}
class Zucchini extends KebabD {
  KebabD k; Zucchini(KebabD k) { this.k = k; }
  boolean isVeggie() { return k.isVeggie(); }
  Object whatHolder() { return k.whatHolder(); }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    show(new CartesianPt(3, 4).distanceToO());
    show(new ManhattanPt(3, 4).distanceToO());
    show(new CartesianPt(1, 1).distanceToO());
    show(new CartesianPt(12, 5).distanceToO());
    show(new CartesianPt(3, 4).closerToO(new ManhattanPt(1, 5)));
    show(new ManhattanPt(1, 5).closerToO(new CartesianPt(3, 4)));
    show(new ManhattanPt(2, 2).closerToO(new CartesianPt(3, 3)));
    show(new CartesianPt(3, 4).minus(new ManhattanPt(1, 1)));
    show(new ManhattanPt(10, 7).minus(new CartesianPt(4, 9)));

    show(new Skewer().onlyOnions());
    show(new Onion(new Onion(new Skewer())).onlyOnions());
    show(new Onion(new Lamb(new Skewer())).onlyOnions());
    show(new Onion(new Tomato(new Skewer())).isVegetarian());
    show(new Tomato(new Lamb(new Onion(new Skewer()))).isVegetarian());

    show(new Shallot(new Radish(new Holder(new Dagger()))).isVeggie());
    show(new Shallot(new Shrimp(new Holder(new Gold()))).isVeggie());
    show(new Shallot(new Radish(new Holder(new Dagger()))).whatHolder());
    show(new Zucchini(new Shrimp(new Holder(new Wood()))).whatHolder());
    show(new Holder(new Sabre()).whatHolder());
  }
}
