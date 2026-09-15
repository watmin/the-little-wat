// oracle/java/ch05-objects-are-people-too.java: A Little Java, A Few Patterns, chapter 5
// (Objects Are People, Too). Our own Java on the chapter's topics: pies whose layers hold any
// Object (fish, integers), visitors whose methods take extra arguments, and equals.
// books/little-java/ch05-objects-are-people-too.wat must print the same, in order.

abstract class FishD {
  // fish are equal when they are the same kind of fish
  public boolean equals(Object o) { return o != null && getClass() == o.getClass(); }
  public int hashCode() { return getClass().hashCode(); }
}
class Anchovy extends FishD { public String toString() { return "(Anchovy)"; } }
class Salmon extends FishD { public String toString() { return "(Salmon)"; } }
class Tuna extends FishD { public String toString() { return "(Tuna)"; } }

class RemV {
  PieD forBot(Object o) { return new Bot(); }
  PieD forTop(Object t, PieD r, Object o) {
    if (o.equals(t)) return r.rem(o);
    else return new Top(t, r.rem(o));
  }
}
class SubstV {
  PieD forBot(Object n, Object o) { return new Bot(); }
  PieD forTop(Object t, PieD r, Object n, Object o) {
    if (o.equals(t)) return new Top(n, r.subst(n, o));
    else return new Top(t, r.subst(n, o));
  }
}

abstract class PieD {
  RemV remFn = new RemV();
  SubstV substFn = new SubstV();
  abstract PieD rem(Object o);
  abstract PieD subst(Object n, Object o);
}
class Bot extends PieD {
  PieD rem(Object o) { return remFn.forBot(o); }
  PieD subst(Object n, Object o) { return substFn.forBot(n, o); }
  public String toString() { return "(Bot)"; }
}
class Top extends PieD {
  Object t; PieD r;
  Top(Object t, PieD r) { this.t = t; this.r = r; }
  PieD rem(Object o) { return remFn.forTop(t, r, o); }
  PieD subst(Object n, Object o) { return substFn.forTop(t, r, n, o); }
  public String toString() { return "(Top " + t + " " + r + ")"; }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    show(new Anchovy().equals(new Anchovy()));
    show(new Anchovy().equals(new Tuna()));
    PieD fishPie = new Top(new Anchovy(), new Top(new Tuna(), new Top(new Anchovy(), new Bot())));
    show(fishPie);
    show(fishPie.rem(new Anchovy()));
    show(fishPie.rem(new Tuna()));
    show(fishPie.rem(new Salmon()));
    show(fishPie.subst(new Salmon(), new Anchovy()));
    show(fishPie.subst(new Tuna(), new Tuna()));
    PieD numPie = new Top(3, new Top(2, new Top(3, new Bot())));
    show(numPie);
    show(numPie.rem(3));
    show(numPie.rem(2));
    show(numPie.subst(5, 3));
    show(numPie.subst(5, 3).rem(5));
    show(new Bot().rem(7));
  }
}
