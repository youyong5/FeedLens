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
合法输入边界审计的逐项发现与独立交集见 [LEGAL_INPUT_AUDIT.md](LEGAL_INPUT_AUDIT.md)。

| 格式 / 输入构造 | 已承诺的输出 | 错误/诊断策略 | 离线回归 | 合法但未映射/处理的例子 |
| --- | --- | --- | --- | --- |
| RSS 2.0 无命名空间 `rss version="2.0" > channel > item` | Feed/Entry 基础字段、item pubDate、channel pubDate/lastBuildDate、copyright、generator、TTL、managingEditor/webMaster、item comments/source URL 与标题、guid 的 isPermaLink 默认值，保序；缺 item link 时有效绝对 HTTP(S) 永久链接 guid 可填入 `Entry.link`，原标识符保持不变；只含 title 或 description 的合法 item 可无标识；channel `skipHours`/`skipDays` 提示、`docs` URL、原始 `rating`、`cloud` 注册描述和 `textInput` 四字段表单描述 | 非法 XML/根/版本/缺 channel 致命；缺必需 channel 元数据、item 同时缺 title 与 description 定位诊断；无法按支持的 RFC 822/1123 常见配置归一化的日期给 `UnnormalizedRssDate`，保留原文与条目；非法 TTL、source、guid、skip 提示及可选构造可恢复；`cloud` 限五个非空属性、1–65535 端口及 RSS 指定的三种协议；`textInput` 限四个直接非空子字段 | `standard_fields_test.mbt`, `rss_metadata_test.mbt`, `rss_permalink_test.mbt`, `rss_date_validation_test.mbt`, `rss_item_required_test.mbt`, `rss_skip_test.mbt`, `rss_optional_channel_test.mbt`, `samples/rss2_permalink_guid.xml`, `samples/rss2_invalid_dates.xml`, `samples/rss2_optional_channel.xml`, `tools/check_rss_permalink_reference.py`, `tools/check_rss_date_validation.py` | 其他 RSS 版本；不执行 cloud 注册或 textInput 表单提交，不解释 PICS rating，不验证 guid URL 的可访问性 |
| RSS XML 文本、实体、CDATA、嵌套标签 | 纯文本/CDATA 解码；正确 Content Module `content:encoded` 为未声明类型正文 | 核心字段内嵌 XML 不拼接，`UnsupportedNestedMarkup`；错误 URI 的同名扩展不映射 | `feedlens_test.mbt`, `samples/rss2_boundaries.xml` | 任意 RSS 扩展模块、嵌入 XHTML/XML 正文结构 |
| RSS 作者、类别、image、enclosure、language | RSS 原生 item `author` 保留邮箱；精确 Dublin Core 命名空间的直接 item `creator` 保留姓名，公开 `AuthorSource::DublinCore` 与 `Rss2` 区分来源并保持文档顺序；其他 Author/Category/FeedImage/Attachment 和语言；编辑与站点管理员联系方式单独保留 | 空 creator 或嵌套 XML 定位诊断，错误命名空间与层级不映射；空值/非法附件定位诊断；不下载 | `rss_dublin_creator_test.mbt`, `samples/rss2_dublin_creator.xml`, `tools/check_diverse_real_reference.py`, `attachments_test.mbt`, `language_test.mbt`, `feed_image_test.mbt` | Dublin Core 的其他属性、iTunes/Media RSS 扩展、图片实际尺寸验证 |
| Atom 1.0 命名空间 `feed > entry` 及独立 `entry` 文档 | `parse` 保留 feed 返回类型；`parse_document` 返回 FeedDocument 或 AtomEntryDocument(entry, diagnostics)；通用 Atom 条目字段和 XHTML；feed/entry/source 的 `id` 原文保留，不受来源 URL 与 `xml:base` 改写；source 的 title/subtitle/updated、rights、generator、链接、icon/logo、作者、贡献者、类别单独保留；合法空/全空白 Text construct 原样保留，空 title 仍区别于缺 title | 不合法 XML/根致命；缺必需字段与作者、重复单值字段、重复相同 type/hreflang 的 alternate 链接定位诊断；相对、空白污染等非绝对 `id` 给 `InvalidAtomId`，保留原文和条目；空 `id` 仍按必需字段缺失诊断；feed 子元素在首个 entry 后再出现非 entry 元素给 `InvalidAtomOrder`，原值保留；entry 内部字段顺序不限制 | `atom_document_test.mbt`, `atom_id_test.mbt`, `samples/atom1_id_boundaries.xml`, `tools/check_atom_id_reference.py`, `atom_source_test.mbt`, `atom_legal_text_test.mbt`, `atom_feed_order_test.mbt` | Atom source 中其他扩展元数据、完整 IRI/日期语法及其他顺序/重复约束的验证尚未覆盖 |
| Atom rights、generator、contributor 与多关系链接 | rights 的 text/html/xhtml 文本构造，entry 无自己的 rights 时继承包含它的 feed rights（包括 XHTML 片段）；显式空 rights 阻断继承；generator 文本及 uri/version 属性，独立贡献者；`links` 保留原始 self/related/alternate/enclosure 等关系及常用属性；`link` 为首个 alternate 的便捷取值；RFC 4287 注册关系 IRI 与短名等价；`rel` 接受单段非空名称或绝对 IRI；链接的 MIME 提示可含复合类型及常见参数；`hreflang` 原样保留 RFC 3066 词法，包括显式空值 | 缺 href、非法 `rel`、非法 length、非法 MIME type/hreflang 与重复 alternate 组合定位诊断；错误 `rel` 仍在 `AtomLink` 中保留原文；重复 alternate 的 hreflang 与 MIME 主/子类型不区分大小写，含参数的 MIME 声明仅在参数文本完全相同时视作同一组合；无效提示不丢弃链接或附件；不下载链接 | `standard_fields_test.mbt`, `atom_relation_test.mbt`, `atom_link_relation_syntax_test.mbt`, `atom_link_media_test.mbt`, `atom_link_language_test.mbt`, `atom_link_type_case_test.mbt`, `atom_legal_text_test.mbt`, `samples/atom1_link_relation_syntax.xml`, `tools/check_atom_link_relations.py` 及既有链接样本与对照脚本 | Atom source 的未映射扩展、其他 scheme 专属 IRI 语义、语言标签注册状态及 MIME 参数语义等价性全面校验 |
| Atom 作者、类别、图片、附件、xml:lang/xml:base | entry→source→feed 作者优先层；source 身份、text/html/xhtml 标题/subtitle/rights、generator、链接、icon/logo 及时间单独保留；显式声明的 Person `name`、category `term/label`、link/enclosure `title` 原样保留空值和空白；category `scheme` 是绝对 IRI，即使有 `xml:base` 也不改写；icon/logo；enclosure；显式 URI 入口 | 缺失必需 Person `name` 或 category `term`、空白/相对 category `scheme`、无效附件定位诊断，异常 scheme 原文保留；Person 的 name/uri/email 重复字段、source 重复单值字段和不合法标题定位诊断；不猜文档来源 URI | `atom_source_test.mbt`, `atom_person_uri_test.mbt`, `atom_declared_metadata_test.mbt`, `atom_category_scheme_test.mbt`, `samples/atom1_category_schemes.xml`, `tools/check_atom_category_schemes.py`, `language_test.mbt`, `uri_test.mbt`, `attachments_test.mbt`, `feed_image_test.mbt` | Person 的未映射扩展与完整 IRI/email 语法校验、source 其他扩展、内容内 URI 自动改写 |
| Atom `type=text`/省略、`type=html` 标题/摘要/内联正文 | XML 解码原值与 `Text`/`Html` 标记；原空白 | 子元素不被剥标签拼接，给 `UnsupportedTextConstruct`/`UnsupportedAtomContent` | `feedlens_test.mbt` | HTML 渲染、清洗、其中的相对链接解析 |
| Atom `type=xhtml` 的 feed/entry title、subtitle/summary、entry/content | 纯文本展示值、`Xhtml` 标记和 `XhtmlFragment`（无外层 div 的确定性 XML 片段、语言、xml:base 链、外层 div 的有序扩展名属性） | 必须有单个正确 XHTML 命名空间的 div；缺失、错误 URI、多根或非空游离文本给定位诊断；合法片段不清洗 | `xhtml_test.mbt`, `samples/atom1_xhtml.xml`, `samples/atom1_xhtml_container.xml`, `tools/check_xhtml_reference.py`, `tools/check_xhtml_container_reference.py` | XHTML 显示/安全清洗、字节级实体/前缀还原；外层 div 的属性交给调用方决定如何应用 |
| Atom `content src`（外链） | `Entry.content_source`/`content_media_type` 便捷取值及 `Entry.atom_body = External`：原始 `src`、URL、声明类型、已知绝对基准 URI；不写入内联 `Entry.content` | 非空内容、纯空白 `src` 或非法类型定位诊断；缺 summary 另诊断；有 content 元素不误报缺 alternate | `atom_content_test.mbt`, `atom_body_test.mbt`, `atom_empty_iri_test.mbt`, `samples/atom1_content_sources.xml`, `samples/atom1_content_forms.xml`, `samples/atom1_empty_iri_references.xml` | 下载/验证外链资源；`src` 的完整 IRI 语法校验 |
| Atom `content type=text/*`（大小写不敏感） | XML 解码文本、原空白与准确的声明媒体类型；MIME `text/html` 不等于 Atom `type="html"`；分号参数可为 token 或含转义/分号的 quoted-string，依媒体类型主体分发 | 内嵌子元素、缺值/不闭合引号/尾随分号等非法媒体类型定位诊断 | `atom_body_test.mbt`, `atom_media_type_test.mbt`, `samples/atom1_content_forms.xml`, `samples/atom1_mime_parameters.xml`, `tools/check_atom_media_reference.py` | HTML/Markdown 渲染、安全清洗、MIME 注释及扩展参数语法的全面验证 |
| Atom `content` XML 媒体类型（`/xml`/`+xml`） | `InlineXml(XmlFragment, media_type)`；不剥 div；确定性序列化保留子节点、属性、命名空间、混合文本、注释与 PI | 非法 XML 仍致命；类型不合法可恢复诊断 | `atom_body_test.mbt`, `samples/atom1_content_forms.xml` | 根据媒体类型作模式校验或渲染、字节级前缀/实体还原、片段内 URI 自动重写 |
| Atom 其他非复合媒体类型 Base64 | `InlineBinary(Bytes, media_type)`，跨三目标取得原始字节；CLI JSON 为 Base64 和字节数 | 非法编码定位诊断且不伪装文本；缺 summary 独立诊断 | `atom_body_test.mbt`, `samples/atom1_content_forms.xml`, `tools/check_cli.ps1` | MIME 内容嗅探、反病毒扫描、媒体解码 |
| JSON Feed 1.0/1.1 精确版本 URL、对象根、`title/items` | Feed/Entry 统一字段及条目顺序、next_url 引用、expired 布尔状态、hubs 的 type/url；1.1 语言。非空白字符串 `id` 原样保留，包括两端空格；1.0 的非字符串 `id` 按规范转为字符串：数字保留词法，其他类型使用紧凑 JSON 表示。附件缺 `mime_type` 时保留 URL 与元数据，类型为空并诊断 | 语法、根、version、必需字段/items 结构错误致命；空/全空白 id 的 item 诊断并跳过；同一响应中重复的有效 id 按公开字符串精确比较并诊断，条目保留；next_url 等于 feed_url、非法 hubs/expired 给诊断；1.1 的非字符串复合 id 诊断并跳过该 item，已有数字 id 容错保留；附件缺 URL 则跳过该附件；无效 RFC 3339 日期保留原文并给 `InvalidJsonFeedDate`，不丢条目 | `json_feed_test.mbt`, `json_identity_test.mbt`, `json_date_validation_test.mbt`, `attachments_test.mbt`, `standard_fields_test.mbt`, `samples/jsonfeed11_duplicate_ids.json`, `tools/check_json_identity_reference.py`, `samples/jsonfeed10_invalid_dates.json`, `samples/jsonfeed11_invalid_dates.json`, `tools/check_json_date_validation.py`, `samples/jsonfeed10_legacy_ids.json`, `samples/jsonfeed11_opaque_strings.json`, `samples/jsonfeed11_attachment_recovery.json` | 不跟随 next_url；跨页循环须由调用方处理；跨响应/跨页的 id 稳定性由调用方检验；任意扩展键不映射 |
| JSON Feed 内容、作者、tags、附件、显示图片 | `content_text`、`content_html` 同时保留，`content` 仍 HTML 优先，空字符串也算存在；1.0 读取单数 `author`，1.1 的 `authors` 优先于兼容用 `author`，空数组明确阻断继承；显式空/空白 name 原样保留，可只声明 avatar；tags 的字符串原样保留，包括空/空白；来源明确的附件/图片 | 可恢复可选字段类型问题诊断；坏附件跳过但不丢 item；1.0 中不把未来版本 `authors` 错认作标准作者 | `standard_fields_test.mbt`, `json_author_version_test.mbt`, `samples/jsonfeed10_author_versions.json`, `samples/jsonfeed11_author_versions.json`, `tools/check_json_author_versions.py`, `attachments_test.mbt`, `entry_display_test.mbt`, `json_feed_test.mbt` | user_comment 依规范供人工查看而非读者展示；对扩展键不作任意映射 |

