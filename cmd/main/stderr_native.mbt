///|
#cfg(any(target="native", target="llvm"))
fn write_stderr(message : String) -> Unit {
  eprintln(message)
}
