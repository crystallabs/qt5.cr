// bindgen renders the `bool *invertible = nullptr` default of
// QTransform::inverted, QMatrix::inverted and QMatrix4x4::inverted as
// `Bool*? = true`, which Crystal rejects on a call using the default, so the
// methods are dropped and these are called instead.  See `Qt::Transform#inverted`
// in src/qt5/transform.cr.
#include <QtGui/QMatrix>
#include <QtGui/QMatrix4x4>
#include <QtGui/QTransform>

QTransform qt5cr_transform_inverted(const QTransform &transform, bool *invertible) {
  return transform.inverted(invertible);
}

QMatrix qt5cr_matrix_inverted(const QMatrix &matrix, bool *invertible) {
  return matrix.inverted(invertible);
}

QMatrix4x4 qt5cr_matrix4x4_inverted(const QMatrix4x4 &matrix, bool *invertible) {
  return matrix.inverted(invertible);
}
