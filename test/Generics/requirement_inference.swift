// RUN: %target-typecheck-verify-swift -typecheck %s -verify
// RUN: %target-typecheck-verify-swift -typecheck -debug-generic-signatures %s > %t.dump 2>&1 
// RUN: %FileCheck %s < %t.dump

protocol P1 { 
  func p1()
}

protocol P2 : P1 { }


struct X1<T : P1> { 
  func getT() -> T { }
}

class X2<T : P1> {
  func getT() -> T { }
}

class X3 { }

struct X4<T : X3> { 
  func getT() -> T { }
}

struct X5<T : P2> { }

// Infer protocol requirements from the parameter type of a generic function.
func inferFromParameterType<T>(_ x: X1<T>) {
  x.getT().p1()
}

// Infer protocol requirements from the return type of a generic function.
func inferFromReturnType<T>(_ x: T) -> X1<T> {
  x.p1()
}

// Infer protocol requirements from the superclass of a generic parameter.
func inferFromSuperclass<T, U : X2<T>>(_ t: T, u: U) -> T {
  t.p1()
}


// Infer protocol requirements from the parameter type of a constructor.
struct InferFromConstructor {
  init<T> (x : X1<T>) {
    x.getT().p1()
  }
}


// Don't infer requirements for outer generic parameters.
class Fox : P1 {
  func p1() {}
}

class Box<T : Fox> {
// CHECK-LABEL: .unpack@
// CHECK-NEXT: Requirements:
// CHECK-NEXT:   T : Fox [explicit]
  func unpack(_ x: X1<T>) {}
}

// ----------------------------------------------------------------------------
// Superclass requirements
// ----------------------------------------------------------------------------

// Compute meet of two superclass requirements correctly.
class Carnivora {}
class Canidae : Carnivora {}

struct U<T : Carnivora> {}

struct V<T : Canidae> {}

// CHECK-LABEL: .inferSuperclassRequirement1@
// CHECK-NEXT: Requirements:
// CHECK-NEXT:   T : Canidae
func inferSuperclassRequirement1<T : Carnivora>(_ v: V<T>) {}

// CHECK-LABEL: .inferSuperclassRequirement2@
// CHECK-NEXT: Requirements:
// CHECK-NEXT:   T : Canidae
func inferSuperclassRequirement2<T : Canidae>(_ v: U<T>) {}

// ----------------------------------------------------------------------------
// Same-type requirements
// ----------------------------------------------------------------------------

protocol P3 {
  associatedtype P3Assoc : P2
}

protocol P4 {
  associatedtype P4Assoc : P1
}

protocol PCommonAssoc1 {
  associatedtype CommonAssoc
}

protocol PCommonAssoc2 {
  associatedtype CommonAssoc
}

protocol PAssoc {
  associatedtype Assoc
}

struct Model_P3_P4_Eq<T : P3, U : P4> where T.P3Assoc == U.P4Assoc {}

// CHECK-LABEL: .inferSameType1@
// CHECK-NEXT: Requirements:
// CHECK-NEXT:   T : P3 [inferred @ {{.*}}:32]
// CHECK-NEXT:   U : P4 [inferred @ {{.*}}:32]
// CHECK-NEXT:   T[.P3].P3Assoc : P1 [redundant @ {{.*}}:18]
// CHECK-NEXT:   T[.P3].P3Assoc : P2 [protocol @ {{.*}}:18]
func inferSameType1<T, U>(_ x: Model_P3_P4_Eq<T, U>) { }

// CHECK-LABEL: .inferSameType2@
// CHECK-NEXT: Requirements:
// CHECK-NEXT:   T : P3 [inferred]
// CHECK-NEXT:   U : P4 [inferred]
// CHECK-NEXT:   T[.P3].P3Assoc : P1 [redundant @ {{.*}}requirement_inference.swift:{{.*}}:18]
// CHECK-NEXT:   T[.P3].P3Assoc : P2 [protocol @ {{.*}}requirement_inference.swift:{{.*}}:18]
// CHECK-NEXT:   T[.P3].P3Assoc == U[.P4].P4Assoc [explicit]
func inferSameType2<T : P3, U : P4>(_: T, _: U) where U.P4Assoc : P2, T.P3Assoc == U.P4Assoc {}

// CHECK-LABEL: .inferSameType3@
// CHECK-NEXT: Requirements:
// CHECK-NEXT:   T : PCommonAssoc1 [inferred]
// CHECK-NEXT:   T : PCommonAssoc2 [inferred]
// CHECK-NEXT:   T[.PCommonAssoc1].CommonAssoc : P1 [explicit @ {{.*}}requirement_inference.swift:{{.*}}:68]
// CHECK-NEXT: Potential archetypes
func inferSameType3<T : PCommonAssoc1>(_: T) where T.CommonAssoc : P1, T : PCommonAssoc2 {}

protocol P5 {
  associatedtype Element
}

protocol P6 {
  associatedtype AssocP6 : P5
}

protocol P7 : P6 {
  associatedtype AssocP7: P6
}

// CHECK-LABEL: P7.nestedSameType1()@
// CHECK: Canonical generic signature: <τ_0_0 where τ_0_0 : P7, τ_0_0.AssocP6.Element : P6, τ_0_0.AssocP6.Element == τ_0_0.AssocP7.AssocP6.Element>
extension P7 where AssocP6.Element : P6, 
        AssocP7.AssocP6.Element : P6,
        AssocP6.Element == AssocP7.AssocP6.Element {
  func nestedSameType1() { }
}

protocol P8 {
  associatedtype A
  associatedtype B
}

protocol P9 : P8 {
  associatedtype A
  associatedtype B
}

protocol P10 {
  associatedtype A
  associatedtype C
}

// CHECK-LABEL: sameTypeConcrete1@
// CHECK: Canonical generic signature: <τ_0_0 where τ_0_0 : P10, τ_0_0 : P9, τ_0_0.A == X3, τ_0_0.B == Int, τ_0_0.C == Int>
func sameTypeConcrete1<T : P9 & P10>(_: T) where T.A == X3, T.C == T.B, T.C == Int { }

// CHECK-LABEL: sameTypeConcrete2@
// CHECK: Canonical generic signature: <τ_0_0 where τ_0_0 : P10, τ_0_0 : P9, τ_0_0.B == X3, τ_0_0.C == X3>
func sameTypeConcrete2<T : P9 & P10>(_: T) where T.B : X3, T.C == T.B, T.C == X3 { }

// Note: a standard-library-based stress test to make sure we don't inject
// any additional requirements.
// CHECK-LABEL: RangeReplaceableCollection.f()@
// CHECK: <τ_0_0 where τ_0_0 : MutableCollection, τ_0_0 : RangeReplaceableCollection, τ_0_0.SubSequence == MutableRangeReplaceableSlice<τ_0_0>>
extension RangeReplaceableCollection where
  Self: MutableCollection,
  Self.SubSequence == MutableRangeReplaceableSlice<Self>
{
	func f() { }
}
