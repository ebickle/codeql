// generated by codegen
import codeql.rust.elements
import TestUtils

from LetStmt x
where toBeTested(x) and not x.isUnknown()
select x, x.getType()
