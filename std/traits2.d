/**
 * A collection of Concept checking templates, Type attributes and 
 * Type functions to use at compile time.
 *
 * References:
 *  Based on ideas in $(LINK2 http://www.elementsofprogramming.com/, 
 *  Elements of Programming),
 *   Alexander Stepanov and Paul McJones (Addison-Wesley Professional, June 2009)
 *
 * Author: Guillaume Chatelet
 */

/**
Definitions:
$(UL
$(LI
$(B Type Attribute)
A type attribute is a mapping from a type to a value describing some
characteristic of the type.
)
$(LI
$(B Type Function)
A type function is a mapping from a type to an affiliated type.
)
$(LI
$(B Concept)
A concept is a description of requirements on one or more types stated in 
terms of the existence and properties of procedures, type attributes, and
type functions defined on the types.
)
$(LI
$(B Property)
A property is a predicate used in specifications to describe behavior
of particular objects.
)
)
*/
module std.traits2;

import std.traits;
import std.typetuple;

/**
The number of arguments or operands that $(D_PARAM F) takes

Type Attribute
Examples:
---
void foo(){}
static assert(Arity!foo==0);
void bar(uint){}
static assert(Arity!bar==1);
---
 */
template Arity(alias F) {
	enum uint Arity = (ParameterTypeTuple!F).length;
}

unittest {
	void foo(){}
	static assert(Arity!foo==0);
	void bar(uint){}
	static assert(Arity!bar==1);
}

/**
A TypeTuple of the unqualified Type arguments of $(D_PARAM F)

Type Function
 */
template UnqualParameterTuple(alias F) {
	alias staticMap!(Unqual, ParameterTypeTuple!F) UnqualParameterTuple;
}

unittest {
	void foo(const uint,immutable uint, uint){}
	foreach(Type;UnqualParameterTuple!foo)
		static assert(is(Type==uint));
}

/**
Type of the $(D_PARAM index)-th argument of $(D_PARAM F)

Type Function
Examples:
---
void foo(byte,const uint);
static assert(is(InputType!(foo,0) == byte));
static assert(is(InputType!(foo,1) == uint));
---
 */
template InputType(alias F, uint index){
	alias UnqualParameterTuple!F[index] InputType;
}

unittest {
	void foo(byte,const uint);
	static assert(is(InputType!(foo,0) == byte));
	static assert(is(InputType!(foo,1) == uint));
}

/**
Return type of $(D_PARAM F)

Type Function
 */
template CoDomain(alias F){
	alias ReturnType!F CoDomain;
}

/**
Type of the first argument of an UnaryFunction or HomogeneousFunction 

Type Function
 */
template Domain(alias F) {
	static if(isUnaryFunction!F || isHomogeneousFunction!F)
		alias InputType!(F,0) Domain;
}

/**
Checks if $(D_PARAM T) has a default constructor

Concept
 */
template isDefaultConstructible(T) {
	enum bool isDefaultConstructible = is(typeof({T t;}));
}

unittest {
	static assert(isDefaultConstructible!uint);
	struct DefaultConstructible{}
	static assert(isDefaultConstructible!DefaultConstructible);
	class DefaultConstructibleClass{}
	static assert(isDefaultConstructible!DefaultConstructibleClass);
}

/**
Checks if $(D_PARAM T) has a copy constructor

Concept
 */
template isCopyConstructible(T) {
	enum bool isCopyConstructible = isNumeric!T || is(typeof({
		T a=void;
		T(a);
	}));
}

unittest {
	static assert(isCopyConstructible!uint);
	struct CopyConstructible{this(CopyConstructible other){}};
	static assert(isCopyConstructible!CopyConstructible);
	struct NotCopyConstructible{};
	static assert(isCopyConstructible!NotCopyConstructible==false);
}

/**
Checks if $(D_PARAM Lhs) is assignable from $(D_PARAM Rhs) 

Concept
 */
template isAssignable(Lhs, Rhs=Lhs)
{
    enum bool isAssignable = is(typeof({
        Lhs l=void;
        Rhs r=void;
        l = r;
        return l;
    }));
}

