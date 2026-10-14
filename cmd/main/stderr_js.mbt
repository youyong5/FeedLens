///|
#cfg(target="js")
extern "js" fn write_stderr(message : String) =
  #| message => console.error(message)
