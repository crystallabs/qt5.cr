// QItemEditorCreatorBase is abstract and declares no constructor, and bindgen
// adds none to an abstract class (std::is_default_constructible is false for
// it), so a Crystal subclass couldn't be created.  This concrete base, wrapped
// as `Qt::ItemEditorCreator`, is what a Crystal creator derives from: override
// `create_widget` and `value_property_name`, and register it with
// `Qt::ItemEditorFactory#register_editor`.
#include <QtWidgets/QItemEditorFactory>

class Qt5crItemEditorCreator : public QItemEditorCreatorBase {
public:
  Qt5crItemEditorCreator() {}
  QWidget *createWidget(QWidget *) const override { return nullptr; }
  QByteArray valuePropertyName() const override { return QByteArray(); }
};
