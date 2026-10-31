#!/usr/bin/env python3
"""Markdown editor with live preview.

Edit a local markdown file (or one fetched from a URL), see a live preview
side by side, save it locally and export it to HTML or PDF.

Dependencies (see md-editor-install.sh / md-editor-requirements.txt):
    pip install PySide6 markdown pygments     # pygments is optional

Usage:
    md-editor.py [FILE_OR_URL]
"""
import argparse
import html
import json
import os
import re
import sys
import urllib.parse
import urllib.request

import markdown
from PySide6.QtCore import QMarginsF, QRect, QSettings, Qt, QTimer, QUrl
from PySide6.QtGui import (QAction, QActionGroup, QColor, QDesktopServices, QFont,
                           QFontDatabase, QIcon, QKeySequence, QPageLayout, QPageSize,
                           QPainter, QPalette, QPixmap, QTextCursor, QTextDocument)
from PySide6.QtWidgets import (QApplication, QColorDialog, QComboBox, QFileDialog,
                               QInputDialog, QLabel, QLineEdit, QMainWindow, QMenu,
                               QMessageBox, QPlainTextEdit, QSplitter, QTextBrowser,
                               QToolButton)

try:
    from PySide6.QtWebEngineCore import QWebEnginePage, QWebEngineSettings
    from PySide6.QtWebEngineWidgets import QWebEngineView
    HAVE_WEBENGINE = True
except ImportError:
    HAVE_WEBENGINE = False

try:
    from pygments.formatters import HtmlFormatter
    from pygments.util import ClassNotFound

    def _pygments_css(*styles):
        for style in styles:
            try:
                return HtmlFormatter(style=style).get_style_defs(".codehilite")
            except ClassNotFound:
                pass
        return ""
    PYGMENTS_CSS = {"light": _pygments_css("default"), "dark": _pygments_css("github-dark", "monokai")}
    HAVE_PYGMENTS = True
except ImportError:
    PYGMENTS_CSS = {"light": "", "dark": ""}
    HAVE_PYGMENTS = False

APP_NAME = "Markdown Editor"
MD_FILTER = "Markdown (*.md *.markdown *.mdown *.txt);;All files (*)"
PARA = "\u2029"  # QTextCursor.selectedText() uses this as the line separator
KEEP = QTextCursor.MoveMode.KeepAnchor

HEADING_RE = re.compile(r"^\s{0,3}#{1,6}(?:\s+|$)")
LIST_RE = re.compile(r"^(\s*)(?:[-*+]\s+\[[ xX]\]\s+|[-*+]\s+|\d+[.)]\s+)")
# indent, task bullet, bullet, number, number delimiter, quote
CONTINUE_RE = re.compile(r"^(\s*)(?:([-*+])\s+\[[ xX]\]\s+|([-*+])\s+|(\d+)([.)])\s+|(>\s?))")
TASK_RE = re.compile(r"(<li>(?:\s*<p>)?)\[([ xX])\]\s")
SPAN_RE = re.compile(r"</?span\b[^>]*>")

FONT_SIZES = ["10", "12", "14", "16", "18", "20", "24", "28", "32", "40", "48"]
PRESET_COLORS = ["#000000", "#6a737d", "#d73a49", "#e36209", "#f9c513", "#28a745",
                 "#0366d6", "#6f42c1", "#ea4aaa", "#ffffff", "#fff59d", "#c8e6c9",
                 "#bbdefb", "#f8bbd0"]

TABLE_SNIPPET = """
| Column 1 | Column 2 | Column 3 |
| -------- | -------- | -------- |
| Cell     | Cell     | Cell     |
| Cell     | Cell     | Cell     |
"""

THEMES = {"system": "&System", "light": "&Light", "dark": "&Dark"}
THEME_COLORS = {
    "light": {"bg": "#ffffff", "fg": "#1f2328", "muted": "#59636e", "border": "#d0d7de",
              "link": "#0969da", "code-bg": "#eff1f3", "pre-bg": "#f6f8fa"},
    "dark": {"bg": "#0d1117", "fg": "#e6edf3", "muted": "#9198a1", "border": "#3d444d",
             "link": "#4493f8", "code-bg": "#262c36", "pre-bg": "#151b23"},
}

BASE_CSS = """
body { margin: 0; background: var(--bg); color: var(--fg);
  font-family: -apple-system, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
  font-size: 16px; line-height: 1.6; }
.markdown-body { box-sizing: border-box; max-width: 900px; margin: 0 auto;
  padding: 24px 32px; word-wrap: break-word; }
h1, h2, h3, h4, h5, h6 { margin: 1.4em 0 .6em; font-weight: 600; line-height: 1.25; }
h1 { font-size: 2em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
h2 { font-size: 1.5em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
h3 { font-size: 1.25em; } h4 { font-size: 1em; } h5 { font-size: .875em; }
h6 { font-size: .85em; color: var(--muted); }
p, ul, ol, blockquote, pre, table, dl { margin: 0 0 1em; }
ul, ol { padding-left: 2em; }
li > input[type=checkbox] { margin: 0 .4em 0 -1.3em; vertical-align: middle; }
a { color: var(--link); text-decoration: none; } a:hover { text-decoration: underline; }
code { font-family: ui-monospace, "DejaVu Sans Mono", Menlo, Consolas, monospace;
  font-size: 85%; background: var(--code-bg); padding: .2em .4em; border-radius: 6px; }
pre { background: var(--pre-bg); padding: 16px; overflow: auto; border-radius: 6px; line-height: 1.45; }
pre code { background: transparent; padding: 0; font-size: 85%; }
.codehilite { border-radius: 6px; margin-bottom: 1em; } .codehilite pre { margin: 0; }
blockquote { margin-left: 0; padding: 0 1em; color: var(--muted); border-left: .25em solid var(--border); }
table { border-collapse: collapse; }
th, td { border: 1px solid var(--border); padding: 6px 13px; }
th { font-weight: 600; background: var(--pre-bg); } tr:nth-child(2n) { background: var(--pre-bg); }
img { max-width: 100%; }
hr { height: .25em; border: 0; background: var(--border); margin: 24px 0; }
@media print {
  .markdown-body { max-width: none; padding: 0; }
  pre, blockquote, table, img { page-break-inside: avoid; }
}
"""


