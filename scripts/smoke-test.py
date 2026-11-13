"""Smoke test for the PySide6 bindings: smoke-test.cpp in Python.

Loads HTML in a QWebEngineView on the offscreen platform, runs JavaScript,
grabs the view to a PNG with a transparent background. Exit code 0 when the
image is saved.
"""
import os
import sys

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
flags = os.environ.get('QTWEBENGINE_CHROMIUM_FLAGS', '')
for flag in ('--disable-gpu', '--no-sandbox'):
    if flag not in flags:
        flags = (flags + ' ' + flag).strip()
os.environ['QTWEBENGINE_CHROMIUM_FLAGS'] = flags

from PySide6 import QtWebEngineWidgets  # noqa: F401  (before the application)
from PySide6.QtCore import QTimer, Qt
from PySide6.QtGui import qAlpha
from PySide6.QtWebEngineCore import QWebEngineSettings
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtWidgets import QApplication

out = sys.argv[1] if len(sys.argv) > 1 else 'out.png'
app = QApplication(sys.argv[:1])
view = QWebEngineView()
view.resize(640, 240)
view.page().setBackgroundColor(Qt.transparent)
view.setAttribute(Qt.WA_DontShowOnScreen)
view.setAttribute(Qt.WA_TranslucentBackground)
settings = view.page().settings()
print('fonts standard={} sans={} serif={} fixed={}'.format(
    *(settings.fontFamily(f) for f in (QWebEngineSettings.StandardFont, QWebEngineSettings.SansSerifFont,
                                       QWebEngineSettings.SerifFont, QWebEngineSettings.FixedFont))), flush=True)

JS = ("var p=document.querySelector('p'), r=p.getBoundingClientRect(), s=getComputedStyle(p);"
      "innerWidth+'x'+innerHeight+' p '+r.left+','+r.top+' '+r.width+'x'+r.height+' ff '+s.fontFamily+' disp '+s.display")


def grab(result):
    print('js:', result, flush=True)
    image = view.grab().toImage()
    print('image format', int(image.format().value), 'alpha', image.hasAlphaChannel(),
          'corner alpha', qAlpha(image.pixel(2, 2)), flush=True)
    saved = image.save(out)
    print('grab saved', saved, 'to', out, flush=True)
    app.exit(0 if saved else 2)


def loaded(ok):
    print('loadFinished', ok, flush=True)
    QTimer.singleShot(2000, lambda: view.page().runJavaScript(JS, 0, grab))


view.page().loadFinished.connect(loaded)
QTimer.singleShot(120000, lambda: (print('timeout', flush=True), app.exit(3)))
view.setHtml("<html><body style='margin:0;background:transparent'>"
             "<p style='font:bold 48px sans-serif;color:#ffd200;text-shadow:2px 2px 0 #000;"
             "text-align:center;margin-top:80px'>Hello from Haiku</p></body></html>")
view.show()
sys.exit(app.exec())
