<img align="right" width="150" height="150" top="100" src="./assets/kolektivo.png">

# Contributing to the Kolektivo Contracts

Thanks for your interest in improving the Kolektivo contracts!

## Solidity Code Style

### Usage of error types vs. `require` vs. `assert`

Use **error types** when reverting non-owner functions.

Use empty **require** statements for (input) validation for only-owner functions. It is assumed that the contract's owner have enough knowledge about the internal workings to be able to track down the issue without costly revert strings.
However, if an applicable error type exists already in the codebase, revert using the error type.

Use **assert** statements for internal invariants that should **never** be broken.

### Returning addresses vs. Interface types

Always return addresses instead of concrete interface types.

While this style reduces the semantic meaning of the return types it has the
positive side-effect that caller's do not need to include the Interface
definitions into their codebase.

However, to work against the loss of type information make sure that the
documentation is sufficint for developers to reason about the returned address.
