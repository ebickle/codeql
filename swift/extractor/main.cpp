#include <fstream>
#include <iomanip>
#include <stdlib.h>
#include <vector>
#include <iostream>
#include <regex>
#include <unistd.h>
#include <chrono>

#include <swift/Basic/LLVMInitialize.h>
#include <swift/FrontendTool/FrontendTool.h>

#include "swift/extractor/SwiftExtractor.h"
#include "swift/extractor/TargetTrapFile.h"
#include "swift/extractor/remapping/SwiftFileInterception.h"
#include "swift/extractor/invocation/SwiftDiagnosticsConsumer.h"
#include "swift/extractor/trap/TrapDomain.h"
#include <swift/Basic/InitializeSwiftModules.h>

using namespace std::string_literals;

static void lockOutputSwiftModuleTraps(const codeql::SwiftExtractorConfiguration& config,
                                       const swift::CompilerInstance& compiler) {
  std::filesystem::path output = compiler.getInvocation().getOutputFilename();
  if (output.extension() == ".swiftmodule") {
    if (auto target = codeql::createTargetTrapFile(config, output)) {
      *target << "// trap file deliberately empty\n"
                 "// this swiftmodule was created during the build, so its entities must have"
                 " been extracted directly from source files";
    }
  }
}

static void processFrontendOptions(swift::FrontendOptions& options) {
  using Action = swift::FrontendOptions::ActionType;
  switch (options.RequestedAction) {
    case Action::EmitModuleOnly:
    case Action::MergeModules:
    case Action::CompileModuleFromInterface:
      // for module emission actions, we redirect the output to our internal artifact storage
      {
        swift::SupplementaryOutputPaths paths;
        paths.ModuleOutputPath =
            codeql::redirect(options.InputsAndOutputs.getSingleOutputFilename()).string();
        options.InputsAndOutputs.setMainAndSupplementaryOutputs(std::vector{paths.ModuleOutputPath},
                                                                std::vector{paths});
        return;
      }
    case Action::EmitObject:
      // for object emission, we do a type check pass instead, muting output but getting the sema
      // phase to run in order to extract everything
      options.RequestedAction = Action::Typecheck;
      return;
    case Action::PrintVersion:
    case Action::DumpAST:
    case Action::PrintAST:
    case Action::PrintASTDecl:
      // these actions are nice to have on the extractor for debugging, so we preserve them. Also,
      // version printing is used by CI to match up the correct compiler version
      return;
    default:
      // otherwise, we have nothing to do
      std::cerr << "Frontend action requires no action from extractor, exiting\n";
      std::exit(0);
  }
}

// This is part of the swiftFrontendTool interface, we hook into the
// compilation pipeline and extract files after the Swift frontend performed
// semantic analysis
class Observer : public swift::FrontendObserver {
 public:
  explicit Observer(const codeql::SwiftExtractorConfiguration& config,
                    codeql::SwiftDiagnosticsConsumer& diagConsumer)
      : config{config}, diagConsumer{diagConsumer} {}

  void parsedArgs(swift::CompilerInvocation& invocation) override {
    processFrontendOptions(invocation.getFrontendOptions());
  }

  void configuredCompiler(swift::CompilerInstance& instance) override {
    instance.addDiagnosticConsumer(&diagConsumer);
    lockOutputSwiftModuleTraps(config, instance);
  }

  void performedSemanticAnalysis(swift::CompilerInstance& compiler) override {
    codeql::extractSwiftFiles(config, compiler);
  }

 private:
  const codeql::SwiftExtractorConfiguration& config;
  codeql::SwiftDiagnosticsConsumer& diagConsumer;
};

static std::string getenv_or(const char* envvar, const std::string& def) {
  if (const char* var = getenv(envvar)) {
    return var;
  }
  return def;
}