def _css_vars(theme):
    colors = " ".join("--%s: %s;" % kv for kv in THEME_COLORS[theme].items())
    return ":root { color-scheme: %s; %s }\n" % (theme, colors)


def preview_css(theme, resolve_vars=False):
    """Stylesheet for the preview. Printing always uses the light colors.

    resolve_vars inlines the colors for QTextBrowser, which has no CSS variables."""
    if resolve_vars:
        colors = THEME_COLORS[theme]
        return re.sub(r"var\(--([\w-]+)\)", lambda m: colors[m[1]], BASE_CSS) + PYGMENTS_CSS[theme]
    css = _css_vars(theme) + BASE_CSS
    if theme == "light":
        return css + PYGMENTS_CSS["light"]
    return (css + "@media screen {\n%s}\n@media print {\n%s%s}\n"
            % (PYGMENTS_CSS["dark"], _css_vars("light"), PYGMENTS_CSS["light"]))

_extensions = ["extra", "sane_lists", "toc", "admonition"]
_ext_config = {}
if HAVE_PYGMENTS:
    _extensions.append("codehilite")
    _ext_config["codehilite"] = {"guess_lang": False}
_MD = markdown.Markdown(extensions=_extensions, extension_configs=_ext_config)


def md_to_html(text):
    body = _MD.reset().convert(text)
    return TASK_RE.sub(lambda m: '%s<input type="checkbox" disabled%s> '
                       % (m[1], "" if m[2] == " " else " checked"), body)


def build_html(body, title="", base_href=None, theme="light"):
    base = f'<base href="{html.escape(base_href)}">' if base_href else ""
    return (f'<!DOCTYPE html>\n<html><head><meta charset="utf-8">{base}'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">'
            f'<title>{html.escape(title)}</title><style>{preview_css(theme)}</style></head>\n'
            f'<body><article id="content" class="markdown-body">\n{body}\n</article></body></html>\n')


def normalize_url(url):
    """Turn GitHub/GitLab "blob" page URLs into raw file URLs."""
    m = re.match(r"https?://github\.com/([^/]+)/([^/]+)/blob/([^?#]+)", url)
    if m:
        return f"https://raw.githubusercontent.com/{m[1]}/{m[2]}/{m[3]}"
    return re.sub(r"^(https?://gitlab\.[^/]+/.+?)/-/blob/", r"\1/-/raw/", url)


