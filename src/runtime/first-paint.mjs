// Startup-only proof, through the upstream identity-bound CDP session.
// Full compatibility verification remains the default and runs separately.
export async function verifyFirstPaint(session, expectedThemeId, expectedRevision, expectedVersion) {
  return session.evaluate(`(${inspectFirstPaint.toString()})(${JSON.stringify({
    expectedThemeId, expectedRevision, expectedVersion,
    nativeHandoff: process.platform === 'win32' && process.env.RISE_NATIVE_HANDOFF === '1',
  })})`);
}

export function inspectFirstPaint(expected) {
  const root = document.documentElement;
  const runtime = window.__CODEX_DREAM_SKIN_STATE__;
  const visible = node => {
    if (!node || node.closest('[data-app-shell-active-page="false"]')) return false;
    const rect = node.getBoundingClientRect(), style = getComputedStyle(node);
    return node.isConnected && rect.width > 0 && rect.height > 0 &&
      rect.right > 0 && rect.bottom > 0 && rect.left < innerWidth && rect.top < innerHeight &&
      style.display !== 'none' && style.visibility === 'visible' &&
      Number(style.opacity) > 0 && (typeof node.checkVisibility !== 'function' ||
        node.checkVisibility({checkOpacity: true, checkVisibilityCSS: true}));
  };
  const hasVisible = selector => [...document.querySelectorAll(selector)].some(visible);
  const artworkPainted = [...document.querySelectorAll('body, [data-ds-part="root"], [data-ds-part="main"], [data-ds-part="home"], main, [role="main"]')]
    .filter(visible).some(node => [null, '::before', '::after'].some(pseudo => {
      const style = getComputedStyle(node, pseudo);
      return (!pseudo || (style.content !== 'none' && style.content !== 'normal')) &&
        style.display !== 'none' && style.visibility === 'visible' && Number(style.opacity) > 0 &&
        typeof runtime?.artUrl === 'string' && /^(blob:|data:image\/)/.test(runtime.artUrl) &&
        style.backgroundImage.includes('url("' + runtime.artUrl + '")');
    }));
  const result = {
    kind: 'rise-first-paint-v1',
    installed: root.getAttribute('data-dream-skin') === 'active',
    themeId: runtime?.themeId, revision: runtime?.revision, version: runtime?.version,
    stylePresent: Boolean(
      (runtime?.styleMode === 'adopted' && [...document.adoptedStyleSheets].includes(runtime.styleSheet)) ||
      (runtime?.styleMode === 'style' && runtime.styleNode &&
        document.getElementById('codex-dream-skin-style') === runtime.styleNode)),
    // Upstream sets this only after the local artwork image has loaded/analyzed.
    artworkReady: root.getAttribute('data-dream-art-ready') === 'true',
    artworkPainted,
    documentVisible: document.visibilityState === 'visible' && !document.hidden,
    // Windows reports fully occluded windows as hidden. Its caller separately
    // matches HWND to the verified browser PID and checks native visibility
    // again before releasing the intro. This exception is never used on Mac.
    requiresNativeWindow: expected.nativeHandoff === true,
    viewportValid: innerWidth >= 280 && innerHeight >= 200,
    mainVisible: hasVisible('[data-ds-part="main"], [data-ds-part="home"], main, [role="main"]'),
    scopeValid: runtime?.scope?.level === 'L1' &&
      Array.isArray(runtime?.scope?.missingL1) && runtime.scope.missingL1.length === 0,
  };
  result.pass = Boolean(expected.expectedThemeId === 'p4r-rise-on-air' &&
    expected.expectedRevision && expected.expectedVersion &&
    result.themeId === expected.expectedThemeId && result.revision === expected.expectedRevision &&
    result.version === expected.expectedVersion && result.installed && result.stylePresent &&
    result.artworkReady && result.artworkPainted && (result.documentVisible || result.requiresNativeWindow) &&
    result.viewportValid && result.mainVisible && result.scopeValid);
  return result;
}