static bool checkRunUnderFilter(int argc, char* const* argv) {
  auto runUnderFilter = getenv("CODEQL_EXTRACTOR_SWIFT_RUN_UNDER_FILTER");
  if (runUnderFilter == nullptr) {
    return true;
  }
  std::string call = argv[0];
  for (auto i = 1; i < argc; ++i) {
    call += ' ';
    call += argv[i];
  }
  std::regex filter{runUnderFilter, std::regex_constants::basic | std::regex_constants::nosubs};
  return std::regex_search(call, filter);
}

// if `CODEQL_EXTRACTOR_SWIFT_RUN_UNDER` env variable is set, and either
// * `CODEQL_EXTRACTOR_SWIFT_RUN_UNDER_FILTER` is not set, or
// * it is set to a regexp matching any substring of the extractor call
// then the running process is substituted with the command (and possibly
// options) stated in `CODEQL_EXTRACTOR_SWIFT_RUN_UNDER`, followed by `argv`.
// Before calling `exec`, `CODEQL_EXTRACTOR_SWIFT_RUN_UNDER` is unset to avoid
// unpleasant loops.
// An example usage is to run the extractor under `gdbserver :1234` when the
// arguments match a given source file.
static void checkWhetherToRunUnderTool(int argc, char* const* argv) {
  assert(argc > 0);

  auto runUnder = getenv("CODEQL_EXTRACTOR_SWIFT_RUN_UNDER");
  if (runUnder == nullptr || !checkRunUnderFilter(argc, argv)) {
    return;
  }
  std::vector<char*> args;
  // split RUN_UNDER value by spaces to get args vector
  for (auto word = std::strtok(runUnder, " "); word != nullptr; word = std::strtok(nullptr, " ")) {
    args.push_back(word);
  }
  // append process args, including extractor executable path
  args.insert(args.end(), argv, argv + argc);
  args.push_back(nullptr);
  // avoid looping on this function
  unsetenv("CODEQL_EXTRACTOR_SWIFT_RUN_UNDER");
  execvp(args[0], args.data());
}

// Creates a target file that should store per-invocation info, e.g. compilation args,
// compilations, diagnostics, etc.
codeql::TargetFile invocationTargetFile(const codeql::SwiftExtractorConfiguration& configuration) {
  auto timestamp = std::chrono::system_clock::now().time_since_epoch().count();
  auto filename = std::to_string(timestamp) + '-' + std::to_string(getpid());
  auto target = std::filesystem::path("invocations") / std::filesystem::path(filename);
  auto maybeFile = codeql::createTargetTrapFile(configuration, target);
  if (!maybeFile) {
    std::cerr << "Cannot create invocation trap file: " << target << "\n";
    abort();
  }
  return std::move(maybeFile.value());
}

codeql::SwiftExtractorConfiguration configure(int argc, char** argv) {
  codeql::SwiftExtractorConfiguration configuration{};
  configuration.trapDir = getenv_or("CODEQL_EXTRACTOR_SWIFT_TRAP_DIR", ".");
  configuration.sourceArchiveDir = getenv_or("CODEQL_EXTRACTOR_SWIFT_SOURCE_ARCHIVE_DIR", ".");
  configuration.scratchDir = getenv_or("CODEQL_EXTRACTOR_SWIFT_SCRATCH_DIR", ".");
  configuration.frontendOptions.assign(argv + 1, argv + argc);
  return configuration;
}

int main(int argc, char** argv) {
  checkWhetherToRunUnderTool(argc, argv);

  if (argc == 1) {
    // TODO: print usage
    return 1;
  }

  // Required by Swift/LLVM
  PROGRAM_START(argc, argv);
  INITIALIZE_LLVM();
  initializeSwiftModules();

  const auto configuration = configure(argc, argv);

  auto openInterception = codeql::setupFileInterception(configuration.getTempArtifactDir());

  auto invocationTrapFile = invocationTargetFile(configuration);
  codeql::TrapDomain invocationDomain(invocationTrapFile);
  codeql::SwiftDiagnosticsConsumer diagConsumer(invocationDomain);
  Observer observer(configuration, diagConsumer);
  int frontend_rc = swift::performFrontend(configuration.frontendOptions, "swift-extractor",
                                           (void*)main, &observer);

  return frontend_rc;
}
