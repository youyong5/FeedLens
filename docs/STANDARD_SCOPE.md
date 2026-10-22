# FeedLens 标准行为与剩余差距矩阵

本矩阵以 [RSS 2.0](https://www.rssboard.org/rss-specification)、
[Atom RFC 4287](https://www.rfc-editor.org/rfc/rfc4287)、
[JSON Feed 1.1](https://www.jsonfeed.org/version/1.1/) 和
[JSON Feed 1.0](https://www.jsonfeed.org/version/1/) 为输入语义依据。
“支持”意为指定构造被映射到公开模型并有离线回归；当前仍不宣称对三种
标准的所有合法文档、扩展和约束均完成验证。独立 Atom Entry 已纳入
验收输入，但表中最后一栏的合法差距仍需在下一次完整符合性申报前处理或明确验收口径。
XML 使用 Milky2018/xml@0.5.0 的命名空间事件；
FeedLens 增加格式层级、映射和诊断，并不取代 XML 解析器。

| 格式 / 输入构造 | 已承诺的输出 | 错误/诊断策略 | 离线回归 | 合法但未映射/处理的例子 |
| --- | --- | --- | --- | --- |
| RSS 2.0 无命名空间 `rss version="2.0" > channel > item` | Feed/Entry 基础字段、item pubDate、channel pubDate/lastBuildDate、copyright、generator、TTL、managingEditor/webMaster、item comments/source URL 与标题、guid 的 isPermaLink 默认值，保序 | 非法 XML/根/版本/缺 channel 致命；缺必需元数据和无标识 item 定位诊断；非法 TTL、source 与 guid 属性可恢复 | `standard_fields_test.mbt`, `rss_metadata_test.mbt`, `samples/rss2_metadata.xml` | 其他 RSS 版本；channel `cloud`、`skipHours`、`docs` 等可选字段尚未投射；不验证 guid URL 的可访问性 |
| RSS XML 文本、实体、CDATA、嵌套标签 | 纯文本/CDATA 解码；正确 Content Module `content:encoded` 为未声明类型正文 | 核心字段内嵌 XML 不拼接，`UnsupportedNestedMarkup`；错误 URI 的同名扩展不映射 | `feedlens_test.mbt`, `samples/rss2_boundaries.xml` | 任意 RSS 扩展模块、嵌入 XHTML/XML 正文结构 |
| RSS 作者、类别、image、enclosure、language | 来源明确的 Author/Category/FeedImage/Attachment 和语言；编辑与站点管理员联系方式单独保留 | 空值/非法附件定位诊断；不下载 | `attachments_test.mbt`, `language_test.mbt`, `feed_image_test.mbt`, `samples/rss2_attachments.xml` | iTunes/Media RSS 扩展、图片实际尺寸验证 |
| Atom 1.0 命名空间 `feed > entry` 及独立 `entry` 文档 | `parse` 保留 feed 返回类型；`parse_document` 返回 FeedDocument 或 AtomEntryDocument(entry, diagnostics)；通用 Atom 条目字段和 XHTML；source 的 id/title/updated、rights、作者、贡献者、类别单独保留 | 不合法 XML/根致命；缺必需字段与作者、重复单值字段、重复相同 type/hreflang 的 alternate 链接定位诊断 | `atom_document_test.mbt`, `atom_source_test.mbt`, `samples/atom1_source_metadata.xml` | Atom source 的其他可选元数据、完整 IRI/日期语法及所有顺序/重复约束的验证尚未覆盖 |
| Atom rights、generator、contributor 与多关系链接 | rights 的 text/html/xhtml 文本构造，generator 文本，独立贡献者；`links` 保留 self/related/alternate/enclosure 等关系及常用属性；`link` 为首个 alternate 的便捷取值 | 缺 href、非法 length 与重复 alternate 组合诊断；不下载链接 | `standard_fields_test.mbt`, `samples/atom1_standard_fields.xml` | generator 的 uri/version 属性、Atom source 的完整投射及链接的完整 IRI 校验 |
| Atom 作者、类别、图片、附件、xml:lang/xml:base | entry→source→feed 作者优先层；source 身份、text/html/xhtml 标题/rights 及时间单独保留；term/scheme/label；icon/logo；enclosure；显式 URI 入口 | 无效作者/类别/附件定位诊断；source 重复单值字段和不合法标题定位诊断；不猜文档来源 URI | `atom_source_test.mbt`, `language_test.mbt`, `uri_test.mbt`, `attachments_test.mbt`, `feed_image_test.mbt` | Person 的更多扩展、Atom source 的链接、subtitle、generator、图片等其他可选元数据、内容内 URI 自动改写 |
| Atom `type=text`/省略、`type=html` 标题/摘要/内联正文 | XML 解码原值与 `Text`/`Html` 标记；原空白 | 子元素不被剥标签拼接，给 `UnsupportedTextConstruct`/`UnsupportedAtomContent` | `feedlens_test.mbt` | HTML 渲染、清洗、其中的相对链接解析 |
| Atom `type=xhtml` 的 feed/entry title、subtitle/summary、entry/content | 纯文本展示值、`Xhtml` 标记和 `XhtmlFragment`（无外层 div 的确定性 XML 片段、语言、xml:base 链） | 必须有单个正确 XHTML 命名空间的 div；缺失、错误 URI、多根或非空游离文本给定位诊断；合法片段不清洗 | `xhtml_test.mbt`, `samples/atom1_xhtml.xml`, `tools/check_xhtml_reference.py` | XHTML 显示/安全清洗、字节级实体/前缀还原、外层 div 非继承类样式属性的投影 |
| Atom `content src`（外链） | `Entry.content_source`/`content_media_type` 便捷取值及 `Entry.atom_body = External`：原始 `src`、URL、声明类型、已知绝对基准 URI；不写入内联 `Entry.content` | 非空内容、空 `src` 或非法类型定位诊断；缺 summary 另诊断；有 content 元素不误报缺 alternate | `atom_content_test.mbt`, `atom_body_test.mbt`, `samples/atom1_content_sources.xml`, `samples/atom1_content_forms.xml` | 下载/验证外链资源；`src` 的完整 IRI 语法校验 |
| Atom `content type=text/*`（大小写不敏感） | XML 解码文本、原空白与准确的声明媒体类型；MIME `text/html` 不等于 Atom `type="html"` | 内嵌子元素、非法媒体类型定位诊断 | `atom_body_test.mbt`, `samples/atom1_content_forms.xml` | HTML/Markdown 渲染、安全清洗、媒体类型参数的完整语法验证 |
| Atom `content` XML 媒体类型（`/xml`/`+xml`） | `InlineXml(XmlFragment, media_type)`；不剥 div；确定性序列化保留子节点、属性、命名空间、混合文本、注释与 PI | 非法 XML 仍致命；类型不合法可恢复诊断 | `atom_body_test.mbt`, `samples/atom1_content_forms.xml` | 根据媒体类型作模式校验或渲染、字节级前缀/实体还原、片段内 URI 自动重写 |
| Atom 其他非复合媒体类型 Base64 | `InlineBinary(Bytes, media_type)`，跨三目标取得原始字节；CLI JSON 为 Base64 和字节数 | 非法编码定位诊断且不伪装文本；缺 summary 独立诊断 | `atom_body_test.mbt`, `samples/atom1_content_forms.xml`, `tools/check_cli.ps1` | MIME 内容嗅探、反病毒扫描、媒体解码 |
| JSON Feed 1.0/1.1 精确版本 URL、对象根、`title/items` | Feed/Entry 统一字段及条目顺序、next_url 引用、expired 布尔状态、hubs 的 type/url；1.1 语言 | 语法、根、version、必需字段/items 结构错误致命；next_url 等于 feed_url、非法 hubs/expired 给诊断 | `json_feed_test.mbt`, `standard_fields_test.mbt`, `samples/jsonfeed11_standard_fields.json` | 不跟随 next_url；跨页循环须由调用方处理；任意扩展键不映射 |
| JSON Feed 内容、作者、tags、附件、显示图片 | `content_text`、`content_html` 同时保留，`content` 仍 HTML 优先；authors 可只声明 avatar；继承；来源明确的附件/图片 | 可恢复可选字段类型问题诊断；坏附件跳过但不丢 item；不下载/清洗 | `standard_fields_test.mbt`, `attachments_test.mbt`, `entry_display_test.mbt` | user_comment 依规范供人工查看而非读者展示；对扩展键不作任意映射 |

共同边界：`parse(String)` 不知道文档 URL，保留原始相对引用；
`parse_with_source(String,String)` 只解析已承诺的 URI 字段，包括 Atom
外链 `content src`；Atom 结构化
XHTML 内部 URI 仍由调用方依据 `base_references`/内部 `xml:base` 自行处理。
`parse_document_with_source` 对独立 Atom Entry 应用相同的来源语义。
Atom 外链正文只交付引用和声明类型，不下载或解码其资源。
日期原文保留，`normalize_date` 仅校验文档化的 RSS/RFC 3339 子集。
可恢复诊断不是完整的标准校验器；JSON DOM 无字段源 span，其语义诊断为 `(1,1)`。

与 feedparser 6.0.11 的独立交集比较见
[`samples/COMPATIBILITY.md`](../samples/COMPATIBILITY.md)。项目净贡献是
MoonBit 三目标可调用的统一且保留来源语义的模型、明确错误边界、离线样本与
Native 本地检查 CLI；不声称覆盖面或清洗能力优于 feedparser。
