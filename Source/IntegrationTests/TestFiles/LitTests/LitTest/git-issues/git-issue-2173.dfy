// RUN: %testDafnyForEachCompiler "%s" --refresh-exit-code=0

datatype T = Leaf(x: int) | T(t: T) {
  function {:tailrecursion} TR() : int {
    if Leaf? then 0
    else t.TR()
  }
}

method Main() {
  print Leaf(0).TR(), "\n";
}
