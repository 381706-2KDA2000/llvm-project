#include "llvm/Pass.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/IR/Constants.h"

#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"

using namespace llvm;

namespace {

struct Practice : public FunctionPass {
    static char ID;
    Practice() : FunctionPass(ID) {}

    bool runOnFunction(Function& function) override {
        errs() << "********** PRACTICE PEEPHOLE OPTIMIZER **********\n";
        errs() << "********** Function: " << function.getName() << '\n';

        bool changed = false;
        for (inst_iterator ii = inst_begin(function), ie = inst_end(function); ii != ie;) {
            auto instruction = &*ii;
            ++ii;

            if (!isTrivialDiv(instruction)) {
                continue;
            }

            if (!instruction->use_empty()) {
                replaceWithArgument(instruction);
            }

            instruction->eraseFromParent();
            changed = true;

        }

        return changed;
    }

private:
    bool isTrivialDiv(Instruction const* instruction) const {
        return isBinaryDiv(instruction) && isTrivial(instruction);
    }

    bool isBinaryDiv(Instruction const* instruction) const {
        return (instruction->getOpcode() == Instruction::SDiv || instruction->getOpcode() == Instruction::UDiv) && instruction->getNumOperands() == 2;
    }

    bool isTrivial(Instruction const* instruction) const {
        auto const& rhs = instruction->getOperand(1);;
        return isOne(rhs);
    }

    bool isOne(Value const* operand) const {
        auto const constant = dyn_cast<ConstantInt>(operand);
        return constant && constant->isOne();
    }

    void replaceWithArgument(Instruction* instruction) const {
        auto const& rhs = instruction->getOperand(1);
        instruction->replaceAllUsesWith(rhs);
    }
};

}

char Practice::ID = 0;
static RegisterPass<Practice> X(
    "practice",
    "Practice Peephole Optimization Pass",
    false,
    false
);

static RegisterStandardPasses Y(
    PassManagerBuilder::EP_EarlyAsPossible,
    [](const PassManagerBuilder& builder, legacy::PassManagerBase& manager) { manager.add(new Practice()); }
);
