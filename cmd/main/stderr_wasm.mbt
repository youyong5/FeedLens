///|
#cfg(any(target="wasm", target="wasm-gc"))
fn write_stderr(message : String) -> Unit {
  println(message)
}