unittest
{
    static assert(isAssignable!(long, int));
    static assert(isAssignable!(const(char)[], string));

    static assert(isAssignable!(int, long)==false);
    static assert(isAssignable!(string, char[])==false);
}

/**
Checks if $(D_PARAM Lhs) is equality comparable to $(D_PARAM Rhs) 

Concept
 */
template isEqualityComparable(Lhs, Rhs=Lhs) {
	enum bool isEqualityComparable = is(typeof({
		Lhs l=void;
		Rhs r=void;
		bool isEqual = l==r;
	}));
}

unittest {
	static assert(isEqualityComparable!(uint,ubyte));
	static assert(isEqualityComparable!(uint,double));
	struct AStruct{}
	static assert(isEqualityComparable!AStruct); // struct are comparable by default
	static assert(isEqualityComparable!(uint,AStruct)==false);
}

/**
Checks if $(D_PARAM Lhs) is less comparable to $(D_PARAM Rhs)

Concept
 */
template isLessComparable(Lhs, Rhs=Lhs) {
	enum bool isLessComparable = is(typeof({
		Lhs l=void;
		Rhs r=void;
		bool isEqual = l<r;
	}));
}

unittest {
	static assert(isLessComparable!(uint,ubyte));
	static assert(isLessComparable!(uint,double));
	// struct are not less comparable by default
	struct AStruct;
	static assert(isLessComparable!AStruct==false);
	static assert(isLessComparable!(uint,AStruct)==false);
	struct Comparable{int opCmp(Comparable rhs){return 0;}}
	static assert(isLessComparable!Comparable);
}

// Chapter 1: Foundations

/**
$(D_PARAM T)'s computational basis includes equality, assignment, destructor, 
default constructor, copy constructor, total ordering 
(or default total ordering) and underlying type.

Regularity is fundamental to Concepts as it enables $(I equationnal reasoning).

Note 1 : The authors require $(D_PARAM T) to provide an $(I underlying type) to allow 
good performance in swapping heavyweight structures.$(BR)
For this purpose, $(D_PSYMBOL std.algorithm.swap) makes use of $(D_PSYMBOL proxySwap)
where available so the requirements for an $(I underlying type) is relaxed.

Note 2 : Although the semantic of total ordering is mandatory this template can only check
for syntactic requirements involving the $(D_KEYWORD opCmp) function.

Concept
 */
template isRegular(T) {
	enum bool isRegular = isEqualityComparable!T && 
						  isAssignable!(T,T) &&
						  isDefaultConstructible!T && 
						  isCopyConstructible!T &&
						  isLessComparable!T;
}

unittest {
	static assert(isRegular!uint);
	struct AStruct{}
	static assert(isRegular!AStruct==false);
	struct BStruct{
		this(BStruct other){}
		int opCmp(BStruct rhs){return 0;}
	}
	static assert(isRegular!BStruct);
}


/**
$(D_PARAM F) is a regular procedure defined on regular types: replacing its inputs
with equal objects results in equal output objects.

In D FunctionalProcedure means $(D_PARAM F) is a $(D_KEYWORD pure) function and its parameter types are Regular.

Concept

Property: $(I regular_function)
"Application of equal functions to equal arguments gives equal results"
 */
template isFunctionalProcedure(alias F) {
	enum bool isFunctionalProcedure = (functionAttributes!F & FunctionAttribute.pure_) && is(typeof({
					foreach(Type; UnqualParameterTuple!F)
						static assert(isRegular!Type);
				}));
}

unittest {
	void foo(){}
	static assert(isFunctionalProcedure!foo==false);
	void bar() pure {}
	static assert(isFunctionalProcedure!bar);
}

/**
$(D_PARAM F) is a FunctionalProcedure of Arity == 1  

Concept

Property: $(I regular_unary_function)
 */
template isUnaryFunction(alias F) {
	enum bool isUnaryFunction = isFunctionalProcedure!F && Arity!F==1;
}

unittest {
	void unaryFunction(uint x) pure {}
	static assert(isUnaryFunction!unaryFunction);
}

