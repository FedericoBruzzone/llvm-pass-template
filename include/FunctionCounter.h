//========================================================================
// FILE:
//    FunctionCounter.h
//
// DESCRIPTION:
//    Declares the FunctionCounter Passes
//      * new pass manager interface
//      * legacy pass manager interface
//      * printer pass for the new pass manager
//========================================================================
#ifndef FUNCTIONCOUNTER_H
#define FUNCTIONCOUNTER_H

#include "llvm/IR/Module.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Pass.h"
#include "llvm/Support/raw_ostream.h"

//------------------------------------------------------------------------------
// New PM interface
//------------------------------------------------------------------------------
// A struct is needed because using 'using ResultFunctionCounter = size_t;' causes problems.
struct MySizeT {
    size_t value;
};

using ResultFunctionCounter = MySizeT;

struct FunctionCounter : public llvm::AnalysisInfoMixin<FunctionCounter> {
  using Result = ResultFunctionCounter;
  Result run(llvm::Module &M, llvm::ModuleAnalysisManager &);
  Result runOnModule(llvm::Module &M);
  // Part of the official API:
  //  https://llvm.org/docs/WritingAnLLVMNewPMPass.html#required-passes
  static bool isRequired() { return true; }

private:
  // A special type used by analysis passes to provide an address that
  // identifies that particular analysis pass type.
  static llvm::AnalysisKey Key;
  friend struct llvm::AnalysisInfoMixin<FunctionCounter>;
};

//------------------------------------------------------------------------------
// New PM interface for the printer pass
//------------------------------------------------------------------------------
class FunctionCounterPrinter
    : public llvm::PassInfoMixin<FunctionCounterPrinter> {
public:
  explicit FunctionCounterPrinter(llvm::raw_ostream &OutS) : OS(OutS) {}
  llvm::PreservedAnalyses run(llvm::Module &M,
                              llvm::ModuleAnalysisManager &MAM);
  // Part of the official API:
  //  https://llvm.org/docs/WritingAnLLVMNewPMPass.html#required-passes
  static bool isRequired() { return true; }

private:
  llvm::raw_ostream &OS;
};

#endif // FUNCTIONCOUNTER_H
