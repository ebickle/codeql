/**
 * Provides Ruby specific classes and predicates for defining flow summaries.
 */

private import ruby
private import DataFlowDispatch
private import DataFlowPrivate
private import DataFlowPublic
private import DataFlowImplCommon
private import FlowSummaryImpl::Private
private import FlowSummaryImpl::Public
private import codeql.ruby.dataflow.FlowSummary as FlowSummary

/** Gets the parameter position of the instance parameter. */
ArgumentPosition instanceParameterPosition() { none() } // disables implicit summary flow to `self` for callbacks

/** Gets the synthesized summary data-flow node for the given values. */
Node summaryNode(SummarizedCallable c, SummaryNodeState state) { result = TSummaryNode(c, state) }

/** Gets the synthesized data-flow call for `receiver`. */
SummaryCall summaryDataFlowCall(Node receiver) { receiver = result.getReceiver() }

/** Gets the type of content `c`. */
DataFlowType getContentType(ContentSet c) { any() }

/** Gets the return type of kind `rk` for callable `c`. */
bindingset[c, rk]
DataFlowType getReturnType(SummarizedCallable c, ReturnKind rk) { any() }

/**
 * Gets the type of the `i`th parameter in a synthesized call that targets a
 * callback of type `t`.
 */
bindingset[t, pos]
DataFlowType getCallbackParameterType(DataFlowType t, ArgumentPosition pos) { any() }

/**
 * Gets the return type of kind `rk` in a synthesized call that targets a
 * callback of type `t`.
 */
DataFlowType getCallbackReturnType(DataFlowType t, ReturnKind rk) { any() }

/**
 * Holds if an external flow summary exists for `c` with input specification
 * `input`, output specification `output`, and kind `kind`.
 */
predicate summaryElement(DataFlowCallable c, string input, string output, string kind) {
  exists(FlowSummary::SummarizedCallable sc, boolean preservesValue |
    sc.propagatesFlowExt(input, output, preservesValue) and
    c.asLibraryCallable() = sc and
    if preservesValue = true then kind = "value" else kind = "taint"
  )
}

/**
 * Gets the summary component for specification component `c`, if any.
 *
 * This covers all the Ruby-specific components of a flow summary.
 */
bindingset[c]
SummaryComponent interpretComponentSpecific(AccessPathToken c) {
  c = "Argument[_]" and
  result = FlowSummary::SummaryComponent::argument(any(ParameterPosition pos | pos.isPositional(_)))
  or
  c = "ArrayElement" and
  result = FlowSummary::SummaryComponent::arrayElementAny()
  or
  c = "ArrayElement[?]" and
  result = FlowSummary::SummaryComponent::arrayElementUnknown()
  or
  exists(int i |
    c.getName() = "ArrayElement" and
    i = AccessPath::parseInt(c.getAnArgument()) and
    result = FlowSummary::SummaryComponent::arrayElementKnown(i)
  )
}

/** Gets the textual representation of a summary component in the format used for flow summaries. */
string getComponentSpecificCsv(SummaryComponent sc) { none() }

/** Gets the textual representation of a parameter position in the format used for flow summaries. */
string getParameterPositionCsv(ParameterPosition pos) {
  pos.isSelf() and result = "self"
  or
  pos.isBlock() and result = "block"
  or
  exists(int i |
    pos.isPositional(i) and
    result = i.toString()
  )
  or
  exists(string name |
    pos.isKeyword(name) and
    result = name + ":"
  )
}

/** Gets the textual representation of an argument position in the format used for flow summaries. */
string getArgumentPositionCsv(ArgumentPosition pos) {
  pos.isSelf() and result = "self"
  or
  pos.isBlock() and result = "block"
  or
  exists(int i |
    pos.isPositional(i) and
    result = i.toString()
  )
  or
  exists(string name |
    pos.isKeyword(name) and
    result = name + ":"
  )
}

/** Holds if input specification component `c` needs a reference. */
predicate inputNeedsReferenceSpecific(string c) { none() }

/** Holds if output specification component `c` needs a reference. */
predicate outputNeedsReferenceSpecific(string c) { none() }

/** Gets the return kind corresponding to specification `"ReturnValue"`. */
NormalReturnKind getReturnValueKind() { any() }

/**
 * All definitions in this module are required by the shared implementation
 * (for source/sink interpretation), but they are unused for Ruby, where
 * we rely on API graphs instead.
 */
private module UnusedSourceSinkInterpretation {
  /**
   * Holds if an external source specification exists for `e` with output specification
   * `output` and kind `kind`.
   */
  predicate sourceElement(AstNode n, string output, string kind) { none() }

  /**
   * Holds if an external sink specification exists for `n` with input specification
   * `input` and kind `kind`.
   */
  predicate sinkElement(AstNode n, string input, string kind) { none() }

  class SourceOrSinkElement = AstNode;

  /** An entity used to interpret a source/sink specification. */
  class InterpretNode extends AstNode {
    /** Gets the element that this node corresponds to, if any. */
    SourceOrSinkElement asElement() { none() }

    /** Gets the data-flow node that this node corresponds to, if any. */
    Node asNode() { none() }

    /** Gets the call that this node corresponds to, if any. */
    DataFlowCall asCall() { none() }

    /** Gets the callable that this node corresponds to, if any. */
    DataFlowCallable asCallable() { none() }

    /** Gets the target of this call, if any. */
    Callable getCallTarget() { none() }
  }

  /** Provides additional sink specification logic. */
  predicate interpretOutputSpecific(string c, InterpretNode mid, InterpretNode node) { none() }

  /** Provides additional source specification logic. */
  predicate interpretInputSpecific(string c, InterpretNode mid, InterpretNode node) { none() }
}

import UnusedSourceSinkInterpretation

module ParsePositions {
  private import FlowSummaryImpl

  private predicate isParamBody(string body) {
    exists(AccessPathToken tok |
      tok.getName() = "Parameter" and
      body = tok.getAnArgument()
    )
  }

  private predicate isArgBody(string body) {
    exists(AccessPathToken tok |
      tok.getName() = "Argument" and
      body = tok.getAnArgument()
    )
  }

  predicate isParsedParameterPosition(string c, int i) {
    isParamBody(c) and
    i = AccessPath::parseInt(c)
  }

  predicate isParsedArgumentPosition(string c, int i) {
    isArgBody(c) and
    i = AccessPath::parseInt(c)
  }

  predicate isParsedKeywordParameterPosition(string c, string paramName) {
    isParamBody(c) and
    c = paramName + ":"
  }

  predicate isParsedKeywordArgumentPosition(string c, string paramName) {
    isArgBody(c) and
    c = paramName + ":"
  }
}

/** Gets the argument position obtained by parsing `X` in `Parameter[X]`. */
ArgumentPosition parseParamBody(string s) {
  exists(int i |
    ParsePositions::isParsedParameterPosition(s, i) and
    result.isPositional(i)
  )
  or
  exists(string name |
    ParsePositions::isParsedKeywordParameterPosition(s, name) and
    result.isKeyword(name)
  )
  or
  s = "self" and
  result.isSelf()
  or
  s = "block" and
  result.isBlock()
}

/** Gets the parameter position obtained by parsing `X` in `Argument[X]`. */
ParameterPosition parseArgBody(string s) {
  exists(int i |
    ParsePositions::isParsedArgumentPosition(s, i) and
    result.isPositional(i)
  )
  or
  exists(string name |
    ParsePositions::isParsedKeywordArgumentPosition(s, name) and
    result.isKeyword(name)
  )
  or
  s = "self" and
  result.isSelf()
  or
  s = "block" and
  result.isBlock()
}
