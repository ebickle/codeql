#include "swift/extractor/visitors/PatternVisitor.h"

namespace codeql {

codeql::NamedPattern PatternVisitor::translateNamedPattern(const swift::NamedPattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  // TODO: in some (but not all) cases, this seems to introduce a duplicate entry
  // for example the vars listed in a case stmt have a different pointer than then ones in
  // patterns.
  //  assert(pattern.getDecl() && "expect NamedPattern to have Decl");
  //  dispatcher_.emit(NamedPatternsTrap{label, pattern.getNameStr().str(),
  //                                       dispatcher_.fetchLabel(pattern.getDecl())});
  entry.name = pattern.getNameStr().str();
  return entry;
}

codeql::TypedPattern PatternVisitor::translateTypedPattern(const swift::TypedPattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  entry.sub_pattern = dispatcher_.fetchLabel(pattern.getSubPattern());
  entry.type_repr = dispatcher_.fetchOptionalLabel(pattern.getTypeRepr(), pattern.getType());
  return entry;
}

codeql::TuplePattern PatternVisitor::translateTuplePattern(const swift::TuplePattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  for (const auto& p : pattern.getElements()) {
    entry.elements.push_back(dispatcher_.fetchLabel(p.getPattern()));
  }
  return entry;
}
codeql::AnyPattern PatternVisitor::translateAnyPattern(const swift::AnyPattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  return entry;
}

codeql::BindingPattern PatternVisitor::translateBindingPattern(
    const swift::BindingPattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  entry.sub_pattern = dispatcher_.fetchLabel(pattern.getSubPattern());
  return entry;
}

codeql::EnumElementPattern PatternVisitor::translateEnumElementPattern(
    const swift::EnumElementPattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  entry.element = dispatcher_.fetchLabel(pattern.getElementDecl());
  entry.sub_pattern = dispatcher_.fetchOptionalLabel(pattern.getSubPattern());
  return entry;
}

codeql::OptionalSomePattern PatternVisitor::translateOptionalSomePattern(
    const swift::OptionalSomePattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  entry.sub_pattern = dispatcher_.fetchLabel(pattern.getSubPattern());
  return entry;
}

codeql::IsPattern PatternVisitor::translateIsPattern(const swift::IsPattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  entry.cast_type_repr =
      dispatcher_.fetchOptionalLabel(pattern.getCastTypeRepr(), pattern.getCastType());
  entry.sub_pattern = dispatcher_.fetchOptionalLabel(pattern.getSubPattern());
  return entry;
}

codeql::ExprPattern PatternVisitor::translateExprPattern(const swift::ExprPattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  entry.sub_expr = dispatcher_.fetchLabel(pattern.getSubExpr());
  return entry;
}

codeql::ParenPattern PatternVisitor::translateParenPattern(const swift::ParenPattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  entry.sub_pattern = dispatcher_.fetchLabel(pattern.getSubPattern());
  return entry;
}

codeql::BoolPattern PatternVisitor::translateBoolPattern(const swift::BoolPattern& pattern) {
  auto entry = dispatcher_.createEntry(pattern);
  entry.value = pattern.getValue();
  return entry;
}

}  // namespace codeql
