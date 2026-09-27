/**
 * Exposes the per-request CSP nonce to libraries that inject a <style> element.
 *
 * Nginx replaces the `__CSP_NONCE__` placeholder in index.html with a random
 * value and allows that value in the `style-src` directive. Libraries built on
 * goober (e.g. react-hot-toast) read `window.__nonce__` and attach it to the
 * <style> element they create, which keeps the policy strict — no
 * 'unsafe-inline' is needed.
 *
 * This module must be imported before any such library is imported, hence it is
 * the first import in main.jsx.
 */
const meta = document.querySelector('meta[name="csp-nonce"]');
const nonce = meta && meta.getAttribute('content');

// In dev (Vite) there is no Nginx and therefore no CSP, so the placeholder is
// left as-is and no nonce is set.
if (nonce && nonce !== '__CSP_NONCE__') {
  window.__nonce__ = nonce;
}
