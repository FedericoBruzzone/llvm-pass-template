//==============================================================================
// FILE:
//    FunctionCounter.cpp
//
// DESCRIPTION:
//    Counts the number of functions in the input module.
//
//    This pass is used in `func-count`, a tool implemented in
//    tools/FuncCountMain.cpp that is a wrapper around FunctionCounter.
//    `func-count` allows you to run FunctionCounter without `opt`.
//
// USAGE:
//      opt -load-pass-plugin libFunctionCounter.dylib `\`
//        -passes="print<function-counter>" `\`
//        -disable-output <input-llvm-file>
//==============================================================================
#include "FunctionCounter.h"

#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/Debug.h"
#include <llvm/Support/raw_ostream.h>

#define DEBUG_TYPE "function-counter"

using namespace llvm;

// Pretty-prints the result of this analysis
static void printFunctionCounterResult(llvm::raw_ostream &OutS,
                                       const ResultFunctionCounter &Functions,
                                       const StringRef ModuleName);

//------------------------------------------------------------------------------
// FunctionCounter Implementation
//------------------------------------------------------------------------------
FunctionCounter::Result FunctionCounter::runOnModule(Module &M) {
  FunctionCounter::Result Res{};
  Res.value = M.size();
  return Res;
}

FunctionCounter::Result FunctionCounter::run(llvm::Module &M,
                                             llvm::ModuleAnalysisManager &) {
  return runOnModule(M);
}

PreservedAnalyses FunctionCounterPrinter::run(Module &M,
                                              ModuleAnalysisManager &MAM) {

  auto Functions = MAM.getResult<FunctionCounter>(M);
  printFunctionCounterResult(OS, Functions, M.getName());
  return PreservedAnalyses::all();
}

//------------------------------------------------------------------------------
// New PM Registration
//------------------------------------------------------------------------------
AnalysisKey FunctionCounter::Key;

llvm::PassPluginLibraryInfo getFunctionCounterPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "function-counter", LLVM_VERSION_STRING,
          [](PassBuilder &PB) {
            // #1 REGISTRATION FOR "opt -passes=print<function-counter>"
            PB.registerPipelineParsingCallback(
                [&](StringRef Name, ModulePassManager &MPM,
                    ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "print<function-counter>") {
                    MPM.addPass(FunctionCounterPrinter(llvm::errs()));
                    return true;
                  }
                  return false;
                });
            // #2 REGISTRATION FOR "MAM.getResult<FunctionCounter>(Module)"
            PB.registerAnalysisRegistrationCallback(
                [](ModuleAnalysisManager &MAM) {
                  MAM.registerPass([&] { return FunctionCounter(); });
                });
          }};
};

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getFunctionCounterPluginInfo();
}

//------------------------------------------------------------------------------
// Helper functions
//------------------------------------------------------------------------------
static void printFunctionCounterResult(raw_ostream &OutS,
                                       const ResultFunctionCounter &Functions,
                                       const StringRef ModuleName) {

  // The following is visible only if you pass -debug on the command line
  // and you have an assert build.
  // errs() is an alternative to dbgs()
  LLVM_DEBUG(dbgs() << "===== DEBUG EXAMPLE =====\n");

  OutS << "================================================="
       << "\n";
  OutS << "Function Counter analysis results\n";
  OutS << "=================================================\n";
  const char *str1 = "NAME";
  const char *str2 = "#N FUNCTIONS";
  const char *ModuleNameS = ModuleName.data();
  OutS << format("%-30s %-10s\n", str1, str2);
  OutS << "-------------------------------------------------"
       << "\n";
  OutS << format("%-30s %-10lu\n", ModuleNameS, Functions.value);
  OutS << "-------------------------------------------------"
       << "\n\n";
}
