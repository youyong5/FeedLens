///|
fn uri_source_valid(source_url : String) -> Bool {
  match uri_parts(source_url) {
    Some(parts) =>
      match (parts.scheme, parts.authority, parts.fragment) {
        (Some(scheme), Some(authority), None) =>
          (scheme.to_lower() == "http" || scheme.to_lower() == "https") &&
          uri_http_authority_valid(authority)
        _ => false
      }
    None => false
  }
}

///|
fn uri_absolute(reference : String) -> String? {
  match uri_parts(reference) {
    Some(parts) if uri_valid_absolute(parts) =>
      Some(
        uri_build({
          scheme: parts.scheme,
          authority: parts.authority,
          path: uri_remove_dot_segments(parts.path),
          query: parts.query,
          fragment: parts.fragment,
        }),
      )
    _ => None
  }
}

///|
fn uri_at(
  base : String?,
  raw : String,
  field : String,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> String {
  let resolved = match base {
    Some(base) => uri_resolve(base, raw)
    None => uri_absolute(raw)
  }
  match resolved {
    Some(value) => value
    None => {
      diagnostics.push({ kind: UnresolvedUri(field), line, column, })
      raw
    }
  }
}

///|
fn uri_with_attachment_url(attachment : Attachment, url : String) -> Attachment {
  {
    source: attachment.source,
    url,
    media_type: attachment.media_type,
    size_in_bytes: attachment.size_in_bytes,
    title: attachment.title,
    duration_in_seconds: attachment.duration_in_seconds,
  }
}

///|
fn uri_with_entry_urls(
  entry : Entry,
  link : String?,
  external_url : String?,
  attachments : Array[Attachment],
  images : Array[EntryImage],
  content_source : String?,
  atom_body : AtomBody?,
  atom_source : AtomSource?,
  links : Array[AtomLink],
  comments_url : String?,
  source_url : String?,
  authors : Array[Author],
  contributors : Array[Author],
) -> Entry {
  {
    identifier: entry.identifier,
    title: entry.title,
    title_kind: entry.title_kind,
    title_xhtml: entry.title_xhtml,
    link,
    external_url,
    language: entry.language,
    description: entry.description,
    description_kind: entry.description_kind,
    description_xhtml: entry.description_xhtml,
    content: entry.content,
    content_text: entry.content_text,
    content_html: entry.content_html,
    content_kind: entry.content_kind,
    content_xhtml: entry.content_xhtml,
    content_source,
    content_media_type: entry.content_media_type,
    atom_body,
    atom_source,
    links,
    comments_url,
    source_url,
    source_title: entry.source_title,
    guid_is_permalink: entry.guid_is_permalink,
    rights: entry.rights,
    rights_kind: entry.rights_kind,
    rights_xhtml: entry.rights_xhtml,
    authors,
    contributors,
    categories: entry.categories,
    attachments,
    images,
    published_at: entry.published_at,
    updated_at: entry.updated_at,
  }
}

///|
fn uri_with_feed_urls(
  feed : Feed,
  link : String?,
  entries : Array[Entry],
  next_url : String?,
  hubs : Array[Hub],
  authors : Array[Author],
  contributors : Array[Author],
  links : Array[AtomLink],
  generator_uri : String?,
) -> Feed {
  {
    format: feed.format,
    identifier: feed.identifier,
    title: feed.title,
    title_kind: feed.title_kind,
    title_xhtml: feed.title_xhtml,
    link,
    language: feed.language,
    description: feed.description,
    description_kind: feed.description_kind,
    description_xhtml: feed.description_xhtml,
    updated_at: feed.updated_at,
    published_at: feed.published_at,
    ttl_minutes: feed.ttl_minutes,
    docs_url: feed.docs_url,
    rating: feed.rating,
    cloud: feed.cloud,
    text_input: feed.text_input,
    skip_hours: feed.skip_hours,
    skip_days: feed.skip_days,
    rights: feed.rights,
    rights_kind: feed.rights_kind,
    rights_xhtml: feed.rights_xhtml,
    generator: feed.generator,
    generator_uri,
    generator_version: feed.generator_version,
    managing_editor: feed.managing_editor,
    webmaster: feed.webmaster,
    next_url,
    expired: feed.expired,
    hubs,
    links,
    authors,
    contributors,
    categories: feed.categories,
    images: feed.images,
    entries,
    diagnostics: feed.diagnostics,
  }
}

///|
fn xml_base_attribute(element : @xml.NamespaceElement) -> String? {
  for attribute in element.attributes {
    if attribute.name.local_name == "base" &&
      attribute.name.namespace_uri ==
      Some("http://www.w3.org/XML/1998/namespace") {
      return Some(attribute.value)
    }
  }
  None
}

///|
fn xml_effective_base(
  element : @xml.NamespaceElement,
  parent_base : String?,
  format : FeedFormat,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> String? {
  if format != Atom1 {
    return parent_base
  }
  match xml_base_attribute(element) {
    None => parent_base
    Some(reference) => {
      let resolved = match parent_base {
        Some(base) => uri_resolve(base, reference)
        None => uri_absolute(reference)
      }
      if resolved is None {
        diagnostics.push({ kind: UnresolvedUri("atom xml:base"), line, column, })
      }
      resolved
    }
  }
}

///|
fn rss_valid_enclosure(element : @xml.NamespaceElement) -> Bool {
  let url = attribute_value(element, "url")
  let media_type = attribute_value(element, "type")
  let length = attribute_value(element, "length")
  match (url, media_type, length) {
    (Some(url), Some(media_type), Some(length)) =>
      !url.trim().is_empty() &&
      !media_type.trim().is_empty() &&
      attachment_size(length) is Some(_)
    _ => false
  }
}

///|
priv struct UriXmlState {
  format : FeedFormat
  standalone : Bool
  source_url : String
  diagnostics : Array[Diagnostic]
  mut feed_link : String?
  mut feed_generator_uri : String?
  links : Array[String?]
  attachments : Array[Array[Attachment]]
  feed_links : Array[AtomLink]
  entry_links : Array[Array[AtomLink]]
  source_links : Array[Array[AtomLink]]
  source_images : Array[Array[FeedImage]]
  source_links_alt : Array[String?]
  source_generators : Array[String?]
  person_lists : Array[Array[Author]]
  person_indexes : Array[Int32]
  entry_own_authors : Array[Bool]
  mut person_group : Int32
  mut person_depth : Int32
  mut person_name : String?
  mut person_uri : String?
  mut person_uri_base : String?
  mut person_uri_line : Int32
  mut person_uri_column : Int32
  mut person_field : String?
  mut person_text : String
  mut feed_link_index : Int32
  mut entry_link_index : Int32
  mut source_link_index : Int32
  mut source_image_index : Int32
  mut source_alternate_seen : Bool
  mut source_open : Bool
  mut source_depth : Int32
  mut image_field : String?
  mut image_text : String
  mut image_base : String?
  mut image_line : Int32
  mut image_column : Int32
  content_sources : Array[String?]
  bodies : Array[AtomBody?]
  entry_link_locations : Array[(Int32, Int32)?]
  mut feed_link_location : (Int32, Int32)?
  mut channel_depth : Int32
  mut entry_index : Int32
  mut entry_depth : Int32
  mut entry_open : Bool
  mut feed_alternate_seen : Bool
  mut entry_alternate_seen : Bool
  mut attachment_index : Int32
}

///|
fn UriXmlState::new(
  feed : Feed,
  source_url : String,
  standalone : Bool,
) -> UriXmlState {
  let links : Array[String?] = []
  let attachments : Array[Array[Attachment]] = []
  let entry_links : Array[Array[AtomLink]] = []
  let source_links : Array[Array[AtomLink]] = []
  let source_images : Array[Array[FeedImage]] = []
  let source_links_alt : Array[String?] = []
  let source_generators : Array[String?] = []
  let feed_links : Array[AtomLink] = []
  let person_lists : Array[Array[Author]] = [
    copy_authors(feed.authors),
    copy_authors(feed.contributors),
  ]
  let person_indexes : Array[Int32] = [0, 0]
  let entry_own_authors : Array[Bool] = []
  for link in feed.links {
    feed_links.push(link)
  }
  let content_sources : Array[String?] = []
  let bodies : Array[AtomBody?] = []
  let locations : Array[(Int32, Int32)?] = []
  for entry in feed.entries {
    links.push(entry.link)
    let copied : Array[Attachment] = []
    for attachment in entry.attachments {
      copied.push(attachment)
    }
    attachments.push(copied)
    let copied_links : Array[AtomLink] = []
    for link in entry.links {
      copied_links.push(link)
    }
    entry_links.push(copied_links)
    let copied_source_links : Array[AtomLink] = []
    let copied_source_images : Array[FeedImage] = []
    match entry.atom_source {
      Some(source) => {
        for link in source.links {
          copied_source_links.push(link)
        }
        for image in source.images {
          copied_source_images.push(image)
        }
        source_links_alt.push(source.link)
        source_generators.push(source.generator_uri)
      }
      None => {
        source_links_alt.push(None)
        source_generators.push(None)
      }
    }
    source_links.push(copied_source_links)
    source_images.push(copied_source_images)
    person_lists.push(copy_authors(entry.authors))
    person_lists.push(copy_authors(entry.contributors))
    match entry.atom_source {
      Some(source) => {
        person_lists.push(copy_authors(source.authors))
        person_lists.push(copy_authors(source.contributors))
      }
      None => {
        person_lists.push([])
        person_lists.push([])
      }
    }
    for person_slot = 0; person_slot < 4; person_slot = person_slot + 1 {
      person_indexes.push(0)
    }
    entry_own_authors.push(false)
    content_sources.push(entry.content_source)
    bodies.push(entry.atom_body)
    locations.push(None)
  }
  {
    format: feed.format,
    standalone,
    source_url,
    diagnostics: feed.diagnostics,
    feed_link: feed.link,
    feed_generator_uri: feed.generator_uri,
    links,
    attachments,
    feed_links,
    entry_links,
    source_links,
    source_images,
    source_links_alt,
    source_generators,
    person_lists,
    person_indexes,
    entry_own_authors,
    person_group: -1,
    person_depth: 0,
    person_name: None,
    person_uri: None,
    person_uri_base: None,
    person_uri_line: 1,
    person_uri_column: 1,
    person_field: None,
    person_text: "",
    feed_link_index: 0,
    entry_link_index: 0,
    source_link_index: 0,
    source_image_index: 0,
    source_alternate_seen: false,
    source_open: false,
    source_depth: 0,
    image_field: None,
    image_text: "",
    image_base: None,
    image_line: 1,
    image_column: 1,
    content_sources,
    bodies,
    entry_link_locations: locations,
    feed_link_location: None,
    channel_depth: 0,
    entry_index: -1,
    entry_depth: 0,
    entry_open: false,
    feed_alternate_seen: false,
    entry_alternate_seen: false,
    attachment_index: 0,
  }
}

///|
fn UriXmlState::resolve_atom_link(
  self : UriXmlState,
  raw : String,
  base : String?,
  line : Int32,
  column : Int32,
  entry : Bool,
) -> Unit {
  let links = if entry {
    if self.entry_index < 0 || self.entry_index >= self.entry_links.length() {
      return
    }
    self.entry_links[self.entry_index]
  } else {
    self.feed_links
  }
  let index = if entry { self.entry_link_index } else { self.feed_link_index }
  if index >= links.length() || links[index].href != raw {
    return
  }
  let link = links[index]
  links[index] = {
    relation: link.relation,
    href: uri_at(base, raw, "atom link", line, column, self.diagnostics),
    media_type: link.media_type,
    hreflang: link.hreflang,
    title: link.title,
    length: link.length,
  }
  if entry {
    self.entry_link_index = index + 1
  } else {
    self.feed_link_index = index + 1
  }
}

///|
fn UriXmlState::resolve_attachment(
  self : UriXmlState,
  raw : String,
  base : String?,
  field : String,
  line : Int32,
  column : Int32,
) -> Unit {
  if self.entry_index < 0 || self.entry_index >= self.attachments.length() {
    return
  }
  let entries_attachments = self.attachments[self.entry_index]
  if self.attachment_index >= entries_attachments.length() ||
    entries_attachments[self.attachment_index].url != raw {
    return
  }
  let resolved = uri_at(base, raw, field, line, column, self.diagnostics)
  entries_attachments[self.attachment_index] = uri_with_attachment_url(
    entries_attachments[self.attachment_index],
    resolved,
  )
  self.attachment_index = self.attachment_index + 1
}

///|
fn uri_with_source_urls(
  source : AtomSource?,
  link : String?,
  links : Array[AtomLink],
  images : Array[FeedImage],
  generator_uri : String?,
  authors : Array[Author],
  contributors : Array[Author],
) -> AtomSource? {
  match source {
    None => None
    Some(source) =>
      Some({
        identifier: source.identifier,
        title: source.title,
        title_kind: source.title_kind,
        title_xhtml: source.title_xhtml,
        subtitle: source.subtitle,
        subtitle_kind: source.subtitle_kind,
        subtitle_xhtml: source.subtitle_xhtml,
        updated_at: source.updated_at,
        rights: source.rights,
        rights_kind: source.rights_kind,
        rights_xhtml: source.rights_xhtml,
        generator: source.generator,
        generator_uri,
        generator_version: source.generator_version,
        authors,
        contributors,
        categories: source.categories,
        link,
        links,
        images,
      })
  }
}

///|
fn UriXmlState::finish_image(self : UriXmlState) -> Unit {
  match self.image_field {
    Some(field) if self.entry_index >= 0 &&
      self.entry_index < self.source_images.length() => {
      let raw = self.image_text
      let images = self.source_images[self.entry_index]
      let index = self.source_image_index
      if index < images.length() &&
        images[index].url == raw &&
        images[index].role ==
        (if field == "icon" { AtomIcon } else { AtomLogo }) {
        let image = images[index]
        images[index] = {
          source: image.source,
          role: image.role,
          url: uri_at(
            self.image_base,
            raw,
            "atom source " + field,
            self.image_line,
            self.image_column,
            self.diagnostics,
          ),
          title: image.title,
          link: image.link,
          description: image.description,
          width: image.width,
          height: image.height,
        }
        self.source_image_index = index + 1
      }
    }
    _ => ()
  }
  self.image_field = None
  self.image_text = ""
}

///|
fn UriXmlState::finish_person(self : UriXmlState) -> Unit {
  let group = self.person_group
  if group >= 0 && group < self.person_lists.length() {
    let people = self.person_lists[group]
    let mut index = self.person_indexes[group]
    while index < people.length() {
      let person = people[index]
      if person.name == self.person_name && person.uri == self.person_uri {
        match self.person_uri {
          Some(raw) =>
            people[index] = {
              source: person.source,
              name: person.name,
              uri: Some(
                uri_at(
                  self.person_uri_base,
                  raw,
                  "atom person uri",
                  self.person_uri_line,
                  self.person_uri_column,
                  self.diagnostics,
                ),
              ),
              email: person.email,
              avatar: person.avatar,
            }
          None => ()
        }
        self.person_indexes[group] = index + 1
        if group >= 2 && (group - 2) % 4 == 0 {
          self.entry_own_authors[(group - 2) / 4] = true
        }
        break
      }
      index = index + 1
    }
  }
  self.person_group = -1
  self.person_field = None
  self.person_text = ""
}

///|
fn UriXmlState::on_element(
  self : UriXmlState,
  element : @xml.NamespaceElement,
  depth : Int32,
  base : String?,
  line : Int32,
  column : Int32,
  is_empty : Bool,
) -> Unit {
  if self.format == Rss2 {
    if depth == 1 && is_rss_name(element.name, "channel") {
      self.channel_depth = depth + 1
    } else if self.channel_depth > 0 &&
      depth == self.channel_depth &&
      is_atom_name(element.name, "link") &&
      atom_element_relation_is(element, "self") {
      match atom_iri_attribute(element, "href") {
        Some(href) => self.resolve_atom_link(href, base, line, column, false)
        None => ()
      }
    } else if self.channel_depth > 0 &&
      depth == self.channel_depth &&
      is_rss_name(element.name, "item") {
      self.entry_index = self.entry_index + 1
      self.entry_depth = depth + 1
      self.entry_open = !is_empty
      self.attachment_index = 0
    } else if self.entry_open &&
      depth == self.entry_depth &&
      is_rss_name(element.name, "link") {
      self.entry_link_locations[self.entry_index] = Some((line, column))
    } else if !self.entry_open &&
      depth == self.channel_depth &&
      is_rss_name(element.name, "link") {
      self.feed_link_location = Some((line, column))
    } else if self.entry_open &&
      depth == self.entry_depth &&
      is_rss_name(element.name, "enclosure") &&
      rss_valid_enclosure(element) {
      match attribute_value(element, "url") {
        Some(url) =>
          self.resolve_attachment(
            url,
            base,
            "rss item " +
            self.entry_index.to_string() +
            " enclosure " +
            self.attachment_index.to_string(),
            line,
            column,
          )
        None => ()
      }
    }
    return
  }
  if self.person_group >= 0 &&
    depth == self.person_depth &&
    is_atom_name(element.name, "name") &&
    is_empty {
    self.person_name = Some("")
  } else if self.person_group >= 0 &&
    depth == self.person_depth &&
    is_atom_name(element.name, "uri") &&
    is_empty {
    self.person_uri = Some("")
    self.person_uri_base = base
    self.person_uri_line = line
    self.person_uri_column = column
  } else if self.person_group >= 0 &&
    depth == self.person_depth &&
    (is_atom_name(element.name, "name") || is_atom_name(element.name, "uri")) &&
    !is_empty {
    self.person_field = Some(element.name.local_name)
    self.person_text = ""
    if is_atom_name(element.name, "uri") {
      self.person_uri_base = base
      self.person_uri_line = line
      self.person_uri_column = column
    }
  } else if self.person_group < 0 &&
    !is_empty &&
    (
      is_atom_name(element.name, "author") ||
      is_atom_name(element.name, "contributor")
    ) {
    let offset = if is_atom_name(element.name, "author") { 0 } else { 1 }
    let group = if self.source_open && depth == self.source_depth {
      2 + self.entry_index * 4 + 2 + offset
    } else if self.entry_open && depth == self.entry_depth {
      2 + self.entry_index * 4 + offset
    } else if !self.entry_open && depth == 1 {
      offset
    } else {
      -1
    }
    if group >= 0 {
      self.person_group = group
      self.person_depth = depth + 1
      self.person_name = None
      self.person_uri = None
      self.person_field = None
      self.person_text = ""
    }
  }
  if (depth == 1 || (self.standalone && depth == 0)) &&
    is_atom_name(element.name, "entry") {
    self.entry_index = self.entry_index + 1
    self.entry_depth = depth + 1
    self.entry_open = !is_empty
    self.entry_alternate_seen = false
    self.attachment_index = 0
    self.entry_link_index = 0
    self.source_open = false
  } else if self.entry_open &&
    depth == self.entry_depth &&
    is_atom_name(element.name, "source") {
    self.source_open = !is_empty
    self.source_depth = depth + 1
    self.source_link_index = 0
    self.source_image_index = 0
    self.source_alternate_seen = false
  } else if self.source_open &&
    depth == self.source_depth &&
    is_atom_name(element.name, "link") {
    match atom_iri_attribute(element, "href") {
      Some(raw) => {
        let links = self.source_links[self.entry_index]
        let index = self.source_link_index
        if index < links.length() && links[index].href == raw {
          let link = links[index]
          links[index] = {
            relation: link.relation,
            href: uri_at(
              base,
              raw,
              "atom source link",
              line,
              column,
              self.diagnostics,
            ),
            media_type: link.media_type,
            hreflang: link.hreflang,
            title: link.title,
            length: link.length,
          }
          self.source_link_index = index + 1
        }
      }
      None => ()
    }
    if !self.source_alternate_seen {
      match atom_alternate_link(element) {
        Some(raw) => {
          self.source_alternate_seen = true
          self.source_links_alt[self.entry_index] = Some(
            uri_at(
              base,
              raw,
              "atom source alternate link",
              line,
              column,
              self.diagnostics,
            ),
          )
        }
        None => ()
      }
    }
  } else if self.source_open &&
    depth == self.source_depth &&
    is_atom_name(element.name, "generator") {
    match atom_attribute_value(element, "uri") {
      Some(raw) if self.source_generators[self.entry_index] == Some(raw) =>
        self.source_generators[self.entry_index] = Some(
          uri_at(
            base,
            raw,
            "atom source generator uri",
            line,
            column,
            self.diagnostics,
          ),
        )
      _ => ()
    }
  } else if self.source_open &&
    depth == self.source_depth &&
    (is_atom_name(element.name, "icon") || is_atom_name(element.name, "logo")) {
    self.image_field = Some(element.name.local_name)
    self.image_text = ""
    self.image_base = base
    self.image_line = line
    self.image_column = column
    if is_empty {
      self.finish_image()
    }
  } else if !self.entry_open &&
    depth == 1 &&
    is_atom_name(element.name, "generator") {
    match atom_attribute_value(element, "uri") {
      Some(raw) if self.feed_generator_uri == Some(raw) =>
        self.feed_generator_uri = Some(
          uri_at(
            base,
            raw,
            "atom feed generator uri",
            line,
            column,
            self.diagnostics,
          ),
        )
      _ => ()
    }
  } else if self.entry_open &&
    depth == self.entry_depth &&
    is_atom_name(element.name, "content") {
    match atom_attribute_value(element, "src") {
      Some(raw) if self.content_sources[self.entry_index] == Some(raw) => {
        let resolved = uri_at(
          base,
          raw,
          "atom entry " + self.entry_index.to_string() + " content src",
          line,
          column,
          self.diagnostics,
        )
        self.content_sources[self.entry_index] = Some(resolved)
        match self.bodies[self.entry_index] {
          Some(External(reference)) if reference.src == raw =>
            self.bodies[self.entry_index] = Some(
              External({
                src: reference.src,
                url: resolved,
                media_type: reference.media_type,
                base_uri: base,
              }),
            )
          _ => ()
        }
      }
      _ => ()
    }
  } else if !self.entry_open && depth == 1 && is_atom_name(element.name, "link") {
    match atom_iri_attribute(element, "href") {
      Some(raw) => self.resolve_atom_link(raw, base, line, column, false)
      None => ()
    }
    if !self.feed_alternate_seen {
      match atom_alternate_link(element) {
        Some(href) => {
          self.feed_alternate_seen = true
          self.feed_link = Some(
            uri_at(
              base,
              href,
              "atom feed alternate link",
              line,
              column,
              self.diagnostics,
            ),
          )
        }
        None => ()
      }
    }
  } else if self.entry_open &&
    depth == self.entry_depth &&
    is_atom_name(element.name, "link") {
    match atom_iri_attribute(element, "href") {
      Some(raw) => self.resolve_atom_link(raw, base, line, column, true)
      None => ()
    }
    if !self.entry_alternate_seen {
      match atom_alternate_link(element) {
        Some(href) => {
          self.entry_alternate_seen = true
          self.links[self.entry_index] = Some(
            uri_at(
              base,
              href,
              "atom entry " + self.entry_index.to_string() + " alternate link",
              line,
              column,
              self.diagnostics,
            ),
          )
        }
        None => ()
      }
    }
    if atom_element_relation_is(element, "enclosure") {
      match atom_iri_attribute(element, "href") {
        Some(href) =>
          self.resolve_attachment(
            href,
            base,
            "atom entry " +
            self.entry_index.to_string() +
            " enclosure " +
            self.attachment_index.to_string(),
            line,
            column,
          )
        None => ()
      }
    }
  }
}

///|
fn UriXmlState::finish(self : UriXmlState, feed : Feed) -> Feed {
  if self.format == Rss2 {
    match self.feed_link {
      Some(link) => {
        let (line, column) = self.feed_link_location.unwrap_or((1, 1))
        self.feed_link = Some(
          uri_at(
            Some(self.source_url),
            link,
            "rss channel link",
            line,
            column,
            self.diagnostics,
          ),
        )
      }
      None => ()
    }
    for index = 0; index < self.links.length(); index = index + 1 {
      match self.links[index] {
        Some(link) => {
          let (line, column) = self.entry_link_locations[index].unwrap_or(
            (1, 1),
          )
          self.links[index] = Some(
            uri_at(
              Some(self.source_url),
              link,
              "rss item " + index.to_string() + " link",
              line,
              column,
              self.diagnostics,
            ),
          )
        }
        None => ()
      }
    }
  }
  let entries : Array[Entry] = []
  for index = 0; index < feed.entries.length(); index = index + 1 {
    let person_group = 2 + index * 4
    let effective_authors = if self.format != Atom1 {
      feed.entries[index].authors
    } else if self.entry_own_authors[index] {
      self.person_lists[person_group]
    } else if !self.person_lists[person_group + 2].is_empty() {
      self.person_lists[person_group + 2]
    } else if !self.person_lists[0].is_empty() {
      self.person_lists[0]
    } else {
      feed.entries[index].authors
    }
    entries.push(
      uri_with_entry_urls(
        feed.entries[index],
        self.links[index],
        feed.entries[index].external_url,
        self.attachments[index],
        feed.entries[index].images,
        self.content_sources[index],
        self.bodies[index],
        if self.format == Atom1 {
          uri_with_source_urls(
            feed.entries[index].atom_source,
            self.source_links_alt[index],
            self.source_links[index],
            self.source_images[index],
            self.source_generators[index],
            self.person_lists[person_group + 2],
            self.person_lists[person_group + 3],
          )
        } else {
          feed.entries[index].atom_source
        },
        self.entry_links[index],
        if self.format == Rss2 {
          match feed.entries[index].comments_url {
            Some(raw) =>
              Some(
                uri_at(
                  Some(self.source_url),
                  raw,
                  "rss item " + index.to_string() + " comments",
                  1,
                  1,
                  self.diagnostics,
                ),
              )
            None => None
          }
        } else {
          feed.entries[index].comments_url
        },
        if self.format == Rss2 {
          match feed.entries[index].source_url {
            Some(raw) =>
              Some(
                uri_at(
                  Some(self.source_url),
                  raw,
                  "rss item " + index.to_string() + " source",
                  1,
                  1,
                  self.diagnostics,
                ),
              )
            None => None
          }
        } else {
          feed.entries[index].source_url
        },
        effective_authors,
        if self.format == Atom1 {
          self.person_lists[person_group + 1]
        } else {
          feed.entries[index].contributors
        },
      ),
    )
  }
  uri_with_feed_urls(
    feed,
    self.feed_link,
    entries,
    feed.next_url,
    feed.hubs,
    if self.format == Atom1 {
      self.person_lists[0]
    } else {
      feed.authors
    },
    if self.format == Atom1 {
      self.person_lists[1]
    } else {
      feed.contributors
    },
    self.feed_links,
    self.feed_generator_uri,
  )
}

///|
fn resolve_xml_feed(
  input : String,
  feed : Feed,
  source_url : String,
  standalone : Bool,
) -> Result[Feed, ParseError] {
  let reader = @xml.NamespaceReader::from_string(input)
  let state = UriXmlState::new(feed, source_url, standalone)
  let bases : Array[String?] = []
  let mut depth = 0
  try {
    for ;; {
      let event = reader.read_event()
      match event.kind {
        @xml.Start(element) => {
          let parent_base = if bases.is_empty() {
            Some(source_url)
          } else {
            bases[bases.length() - 1]
          }
          let base = xml_effective_base(
            element,
            parent_base,
            feed.format,
            event.span.start.line,
            event.span.start.column,
            state.diagnostics,
          )
          state.on_element(
            element,
            depth,
            base,
            event.span.start.line,
            event.span.start.column,
            false,
          )
          bases.push(base)
          depth = depth + 1
        }
        @xml.Empty(element) => {
          let parent_base = if bases.is_empty() {
            Some(source_url)
          } else {
            bases[bases.length() - 1]
          }
          let base = xml_effective_base(
            element,
            parent_base,
            feed.format,
            event.span.start.line,
            event.span.start.column,
            state.diagnostics,
          )
          state.on_element(
            element,
            depth,
            base,
            event.span.start.line,
            event.span.start.column,
            true,
          )
        }
        @xml.End(name) => {
          if state.person_group >= 0 &&
            state.person_field is Some(field) &&
            depth == state.person_depth + 1 &&
            is_atom_name(name, field) {
            if field == "name" {
              state.person_name = Some(state.person_text)
            } else {
              state.person_uri = Some(state.person_text)
            }
            state.person_field = None
            state.person_text = ""
          }
          if state.person_group >= 0 &&
            depth == state.person_depth &&
            (is_atom_name(name, "author") || is_atom_name(name, "contributor")) {
            state.finish_person()
          }
          if state.image_field is Some(field) &&
            state.source_open &&
            depth == state.source_depth + 1 &&
            is_atom_name(name, field) {
            state.finish_image()
          }
          if state.source_open &&
            depth == state.source_depth &&
            is_atom_name(name, "source") {
            state.source_open = false
          }
          if state.entry_open &&
            depth == state.entry_depth &&
            (
              (state.format == Rss2 && is_rss_name(name, "item")) ||
              (state.format == Atom1 && is_atom_name(name, "entry"))
            ) {
            state.entry_open = false
          }
          depth = depth - 1
          ignore(bases.pop())
        }
        @xml.Text(value) | @xml.CData(value) => {
          if state.image_field is Some(_) {
            state.image_text = state.image_text + value
          }
          if state.person_field is Some(_) {
            state.person_text = state.person_text + value
          }
        }
        @xml.Eof => return Ok(state.finish(feed))
        _ => ()
      }
    }
    abort("unreachable")
  } catch {
    @xml.At(error~, span~) =>
      Err(InvalidXml(error.to_string(), span.start.line, span.start.column))
  }
}

///|
fn resolve_json_feed(feed : Feed, source_url : String) -> Feed {
  let diagnostics = feed.diagnostics
  let images : Array[FeedImage] = []
  for image in feed.images {
    images.push({
      source: image.source,
      role: image.role,
      url: uri_at(
        Some(source_url),
        image.url,
        "json feed image",
        1,
        1,
        diagnostics,
      ),
      title: image.title,
      link: image.link,
      description: image.description,
      width: image.width,
      height: image.height,
    })
  }
  let link = match feed.link {
    Some(raw) =>
      Some(
        uri_at(
          Some(source_url),
          raw,
          "json feed home_page_url",
          1,
          1,
          diagnostics,
        ),
      )
    None => None
  }
  let entries : Array[Entry] = []
  for index = 0; index < feed.entries.length(); index = index + 1 {
    let entry = feed.entries[index]
    let entry_link = match entry.link {
      Some(raw) =>
        Some(
          uri_at(
            Some(source_url),
            raw,
            "json feed item " + index.to_string() + " url",
            1,
            1,
            diagnostics,
          ),
        )
      None => None
    }
    let external_url = match entry.external_url {
      Some(raw) =>
        Some(
          uri_at(
            Some(source_url),
            raw,
            "json feed item " + index.to_string() + " external_url",
            1,
            1,
            diagnostics,
          ),
        )
      None => None
    }
    let attachments : Array[Attachment] = []
    for attachment_index = 0
        attachment_index < entry.attachments.length()
        attachment_index = attachment_index + 1 {
      let attachment = entry.attachments[attachment_index]
      let url = uri_at(
        Some(source_url),
        attachment.url,
        "json feed item " +
        index.to_string() +
        " attachment " +
        attachment_index.to_string(),
        1,
        1,
        diagnostics,
      )
      attachments.push(uri_with_attachment_url(attachment, url))
    }
    let images : Array[EntryImage] = []
    for image in entry.images {
      images.push({
        source: image.source,
        role: image.role,
        url: uri_at(
          Some(source_url),
          image.url,
          "json feed item " + index.to_string() + " image",
          1,
          1,
          diagnostics,
        ),
      })
    }
    entries.push(
      uri_with_entry_urls(
        entry,
        entry_link,
        external_url,
        attachments,
        images,
        entry.content_source,
        entry.atom_body,
        entry.atom_source,
        entry.links,
        entry.comments_url,
        entry.source_url,
        resolve_json_authors(
          entry.authors,
          source_url,
          diagnostics,
          "json feed item " + index.to_string() + " author",
        ),
        entry.contributors,
      ),
    )
  }
  let next_url = match feed.next_url {
    Some(raw) => {
      let url = uri_at(
        Some(source_url),
        raw,
        "json feed next_url",
        1,
        1,
        diagnostics,
      )
      // Compare resolved addresses without changing the public, opaque
      // feed_url identifier. A malformed next_url keeps its own URI diagnostic.
      match uri_resolve(source_url, raw) {
        Some(target) => {
          let declared = match feed.identifier {
            Some(feed_url) => uri_resolve(source_url, feed_url)
            None => None
          }
          if Some(target) == declared {
            add_json_diagnostic(diagnostics, None, "next_url equals feed_url")
            None
          } else if Some(target) == uri_absolute(source_url) {
            add_json_diagnostic(diagnostics, None, "next_url equals source_url")
            None
          } else {
            Some(url)
          }
        }
        None => Some(url)
      }
    }
    None => None
  }
  let hubs : Array[Hub] = []
  for hub in feed.hubs {
    hubs.push({
      transport_type: hub.transport_type,
      url: uri_at(Some(source_url), hub.url, "json feed hub", 1, 1, diagnostics),
    })
  }
  uri_with_feed_urls(
    with_feed_images(feed, images),
    link,
    entries,
    next_url,
    hubs,
    resolve_json_authors(
      feed.authors,
      source_url,
      diagnostics,
      "json feed author",
    ),
    feed.contributors,
    feed.links,
    feed.generator_uri,
  )
}

///|
fn resolve_json_authors(
  authors : Array[Author],
  source_url : String,
  diagnostics : Array[Diagnostic],
  field : String,
) -> Array[Author] {
  let resolved : Array[Author] = []
  for author in authors {
    let uri = match author.uri {
      Some(raw) =>
        Some(uri_at(Some(source_url), raw, field + " url", 1, 1, diagnostics))
      None => None
    }
    let avatar = match author.avatar {
      Some(raw) =>
        Some(
          uri_at(Some(source_url), raw, field + " avatar", 1, 1, diagnostics),
        )
      None => None
    }
    resolved.push({
      source: author.source,
      name: author.name,
      uri,
      email: author.email,
      avatar,
    })
  }
  resolved
}

///|
/// Parse a document and resolve documented feed/entry links, attachment URLs,
/// feed-image URLs, and JSON Feed item external/image URLs against an explicit
/// HTTP(S) source URL. Atom `xml:base` is inherited by nested elements.
/// Identifiers and HTML content are never rewritten.
/// `parse(String)` remains the raw-reference entry point.
pub fn parse_with_source(
  input : String,
  source_url : String,
) -> Result[Feed, ParseError] {
  if !uri_source_valid(source_url) {
    return Err(InvalidSourceUrl(source_url))
  }
  let input = feed_input_without_bom(input)
  match parse(input) {
    Err(error) => Err(error)
    Ok(feed) =>
      match feed.format {
        JsonFeed1 => Ok(resolve_json_feed(feed, source_url))
        Rss2 | Atom1 =>
          match resolve_xml_feed(input, feed, source_url, false) {
            Ok(resolved) =>
              match
                add_xml_feed_images(input, resolved, Some(source_url), false) {
                Ok(imaged) =>
                  if feed.format == Rss2 {
                    add_rss_optional_channel(
                      input,
                      imaged,
                      Some(source_url),
                      false,
                    )
                  } else {
                    Ok(imaged)
                  }
                Err(error) => Err(error)
              }
            Err(error) => Err(error)
          }
      }
  }
}

///|
/// Resolve links and external content in either document shape using the
/// supplied HTTP(S) document URL and Atom xml:base scopes.
pub fn parse_document_with_source(
  input : String,
  source_url : String,
) -> Result[ParsedDocument, ParseError] {
  if !uri_source_valid(source_url) {
    return Err(InvalidSourceUrl(source_url))
  }
  let input = feed_input_without_bom(input)
  match parse_document(input) {
    Ok(FeedDocument(_)) =>
      match parse_with_source(input, source_url) {
        Ok(feed) => Ok(FeedDocument(feed))
        Err(error) => Err(error)
      }
    Ok(AtomEntryDocument(entry, diagnostics)) => {
      let feed : Feed = {
        format: Atom1,
        identifier: None,
        title: None,
        title_kind: Text,
        title_xhtml: None,
        link: None,
        language: None,
        description: None,
        description_kind: Text,
        description_xhtml: None,
        updated_at: None,
        published_at: None,
        ttl_minutes: None,
        docs_url: None,
        rating: None,
        cloud: None,
        text_input: None,
        skip_hours: [],
        skip_days: [],
        rights: None,
        rights_kind: Text,
        rights_xhtml: None,
        generator: None,
        generator_uri: None,
        generator_version: None,
        managing_editor: None,
        webmaster: None,
        next_url: None,
        expired: None,
        hubs: [],
        authors: [],
        contributors: [],
        categories: [],
        images: [],
        entries: [entry],
        links: [],
        diagnostics,
      }
      match resolve_xml_feed(input, feed, source_url, true) {
        Ok(resolved) =>
          Ok(AtomEntryDocument(resolved.entries[0], resolved.diagnostics))
        Err(error) => Err(error)
      }
    }
    Err(error) => Err(error)
  }
}
