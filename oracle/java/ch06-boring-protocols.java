// oracle/java/ch06-boring-protocols.java: A Little Java, A Few Patterns, chapter 6 (Boring
// Protocols). Our own Java on the chapter's topics: every visitor implements one interface, a
// protocol, and keeps its extra arguments in fields; a pie has one accept for all of them.
// books/little-java/ch06-boring-protocols.wat must print the same, in order.

interface PieVisitorI {
  PieD forBot();
  PieD forTop(Object t, PieD r);
}
abstract class PieD {
  abstract PieD accept(PieVisitorI ask);
}
class Bot extends PieD {
  PieD accept(PieVisitorI ask) { return ask.forBot(); }
  public String toString() { return "(Bot)"; }
}
class Top extends PieD {
  Object t; PieD r;
  Top(Object t, PieD r) { this.t = t; this.r = r; }
  PieD accept(PieVisitorI ask) { return ask.forTop(t, r); }
  public String toString() { return "(Top " + t + " " + r + ")"; }
}
class RemV implements PieVisitorI {
  Object o; RemV(Object o) { this.o = o; }
  public PieD forBot() { return new Bot(); }
  public PieD forTop(Object t, PieD r) {
    if (o.equals(t)) return r.accept(this);
    else return new Top(t, r.accept(this));
  }
}
class SubstV implements PieVisitorI {
  Object n; Object o; SubstV(Object n, Object o) { this.n = n; this.o = o; }
  public PieD forBot() { return new Bot(); }
  public PieD forTop(Object t, PieD r) {
    if (o.equals(t)) return new Top(n, r.accept(this));
    else return new Top(t, r.accept(this));
  }
}
// substitute only the first c
class LtdSubstV implements PieVisitorI {
  int c; Object n; Object o;
  LtdSubstV(int c, Object n, Object o) { this.c = c; this.n = n; this.o = o; }
  public PieD forBot() { return new Bot(); }
  public PieD forTop(Object t, PieD r) {
    if (c == 0) return new Top(t, r);
    else if (o.equals(t)) return new Top(n, r.accept(new LtdSubstV(c - 1, n, o)));
    else return new Top(t, r.accept(this));
  }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    PieD pie = new Top(3, new Top(2, new Top(3, new Top(7, new Top(3, new Bot())))));
    show(pie.accept(new RemV(3)));
    show(pie.accept(new RemV(8)));
    show(pie.accept(new SubstV(5, 3)));
    show(pie.accept(new LtdSubstV(2, 5, 3)));
    show(pie.accept(new LtdSubstV(0, 5, 3)));
    show(pie.accept(new LtdSubstV(9, 5, 3)));
    // visitors compose through accept
    show(pie.accept(new LtdSubstV(1, 5, 3)).accept(new RemV(3)));
    show(new Bot().accept(new SubstV(1, 2)));
  }
}
