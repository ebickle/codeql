// generated by codegen
import codeql.rust.elements
import TestUtils

from UnderscoreExpr x
where toBeTested(x) and not x.isUnknown()
select x
