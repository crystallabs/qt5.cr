// QValidator::validate and fixup take the input by non-const reference, so
// the validator can change it.  QString maps to the Crystal String, passed by
// value, which bindgen can't pass that way: these take a copy instead.  See
// `Qt::Validator#validate` and `#fixup` in src/qt5/validator.cr.
#include <QtGui/QValidator>

QValidator::State qt5cr_validator_validate(const QValidator *validator, const QString &input, int pos) {
  QString copy = input;
  return validator->validate(copy, pos);
}

QString qt5cr_validator_fixup(const QValidator *validator, const QString &input) {
  QString copy = input;
  validator->fixup(copy);
  return copy;
}