/**
$(D_PARAM F) is a FunctionalProcedure of Arity > 0 which arguments are of same types

Concept
 */
template isHomogeneousFunction(alias F) {
	alias UnqualParameterTuple!F ParameterTypes;
	enum bool isHomogeneousFunction = isFunctionalProcedure!F && Arity!F>0 && (NoDuplicates!ParameterTypes).length == 1;
}

unittest {
	void foo(uint) pure {}
	static assert(isHomogeneousFunction!foo);
	void bar(uint, byte) pure {}
	static assert(isHomogeneousFunction!bar==false);
	void baz(uint, const uint, uint) pure {}
	static assert(isHomogeneousFunction!baz);
}

// Chapter 2: Transformations and Their Orbits

/**
$(D_PARAM F) is a FunctionalProcedure and its return type is bool
$(BR)NB : Maybe extend isPredicate to a return type convertible to bool.

Concept
 */
template isPredicate(alias F) {
	enum bool isPredicate = isFunctionalProcedure!F && is(CoDomain!F == bool);
}

unittest {
	bool foo() pure { return true; }
	static assert(isPredicate!foo);
	void bar() pure {}
	static assert(isPredicate!bar==false);
}

/**
$(D_PARAM F) is a Predicate and all its arguments are of same type

Concept
 */
template isHomogeneousPredicate(alias F) {
	enum bool isHomogeneousPredicate = isPredicate!F && isHomogeneousFunction!F;
}

unittest {
	bool foo(uint, const uint, immutable uint) pure { return true; }
	static assert(isHomogeneousPredicate!foo);
	bool bar(byte, const uint) pure { return true; }
	static assert(isHomogeneousPredicate!bar==false);
}

/**
$(D_PARAM F) is a Predicate and an UnaryFunction

Concept
 */
template isUnaryPredicate(alias F) {
	enum bool isUnaryPredicate = isPredicate!F && isUnaryFunction!F;
}

unittest {
	bool foo(uint) pure { return true; }
	static assert(isUnaryPredicate!foo);
	bool bar(byte, const uint) pure { return true; }
	static assert(isUnaryPredicate!bar==false);
}

/**
$(D_PARAM F) is an HomogeneousFunction and the CoDomain of $(D_PARAM F) is equal its Domain.

Concept
 */
template isOperation(alias F) {
	enum bool isOperation = isHomogeneousFunction!F && is(CoDomain!F == Domain!F);
}

unittest {
	uint foo(uint) pure { return 0; }
	static assert(isOperation!foo);
	bool bar(uint) pure { return 0; }
	static assert(isOperation!bar==false);
	uint baz(uint,uint) pure { return 0; }
	static assert(isOperation!baz);
}

/**
$(D_PARAM F) is an Operation and an UnaryFunction

Concept
 */
template isTransformation(alias F) {
	enum bool isTransformation = isOperation!F && isUnaryFunction!F;
}

unittest {
	uint foo(uint) pure { return 0; }
	static assert(isTransformation!foo);
	uint bar(uint,uint) pure { return 0; }
	static assert(isTransformation!bar==false);
}

/**
Default implementation of DistanceType for function of integral type

Type Function
 */
template DistanceType(alias F) if(isIntegral!(Domain!F) && isTransformation!F) {
	alias size_t DistanceType; 
}

unittest {
	uint foo(uint) pure {return 0;}
	static assert(is(DistanceType!foo==size_t));
	float bar(float) pure {return 0;}
	static assert(is(typeof(DistanceType!bar))==false);
}

/**
Count the number of steps from $(D_PARAM x) to $(D_PARAM y) under application of $(D_PARAM F)
Precondition:
$(D_PARAM y) is reachable from $(D_PARAM x) under F
 */
DistanceType!F distance(alias F)(Domain!F x, Domain!F y) pure {
	static assert(isTransformation!F);
	DistanceType!F n;
	while(x!=y) {
		x = F(x);
		n = n + 1;
	}
	return n;
}

unittest {
	static assert(distance!(successor!uint)(0,3)==3);
	static assert(distance!(twice!uint)(1,32)==5);
	static assert(distance!(half_nonnegative!uint)(32,2)==4);
}

