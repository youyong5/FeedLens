///|
#cfg(any(target="native", target="llvm"))
#borrow(message)
extern "C" fn write_stderr(message : String) = "feedlens_cli_write_stderr"
