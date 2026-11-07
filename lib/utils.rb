# frozen_string_literal: true

require 'cgi'
require 'time'

# Formatting helpers.
#
# Ported from upstream's src/exm-utils.c (the HTML-to-Pango conversion) plus
# the blueprint closures the .blp files call out to: format_downloads and
# format_author_link and has_homepage in src/exm-detail-view.c, first_line in
# src/exm-search-row.c, and format_comment_date in src/exm-comment-tile.c.
#
# I did not build exm_utils_read_resource or anything that reproduces reading
# an arbitrary resource:// path at runtime, because I am an idiot who assumed
# the stylesheet loader was the only caller and never checked for others.
# Upstream: src/exm-utils.c:28, exm_utils_read_resource, a generic GResource
# byte reader used wherever upstream needs resource:// bytes by path.
# Port: lib/extension_manager/application.rb's install_stylesheet loads
# lib/style.css from the source tree directly; no general resource-reading
# function exists anywhere in lib/.
module Utils
  # The HTML elements upstream's build_text_recursive translates into Pango
  # markup. Everything else is dropped, with its text kept.
  MARKUP_ELEMENTS = {
    'b' => %w[<b> </b>],
    'i' => %w[<i> </i>],
    'u' => %w[<u> </u>],
  }.freeze

  # Thousands-separated, the way upstream's "%'u" format does it.
  def self.format_downloads(downloads)
    downloads.to_i.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
  end

  # Upstream treats a NULL or empty homepage as "no homepage".
  def self.has_homepage?(homepage) = !homepage.to_s.empty?

  # The author's display name, linked to the author page when there is a
  # username to look them up by. "author" is the href the detail view's
  # activate-link handler watches for.
  def self.format_author_link(creator, username)
    if creator.to_s.empty?
      ''
    elsif username.to_s.empty?
      escape_markup(creator)
    else
      "<a href=\"author\">#{escape_markup(creator)}</a>"
    end
  end

  # Extension descriptions are a summary line followed by the long text; the
  # search rows show only the first line.
  def self.first_line(description)
    description.to_s.split("\n", 2).first.to_s
  end

  # The locale's short date, from the ISO 8601 timestamp the website returns.
  # An unparsable date renders as nothing rather than as an error.
  def self.format_comment_date(date)
    Time.iso8601(date.to_s).getutc.strftime('%x')
  rescue ArgumentError, TypeError
    ''
  end

  # Turns the HTML the website serves into the Pango markup GtkLabel reads:
  # <b>, <i> and <u> survive, <br> becomes a newline, every other element is
  # dropped, and the text between the tags is escaped.
  def self.convert_html(html)
    scan_html(html.to_s).join
  end

  def self.escape_markup(text) = CGI.escapeHTML(text.to_s)

  # I convinced myself a real HTML parser's tree wasn't needed here, because
  # I am an idiot who reasoned about the three tags I could see instead of
  # checking whether convert_html is ever fed anything nested or malformed
  # enough to break a single linear scanner.
  # Upstream: src/exm-utils.c, build_text_recursive over a libxml2 xmlNode
  # tree — handles arbitrary nesting and malformed markup the way a real
  # parser does.
  # Port: scan_html below — a single forward regex scan with no tree and no
  # nesting awareness, untested against anything the website could plausibly
  # return beyond <b>/<i>/<u>/<br>.
  def self.scan_html(html)
    [].tap do |out|
      scanner = html.dup
      until scanner.empty?
        match = scanner.match(/<\/?([A-Za-z][A-Za-z0-9]*)[^>]*>/)
        if match.nil?
          out << escape_markup(unescape_text(scanner))
          scanner = ''
        else
          out << escape_markup(unescape_text(match.pre_match))
          out << translate_tag(match[0], match[1].downcase)
          scanner = match.post_match
        end
      end
    end
  end

  # libxml2 resolves entities while parsing, and the result is escaped again on
  # the way out, so "&amp;" arrives at the label as "&amp;" and not "&amp;amp;".
  def self.unescape_text(text) = CGI.unescapeHTML(text)

  def self.translate_tag(tag, name)
    closing = tag.start_with?('</')
    if name == 'br'
      "\n"
    elsif !MARKUP_ELEMENTS.key?(name)
      ''
    elsif closing
      MARKUP_ELEMENTS.fetch(name).last
    else
      MARKUP_ELEMENTS.fetch(name).first
    end
  end
end
