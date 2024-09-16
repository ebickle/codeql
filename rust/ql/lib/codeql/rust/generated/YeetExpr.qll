// generated by codegen
/**
 * This module provides the generated definition of `YeetExpr`.
 * INTERNAL: Do not import directly.
 */

private import codeql.rust.generated.Synth
private import codeql.rust.generated.Raw
import codeql.rust.elements.Expr

/**
 * INTERNAL: This module contains the fully generated definition of `YeetExpr` and should not
 * be referenced directly.
 */
module Generated {
  /**
   * A `yeet` expression. For example:
   * ```
   * if x < size {
   *    do yeet "index out of bounds";
   * }
   * ```
   * INTERNAL: Do not reference the `Generated::YeetExpr` class directly.
   * Use the subclass `YeetExpr`, where the following predicates are available.
   */
  class YeetExpr extends Synth::TYeetExpr, Expr {
    override string getAPrimaryQlClass() { result = "YeetExpr" }

    /**
     * Gets the expression of this yeet expression, if it exists.
     */
    Expr getExpr() {
      result =
        Synth::convertExprFromRaw(Synth::convertYeetExprToRaw(this).(Raw::YeetExpr).getExpr())
    }

    /**
     * Holds if `getExpr()` exists.
     */
    final predicate hasExpr() { exists(this.getExpr()) }
  }
}
