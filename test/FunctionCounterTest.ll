; RUN:  opt -load-pass-plugin %shlibdir/libFunctionCounter%shlibext -passes="print<function-counter>" -disable-output %s 2>&1 | FileCheck %s

; Makes sure that the functions are counted correctly.

; CHECK-NOT: foo
; CHECK-NOT: bar

; CHECK:      =================================================
; CHECK-NEXT: Function Counter analysis results
; CHECK-NEXT: =================================================
; CHECK-NEXT: NAME                           #N FUNCTIONS
; CHECK-NEXT: -------------------------------------------------
; CHECK-NEXT: test/FunctionCounterTest.ll    2
; CHECK-NEXT: -------------------------------------------------

define i32 @foo(i32) {
  ret i32 %0
}

define i32 @bar(i32) {
  ret i32 %0
}
