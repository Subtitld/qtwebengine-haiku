// Smoke test: load HTML in a QWebEngineView, grab it to a PNG.
#include <QApplication>
#include <QTimer>
#include <QWebEnginePage>
#include <QWebEngineSettings>
#include <QImage>
#include <QWebEngineView>
#include <cstdio>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    const QString out = argc > 1 ? QString::fromLocal8Bit(argv[1]) : QStringLiteral("out.png");
    QWebEngineView view;
    view.resize(640, 240);
    view.page()->setBackgroundColor(Qt::transparent);
    view.setAttribute(Qt::WA_DontShowOnScreen);
    view.setAttribute(Qt::WA_TranslucentBackground);
    auto *st = view.page()->settings();
    std::printf("fonts standard=%s sans=%s serif=%s fixed=%s\n",
                qPrintable(st->fontFamily(QWebEngineSettings::StandardFont)),
                qPrintable(st->fontFamily(QWebEngineSettings::SansSerifFont)),
                qPrintable(st->fontFamily(QWebEngineSettings::SerifFont)),
                qPrintable(st->fontFamily(QWebEngineSettings::FixedFont)));
    QObject::connect(view.page(), &QWebEnginePage::loadFinished, [&](bool ok) {
        std::printf("loadFinished %d\n", ok);
        std::fflush(stdout);
        QTimer::singleShot(2000, [&] {
            view.page()->runJavaScript("var r=document.querySelector('p').getBoundingClientRect();"
                                     "innerWidth+'x'+innerHeight+' dpr '+devicePixelRatio+' p '+r.left+','+r.top+' '+r.width+'x'+r.height+"
                                     "' ta '+getComputedStyle(document.querySelector('p')).textAlign+' ff '+getComputedStyle(document.querySelector('p')).fontFamily+' disp '+getComputedStyle(document.querySelector('p')).display+' body '+getComputedStyle(document.body).display+' head '+getComputedStyle(document.head).display", [&](const QVariant &v) {
                std::printf("js: %s\n", qPrintable(v.toString()));
                const QImage img = view.grab().toImage();
                std::printf("image format %d alpha %d corner alpha %d\n", int(img.format()), img.hasAlphaChannel(), qAlpha(img.pixel(2, 2)));
                const bool saved = img.save(out);
                std::printf("grab saved %d to %s\n", saved, qPrintable(out));
                std::fflush(stdout);
                app.exit(saved ? 0 : 2);
            });
        });
    });
    QTimer::singleShot(120000, [&] { std::printf("timeout\n"); app.exit(3); });
    view.setHtml(QStringLiteral(
        "<html><body style='margin:0;background:transparent'>"
        "<p style='font:bold 48px sans-serif;color:#ffd200;text-shadow:2px 2px 0 #000;"
        "text-align:center;margin-top:80px'>Hello from Haiku</p></body></html>"));
    view.show();
    return app.exec();
}
