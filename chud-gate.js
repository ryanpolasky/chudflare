/*!
 * chud-gate.js — drop-in script that gates a site behind chudflare.com/verify
 * usage: <script src="https://chudflare.com/chud-gate.js"></script>
 *        <script src="https://chudflare.com/chud-gate.js" data-manual></script>
 *
 * options (on the script tag):
 *   data-manual  if present, the visitor sees a "Continue to <site>" button
 *                after verification. otherwise we auto-redirect after 2s.
 *
 * how it works:
 *   1. if the user just got back from /verify with #chud-verified in
 *      the URL, we stash the timestamp in localStorage and let them through.
 *   2. if a fresh verification is on file (<24h old), let them through.
 *   3. otherwise, redirect to chudflare.com/verify?return=<this page>
 *      so they have to prove they are a chud before continuing.
 *
 * the site owner gets the bit, the visitor gets verified, nothing ever happens.
 */
(function () {
  'use strict';

  var KEY = 'chudflare-verified-chud';
  var TTL = 24 * 60 * 60 * 1000; // 24h
  var GATE_URL = 'https://chudflare.com/verify';

  // read script-tag options. document.currentScript works in modern browsers;
  // for older ones we fall back to the last <script src="chud-gate.js"> on the page.
  function getScriptTag() {
    if (document.currentScript) return document.currentScript;
    var all = document.getElementsByTagName('script');
    for (var i = all.length - 1; i >= 0; i--) {
      if (all[i].src && all[i].src.indexOf('chud-gate.js') !== -1) return all[i];
    }
    return null;
  }
  var tag = getScriptTag();
  var manual = !!(tag && tag.hasAttribute('data-manual'));

  function readVerified() {
    try {
      var raw = localStorage.getItem(KEY);
      if (!raw) return 0;
      var ts = parseInt(raw, 10);
      return isFinite(ts) ? ts : 0;
    } catch (e) { return 0; }
  }

  function writeVerified() {
    try { localStorage.setItem(KEY, String(Date.now())); } catch (e) {}
  }

  // if we just bounced back from verify.html, accept the verification token
  // and strip the hash so the URL stays clean.
  var hash = location.hash || '';
  if (hash.indexOf('chud-verified') !== -1) {
    writeVerified();
    try {
      var cleanHash = hash.replace(/[#&]chud-verified/g, '');
      if (cleanHash === '#' || cleanHash === '') cleanHash = '';
      history.replaceState(null, '', location.pathname + location.search + cleanHash);
    } catch (e) {}
    return; // verified, no redirect needed
  }

  if (Date.now() - readVerified() < TTL) return;

  // not verified. redirect to the gate.
  var ret = encodeURIComponent(location.href);
  var extra = manual ? '&manual=1' : '';
  location.replace(GATE_URL + '?return=' + ret + extra);
})();
