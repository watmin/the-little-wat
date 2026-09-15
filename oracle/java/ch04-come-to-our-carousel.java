// oracle/java/ch04-come-to-our-carousel.java: A Little Java, A Few Patterns, chapter 4 (Come to
// Our Carousel). Our own Java on the chapter's topics: each method moves out of the variants
// into a visitor, an object with a method per variant, and every variant's method just asks
// its visitor. books/little-java/ch04-come-to-our-carousel.wat must print the same, in order.

class OnlyOnionsV {
  boolean forSkewer() { return true; }
  boolean forOnion(ShishD s) { return s.onlyOnions(); }
  boolean forLamb(ShishD s) { return false; }
  boolean forTomato(ShishD s) { return false; }
}
class IsVegetarianV {
  boolean forSkewer() { return true; }
  boolean forOnion(ShishD s) { return s.isVegetarian(); }
  boolean forLamb(ShishD s) { return false; }
  boolean forTomato(ShishD s) { return s.isVegetarian(); }
}
abstract class ShishD {
  OnlyOnionsV ooFn = new OnlyOnionsV();
  IsVegetarianV ivFn = new IsVegetarianV();
  abstract boolean onlyOnions();
  abstract boolean isVegetarian();
}
class Skewer extends ShishD {
  boolean onlyOnions() { return ooFn.forSkewer(); }
  boolean isVegetarian() { return ivFn.forSkewer(); }
}
class Onion extends ShishD {
  ShishD s; Onion(ShishD s) { this.s = s; }
  boolean onlyOnions() { return ooFn.forOnion(s); }
  boolean isVegetarian() { return ivFn.forOnion(s); }
}
class Lamb extends ShishD {
  ShishD s; Lamb(ShishD s) { this.s = s; }
  boolean onlyOnions() { return ooFn.forLamb(s); }
  boolean isVegetarian() { return ivFn.forLamb(s); }
}
class Tomato extends ShishD {
  ShishD s; Tomato(ShishD s) { this.s = s; }
  boolean onlyOnions() { return ooFn.forTomato(s); }
  boolean isVegetarian() { return ivFn.forTomato(s); }
}

class RemAV {
  PizzaD forCrust() { return new Crust(); }
  PizzaD forCheese(PizzaD p) { return new Cheese(p.remA()); }
  PizzaD forOlive(PizzaD p) { return new Olive(p.remA()); }
  PizzaD forAnchovy(PizzaD p) { return p.remA(); }
  PizzaD forSausage(PizzaD p) { return new Sausage(p.remA()); }
}
class TopAwCV {
  PizzaD forCrust() { return new Crust(); }
  PizzaD forCheese(PizzaD p) { return new Cheese(p.topAwC()); }
  PizzaD forOlive(PizzaD p) { return new Olive(p.topAwC()); }
  PizzaD forAnchovy(PizzaD p) { return new Cheese(new Anchovy(p.topAwC())); }
  PizzaD forSausage(PizzaD p) { return new Sausage(p.topAwC()); }
}
class SubAbCV {
  PizzaD forCrust() { return new Crust(); }
  PizzaD forCheese(PizzaD p) { return new Cheese(p.subAbC()); }
  PizzaD forOlive(PizzaD p) { return new Olive(p.subAbC()); }
  PizzaD forAnchovy(PizzaD p) { return new Cheese(p.subAbC()); }
  PizzaD forSausage(PizzaD p) { return new Sausage(p.subAbC()); }
}
abstract class PizzaD {
  RemAV remFn = new RemAV();
  TopAwCV topFn = new TopAwCV();
  SubAbCV subFn = new SubAbCV();
  abstract PizzaD remA();
  abstract PizzaD topAwC();
  abstract PizzaD subAbC();
}
class Crust extends PizzaD {
  PizzaD remA() { return remFn.forCrust(); }
  PizzaD topAwC() { return topFn.forCrust(); }
  PizzaD subAbC() { return subFn.forCrust(); }
  public String toString() { return "(Crust)"; }
}
class Cheese extends PizzaD {
  PizzaD p; Cheese(PizzaD p) { this.p = p; }
  PizzaD remA() { return remFn.forCheese(p); }
  PizzaD topAwC() { return topFn.forCheese(p); }
  PizzaD subAbC() { return subFn.forCheese(p); }
  public String toString() { return "(Cheese " + p + ")"; }
}
class Olive extends PizzaD {
  PizzaD p; Olive(PizzaD p) { this.p = p; }
  PizzaD remA() { return remFn.forOlive(p); }
  PizzaD topAwC() { return topFn.forOlive(p); }
  PizzaD subAbC() { return subFn.forOlive(p); }
  public String toString() { return "(Olive " + p + ")"; }
}
class Anchovy extends PizzaD {
  PizzaD p; Anchovy(PizzaD p) { this.p = p; }
  PizzaD remA() { return remFn.forAnchovy(p); }
  PizzaD topAwC() { return topFn.forAnchovy(p); }
  PizzaD subAbC() { return subFn.forAnchovy(p); }
  public String toString() { return "(Anchovy " + p + ")"; }
}
class Sausage extends PizzaD {
  PizzaD p; Sausage(PizzaD p) { this.p = p; }
  PizzaD remA() { return remFn.forSausage(p); }
  PizzaD topAwC() { return topFn.forSausage(p); }
  PizzaD subAbC() { return subFn.forSausage(p); }
  public String toString() { return "(Sausage " + p + ")"; }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    // the same answers as chapters 2 and 3: only where the code lives has changed
    show(new Onion(new Onion(new Skewer())).onlyOnions());
    show(new Onion(new Lamb(new Skewer())).onlyOnions());
    show(new Onion(new Tomato(new Skewer())).isVegetarian());
    show(new Tomato(new Lamb(new Onion(new Skewer()))).isVegetarian());
    PizzaD p1 = new Anchovy(new Olive(new Anchovy(new Anchovy(new Cheese(new Crust())))));
    show(p1.remA());
    show(p1.topAwC());
    show(p1.subAbC());
    show(new Sausage(new Anchovy(new Crust())).topAwC());
    show(p1.topAwC().remA());
  }
}
