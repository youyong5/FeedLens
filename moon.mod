// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "youyong5/feedlens"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/youyong5/FeedLens"

license = "Apache-2.0"

keywords = [ "feed", "rss", "atom", "json-feed", "parser" ]

preferred_target = "wasm"

description = "Multi-format RSS 2.0, Atom 1.0 and JSON Feed 1.0/1.1 parsing library with source-aware links and diagnostics"

import {
  "Milky2018/xml@0.5.0",
  "moonbitlang/x@0.5.5",
}