共同边界：`parse(String)` 不知道文档 URL，保留原始相对引用；
RSS channel 仅额外映射直接子元素中、准确 Atom 命名空间的 `rel=self` 链接
（含 RFC 4287 注册关系 IRI 写法）到 `Feed.links`，不替换 RSS 原生 `Feed.link`。
依据 [RSS Best Practices Profile §5.1.1](https://www.rssboard.org/rss-profile)。
`parse_with_source` 按显式文档 URL 解析其相对 href，不将 RSS 的
`xml:base` 解释为整份 RSS 的基准；其他 Atom 关系及 item 扩展仍不映射。
真实 `real_hn_rss.xml`、合成 `samples/rss2_atom_self.xml`、
`rss_atom_self_test.mbt` 与 `tools/check_rss_atom_self_reference.py`
固定了来源、命名空间、层级和输出边界。
JSON Feed 的 `next_url` 与 `feed_url` 原文相同会立即诊断；已知文档来源时，
`parse_with_source` 还会按 RFC 3986 解析两个引用，若 `next_url` 指回声明的
`feed_url` 或当前文档 URL，清除该分页链接并给 `InvalidJsonFeedField`。
`Feed.identifier` 仍保留原始 `feed_url`；其他跨响应循环需调用方追踪。
`samples/jsonfeed11_self_pagination.json`、`json_pagination_test.mbt`
和 `tools/check_json_pagination_reference.py` 分别固定输入、库输出及 Python URL 对照。
所有解析入口均接受开头一个 UTF-8 BOM；只有首个 U+FEFF 会被去掉，
正文里的同字符保留，前有空白或连续两个 BOM 不被宽松接受。JSON 的处理是
[RFC 8259 §8.1](https://www.rfc-editor.org/rfc/rfc8259#section-8.1)
允许的读取端互操作性策略，不意味着发布端应生成 BOM。
`parse_with_source(String,String)` 只解析已承诺的 URI 字段，包括 Atom
外链 `content src`，以及 feed/entry/source 作者与贡献者 `uri` 的元素级 `xml:base`；Atom 结构化
XHTML 内部 URI 仍由调用方依据 `base_references`/内部 `xml:base` 自行处理。
`parse_document_with_source` 对独立 Atom Entry 应用相同的来源语义。
URI 合并与去除路径点段以 [RFC 3986 §5.4](https://www.rfc-editor.org/rfc/rfc3986#section-5.4)
的正常和异常参考例为固定预期；`uri_wbtest.mbt` 覆盖这些例子，
`uri_rfc3986_source_test.mbt` 再由三个公开格式入口验证链接与附件的实际输出。
严格解析时 `http:g` 保留为带 scheme 的绝对引用；它不能充当
`parse_with_source` 的 HTTP(S) 文档 URL，后者仍须有有效主机。
相对引用的 ASCII 路径、查询和片段字符按 [RFC 3986 §3.3–3.5](https://www.rfc-editor.org/rfc/rfc3986#section-3.3)
检查：`[`、`]`、`{`、`}`、`|`、`^` 等字符应先百分号转义，片段中的
第二个 `#` 也不能原样出现。无效引用保留在对应字段，给 `UnresolvedUri`，
不删除仍可用的 feed 或 item；`uri_character_boundary_test.mbt` 覆盖三种格式。
HTTP(S) 主机前可选的 userinfo 同样检查 RFC 3986 的 ASCII 字符范围；
非法 userinfo 的文档来源 URL 返回 `InvalidSourceUrl`。
非 ASCII 码点依 [RFC 3987 §2.2](https://www.rfc-editor.org/rfc/rfc3987#section-2.2)
的 `ucschar` 检查；`iprivate` 只接受在 query，不把它当作主机、路径、
fragment 或 userinfo。`uri_wbtest.mbt` 覆盖 BMP 与补充平面的端点，
`uri_iri_range_test.mbt` 固定三种格式的公开入口结果。此处仍不联网校验
域名，也不宣称 URI/IRI 所有 scheme 专属语义均通过验证。
Atom `link href` 在普通 `parse` 中也执行来源无关的 IRI 引用词法检查；
错误值留在 `AtomLink`（附件仍留在 `Attachment`），分别给定位的
`InvalidAtomLink` 或 `InvalidAttachment`。固定样本
`samples/atom1_link_href_syntax.xml`、`atom_link_href_syntax_test.mbt` 与
`tools/check_atom_link_hrefs.py` 对照普通及来源感知输出。
Atom 链接 `href=""`、附件 `href=""`、外链正文 `src=""` 均作为合法的空 IRI
引用原样保留；已知来源时依自身 `xml:base` 解析为当前基准 URI。缺少该属性与空属性
不同，纯空白属性不冒充空引用。固定样本 `samples/atom1_empty_iri_references.xml`
及独立 ElementTree/urllib 对照涵盖 feed、entry、source 和独立 Entry。
Atom 外链正文只交付引用和声明类型，不下载或解码其资源。
Person 的相对 `uri` 遵循 [RFC 4287 §3.2.2](https://www.rfc-editor.org/rfc/rfc4287#section-3.2.2)
和 [XML Base §4.3](https://www.w3.org/TR/xmlbase/#matching)。合法 person URI 的完整 IRI 语法
尚未由本库验证；无法解析时原值保留并给定位诊断。
显式 HTTP(S) 来源 URL 需要无片段且有可解析的 host/port 结构；
`parse_with_source` 和独立 Entry 入口共用此约束。常见 ASCII reg-name
字符、Unicode IRI 域名、合法方括号 IPv6/IPv4 尾部及 RFC 3986 的 IPvFuture
主机、分层 `xml:base` 有离线回归和 Python IPv6/URL join 对照，
见 `uri_source_boundary_test.mbt`、`samples/atom1_iri_host.xml`、
`samples/atom1_ip_literals.xml` 及 `tools/check_source_authority_reference.py`。
不接受任意方括号字符串及畸形 IPv6；IPvFuture 仅检验其 URI 词法，不联网识别
未知地址机制。按已废止 RFC 6874 的现行 [RFC 9844](https://www.rfc-editor.org/rfc/rfc9844)，
不把带 `%25ZoneID` 的主机当作普通 URI 来源接受。Unicode IRI 各码点范围和
DNS 可达性仍未验证。
日期原文保留；Atom feed、entry、source 的 `updated` 和 entry 的
`published` 在解析时校验 Date construct，无效值产生元素定位的
`InvalidAtomDate`，包括显式空元素；`normalize_date` 校验文档化的
RSS/RFC 3339 子集；RSS
两位年份依 [RFC 2822 §4](https://www.rfc-editor.org/rfc/rfc2822#section-4)
固定映射 00–49 为 2000–2049、50–99 为 1950–1999，
带星期名时校验真实日历；`samples/rss2_two_digit_years.xml` 与 feedparser
6.0.11 秒级独立对照。RSS RFC 822 星期、月份和命名时区不区分大小写，
单字母 `Z` 为已知 UTC；其他军用单字母时区因 [RFC 1123 §5.2.14](https://www.rfc-editor.org/rfc/rfc1123#section-5.2.14)
指出符号歧义，保留原文并给无法归一化诊断，不猜本地偏移。`samples/rss2_case_and_zone.xml`
和 `tools/check_rss_case_zone_reference.py` 对照 Python 邮件日期解析器的 UTC 交集。
RFC 3339
小数秒任意正位数可输入，UTC 文本保留全部位数，`nanosecond` 截取前九位，
`Fraction(digits)` 保留声明位数。跨格式合成样本的秒级独立交集与库内完整
小数位回归见 `date_test.mbt` 和 `tools/check_real_cross_format.py`。
Atom Date construct 还要求大写 `T` 和 `Z`，JSON Feed 日期遵循允许小写
`t`/`z` 的 RFC 3339；`normalize_date` 按格式区分，原值不变。
RFC 3339 `-00:00` 与 RSS 邮件日期 `-0000` 的 UTC 时刻可确定，
`NormalizedDate.offset_known=false` 明示原本地时区未知；`offset_minutes=0`
仅供 UTC 算术，不能解释为已知本地偏移。三格式离线镜像与独立交集见
`date_unknown_offset_test.mbt`、`samples/*unknown_offset*` 和
`tools/check_unknown_offset_reference.py`。已公布的正闰秒按
[NIST 27 项日期快照](../samples/LEAP_SECONDS_NIST_2026-10-23.md) 核对：偏移
换算后的 UTC 必须是公布日期的 `23:59:60`，`NormalizedDate.is_leap_second`
保留此语义；`unix_seconds` 取前一 POSIX 秒，不能单靠整数区分闰秒。新闰秒
公布后须更新快照；不预测未来闰秒。
见 `date_author_boundary_test.mbt`、`samples/atom1_date_case.xml`、
`samples/jsonfeed11_empty_author_date.json` 和 `tools/check_date_author_reference.py`。
可恢复诊断不是完整的标准校验器；JSON DOM 无字段源 span，其语义诊断为 `(1,1)`。

与 feedparser 6.0.11 的独立交集比较见
[`samples/COMPATIBILITY.md`](../samples/COMPATIBILITY.md)。项目净贡献是
MoonBit 三目标可调用的统一且保留来源语义的模型、明确错误边界、离线样本与
Native 本地检查 CLI；不声称覆盖面或清洗能力优于 feedparser。