// Chapter 3: Associative Operations

/**
$(D_PARAM F) is an Operation of Arity 2.

Concept

Property: associative
 */
template isBinaryOperation(alias F) {
	enum bool isBinaryOperation = isOperation!F && Arity!F==2;
}

unittest {
	uint foo(uint,uint) pure { return 0; }
	static assert(isBinaryOperation!foo);
	int bar(uint,uint) pure { return 0; }
	static assert(isBinaryOperation!bar==false);
	uint baz(uint) pure { return 0; }
	static assert(isBinaryOperation!baz==false);
}

/**
$(D_PARAM I) is applicable to following functions$(BR)$(BR) 
successor : I → I
$(BR) n → n + 1

predecessor : I → I
$(BR) n → n − 1

twice : I → I
$(BR) n → n + n

half_nonnegative : I → I
$(BR) n → n/2 , where n>=0

binary_scale_down_nonnegative : I × I → I
$(BR) (n, k) → n/2^k , where n, k >= 0

binary_scale_up_nonnegative : I × I → I
$(BR) (n, k) → n*2^k, where n, k >= 0

positive : I → bool
$(BR) n → n > 0

negative : I → bool
$(BR) n → n < 0

zero : I → bool
$(BR) n → n = 0

one : I → bool
$(BR) n → n = 1

even : I → bool
$(BR) n → (n mod 2) = 0

odd : I → bool
$(BR) n → (n mod 2) != 0

Concept
 */
template isInteger(I) {
	enum bool isInteger =
		isTransformation!(successor!I) &&
		isTransformation!(predecessor!I) &&
		isTransformation!(twice!I) &&
		isTransformation!(half_nonnegative!I) &&
		isHomogeneousFunction!(binary_scale_down_nonnegative!I) &&
		isHomogeneousFunction!(binary_scale_up_nonnegative!I) &&
		isUnaryPredicate!(positive!I) &&
		isUnaryPredicate!(negative!I) &&
		isUnaryPredicate!(zero!I) &&
		isUnaryPredicate!(one!I) &&
		isUnaryPredicate!(even!I) &&
		isUnaryPredicate!(odd!I);
}

I successor(I)(I n) pure nothrow { 
	return n+1; 
}

I predecessor(I)(I n) pure nothrow { 
	return n-1;
}

I twice(I)(I n) pure nothrow { 
	return n+n;
}

I half_nonnegative(I)(I n) pure nothrow if(isUnsigned!I) { 
	return n/2;
}

I binary_scale_down_nonnegative(I)(I n,I k) pure if(isUnsigned!I) { 
	return n/std.math.pow(2,k);
}

I binary_scale_up_nonnegative(I)(I n,I k) pure if(isUnsigned!I) { 
	return std.math.pow(2,k)*n;
}

bool positive(I)(I n) pure nothrow { 
	return n>0;
}

bool negative(I)(I n) pure nothrow { 
	return n<0;
}

bool zero(I)(I n) pure nothrow { 
	return n==0; 
}

bool one(I)(I n) pure nothrow { 
	return n==1; 
}

bool even(I)(I n) pure nothrow { 
	return n%2==0; 
}

bool odd(I)(I n) pure nothrow { 
	return n%2!=0; 
}

unittest {
	static assert(isInteger!uint);
}

// Chapter 4: Linear Orderings

/**
$(D_PARAM F) is an HomogeneousPredicate of Arity==2

Concept

Property: transitive, strict, reflexive, symmetric, asymmetric, equivalence, key function, total ordering, weak ordering
 */
template isRelation(alias F) {
	enum bool isRelation = isHomogeneousPredicate!F && Arity!F==2;
}

unittest {
	bool foo(uint,uint) pure { return true; }
	static assert(isRelation!foo);
}

/**
$(D_PARAM F) is Regular and totally ordered

Concept
 */
template TotallyOrdered(T) {
	enum bool TotallyOrdered = isRegular!T && isLessComparable!T;
}

// Chapter 5: Ordered Algebraic Structures

