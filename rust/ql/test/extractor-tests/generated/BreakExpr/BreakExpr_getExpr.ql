// generated by codegen
import codeql.rust.elements
import TestUtils

from BreakExpr x
where toBeTested(x) and not x.isUnknown()
select x, x.getExpr()