def fetch_url(url):
    req = urllib.request.Request(normalize_url(url), headers={"User-Agent": "md-editor/1.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        charset = resp.headers.get_content_charset() or "utf-8"
        return resp.geturl(), resp.read().decode(charset, errors="replace")


def qlen(text):
    """Length of text in UTF-16 code units, which is what QTextCursor positions count."""
    return len(text.encode("utf-16-le")) // 2


def pdf_page_layout():
    return QPageLayout(QPageSize(QPageSize.PageSizeId.A4), QPageLayout.Orientation.Portrait,
                       QMarginsF(15, 15, 15, 15), QPageLayout.Unit.Millimeter)


def dark_palette():
    R = QPalette.ColorRole
    p = QPalette()
    for role, color in ((R.Window, "#1e1f22"), (R.WindowText, "#dfe1e5"), (R.Base, "#16171a"),
                        (R.AlternateBase, "#26282c"), (R.Text, "#dfe1e5"), (R.Button, "#2b2d30"),
                        (R.ButtonText, "#dfe1e5"), (R.BrightText, "#ff6b6b"), (R.ToolTipBase, "#2b2d30"),
                        (R.ToolTipText, "#dfe1e5"), (R.Highlight, "#2f65ca"), (R.HighlightedText, "#ffffff"),
                        (R.Link, "#4493f8"), (R.PlaceholderText, "#8a8f98"), (R.Mid, "#3c3f44"),
                        (R.Dark, "#121316"), (R.Light, "#3c3f44"), (R.Shadow, "#000000")):
        p.setColor(role, QColor(color))
    for role in (R.WindowText, R.Text, R.ButtonText):
        p.setColor(QPalette.ColorGroup.Disabled, role, QColor("#6b6f76"))
    return p


def swatch_icon(color):
    pm = QPixmap(16, 16)
    pm.fill(color)
    p = QPainter(pm)
    p.setPen(QColor("#888888"))
    p.drawRect(0, 0, 15, 15)
    p.end()
    return QIcon(pm)


def color_button_icon(color, background):
    pm = QPixmap(22, 22)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    font = p.font()
    font.setBold(True)
    font.setPixelSize(14)
    p.setFont(font)
    if background:
        p.fillRect(2, 2, 18, 18, color)
        p.setPen(QColor("#000000") if color.lightness() > 128 else QColor("#ffffff"))
        p.drawText(QRect(0, 0, 22, 22), Qt.AlignmentFlag.AlignCenter, "A")
    else:
        p.setPen(QApplication.palette().windowText().color())
        p.drawText(QRect(0, 0, 22, 17), Qt.AlignmentFlag.AlignCenter, "A")
        p.fillRect(3, 17, 16, 4, color)
    p.end()
    return QIcon(pm)


# ---------------------------------------------------------------------------
# Preview widgets
# ---------------------------------------------------------------------------

if HAVE_WEBENGINE:
    class _PreviewPage(QWebEnginePage):
        base_url = QUrl()

        def acceptNavigationRequest(self, url, nav_type, is_main_frame):
            if nav_type != QWebEnginePage.NavigationType.NavigationTypeLinkClicked:
                return True
            strip = QUrl.UrlFormattingOption.RemoveFragment
            if url.hasFragment() and url.adjusted(strip) == self.base_url.adjusted(strip):
                self.runJavaScript("var e = document.getElementById(%s); if (e) e.scrollIntoView();"
                                   % json.dumps(url.fragment()))
            else:
                QDesktopServices.openUrl(url)
            return False

    class WebPreview(QWebEngineView):
        """Chromium based preview. The page shell is loaded once per base URL and
        later updates only replace the body, which keeps the scroll position."""

        def __init__(self, parent=None):
            super().__init__(parent)
            self.setPage(_PreviewPage(self))
            s = self.settings()
            s.setAttribute(QWebEngineSettings.WebAttribute.LocalContentCanAccessRemoteUrls, True)
            s.setAttribute(QWebEngineSettings.WebAttribute.LocalContentCanAccessFileUrls, True)
            self._base = None
            self._ready = False
            self._pending = None
            self._pdf_done = None
            self._theme = "light"
            self._restore_y = None
            self.loadFinished.connect(self._on_loaded)
            self.page().pdfPrintingFinished.connect(self._on_pdf_finished)

        def set_theme(self, theme):
            # Swapping the <style> text in place crashes Chromium, so rebuild the page
            # on the next update and carry the scroll position over.
            self._theme = theme
            self.page().setBackgroundColor(QColor(THEME_COLORS[theme]["bg"]))
            if self._ready:
                self.page().runJavaScript("window.scrollY", 0, self._remember_scroll)
            self._base = None

        def _remember_scroll(self, y):
            self._restore_y = y

        def set_content(self, body, base):
            if base == self._base and self._ready:
                self.page().runJavaScript("document.getElementById('content').innerHTML = %s;"
                                          % json.dumps(body))
            elif base == self._base:
                self._pending = body
            else:
                self._base, self._ready, self._pending = base, False, None
                self.page().base_url = base
                self.setHtml(build_html(body, theme=self._theme), base)

        def _on_loaded(self, _ok):
            self._ready = True
            if self._pending is not None:
                body, self._pending = self._pending, None
                self.set_content(body, self._base)
            if self._restore_y:
                self.page().runJavaScript("window.scrollTo(0, %d);" % self._restore_y)
                self._restore_y = None

        def scroll_to_ratio(self, ratio):
            if self._ready:
                self.page().runJavaScript(
                    "window.scrollTo(0, %f * (document.documentElement.scrollHeight"
                    " - window.innerHeight));" % ratio)

        def export_pdf(self, path, done):
            if not self._ready or self._pending is not None:
                QTimer.singleShot(100, lambda: self.export_pdf(path, done))
                return
            self._pdf_done = done
            # The page background color fills the PDF margins; print always uses the light theme.
            self.page().setBackgroundColor(QColor(THEME_COLORS["light"]["bg"]))
            # Round-trip through the JS queue so pending body updates are applied first.
            self.page().runJavaScript("0", 0, lambda _: self.page().printToPdf(path, pdf_page_layout()))

        def _on_pdf_finished(self, _path, ok):
            self.page().setBackgroundColor(QColor(THEME_COLORS[self._theme]["bg"]))
            if self._pdf_done:
                done, self._pdf_done = self._pdf_done, None
                done(ok)


class TextPreview(QTextBrowser):
    """Fallback preview used when QtWebEngine is not installed (limited CSS support)."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setOpenExternalLinks(True)
        self._body = ""
        self.set_theme("light")

    def set_theme(self, theme):
        colors = THEME_COLORS[theme]
        self.setStyleSheet("QTextBrowser { background: %s; color: %s; }" % (colors["bg"], colors["fg"]))
        self.document().setDefaultStyleSheet(preview_css(theme, resolve_vars=True))

    def set_content(self, body, base):
        sb = self.verticalScrollBar()
        pos = sb.value()
        self._body = body
        self.document().setBaseUrl(base)
        self.setHtml(body)
        sb.setValue(pos)

    def scroll_to_ratio(self, ratio):
        sb = self.verticalScrollBar()
        sb.setValue(int(ratio * sb.maximum()))

    def export_pdf(self, path, done):
        from PySide6.QtPrintSupport import QPrinter
        printer = QPrinter(QPrinter.PrinterMode.HighResolution)
        printer.setOutputFormat(QPrinter.OutputFormat.PdfFormat)
        printer.setOutputFileName(path)
        printer.setPageLayout(pdf_page_layout())
        doc = QTextDocument()
        doc.setDefaultStyleSheet(preview_css("light", resolve_vars=True))
        doc.setBaseUrl(self.document().baseUrl())
        doc.setHtml(self._body)
        doc.print_(printer)
        done(True)


# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------

class MarkdownEdit(QPlainTextEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        font = QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont)
        font.setPointSize(11)
        self.setFont(font)
        self.setTabStopDistance(self.fontMetrics().horizontalAdvance(" ") * 4)

    # -- cursor helpers -----------------------------------------------------

    def _select(self, start, end):
        c = self.textCursor()
        c.setPosition(start)
        c.setPosition(end, KEEP)
        self.setTextCursor(c)

    def _range_text(self, start, end):
        if start < 0 or end > self.document().characterCount() - 1:
            return None
        c = QTextCursor(self.document())
        c.setPosition(start)
        c.setPosition(end, KEEP)
        return c.selectedText()

    def _block_cursor(self):
        """Cursor selecting every full line touched by the current selection."""
        c = self.textCursor()
        doc = self.document()
        first = doc.findBlock(c.selectionStart())
        last = doc.findBlock(c.selectionEnd())
        if (c.hasSelection() and last.blockNumber() > first.blockNumber()
                and c.selectionEnd() == last.position()):
            last = last.previous()
        bc = QTextCursor(doc)
        bc.setPosition(first.position())
        bc.setPosition(last.position() + last.length() - 1, KEEP)
        return bc

    # -- editing primitives -------------------------------------------------

    def wrap_inline(self, left, right, placeholder="text"):
        """Wrap the selection in left/right markers, or unwrap if already wrapped."""
        c = self.textCursor()
        start, end = c.selectionStart(), c.selectionEnd()
        sel = c.selectedText().replace(PARA, "\n")
        ql, qr = qlen(left), qlen(right)
        c.beginEditBlock()
        if sel and len(sel) >= len(left) + len(right) and sel.startswith(left) and sel.endswith(right):
            inner = sel[len(left):len(sel) - len(right)]
            c.insertText(inner)
            c.endEditBlock()
            self._select(start, start + qlen(inner))
        elif sel and self._range_text(start - ql, start) == left and self._range_text(end, end + qr) == right:
            c.setPosition(end)
            c.setPosition(end + qr, KEEP)
            c.removeSelectedText()
            c.setPosition(start - ql)
            c.setPosition(start, KEEP)
            c.removeSelectedText()
            c.endEditBlock()
            self._select(start - ql, end - ql)
        else:
            inner = sel or placeholder
            c.insertText(left + inner + right)
            c.endEditBlock()
            self._select(start + ql, start + ql + qlen(inner))
        self.setFocus()

    def transform_lines(self, fn):
        """Replace the selected lines with fn(lines) as a single undo step."""
        had_selection = self.textCursor().hasSelection()
        bc = self._block_cursor()
        lines = bc.selectedText().split(PARA)
        new = fn(lines)
        if new != lines:
            start = bc.selectionStart()
            text = "\n".join(new)
            bc.beginEditBlock()
            bc.insertText(text)
            bc.endEditBlock()
            if had_selection:
                self._select(start, start + qlen(text))
            else:
                c = self.textCursor()
                c.setPosition(start + qlen(text))
                self.setTextCursor(c)
        self.setFocus()

    def insert_snippet(self, text, block=False):
        c = self.textCursor()
        if block:
            doc = self.document()
            before = QTextCursor(doc)
            before.setPosition(c.selectionStart())
            after = QTextCursor(doc)
            after.setPosition(c.selectionEnd())
            if not before.atBlockStart():
                text = "\n" + text
            if not after.atBlockEnd():
                text += "\n"
        c.insertText(text)
        self.setTextCursor(c)
        self.setFocus()

    # -- markdown operations ------------------------------------------------

    def set_heading(self, level):
        def fn(lines):
            out = []
            for line in lines:
                if len(lines) > 1 and not line.strip():
                    out.append(line)
                    continue
                body = HEADING_RE.sub("", line, count=1)
                out.append("%s %s" % ("#" * level, body.lstrip()) if level else body)
            return out
        self.transform_lines(fn)

    def _needs_gap(self, same_kind):
        """True if the line above the selection is paragraph text that would swallow a new block."""
        prev = self.document().findBlock(self.textCursor().selectionStart()).previous()
        return prev.isValid() and bool(prev.text().strip()) and not same_kind(prev.text())

    def toggle_list(self, kind):
        prefixes = {"bullet": "- ", "number": None, "task": "- [ ] "}
        gap = self._needs_gap(LIST_RE.match)

        def split(line):
            m = LIST_RE.match(line)
            if m:
                return m[1], line[m.end():], self._list_kind(m[0])
            indent = line[:len(line) - len(line.lstrip())]
            return indent, line[len(indent):], None

        def fn(lines):
            parsed = [split(line) for line in lines]
            items = [p for p, line in zip(parsed, lines) if line.strip()]
            remove = bool(items) and all(p[2] == kind for p in items)
            out, n = [], 1
            for line, (indent, rest, _) in zip(lines, parsed):
                if len(lines) > 1 and not line.strip():
                    out.append(line)
                elif remove:
                    out.append(indent + rest)
                else:
                    out.append(indent + (prefixes[kind] or "%d. " % n) + rest)
                    n += 1
            return out if remove or not gap else [""] + out
        self.transform_lines(fn)

    @staticmethod
    def _list_kind(marker):
        marker = marker.strip()
        if marker[0].isdigit():
            return "number"
        return "task" if "[" in marker else "bullet"

    def toggle_quote(self):
        is_quote = lambda line: line.lstrip().startswith(">")
        gap = self._needs_gap(is_quote)

        def fn(lines):
            items = [line for line in lines if line.strip()]
            if items and all(is_quote(line) for line in items):
                return [re.sub(r"^(\s*)>\s?", r"\1", line) for line in lines]
            out = [("> " + line) if line.strip() or len(lines) == 1 else line for line in lines]
            return [""] + out if gap else out
        self.transform_lines(fn)

    def indent(self):
        self.transform_lines(lambda lines: [("    " + l) if l.strip() else l for l in lines])

    def outdent(self):
        self.transform_lines(lambda lines: [re.sub(r"^( {1,4}|\t)", "", l) for l in lines])

    def code_block(self):
        sel = self.textCursor().selectedText().replace(PARA, "\n")
        self.insert_snippet("```\n%s\n```" % (sel or "code"), block=True)

    def clear_styles(self):
        c = self.textCursor()
        if not c.hasSelection():
            c = self._block_cursor()
        start = c.selectionStart()
        new = SPAN_RE.sub("", c.selectedText().replace(PARA, "\n"))
        c.insertText(new)
        self._select(start, start + qlen(new))
        self.setFocus()

    # -- key handling -------------------------------------------------------

    def keyPressEvent(self, e):
        plain = e.modifiers() in (Qt.KeyboardModifier.NoModifier, Qt.KeyboardModifier.KeypadModifier)
        c = self.textCursor()
        if e.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter) and plain and not c.hasSelection():
            if self._continue_list(c):
                return
        elif e.key() == Qt.Key.Key_Tab and plain:
            multi_line = c.hasSelection() and PARA in c.selectedText()
            if multi_line or LIST_RE.match(c.block().text()):
                self.indent()
            else:
                c.insertText("    ")
            return
        elif e.key() == Qt.Key.Key_Backtab:
            self.outdent()
            return
        super().keyPressEvent(e)

    def _continue_list(self, c):
        """On Enter inside a list item / quote, start the next item (or end the list)."""
        line = c.block().text()
        m = CONTINUE_RE.match(line)
        if not m or c.positionInBlock() < m.end():
            return False
        if not line[m.end():].strip():
            c.beginEditBlock()
            c.movePosition(QTextCursor.MoveOperation.StartOfBlock)
            c.movePosition(QTextCursor.MoveOperation.EndOfBlock, KEEP)
            c.removeSelectedText()
            c.endEditBlock()
            return True
        indent = m[1]
        if m[2]:
            marker = "%s [ ] " % m[2]
        elif m[3]:
            marker = m[3] + " "
        elif m[4]:
            marker = "%d%s " % (int(m[4]) + 1, m[5])
        else:
            marker = "> "
        c.insertText("\n" + indent + marker)
        self.ensureCursorVisible()
        return True


# ---------------------------------------------------------------------------
# Main window
# ---------------------------------------------------------------------------

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.path = None        # local file backing the document
        self.source_url = None  # remote URL the document was fetched from
        self.fg_color = QColor("#d73a49")
        self.bg_color = QColor("#fff59d")
        self.settings = QSettings("md-editor", "md-editor")
        app = QApplication.instance()
        self._system_style = app.style().name()
        self._system_palette = QPalette(app.palette())
        self.preview_theme = "light"

        self.editor = MarkdownEdit()
        self.preview = WebPreview() if HAVE_WEBENGINE else TextPreview()
        self.splitter = QSplitter(Qt.Orientation.Horizontal)
        self.splitter.addWidget(self.editor)
        self.splitter.addWidget(self.preview)
        self.splitter.setChildrenCollapsible(True)
        self.splitter.setStretchFactor(0, 1)
        self.splitter.setStretchFactor(1, 1)
        self.splitter.splitterMoved.connect(self._sync_fold_actions)
        self.setCentralWidget(self.splitter)

        self.render_timer = QTimer(self)
        self.render_timer.setSingleShot(True)
        self.render_timer.setInterval(250)
        self.render_timer.timeout.connect(self.render_now)

        self._build_actions()
        self._build_menus()
        self._build_toolbars()
        self._build_statusbar()

        doc = self.editor.document()
        doc.modificationChanged.connect(self.setWindowModified)
        self.editor.textChanged.connect(self.render_timer.start)
        self.editor.cursorPositionChanged.connect(self._on_cursor_moved)
        self.editor.undoAvailable.connect(self.act_undo.setEnabled)
        self.editor.redoAvailable.connect(self.act_redo.setEnabled)
        self.editor.verticalScrollBar().valueChanged.connect(self._sync_scroll)
        self.act_undo.setEnabled(False)
        self.act_redo.setEnabled(False)

        self.resize(1400, 850)
        theme = self.settings.value("theme", "system")
        self.apply_theme(theme if theme in THEMES else "system")
        self._set_document("", None, None)

    # -- construction -------------------------------------------------------

    def _act(self, text, slot, shortcut=None, icon=None, checkable=False, tip=None, short=None):
        a = QAction(text, self)
        if short:
            a.setIconText(short)  # label used on text-only toolbar buttons
        if icon:
            a.setIcon(QIcon.fromTheme(icon))
        if shortcut:
            a.setShortcut(QKeySequence(shortcut))
        tip = tip or text.replace("&", "").rstrip("…")
        if shortcut:
            tip += " (%s)" % a.shortcut().toString(QKeySequence.SequenceFormat.NativeText)
        a.setToolTip(tip)
        if checkable:
            a.setCheckable(True)
            a.triggered.connect(slot)
        else:
            a.triggered.connect(lambda *_: slot())
        return a

    def _build_actions(self):
        ed = self.editor
        A = self._act
        self.act_new = A("&New", self.new_file, QKeySequence.StandardKey.New, "document-new")
        self.act_open = A("&Open…", self.open_file_dialog, QKeySequence.StandardKey.Open, "document-open")
        self.act_open_url = A("Open &URL…", self.open_url_dialog, "Ctrl+Shift+O", "network-server",
                              tip="Open markdown from a URL")
        self.act_save = A("&Save", self.save, QKeySequence.StandardKey.Save, "document-save")
        self.act_save_as = A("Save &As…", self.save_as, "Ctrl+Shift+S", "document-save-as")
        self.act_export_html = A("Export &HTML…", self.export_html, None, "text-html",
                                 tip="Save as HTML")
        self.act_export_pdf = A("Export &PDF…", self.export_pdf, "Ctrl+Shift+E", "application-pdf",
                                tip="Save as PDF")
        self.act_quit = A("&Quit", self.close, QKeySequence.StandardKey.Quit, "application-exit")

        self.act_undo = A("&Undo", ed.undo, QKeySequence.StandardKey.Undo, "edit-undo")
        self.act_redo = A("&Redo", ed.redo, QKeySequence.StandardKey.Redo, "edit-redo")
        self.act_cut = A("Cu&t", ed.cut, QKeySequence.StandardKey.Cut, "edit-cut")
        self.act_copy = A("&Copy", ed.copy, QKeySequence.StandardKey.Copy, "edit-copy")
        self.act_paste = A("&Paste", ed.paste, QKeySequence.StandardKey.Paste, "edit-paste")
        self.act_select_all = A("Select &All", ed.selectAll, QKeySequence.StandardKey.SelectAll)

        self.act_bold = A("&Bold", lambda: ed.wrap_inline("**", "**", "bold text"), "Ctrl+B", short="B")
        self.act_italic = A("&Italic", lambda: ed.wrap_inline("*", "*", "italic text"), "Ctrl+I", short="I")
        self.act_strike = A("&Strikethrough", lambda: ed.wrap_inline("~~", "~~", "strikethrough"),
                            "Ctrl+Shift+X", short="S")
        self.act_code = A("Inline &Code", lambda: ed.wrap_inline("`", "`", "code"), "Ctrl+E", short="</>")
        self.act_code_block = A("Code B&lock", ed.code_block, "Ctrl+Shift+C", short="{ }")
        self.act_bullet = A("Bulleted List", lambda: ed.toggle_list("bullet"), "Ctrl+Shift+8", short="• List")
        self.act_number = A("Numbered List", lambda: ed.toggle_list("number"), "Ctrl+Shift+7", short="1. List")
        self.act_task = A("Task List", lambda: ed.toggle_list("task"), "Ctrl+Shift+9", short="☐ Task")
        self.act_quote = A("Blockquote", ed.toggle_quote, "Ctrl+Shift+Q", short="❝ Quote")
        self.act_indent = A("Indent", ed.indent, "Ctrl+]", short="→")
        self.act_outdent = A("Outdent", ed.outdent, "Ctrl+[", short="←")
        self.act_link = A("Insert &Link…", self.insert_link, "Ctrl+K", short="Link")
        self.act_image = A("Insert I&mage…", self.insert_image, "Ctrl+Shift+I", short="Image")
        self.act_table = A("Insert &Table", lambda: ed.insert_snippet(TABLE_SNIPPET, block=True), short="Table")
        self.act_hr = A("Horizontal &Rule", lambda: ed.insert_snippet("\n---\n", block=True), short="―")
        self.act_clear = A("Clear Styles", ed.clear_styles, "Ctrl+\\",
                           tip="Remove size/color styling from the selection")
        self.act_fg = A("Text Color…", lambda: self._custom_color(False))
        self.act_bg = A("Background Color…", lambda: self._custom_color(True))
        self.heading_actions = [A("Paragraph" if n == 0 else "Heading %d" % n,
                                  lambda n=n: ed.set_heading(n), "Ctrl+%d" % n) for n in range(7)]

        self.act_show_editor = A("&Editor", lambda on: self._set_pane_visible(0, on),
                                 "Ctrl+Alt+1", checkable=True, tip="Show/fold the editor")
        self.act_show_preview = A("&Preview", lambda on: self._set_pane_visible(1, on),
                                  "Ctrl+Alt+2", checkable=True, tip="Show/fold the preview")
        self.act_split = A("Split &Evenly", self._split_evenly, "Ctrl+Alt+0")
        self.act_sync = A("&Sync Scroll", lambda on: None, checkable=True)
        self.act_wrap = A("&Word Wrap", self._set_wrap, checkable=True)
        self.act_zoom_in = A("Zoom &In", lambda: ed.zoomIn(1), QKeySequence.StandardKey.ZoomIn)
        self.act_zoom_out = A("Zoom &Out", lambda: ed.zoomOut(1), QKeySequence.StandardKey.ZoomOut)
        for a in (self.act_show_editor, self.act_show_preview, self.act_sync, self.act_wrap):
            a.setChecked(True)

        self.theme_group = QActionGroup(self)
        self.theme_actions = {}
        for name, label in THEMES.items():
            a = A(label, lambda on, n=name: self.apply_theme(n), checkable=True,
                  tip="%s theme" % label.replace("&", ""))
            self.theme_group.addAction(a)
            self.theme_actions[name] = a
        self.act_toggle_theme = A("Toggle Light/Dark", self._toggle_theme, "Ctrl+Alt+T")

    def _build_menus(self):
        mb = self.menuBar()
        m = mb.addMenu("&File")
        m.addActions([self.act_new, self.act_open, self.act_open_url])
        m.addSeparator()
        m.addActions([self.act_save, self.act_save_as])
        m.addSeparator()
        m.addActions([self.act_export_html, self.act_export_pdf])
        m.addSeparator()
        m.addAction(self.act_quit)

        m = mb.addMenu("&Edit")
        m.addActions([self.act_undo, self.act_redo])
        m.addSeparator()
        m.addActions([self.act_cut, self.act_copy, self.act_paste, self.act_select_all])

        m = mb.addMenu("F&ormat")
        hm = m.addMenu("&Heading")
        hm.addActions(self.heading_actions)
        m.addSeparator()
        m.addActions([self.act_bold, self.act_italic, self.act_strike, self.act_code])
        m.addActions([self.act_fg, self.act_bg, self.act_clear])
        m.addSeparator()
        m.addActions([self.act_bullet, self.act_number, self.act_task, self.act_quote,
                      self.act_indent, self.act_outdent])
        m.addSeparator()
        m.addActions([self.act_link, self.act_image, self.act_table, self.act_code_block, self.act_hr])

        m = mb.addMenu("&View")
        m.addActions([self.act_show_editor, self.act_show_preview, self.act_split])
        m.addSeparator()
        m.addActions([self.act_sync, self.act_wrap, self.act_zoom_in, self.act_zoom_out])
        m.addSeparator()
        self.theme_menu = m.addMenu("&Theme")
        self.theme_menu.addActions(list(self.theme_actions.values()))
        self.theme_menu.addSeparator()
        self.theme_menu.addAction(self.act_toggle_theme)

    def _build_toolbars(self):
        tb = self.addToolBar("File")
        tb.setObjectName("file-toolbar")
        tb.addActions([self.act_new, self.act_open, self.act_open_url, self.act_save, self.act_save_as])
        tb.addSeparator()
        tb.addActions([self.act_export_html, self.act_export_pdf])
        tb.addSeparator()
        tb.addActions([self.act_undo, self.act_redo])
        tb.addSeparator()
        tb.addWidget(QLabel(" Show: "))
        tb.addActions([self.act_show_editor, self.act_show_preview])
        tb.addSeparator()
        theme_btn = QToolButton(self)
        theme_btn.setText("Theme")
        theme_btn.setToolTip("Choose light or dark theme")
        theme_btn.setMenu(self.theme_menu)
        theme_btn.setPopupMode(QToolButton.ToolButtonPopupMode.InstantPopup)
        tb.addWidget(theme_btn)

        self.addToolBarBreak()
        ft = self.addToolBar("Format")
        ft.setObjectName("format-toolbar")
        ft.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextOnly)

        self.heading_combo = QComboBox()
        self.heading_combo.addItems(["Paragraph"] + ["Heading %d" % n for n in range(1, 7)])
        self.heading_combo.setToolTip("Header level (Ctrl+0 … Ctrl+6)")
        self.heading_combo.activated.connect(self.editor.set_heading)
        ft.addWidget(self.heading_combo)

        self.size_combo = QComboBox()
        self.size_combo.addItem("Size")
        self.size_combo.addItems([s + " px" for s in FONT_SIZES])
        self.size_combo.setToolTip("Font size")
        self.size_combo.activated.connect(self._apply_font_size)
        ft.addWidget(self.size_combo)
        ft.addSeparator()

        for a, style in ((self.act_bold, "bold"), (self.act_italic, "italic"), (self.act_strike, "strike")):
            ft.addAction(a)
            w = ft.widgetForAction(a)
            f = QFont(w.font())
            f.setBold(style == "bold")
            f.setItalic(style == "italic")
            f.setStrikeOut(style == "strike")
            w.setFont(f)
        ft.addAction(self.act_code)
        ft.addSeparator()

        self.fg_button = self._color_button(False)
        self.bg_button = self._color_button(True)
        ft.addWidget(self.fg_button)
        ft.addWidget(self.bg_button)
        ft.addAction(self.act_clear)
        ft.addSeparator()
        ft.addActions([self.act_bullet, self.act_number, self.act_task, self.act_quote,
                       self.act_outdent, self.act_indent])
        ft.addSeparator()
        ft.addActions([self.act_link, self.act_image, self.act_table, self.act_code_block, self.act_hr])

    def _color_button(self, background):
        btn = QToolButton(self)
        btn.setPopupMode(QToolButton.ToolButtonPopupMode.MenuButtonPopup)
        btn.setToolTip("Background color" if background else "Text (foreground) color")
        menu = QMenu(btn)
        for name in PRESET_COLORS:
            a = QAction(swatch_icon(QColor(name)), name, menu)
            a.triggered.connect(lambda *_, n=name: self._pick_color(background, QColor(n)))
            menu.addAction(a)
        menu.addSeparator()
        custom = QAction("Custom…", menu)
        custom.triggered.connect(lambda *_: self._custom_color(background))
        menu.addAction(custom)
        btn.setMenu(menu)
        btn.setIcon(color_button_icon(self.bg_color if background else self.fg_color, background))
        btn.clicked.connect(lambda *_: self._apply_color(background))
        return btn

    def _build_statusbar(self):
        sb = self.statusBar()
        self.source_label = QLabel()
        self.words_label = QLabel()
        self.pos_label = QLabel()
        sb.addWidget(self.source_label, 1)
        sb.addPermanentWidget(self.words_label)
        sb.addPermanentWidget(self.pos_label)
        if not HAVE_WEBENGINE:
            sb.showMessage("QtWebEngine not found: using basic preview", 8000)

    # -- formatting slots ---------------------------------------------------

    def _apply_font_size(self, index):
        if index > 0:
            self.editor.wrap_inline('<span style="font-size:%spx">' % FONT_SIZES[index - 1], "</span>")
        self.size_combo.setCurrentIndex(0)

    def _apply_color(self, background):
        if background:
            self.editor.wrap_inline('<span style="background-color:%s">' % self.bg_color.name(), "</span>")
        else:
            self.editor.wrap_inline('<span style="color:%s">' % self.fg_color.name(), "</span>")

    def _pick_color(self, background, color):
        if background:
            self.bg_color = color
            self.bg_button.setIcon(color_button_icon(color, True))
        else:
            self.fg_color = color
            self.fg_button.setIcon(color_button_icon(color, False))
        self._apply_color(background)

    def _custom_color(self, background):
        current = self.bg_color if background else self.fg_color
        color = QColorDialog.getColor(current, self, "Background color" if background else "Text color")
        if color.isValid():
            self._pick_color(background, color)

    def insert_link(self):
        url, ok = QInputDialog.getText(self, "Insert link", "URL:", QLineEdit.EchoMode.Normal, "https://")
        if ok and url.strip():
            self.editor.wrap_inline("[", "](%s)" % url.strip(), "link text")

    def insert_image(self):
        src, ok = QInputDialog.getText(self, "Insert image", "Image URL or path (leave empty to browse):",
                                       QLineEdit.EchoMode.Normal, "")
        if not ok:
            return
        src = src.strip()
        if not src:
            src, _ = QFileDialog.getOpenFileName(self, "Insert image", self._dialog_dir(),
                                                 "Images (*.png *.jpg *.jpeg *.gif *.svg *.webp);;All files (*)")
            if not src:
                return
            if self.path:
                src = os.path.relpath(src, os.path.dirname(self.path))
        self.editor.wrap_inline("![", "](%s)" % src.replace(" ", "%20"), "alt text")

    # -- view slots ---------------------------------------------------------

    def _set_pane_visible(self, idx, visible):
        sizes = self.splitter.sizes()
        total = sum(sizes) or self.splitter.width()
        other = 1 - idx
        if visible:
            if sizes[idx] == 0:
                sizes = [total // 2, total - total // 2]
        else:
            # Folding the only visible pane swaps to the other one.
            sizes[idx], sizes[other] = 0, total
        self.splitter.setSizes(sizes)
        self._sync_fold_actions()

    def apply_theme(self, name):
        app = QApplication.instance()
        if name == "system":
            app.setStyle(self._system_style)
            app.setPalette(self._system_palette)
            system_dark = self._system_palette.color(QPalette.ColorRole.Window).lightness() < 128
            self.preview_theme = "dark" if system_dark else "light"
        else:
            app.setStyle("Fusion")
            app.setPalette(dark_palette() if name == "dark" else app.style().standardPalette())
            self.preview_theme = name
        self.theme_actions[name].setChecked(True)
        self.settings.setValue("theme", name)
        self.fg_button.setIcon(color_button_icon(self.fg_color, False))
        self.preview.set_theme(self.preview_theme)
        self.render_now()

    def _toggle_theme(self):
        self.apply_theme("light" if self.preview_theme == "dark" else "dark")

    def _split_evenly(self):
        total = sum(self.splitter.sizes()) or self.splitter.width()
        self.splitter.setSizes([total // 2, total - total // 2])
        self._sync_fold_actions()

    def _sync_fold_actions(self, *_):
        sizes = self.splitter.sizes()
        if sum(sizes) == 0:
            return
        self.act_show_editor.setChecked(sizes[0] > 0)
        self.act_show_preview.setChecked(sizes[1] > 0)

    def _set_wrap(self, on):
        self.editor.setLineWrapMode(QPlainTextEdit.LineWrapMode.WidgetWidth if on
                                    else QPlainTextEdit.LineWrapMode.NoWrap)

    def _sync_scroll(self, value):
        if self.act_sync.isChecked():
            sb = self.editor.verticalScrollBar()
            self.preview.scroll_to_ratio(value / sb.maximum() if sb.maximum() else 0.0)

    def _on_cursor_moved(self):
        c = self.editor.textCursor()
        m = re.match(r"^\s{0,3}(#{1,6})(?:\s|$)", c.block().text())
        self.heading_combo.blockSignals(True)
        self.heading_combo.setCurrentIndex(len(m[1]) if m else 0)
        self.heading_combo.blockSignals(False)
        self.pos_label.setText("  Ln %d, Col %d  " % (c.blockNumber() + 1, c.positionInBlock() + 1))

    # -- rendering ----------------------------------------------------------

    def _base_url(self):
        if self.source_url:
            return QUrl(self.source_url)
        if self.path:
            return QUrl.fromLocalFile(os.path.dirname(self.path) + os.sep)
        return QUrl.fromLocalFile(os.getcwd() + os.sep)

    def render_now(self):
        self.render_timer.stop()
        text = self.editor.toPlainText()
        self.preview.set_content(md_to_html(text), self._base_url())
        self.words_label.setText("  %d words  " % len(text.split()))

    # -- document / file handling -------------------------------------------

    def _display_name(self):
        if self.path:
            return os.path.basename(self.path)
        if self.source_url:
            return os.path.basename(urllib.parse.urlparse(self.source_url).path) or self.source_url
        return "Untitled"

    def _doc_title(self):
        m = re.search(r"^#\s+(.+?)\s*#*\s*$", self.editor.toPlainText(), re.MULTILINE)
        return m[1] if m else os.path.splitext(self._display_name())[0]

    def _update_title(self):
        self.setWindowTitle("%s[*] — %s" % (self._display_name(), APP_NAME))
        if self.path and self.source_url:
            self.source_label.setText("  %s  (from %s)" % (self.path, self.source_url))
        else:
            self.source_label.setText("  " + (self.path or self.source_url or "new document"))

    def _dialog_dir(self):
        return os.path.dirname(self.path) if self.path else os.getcwd()

    def _suggest_path(self, ext):
        if self.path:
            return os.path.splitext(self.path)[0] + ext
        name = "untitled"
        if self.source_url:
            name = os.path.splitext(os.path.basename(urllib.parse.urlparse(self.source_url).path))[0] or "document"
        return os.path.join(self._dialog_dir(), name + ext)

    def _set_document(self, text, path, url):
        self.path, self.source_url = path, url
        self.editor.setPlainText(text)
        self.editor.document().setModified(False)
        self.setWindowModified(False)
        self._update_title()
        self._on_cursor_moved()
        self.render_now()

    def load_source(self, source):
        if re.match(r"^https?://", source, re.IGNORECASE):
            self.load_url(source)
        else:
            self.load_path(source)

    def load_path(self, path):
        path = os.path.abspath(os.path.expanduser(path))
        text = ""
        if os.path.exists(path):
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    text = f.read()
            except OSError as e:
                QMessageBox.critical(self, "Open", "Cannot open %s:\n%s" % (path, e))
                return
        else:
            self.statusBar().showMessage("New file: %s" % path, 5000)
        self._set_document(text, path, None)

    def load_url(self, url):
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            final_url, text = fetch_url(url)
        except Exception as e:
            QApplication.restoreOverrideCursor()
            QMessageBox.critical(self, "Open URL", "Failed to fetch %s:\n%s" % (url, e))
            return
        QApplication.restoreOverrideCursor()
        self._set_document(text, None, final_url)
        self.statusBar().showMessage("Fetched %s — use Save to store it locally" % final_url, 8000)

    def new_file(self):
        if self.maybe_save():
            self._set_document("", None, None)

    def open_file_dialog(self):
        if not self.maybe_save():
            return
        path, _ = QFileDialog.getOpenFileName(self, "Open Markdown", self._dialog_dir(), MD_FILTER)
        if path:
            self.load_path(path)

    def open_url_dialog(self):
        if not self.maybe_save():
            return
        url, ok = QInputDialog.getText(self, "Open from URL", "Markdown URL (GitHub/GitLab page URLs work too):",
                                       QLineEdit.EchoMode.Normal, self.source_url or "https://")
        if ok and url.strip():
            self.load_url(url.strip())

    def _write_file(self, path, content):
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
        except OSError as e:
            QMessageBox.critical(self, "Save", "Cannot write %s:\n%s" % (path, e))
            return False
        return True

    def save(self):
        if not self.path:
            return self.save_as()
        if not self._write_file(self.path, self.editor.toPlainText()):
            return False
        self.editor.document().setModified(False)
        self.statusBar().showMessage("Saved %s" % self.path, 4000)
        return True

    def save_as(self):
        path, _ = QFileDialog.getSaveFileName(self, "Save Markdown", self._suggest_path(".md"), MD_FILTER)
        if not path:
            return False
        if not os.path.splitext(path)[1]:
            path += ".md"
        self.path = os.path.abspath(path)
        self._update_title()
        return self.save()

    def maybe_save(self):
        if not self.editor.document().isModified():
            return True
        btn = QMessageBox.StandardButton
        r = QMessageBox.question(self, "Unsaved changes",
                                 "Save changes to %s?" % self._display_name(),
                                 btn.Save | btn.Discard | btn.Cancel, btn.Save)
        if r == btn.Save:
            return self.save()
        return r == btn.Discard

    def export_html(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export HTML", self._suggest_path(".html"),
                                              "HTML (*.html *.htm);;All files (*)")
        if not path:
            return
        if not os.path.splitext(path)[1]:
            path += ".html"
        page = build_html(md_to_html(self.editor.toPlainText()), self._doc_title(), self.source_url,
                          self.preview_theme)
        if self._write_file(path, page):
            self.statusBar().showMessage("Exported %s" % path, 5000)

    def export_pdf(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export PDF", self._suggest_path(".pdf"),
                                              "PDF (*.pdf);;All files (*)")
        if not path:
            return
        if not os.path.splitext(path)[1]:
            path += ".pdf"
        self.render_now()
        self.statusBar().showMessage("Exporting %s…" % path)

        def done(ok):
            if ok:
                self.statusBar().showMessage("Exported %s" % path, 5000)
            else:
                self.statusBar().clearMessage()
                QMessageBox.critical(self, "Export PDF", "Failed to write %s" % path)
        self.preview.export_pdf(path, done)

    def closeEvent(self, e):
        if self.maybe_save():
            e.accept()
        else:
            e.ignore()


def main():
    parser = argparse.ArgumentParser(description="Markdown editor with live preview")
    parser.add_argument("source", nargs="?", help="markdown file path or http(s) URL to open")
    args = parser.parse_args()

    QApplication.setAttribute(Qt.ApplicationAttribute.AA_ShareOpenGLContexts)
    app = QApplication(sys.argv[:1])
    app.setApplicationName(APP_NAME)
    win = MainWindow()
    win.show()
    if args.source:
        QTimer.singleShot(0, lambda: win.load_source(args.source))
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
