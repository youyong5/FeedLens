///|
fn user_args() -> Array[String] {
  match @env.args() {
    [_, .. rest] => rest.to_owned()
    [] => []
  }
}

///|
fn fail(message : String) -> Unit {
  write_stderr("feedlens: " + message)
  @sys.exit(2)
}

///|
fn main {
  match @render.parse_args(user_args()) {
    Ok(Help) => println(@render.help_text())
    Ok(Parse(path, json)) =>
      try {
        let input = @fs.read_file_to_string(path)
        match @feedlens.parse(input) {
          Ok(feed) =>
            if json {
              println(@render.render_json(feed))
            } else {
              println(@render.render_human(feed))
            }
          Err(error) =>
            fail(
              "could not parse '" +
              path +
              "': " +
              @render.parse_error_text(error),
            )
        }
      } catch {
        @fs.IOError(message) =>
          fail("could not read '" + path + "': " + message)
      }
    Err(message) => fail(message + "; run with --help for usage")
  }
}
