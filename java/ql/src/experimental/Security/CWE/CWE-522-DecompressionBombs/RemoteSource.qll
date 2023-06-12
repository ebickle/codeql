import java
import semmle.code.java.dataflow.DataFlow

abstract class FormRemoteFlowSource extends DataFlow::Node { }

abstract class FileUploadRemoteFlowSource extends DataFlow::Node { }

class CommonsFileUploadAdditionalTaintStep extends Unit {
  abstract predicate step(DataFlow::Node n1, DataFlow::Node n2);
}

module ApacheCommonsFileUpload {
  module DangerousSink {
    class TypeDiskFileItemFactory extends RefType {
      TypeDiskFileItemFactory() {
        this.getAStrictAncestor*()
            .hasQualifiedName("org.apache.commons.fileupload.disk", "DiskFileItemFactory")
        or
        this.getAStrictAncestor*()
            .hasQualifiedName("org.apache.commons.fileupload", "FileItemFactory")
      }
    }

    abstract class FileWriteSink extends MethodAccess {
      abstract Expr getAPathArgument();
    }

    class FileItemWrite extends FileWriteSink {
      FileItemWrite() {
        this.getReceiverType() instanceof RemoteFlowSource::TypeFileUpload and
        this.getCallee().hasName(["write"])
      }

      override Expr getAPathArgument() { result = this.getArgument(0) }
    }

    class DiskFileItemFactoryCreateItem extends FileWriteSink {
      DiskFileItemFactoryCreateItem() {
        this.getReceiverType() instanceof TypeDiskFileItemFactory and
        this.getCallee().hasName(["createItem"])
      }

      override Expr getAPathArgument() { result = this.getArgument(3) }
    }

    class DiskFileItemFactorySetRepository extends FileWriteSink {
      DiskFileItemFactorySetRepository() {
        this.getReceiverType() instanceof TypeDiskFileItemFactory and
        this.getCallee().hasName(["setRepository"])
      }

      override Expr getAPathArgument() { result = this.getArgument(0) }
    }
  }

  module RemoteFlowSource {
    class TypeServletFileUpload extends RefType {
      TypeServletFileUpload() {
        this.hasQualifiedName("org.apache.commons.fileupload.servlet", "ServletFileUpload")
      }
    }

    class TypeFileUpload extends RefType {
      TypeFileUpload() {
        this.getAStrictAncestor*().hasQualifiedName("org.apache.commons.fileupload", "FileItem")
      }
    }

    class TypeFileItemStream extends RefType {
      TypeFileItemStream() {
        this.getAStrictAncestor*()
            .hasQualifiedName("org.apache.commons.fileupload", "FileItemStream")
      }
    }

    class ServletFileUpload extends FileUploadRemoteFlowSource {
      ServletFileUpload() {
        exists(MethodAccess ma |
          ma.getReceiverType() instanceof TypeServletFileUpload and
          ma.getCallee().hasName(["parseRequest"]) and
          this.asExpr() = ma
        )
      }
    }

    private class FileItemRemoteSource extends FileUploadRemoteFlowSource {
      FileItemRemoteSource() {
        exists(MethodAccess ma |
          ma.getReceiverType() instanceof TypeFileUpload and
          ma.getCallee()
              .hasName([
                  "getInputStream", "getFieldName", "getContentType", "get", "getName", "getString"
                ]) and
          this.asExpr() = ma
        )
      }
    }

    private class FileItemStreamRemoteSource extends FileUploadRemoteFlowSource {
      FileItemStreamRemoteSource() {
        exists(MethodAccess ma |
          ma.getReceiverType() instanceof TypeFileItemStream and
          ma.getCallee().hasName(["getContentType", "getFieldName", "getName", "openStream"]) and
          this.asExpr() = ma
        )
      }
    }
  }

  module Util {
    class TypeStreams extends RefType {
      TypeStreams() { this.hasQualifiedName("org.apache.commons.fileupload.util", "Streams") }
    }

    private class AsStringAdditionalTaintStep extends CommonsFileUploadAdditionalTaintStep {
      override predicate step(DataFlow::Node n1, DataFlow::Node n2) {
        exists(Call call |
          call.getCallee().getDeclaringType() instanceof TypeStreams and
          call.getArgument(0) = n1.asExpr() and
          call = n2.asExpr() and
          call.getCallee().hasName("asString")
        )
      }
    }

    private class CopyAdditionalTaintStep extends CommonsFileUploadAdditionalTaintStep {
      override predicate step(DataFlow::Node n1, DataFlow::Node n2) {
        exists(Call call |
          call.getCallee().getDeclaringType() instanceof TypeStreams and
          call.getArgument(0) = n1.asExpr() and
          call.getArgument(1) = n2.asExpr() and
          call.getCallee().hasName("copy")
        )
      }
    }
  }
}

module ServletRemoteMultiPartSources {
  class TypePart extends RefType {
    TypePart() { this.hasQualifiedName(["javax.servlet.http", "jakarta.servlet.http"], "Part") }
  }

  private class ServletPartCalls extends FormRemoteFlowSource {
    ServletPartCalls() {
      exists(MethodAccess ma |
        ma.getReceiverType() instanceof TypePart and
        ma.getCallee()
            .hasName([
                "getInputStream", "getName", "getContentType", "getHeader", "getHeaders",
                "getHeaderNames", "getSubmittedFileName", "write"
              ]) and
        this.asExpr() = ma
      )
    }
  }
}
