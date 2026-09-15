// oracle/java/ch10-the-state-of-things-to-come.java: A Little Java, A Few Patterns, chapter 10
// (The State of Things to Come). Our own Java on the chapter's topics: an object whose field
// changes (a pie man keeping one pie, and answering how many of a topping it has after each
// change), and a visitor that changes a pie in place, seen through every reference to it.
// books/little-java/ch10-the-state-of-things-to-come.wat must print the same, in order.

abstract class PieD {
  abstract Object accept(PieVisitorI ask);
}
class Bot extends PieD {
  Object accept(PieVisitorI ask) { return ask.forBot(this); }
  public String toString() { return "(Bot)"; }
}
class Top extends PieD {
  int t; PieD r;
  Top(int t, PieD r) { this.t = t; this.r = r; }
  Object accept(PieVisitorI ask) { return ask.forTop(this); }
  public String toString() { return "(Top " + t + " " + r + ")"; }
}
interface PieVisitorI { Object forBot(Bot that); Object forTop(Top that); }

class OccursV implements PieVisitorI {
  int a; OccursV(int a) { this.a = a; }
  public Object forBot(Bot that) { return 0; }
  public Object forTop(Top that) {
    int rest = ((Integer) that.r.accept(this)).intValue();
    return that.t == a ? rest + 1 : rest;
  }
}
class RemV implements PieVisitorI {
  int o; RemV(int o) { this.o = o; }
  public Object forBot(Bot that) { return new Bot(); }
  public Object forTop(Top that) {
    PieD rest = (PieD) that.r.accept(this);
    return that.t == o ? rest : new Top(that.t, rest);
  }
}
// changes the pie it visits, in place: every Top holding o now holds n
class SubstInPlaceV implements PieVisitorI {
  int n; int o; SubstInPlaceV(int n, int o) { this.n = n; this.o = o; }
  public Object forBot(Bot that) { return that; }
  public Object forTop(Top that) {
    if (that.t == o) that.t = n;
    that.r.accept(this);
    return that;
  }
}

interface PiemanI {
  int addTop(int t);
  int remTop(int t);
  int substTop(int n, int o);
  int occTop(int o);
}
// the pie man keeps one pie, and changes it
class PiemanM implements PiemanI {
  PieD p = new Bot();
  public int addTop(int t) { p = new Top(t, p); return occTop(t); }
  public int remTop(int t) { p = (PieD) p.accept(new RemV(t)); return occTop(t); }
  public int substTop(int n, int o) { p.accept(new SubstInPlaceV(n, o)); return occTop(n); }
  public int occTop(int o) { return ((Integer) p.accept(new OccursV(o))).intValue(); }
  public String toString() { return p.toString(); }
}

public class Main {
  static void show(Object o) { System.out.println("=> " + o); }
  public static void main(String[] args) {
    PiemanM y = new PiemanM();
    show(y.addTop(3));
    show(y.addTop(2));
    show(y.addTop(3));
    show(y);
    show(y.occTop(3));
    show(y.substTop(5, 3));
    show(y);
    show(y.remTop(5));
    show(y);
    show(y.addTop(7));
    // two pie men are two pies
    PiemanM z = new PiemanM();
    show(z.addTop(7));
    show(y);
    show(z);
    // a pie changed in place is changed for every reference to it
    PieD pie = new Top(1, new Top(2, new Top(1, new Bot())));
    PieD alias = pie;
    pie.accept(new SubstInPlaceV(9, 1));
    show(alias);
    // and pie == alias is true: the same object. wat values have no identity (ch 3), so that
    // is not a result compared here; the change seen through the alias is.
  }
}
