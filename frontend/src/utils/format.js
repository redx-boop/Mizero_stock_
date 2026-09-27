/**
 * Format a number as currency with 2 decimal places
 */
export function formatCurrency(val) {
  return Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

/**
 * Format a number with comma separators (no decimals for integers)
 */
export function formatNumber(val) {
  return Number(val || 0).toLocaleString();
}

/**
 * Format a large currency value in human-readable scale,
 * e.g. 2322901731.72 → "2.32 billion", 456700000 → "456.70 million".
 * Values below 1,000 fall back to full currency formatting.
 * Thresholds are 999.5× the unit so values that would display as
 * "1000.00 million" roll over to "1.00 billion" instead.
 */
export function formatCurrencyCompact(val) {
  const num = Number(val || 0);
  const abs = Math.abs(num);
  if (abs >= 999.5e6) return `${(num / 1e9).toFixed(2)} billion`;
  if (abs >= 999.5e3) return `${(num / 1e6).toFixed(2)} million`;
  if (abs >= 999.5) return `${(num / 1e3).toFixed(1)} thousand`;
  return formatCurrency(num);
}
