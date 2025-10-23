declare interface CallableFunction {
  (...args: unknown[]): unknown;
  apply(thisArg: unknown, argArray?: unknown[]): unknown;
  call(thisArg: unknown, ...args: unknown[]): unknown;
  bind(thisArg: unknown, ...args: unknown[]): CallableFunction;
}

declare interface NewableFunction {
  new (...args: unknown[]): unknown;
  (...args: unknown[]): unknown;
}
