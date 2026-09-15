// oracle/java/ch03-whats-new.java: A Little Java, A Few Patterns, chapter 3 (What's New?).
// Our own Java on the chapter's topics: methods that build new pizzas from old ones.
// books/little-java/ch03-whats-new.wat must print the same results, in order.
//
// Java objects also have identity: new Crust() == new Crust() is false. wat values have none
// (equality is structural), so the comparisons here are structural, with equals.

abstract class PizzaD {
  abstract PizzaD remA();    // remove the anchovies
  abstract PizzaD topAwC();  // top every anchovy with cheese
  abstract PizzaD subAbC();  // substitute cheese for every anchovy
  public boolean equals(Object o) { return o != null && toString().equals(o.toString()); }
}
class Crust extends PizzaD {
  PizzaD remA() { return new Crust(); }
  PizzaD topAwC() { return new Crust(); }
  PizzaD subAbC() { return new Crust(); }
  public String toString() { return "(Crust)"; }
}
class Cheese extends PizzaD {
  PizzaD p; Cheese(PizzaD p) { this.p = p; }
  PizzaD remA() { return new Cheese(p.remA()); }
  PizzaD topAwC() { return new Cheese(p.topAwC()); }
  PizzaD subAbC() { return new Cheese(p.subAbC()); }
  public String toString() { return "(Cheese " + p + ")"; }
}
class Olive extends PizzaD {
  PizzaD p; Olive(PizzaD p) { this.p = p; }
  PizzaD remA() { return new Olive(p.remA()); }
  PizzaD topAwC() { return new Olive(p.topAwC()); }
  PizzaD subAbC() { return new Olive(p.subAbC()); }
  public String toString() { return "(Olive " + p + ")"; }
}
class Anchovy extends PizzaD {
  PizzaD p; Anchovy(PizzaD p) { this.p = p; }
  PizzaD remA() { return p.remA(); }
  PizzaD topAwC() { return new Cheese(new Anchovy(p.topAwC())); }
  PizzaD subAbC() { return new Cheese(p.subAbC()); }
  public String toString() { return "(Anchovy " + p + ")"; }
}
class Sausage extends PizzaD {
  PizzaD p; Sausage(PizzaD p) { this.p = p; }
  PizzaD remA() { return new Sausage(p.remA()); }
  PizzaD topAwC() { return new Sausage(p.topAwC()); }
  PizzaD subAbC() { return new Sausage(p.subAbC()); }
  public String toString() { return "(Sausage " + p + ")"; }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    PizzaD p1 = new Anchovy(new Olive(new Anchovy(new Anchovy(new Cheese(new Crust())))));
    PizzaD p2 = new Sausage(new Anchovy(new Crust()));
    show(p1);
    show(p1.remA());
    show(p1.topAwC());
    show(p1.subAbC());
    show(p2.remA());
    show(p2.topAwC());
    show(p2.subAbC());
    show(new Crust().remA());
    // the methods compose: removing after topping leaves only the cheese
    show(p1.topAwC().remA());
    show(p1.subAbC().remA());
    // structural equality
    show(p1.topAwC().remA().equals(p1.subAbC()));
    show(p1.remA().equals(p1.subAbC()));
    show(p2.remA().equals(new Sausage(new Crust())));
  }
}
