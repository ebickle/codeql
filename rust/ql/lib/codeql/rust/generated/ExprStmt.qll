// generated by codegen
/**
 * This module provides the generated definition of `ExprStmt`.
 * INTERNAL: Do not import directly.
 */

private import codeql.rust.generated.Synth
private import codeql.rust.generated.Raw
import codeql.rust.elements.Expr
import codeql.rust.elements.Stmt

/**
 * INTERNAL: This module contains the fully generated definition of `ExprStmt` and should not
 * be referenced directly.
 */
module Generated {
  /**
   * An expression statement. For example:
   * ```
   * start();
   * finish()
   * use std::env;
   * ```
   * INTERNAL: Do not reference the `Generated::ExprStmt` class directly.
   * Use the subclass `ExprStmt`, where the following predicates are available.
   */
  class ExprStmt extends Synth::TExprStmt, Stmt {
    override string getAPrimaryQlClass() { result = "ExprStmt" }

    /**
     * Gets the expression of this expression statement.
     */
    Expr getExpr() {
      result =
        Synth::convertExprFromRaw(Synth::convertExprStmtToRaw(this).(Raw::ExprStmt).getExpr())
    }

    /**
     * Holds if this expression statement has semicolon.
     */
    predicate hasSemicolon() { Synth::convertExprStmtToRaw(this).(Raw::ExprStmt).hasSemicolon() }
  }
}
