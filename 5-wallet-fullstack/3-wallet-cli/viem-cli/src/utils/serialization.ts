/**
 * Custom JSON serialization utilities for handling BigInt values
 */

/**
 * JSON.stringify replacer function that converts BigInt values to strings
 * @param key - The property key
 * @param value - The property value
 * @returns The value with BigInt converted to string
 */
export const bigIntReplacer = (key: string, value: unknown): unknown => {
  if (typeof value === 'bigint') {
    return value.toString();
  }
  return value;
};

/**
 * Safely stringify an object that may contain BigInt values
 * @param obj - The object to stringify
 * @param space - Optional spacing for pretty printing
 * @returns JSON string with BigInt values converted to strings
 */
export const stringifyWithBigInt = (obj: unknown, space?: string | number): string => {
  return JSON.stringify(obj, bigIntReplacer, space);
};