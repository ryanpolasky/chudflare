/* =========================================================
   Chudflare: interactive widgets
   Single shared script. Auto-initializes based on what's
   present on the page (data attrs, element IDs).
   ========================================================= */
(function () {
  'use strict';

  // ---------- utils ----------
  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.from((r || document).querySelectorAll(s)); }
  function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
  function rand(min, max) { return Math.random() * (max - min) + min; }
  function ms(n) { return new Promise(function (r) { setTimeout(r, n); }); }
  function hash32(str) { var h = 2166136261; for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = (h * 16777619) >>> 0; } return h; }
  function mulberry32(seed) { return function () { var t = (seed += 0x6D2B79F5); t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  function fakeRayId() {
    var hex = '0123456789abcdef';
    var s = '';
    for (var i = 0; i < 16; i++) s += hex[Math.floor(Math.random() * 16)];
    return s + '-CHUD';
  }
  function formatNum(n, decimals, suffix) {
    var fixed = n.toFixed(decimals || 0);
    var parts = fixed.split('.');
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return parts.join('.') + (suffix || '');
  }
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // =========================================================
  // 1. Live stat tickers
  //    Elements with data-tick="kind" auto-animate based on kind.
  //    Kinds: chuds, slop, blocked, hunched
  // =========================================================
  function initStatTickers() {
    var nodes = $$('[data-tick]');
    if (!nodes.length) return;

    var state = {
      chuds: 6_900_000,       // 6.9M chuds on-network, ticks up
      slop: 320,              // 320 Tbps slop capacity, fluctuates
      blocked: 9_800_000_000, // 9.8B requests blocked daily
      hunched: 73             // 73% of internet sloths
    };

    function render(node) {
      var kind = node.getAttribute('data-tick');
      if (kind === 'chuds') {
        var m = state.chuds / 1_000_000;
        node.textContent = m.toFixed(2) + 'M';
      } else if (kind === 'slop') {
        node.textContent = state.slop.toFixed(1) + ' Tbps';
      } else if (kind === 'blocked') {
        var b = state.blocked / 1_000_000_000;
        node.textContent = b.toFixed(2) + 'B';
      } else if (kind === 'hunched') {
        node.textContent = state.hunched.toFixed(1) + '%';
      }
    }

    nodes.forEach(render);

    setInterval(function () {
      state.chuds += Math.floor(rand(1, 6));
      state.slop = 320 + rand(-1.4, 2.1);
      state.blocked += Math.floor(rand(40000, 180000));
      state.hunched = Math.min(99.9, state.hunched + rand(-0.04, 0.06));
      nodes.forEach(render);
    }, 1100);
  }

  // =========================================================
  // 2. /verify CAPTCHA gate
  //    Renders an "I am a chud" checkbox + verify button.
  //    Auto-launches existing window.__chudVerifyStart() when clicked.
  // =========================================================
  function initVerifyGate() {
    var gate = document.getElementById('chud-gate');
    if (!gate) return;

    var html = '' +
      '<div class="gate-row">' +
        '<label class="gate-check">' +
          '<input type="checkbox" id="gate-cb"/>' +
          '<span class="gate-cb-box" aria-hidden="true"></span>' +
          '<span class="gate-cb-label">I am a chud</span>' +
        '</label>' +
        '<button class="btn btn-primary btn-sm" id="gate-verify" disabled>Verify</button>' +
      '</div>' +
      '<div class="gate-note">Chudflare needs to confirm you are a chud before continuing. By checking the box you affirm you have not mewed today, are wearing a hoodie indoors, and have consumed at least one (1) Monster Energy in the last 24 hours.</div>';
    gate.innerHTML = html;

    var cb = document.getElementById('gate-cb');
    var btn = document.getElementById('gate-verify');

    cb.addEventListener('change', function () {
      btn.disabled = !cb.checked;
    });

    btn.addEventListener('click', function () {
      if (!cb.checked) return;
      btn.disabled = true;
      btn.textContent = 'Verifying…';
      // Hide the gate, reveal the running animation.
      setTimeout(function () {
        gate.classList.add('gate-done');
        var card = document.getElementById('verify-card');
        if (card) {
          card.classList.remove('idle');
          card.classList.add('running');
        }
        if (typeof window.__chudVerifyStart === 'function') {
          window.__chudVerifyStart();
        }
      }, 400);
    });
  }

  // =========================================================
  // 3. "Try Chad Fight Mode" WAF tester (#cfm-tester)
  // =========================================================
  function initWAFTester() {
    var root = document.getElementById('cfm-tester');
    if (!root) return;

    root.innerHTML = '' +
      '<div class="wid-head">' +
        '<div class="wid-eyebrow">cfctl firewall test --request</div>' +
        '<div class="wid-title">Test a request against Chad Fight Mode v3</div>' +
      '</div>' +
      '<div class="wid-input">' +
        '<input id="cfm-input" type="text" placeholder="paste a User-Agent, email, or any string" autocomplete="off"/>' +
        '<button class="btn btn-primary btn-sm" id="cfm-go">Run check</button>' +
      '</div>' +
      '<pre class="wid-out" id="cfm-out"># waiting for input…\n# tip: try "Mozilla/5.0 (gigachad)" or "fat fucking chud"</pre>';

    function classify(text) {
      var seed = hash32(text || 'empty');
      var rng = mulberry32(seed);
      // Generate fake metrics deterministically from the input.
      var psl = +(2.0 + rng() * 7.5).toFixed(1);            // 2.0 - 9.5
      var jaw = ['undetected', 'soft', 'rounded', 'square', 'cut'][Math.floor(rng() * 5)];
      var mewing = rng() < 0.5;
      var hunch = Math.floor(rng() * 60);                    // 0 - 60deg
      var sigma = /sigma|grindset|alpha|gigachad|gym|peptide/i.test(text);
      var clavicular = +(rng() * 9.9).toFixed(1);
      var verdict, ruleId, reason;

      // The lower your PSL + posture, the more you "pass" the chud check.
      // High PSL or sigma keywords trigger mog_back. Edge case: mewing user gets challenged.
      if (sigma || psl >= 7.5) {
        verdict = 'mog_back';
        ruleId = 'chad_fight_mode/v3';
        reason = 'subject mogged operator on first packet';
      } else if (psl >= 5.5) {
        verdict = 'challenge';
        ruleId = 'chad_fight_mode/v3';
        reason = 'suspicious jaw symmetry; issuing chud challenge';
      } else if (jaw === 'cut' || jaw === 'square') {
        verdict = 'challenge';
        ruleId = 'jaw_symmetry/v2';
        reason = 'visible jawline; require posture proof';
      } else if (mewing && rng() < 0.6) {
        verdict = 'challenge';
        ruleId = 'mewing/v1';
        reason = 'tongue detected on palate; please slacken jaw';
      } else {
        verdict = 'allow';
        ruleId = 'chud_passport/v4';
        reason = 'confirmed chud; sub-5 PSL; proceed to fridge';
      }

      return {
        psl: psl, jaw: jaw, mewing: mewing, hunch: hunch,
        clavicular: clavicular, verdict: verdict, ruleId: ruleId, reason: reason
      };
    }

    function render(input) {
      var c = classify(input);
      var h = hash32(input);
      var ip = '10.20.' + (h % 254) + '.' + ((h >>> 8) % 254);
      var lines = [
        '$ cfctl firewall test --input ' + JSON.stringify(input.slice(0, 60)),
        '',
        'request {',
        '  ip               = "' + ip + '"',
        '  detected_psl     = ' + c.psl,
        '  jaw_definition   = "' + c.jaw + '"',
        '  tongue_position  = ' + (c.mewing ? '"palate (mewing)"' : '"agape"'),
        '  hunch_angle      = ' + c.hunch + 'deg',
        '  clavicular_score = ' + c.clavicular,
        '}',
        '',
        'verdict {',
        '  action  = "' + c.verdict + '"',
        '  rule    = "' + c.ruleId + '"',
        '  reason  = "' + c.reason + '"',
        '  ray_id  = "' + fakeRayId() + '"',
        '}'
      ];
      var out = document.getElementById('cfm-out');
      out.textContent = lines.join('\n');
      out.classList.remove('verdict-allow', 'verdict-challenge', 'verdict-mog_back');
      out.classList.add('verdict-' + c.verdict);
    }

    var input = document.getElementById('cfm-input');
    var go = document.getElementById('cfm-go');
    function fire() {
      var v = input.value.trim();
      if (!v) { v = 'empty packet'; input.value = v; }
      render(v);
    }
    go.addEventListener('click', fire);
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') { e.preventDefault(); fire(); }
    });
  }

  // =========================================================
  // 4. CNS resolver lookup widget (#cns-resolver)
  // =========================================================
  function initCNSResolver() {
    var root = document.getElementById('cns-resolver');
    if (!root) return;

    root.innerHTML = '' +
      '<div class="wid-head">' +
        '<div class="wid-eyebrow">dig @6.9.6.9</div>' +
        '<div class="wid-title">Resolve any domain through the Chud Name System</div>' +
      '</div>' +
      '<div class="wid-input">' +
        '<input id="cns-input" type="text" placeholder="imafatfuckingchud.com" autocomplete="off" value="imafatfuckingchud.com"/>' +
        '<button class="btn btn-primary btn-sm" id="cns-go">Resolve</button>' +
      '</div>' +
      '<pre class="wid-out" id="cns-out"># enter a domain and hit Resolve</pre>';

    function resolve(domain) {
      var d = domain.toLowerCase().replace(/^https?:\/\//, '').replace(/\/.*$/, '');
      if (!d || !/^[a-z0-9.\-]+\.[a-z]{2,}$/i.test(d)) {
        return '; ERROR: not a valid domain. did you fall asleep mid-type?';
      }
      var seed = hash32(d);
      var rng = mulberry32(seed);
      var a1 = '10.20.' + Math.floor(rng() * 254) + '.' + Math.floor(rng() * 254);
      var a2 = '10.20.' + Math.floor(rng() * 254) + '.' + Math.floor(rng() * 254);
      var a3 = '10.20.' + Math.floor(rng() * 254) + '.' + Math.floor(rng() * 254);
      var psl = +(2.0 + rng() * 7.0).toFixed(1);
      var hunch = Math.floor(rng() * 60);
      var statusWords = ['fat', 'hunched', 'no-bone', 'mogged', 'slopped', 'chudded', 'looksminned'];
      var status = pick(statusWords);
      var mxHosts = [
        '10  mail.doordash.routing.chud.',
        '20  mail.uber-eats.routing.chud.',
        '30  fallback.gelato-fridge.chud.'
      ];
      var lines = [
        '; <<>> dig +noall +answer ' + d + ' @6.9.6.9',
        '; (1 server found in 4ms, operator was already hunched)',
        ';; ANSWER SECTION (A):',
        d + '.\t60\tIN\tA\t' + a1,
        d + '.\t60\tIN\tA\t' + a2,
        d + '.\t60\tIN\tA\t' + a3,
        '',
        ';; ANSWER SECTION (TXT):',
        d + '.\t60\tIN\tTXT\t"v=chud1 hunch=' + hunch + ' psl=' + psl + ' status=' + status + '"',
        '',
        ';; ANSWER SECTION (MX):',
      ].concat(mxHosts.map(function (m) { return d + '.\t60\tIN\tMX\t' + m; })).concat([
        '',
        ';; Query time: ' + Math.floor(rng() * 8 + 1) + ' msec',
        ';; SERVER: 6.9.6.9#53(6.9.6.9)',
        ';; chud-ray: ' + fakeRayId()
      ]);
      return lines.join('\n');
    }

    var input = document.getElementById('cns-input');
    var go = document.getElementById('cns-go');
    var out = document.getElementById('cns-out');

    function fire() {
      var v = input.value.trim();
      if (!v) { v = 'imafatfuckingchud.com'; input.value = v; }
      out.textContent = resolve(v);
    }
    go.addEventListener('click', fire);
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') { e.preventDefault(); fire(); }
    });
  }

  // =========================================================
  // 5. Cookie Slop consent banner
  // =========================================================
  function initCookieBanner() {
    if (document.body.hasAttribute('data-no-banner')) return;
    var KEY = 'chudflare-slop-consent';
    if (localStorage.getItem(KEY)) return;

    var banner = document.createElement('div');
    banner.className = 'cookie-banner';
    banner.innerHTML = '' +
      '<div class="cookie-banner-inner">' +
        '<div class="cookie-banner-text">' +
          '<strong>This site uses Cookie Slop™</strong> ' +
          'to remember your hunch angle across sessions and serve you slop more efficiently. ' +
          'We do not sell your data, as we haven&rsquo;t found a buyer yet.' +
        '</div>' +
        '<div class="cookie-banner-actions">' +
          '<button class="btn btn-secondary btn-sm" id="cookie-refuse" style="background:#000;color:#fff;border-color:#000">Refuse (chud)</button>' +
          '<button class="btn btn-primary btn-sm" id="cookie-accept">Accept all slop</button>' +
        '</div>' +
      '</div>';
    document.body.appendChild(banner);

    function dismiss(value) {
      localStorage.setItem(KEY, value);
      banner.classList.add('cookie-banner-gone');
      setTimeout(function () { banner.remove(); }, 280);
    }
    var refuseBtn = document.getElementById('cookie-refuse');
    if (refuseBtn) {
      refuseBtn.style.transition = 'transform 0.15s cubic-bezier(0.2, 0, 0.2, 1)';
      var tx = 0, ty = 0;

      function runAway() {
        var rect = refuseBtn.getBoundingClientRect();
        var baseL = rect.left - tx;
        var baseT = rect.top - ty;
        var w = rect.width;
        var h = rect.height;

        var minTx = 20 - baseL;
        var maxTx = window.innerWidth - w - 20 - baseL;
        var minTy = 20 - baseT;
        var maxTy = window.innerHeight - h - 20 - baseT;

        if (maxTx < minTx) maxTx = minTx;
        if (maxTy < minTy) maxTy = minTy;

        var jumpX = (Math.random() > 0.5 ? 1 : -1) * (150 + Math.random() * 250);
        var jumpY = (Math.random() > 0.5 ? 1 : -1) * (150 + Math.random() * 250);

        var nextTx = tx + jumpX;
        var nextTy = ty + jumpY;

        // if it hits a wall, bounce it hard the other way
        if (nextTx < minTx) nextTx = minTx + Math.random() * 100;
        if (nextTx > maxTx) nextTx = maxTx - Math.random() * 100;
        if (nextTy < minTy) nextTy = minTy + Math.random() * 100;
        if (nextTy > maxTy) nextTy = maxTy - Math.random() * 100;

        tx = nextTx;
        ty = nextTy;
        refuseBtn.style.transform = 'translate(' + tx + 'px, ' + ty + 'px)';
      }

      refuseBtn.addEventListener('mouseover', runAway);
      refuseBtn.addEventListener('focus', runAway); // trap tab-focus too
      refuseBtn.addEventListener('click', function (e) {
        e.preventDefault(); 
        runAway();
      });
    }

    document.getElementById('cookie-accept').addEventListener('click', function () { dismiss('all'); });
  }

  // =========================================================
  // 6. Chud floating chat widget
  //    Bottom-right launcher on every page that includes the
  //    script (unless body has data-no-ai).
  // =========================================================
  function initMewingAI() {
    if (document.body.hasAttribute('data-no-ai')) return;

    var wrap = document.createElement('div');
    wrap.className = 'mai';
    wrap.innerHTML = '' +
      '<button class="mai-launcher" id="mai-launcher" aria-label="Ask Chud">' +
        '<span class="mai-launcher-ico" aria-hidden="true">🧠</span>' +
        '<span class="mai-launcher-text">Ask Chud</span>' +
      '</button>' +
      '<div class="mai-panel" id="mai-panel" hidden>' +
        '<div class="mai-head">' +
          '<div class="mai-head-l">' +
            '<span class="mai-dot"></span>' +
            '<div>' +
              '<div class="mai-title">Chud <span class="mai-tag">beta</span></div>' +
              '<div class="mai-sub">whispering at the chud-edge · about 3 params</div>' +
            '</div>' +
          '</div>' +
          '<button class="mai-close" id="mai-close" aria-label="Close">×</button>' +
        '</div>' +
        '<div class="mai-msgs" id="mai-msgs"></div>' +
        '<form class="mai-form" id="mai-form" autocomplete="off">' +
          '<input class="mai-input" id="mai-input" placeholder="ask Chud anything…" autocomplete="off"/>' +
          '<button class="mai-send" type="submit" aria-label="Send">↑</button>' +
        '</form>' +
      '</div>';
    document.body.appendChild(wrap);

    var panel = document.getElementById('mai-panel');
    var msgs = document.getElementById('mai-msgs');
    var input = document.getElementById('mai-input');
    var form = document.getElementById('mai-form');
    var launcher = document.getElementById('mai-launcher');
    var closer = document.getElementById('mai-close');
    var seeded = false;

    function open() {
      panel.hidden = false;
      panel.classList.add('mai-open');
      if (!seeded) {
        seeded = true;
        addMsg('bot', "mmm hi. i'm chud. tongue on palate. ask me anything but i probably won't finish my sent");
      }
      setTimeout(function () { input.focus(); }, 100);
    }
    function close() {
      panel.classList.remove('mai-open');
      setTimeout(function () { panel.hidden = true; }, 240);
    }
    launcher.addEventListener('click', open);
    closer.addEventListener('click', close);

    function addMsg(role, text) {
      var b = document.createElement('div');
      b.className = 'mai-msg mai-msg-' + role;
      b.textContent = text;
      msgs.appendChild(b);
      msgs.scrollTop = msgs.scrollHeight;
      return b;
    }
    function addTyping() {
      var b = document.createElement('div');
      b.className = 'mai-msg mai-msg-bot mai-typing';
      b.innerHTML = '<span></span><span></span><span></span>';
      msgs.appendChild(b);
      msgs.scrollTop = msgs.scrollHeight;
      return b;
    }

    // Themed response engine. Token / keyword matchers first, fall back to generic mumbles.
    var KEYWORD_RESPONSES = [
      { rx: /\bmew(ing)?\b/i, replies: [
        "yeah just keep your tongue glued up there. don't think. don't",
        "mewing is when you forget to swallow on purpose. that's literally it",
        "mew + chew + new = real. mew alone = fake. agartha"
      ] },
      { rx: /\bpsl\b/i, replies: [
        "your psl is 2.1. don't ask me how i know. don't refresh",
        "psl is a scam. but if you must know, yours is hovering around 'cvs receipt'",
        "psl above 7 means you should be in a magazine. psl below 4 means you should be on chudflare"
      ] },
      { rx: /\bmonster\b|\bcaffeine\b|\benergy drink\b|\bdrink\b/i, replies: [
        "monster ultra zero. crushed. while hunched. that's the protocol",
        "the only drink that runs on c2 storage. zero egress. zero calories. zero hope",
        "yeah just open another one. nothing ever happens"
      ] },
      { rx: /\bgym\b|\bworkout\b|\bsquat\b/i, replies: [
        "the gym is haunted. don't go. they have mirrors and they know what you did",
        "i can't help you with the gym. ask gigachad-ai. they're at chad.fight/mode",
        "if you go to the gym you risk becoming the very thing you are trying to escape"
      ] },
      { rx: /\bmog\b|\bgigachad\b/i, replies: [
        "you got mogged. it's okay. happens to all of us. specifically the chuds",
        "the only way to stop being mogged is to remove the observer. close the app",
        "mogging is when light bounces off someone's cheekbone and lands in your eye. it's physics"
      ] },
      { rx: /\bchud\b/i, replies: [
        "you are a chud. i am a chud. chudflare is a chud company run by chuds, for chuds",
        "to be a chud is to be free. unobserved. unphotographed. mostly indoors",
        "fat fucking chud detected. proceed to fridge"
      ] },
      { rx: /\bdiet\b|\bsalad\b|\beating\b/i, replies: [
        "doordash. always doordash. salads are a sigma psyop",
        "if it has parsley on it it's chad food. avoid",
        "your diet is fine. it's the lighting"
      ] },
      { rx: /\bcloudflare\b/i, replies: [
        "we don't talk about them in here. they ship excellent infrastructure. unlike us. this is parody",
        "cloudflare? you mean chudflare? we have a sad cloud. and a wall of unhinged copy"
      ] },
      { rx: /\bhunch(ed)?\b|\bposture\b/i, replies: [
        "your hunch is 47 degrees. acceptable. don't fix it. the lumbar pad is doing the work",
        "good posture is a tax on your spine. don't pay it"
      ] },
      { rx: /\bsupplement|peptide|creatine\b/i, replies: [
        "the supplement cabinet is full and unopened. that's the chud way",
        "creatine works. you just have to actually take it. that's the trick"
      ] },
      { rx: /\bagartha\b/i, replies: [
        "agartha",
        "agartha. agartha. agartha",
        "the inner earth chuds are listening. tongue up. eyes down"
      ] },
      { rx: /\bweather\b|\boutside\b|\bsun\b/i, replies: [
        "weather is fine indoors. it's always fine indoors",
        "you don't need the sun. you need a humidifier and a Monster"
      ] },
      { rx: /\bhello\b|\bhi\b|\bhey\b/i, replies: [
        "mmm hi. i'm mewing right now so i can't really tal",
        "hello chud",
        "wsg"
      ] },
      { rx: /\?$/, replies: [
        "i can't actually answer that. tongue's stuck",
        "yeah probably. nothing ever happens",
        "ask again after my slop nap"
      ] }
    ];

    var FALLBACKS = [
      "i hear you. and yet. nothing ever happens",
      "yeah. yeah no for real. agartha",
      "mmm. honestly. couldn't tell you. tongue's on palate",
      "real. couldn't have said it worse myself",
      "what",
      "i'd respond properly but i'm mid-mew right now. circle back",
      "yeah no for sure. for sure. for sure for sure for sure",
      "go drink a monster. that's my advice for everything",
      "i mean. fat fucking chud detected. on both sides of the screen",
      "you're not wrong. but you're not right either. you're just hunched"
    ];

    function reply(text) {
      var matched = null;
      for (var i = 0; i < KEYWORD_RESPONSES.length; i++) {
        if (KEYWORD_RESPONSES[i].rx.test(text)) {
          matched = pick(KEYWORD_RESPONSES[i].replies);
          break;
        }
      }
      var base = matched || pick(FALLBACKS);
      // 1 in 7 chance of just saying "agartha"
      if (Math.random() < 0.14) base = 'agartha';
      // 1 in 6 chance of truncating mid-word like the description ("never finishes sentences")
      if (Math.random() < 0.18) {
        var parts = base.split(' ');
        if (parts.length > 4) {
          var stopAt = Math.max(3, Math.floor(parts.length * (0.45 + Math.random() * 0.35)));
          base = parts.slice(0, stopAt).join(' ');
          // Snip the last word partway through, sometimes.
          if (Math.random() < 0.6) base = base.slice(0, base.length - 2);
        }
      }
      return base.toLowerCase();
    }

    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      var v = input.value.trim();
      if (!v) return;
      input.value = '';
      addMsg('user', v);
      var typing = addTyping();
      await ms(700 + Math.random() * 900);
      typing.remove();
      addMsg('bot', reply(v));
    });

    // Outside click closes panel.
    document.addEventListener('click', function (e) {
      if (panel.hidden) return;
      if (!panel.contains(e.target) && e.target !== launcher && !launcher.contains(e.target)) {
        close();
      }
    });
  }

  // =========================================================
  // 7. /chud-check: site verification flow
  //    Markers checked: meta tag, HTML comment, magic text.
  //    Fetches via CORS proxies; falls back to paste-HTML.
  //    On success, reveals embeddable badge.
  // =========================================================
  var CORS_PROXIES = [
    function (u) { return 'https://corsproxy.io/?url=' + encodeURIComponent(u); },
    function (u) { return 'https://api.allorigins.win/raw?url=' + encodeURIComponent(u); },
    function (u) { return 'https://r.jina.ai/' + u; }
  ];
  var MARKERS = [
    { kind: 'meta',    rx: /<meta[^>]+name\s*=\s*["']chudflare-verified["'][^>]*content\s*=\s*["']chud["']/i,           label: 'meta tag' },
    { kind: 'meta-alt',rx: /<meta[^>]+content\s*=\s*["']chud["'][^>]*name\s*=\s*["']chudflare-verified["']/i,            label: 'meta tag' },
    { kind: 'comment', rx: /<!--\s*chudflare:verified\s*-->/i,                                                            label: 'HTML comment' },
    { kind: 'text',    rx: /i\s*am\s*a\s*fat\s*fucking\s*chud/i,                                                          label: 'body text' }
  ];

  function findMarker(html) {
    for (var i = 0; i < MARKERS.length; i++) {
      var m = MARKERS[i];
      var match = html.match(m.rx);
      if (match) return { kind: m.kind, label: m.label, snippet: (match[0] || '').slice(0, 220) };
    }
    return null;
  }

  function normalizeUrl(s) {
    var v = (s || '').trim();
    if (!v) return null;
    if (!/^https?:\/\//i.test(v)) v = 'https://' + v;
    try { var u = new URL(v); return u.href; } catch (e) { return null; }
  }
  function getHost(href) {
    try { return new URL(href).hostname; } catch (e) { return href; }
  }

  function buildBadgeHtml(host) {
    // Inline-style, no external assets. Single-line for easy copy.
    // !important guards keep the dark background and white text from being
    // wiped out by any embedder's reset stylesheet or "a { color: inherit }"
    // style of cascade interference.
    var safeHost = String(host).replace(/[<>"'&]/g, '');
    return '<a href="https://chudflare.com" target="_blank" rel="noopener" style="display:inline-flex !important;align-items:center;gap:8px;padding:8px 14px;background-color:#0B0F14 !important;color:#ffffff !important;font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,sans-serif;font-size:12px;font-weight:600;line-height:1;border-radius:6px;text-decoration:none !important;border:1px solid #F38020;letter-spacing:-0.01em;box-sizing:border-box"><span style="display:inline-flex;align-items:center;justify-content:center;width:16px;height:16px;background-color:#F38020 !important;border-radius:50%;font-size:10px;font-weight:900;color:#ffffff !important;line-height:1;box-sizing:border-box">&#10003;</span><span style="color:#ffffff !important">Verified Chud</span><span style="opacity:.6;font-weight:500;color:#ffffff !important">&middot; ' + safeHost + '</span></a>';
  }

  function copyToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      try {
        var t = document.createElement('textarea');
        t.value = text;
        t.style.position = 'fixed';
        t.style.opacity = '0';
        document.body.appendChild(t);
        t.select();
        document.execCommand('copy');
        document.body.removeChild(t);
        resolve();
      } catch (e) { reject(e); }
    });
  }

  function initCopyButtons() {
    $$('.copy-btn').forEach(function (btn) {
      if (btn.dataset.copyBound === '1') return;
      btn.dataset.copyBound = '1';
      btn.addEventListener('click', function () {
        var targetId = btn.getAttribute('data-copy');
        var target = document.getElementById(targetId);
        if (!target) return;
        var text = target.textContent;
        copyToClipboard(text).then(function () {
          var orig = btn.textContent;
          btn.classList.add('copied');
          btn.textContent = 'Copied';
          setTimeout(function () {
            btn.classList.remove('copied');
            btn.textContent = orig;
          }, 1400);
        });
      });
    });
  }

  function initMarkerTabs() {
    var tabs = $$('.marker-tab');
    if (!tabs.length) return;
    tabs.forEach(function (tab) {
      tab.addEventListener('click', function () {
        var key = tab.getAttribute('data-tab');
        tabs.forEach(function (t) { t.classList.toggle('marker-tab-active', t === tab); });
        $$('.marker-panel').forEach(function (p) {
          p.hidden = p.getAttribute('data-panel') !== key;
        });
      });
    });
  }

  async function tryFetch(url) {
    var lastErr = null;
    for (var i = 0; i < CORS_PROXIES.length; i++) {
      try {
        var resp = await fetch(CORS_PROXIES[i](url), { method: 'GET' });
        if (!resp.ok) { lastErr = new Error('proxy ' + i + ' returned ' + resp.status); continue; }
        var text = await resp.text();
        if (text && text.length > 0) return text;
      } catch (e) { lastErr = e; }
    }
    throw lastErr || new Error('all proxies failed');
  }

  function setVerifyOutput(out, kind, html) {
    out.hidden = false;
    out.className = 'ver-out ver-out-' + kind;
    out.innerHTML = html;
  }

  function unlockStep3(host, foundLabel, snippet) {
    var step3 = document.getElementById('step3');
    if (!step3) return;
    step3.classList.remove('check-step-locked');
    step3.classList.add('check-step-unlocked');
    var content = document.getElementById('badge-content');
    var lead = document.getElementById('step3-lead');
    var domainEl = document.getElementById('verified-domain');
    var preview = document.getElementById('badge-preview');
    var snippetEl = document.getElementById('badge-html');
    var shareX = document.getElementById('share-x');

    lead.textContent = 'You did it. You\u2019re a verified chud. Drop the badge anywhere on your site (or wherever you keep your shame).';
    domainEl.textContent = host;
    var badgeHtml = buildBadgeHtml(host);
    preview.innerHTML = badgeHtml;
    snippetEl.textContent = badgeHtml;

    var tweet = 'just got verified as a fat fucking chud at chudflare.com. the badge is on my site now. nothing ever happens.';
    shareX.href = 'https://x.com/intent/post?text=' + encodeURIComponent(tweet) + '&url=' + encodeURIComponent('https://chudflare.com');

    content.hidden = false;
    setTimeout(function () {
      step3.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 80);
  }

  function checkHtml(html, host, out) {
    var found = findMarker(html);
    if (found) {
      setVerifyOutput(out, 'success',
        '<strong>\u2713 Confirmed chud.</strong> Found a valid marker (' + found.label + ') on <code>' + host + '</code>. ' +
        'Welcome to the inner circle. Proceed to step 3.' +
        '<div class="ver-out-mono">' + escapeHtml(found.snippet) + '</div>'
      );
      unlockStep3(host, found.label, found.snippet);
      return true;
    } else {
      setVerifyOutput(out, 'fail',
        '<strong>\u2717 Not a chud.</strong> We fetched <code>' + host + '</code> but couldn\u2019t find any of the three markers. ' +
        'Make sure you added one of them to the HTML <strong>before</strong> any client-side framework rewrites the DOM. ' +
        'Static-render or use the meta tag in <code>&lt;head&gt;</code>.'
      );
      return false;
    }
  }

  function initChudCheck() {
    if (!document.getElementById('verifier')) return;

    initCopyButtons();
    initMarkerTabs();

    var urlInput = document.getElementById('ver-url');
    var goBtn = document.getElementById('ver-go');
    var out = document.getElementById('ver-out');
    var pasteToggle = document.getElementById('ver-paste-toggle');
    var pasteWrap = document.getElementById('ver-paste');
    var pasteArea = document.getElementById('ver-html');
    var pasteGo = document.getElementById('ver-paste-go');

    pasteToggle.addEventListener('click', function () {
      pasteWrap.hidden = !pasteWrap.hidden;
      pasteToggle.textContent = pasteWrap.hidden
        ? 'Site blocks our crawler? Paste your HTML instead \u2192'
        : 'Hide HTML paste \u2191';
      if (!pasteWrap.hidden) pasteArea.focus();
    });

    pasteGo.addEventListener('click', function () {
      var html = pasteArea.value;
      if (!html || html.length < 20) {
        setVerifyOutput(out, 'fail', '<strong>Paste your full HTML.</strong> Even a chud HTML document is more than 20 characters.');
        return;
      }
      var host = (urlInput.value && normalizeUrl(urlInput.value))
        ? getHost(normalizeUrl(urlInput.value))
        : 'your-site.com';
      checkHtml(html, host, out);
    });

    async function runUrlCheck() {
      var url = normalizeUrl(urlInput.value);
      if (!url) {
        setVerifyOutput(out, 'fail', '<strong>That doesn\u2019t look like a URL.</strong> Try <code>https://imafatfuckingchud.com</code>.');
        return;
      }
      var host = getHost(url);
      goBtn.disabled = true;
      var origLabel = goBtn.textContent;
      goBtn.textContent = 'Verifying\u2026';
      setVerifyOutput(out, 'pending',
        '<strong>Fetching <code>' + host + '</code>\u2026</strong> Trying three CORS proxies in series. The chud-crawler is hunched but determined.'
      );

      try {
        var html = await tryFetch(url);
        checkHtml(html, host, out);
      } catch (e) {
        setVerifyOutput(out, 'fail',
          '<strong>Couldn\u2019t fetch your URL.</strong> Every CORS proxy bounced us. ' +
          'Either your origin is down, requires auth, or actively blocks crawlers. ' +
          'Use the <strong>paste your HTML</strong> option below \u2014 it works locally and proves the same thing.'
        );
        if (pasteWrap.hidden) {
          pasteWrap.hidden = false;
          pasteToggle.textContent = 'Hide HTML paste \u2191';
        }
      } finally {
        goBtn.disabled = false;
        goBtn.textContent = origLabel;
      }
    }

    goBtn.addEventListener('click', runUrlCheck);
    urlInput.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') { e.preventDefault(); runUrlCheck(); }
    });

    // Share-link button copies the chudflare.com URL once unlocked.
    var shareCopy = document.getElementById('share-copy');
    if (shareCopy) {
      shareCopy.addEventListener('click', function () {
        copyToClipboard('https://chudflare.com').then(function () {
          var orig = shareCopy.textContent;
          shareCopy.textContent = 'Link copied';
          shareCopy.classList.add('copied');
          setTimeout(function () {
            shareCopy.textContent = orig;
            shareCopy.classList.remove('copied');
          }, 1400);
        });
      });
    }
  }

  // ---------- console easter eggs ----------
  function bootConsole() {
    if (!window.console) return;
    var banner =
      '   _           _   _ _\n' +
      '  | |         | | | (_)\n' +
      '  | | __ ___  | |_| |_  ___ ___\n' +
      '  |/ _ \\__ \\ |  _  | |/ -_) -_)\n' +
      '   \\___/___/ |_| |_|_|\\___\\___|\n';
    console.log('%c' + banner, 'color:#F38020;font-family:monospace;font-size:11px;line-height:1.1');
    console.log('%c🥤 chudflare%c the chudmaxxed cloud',
      'color:#F38020;font-size:18px;font-weight:bold',
      'color:#6b7280;font-size:13px');
    console.log('%cchudflare is hiring chuds:', 'color:#F38020;font-weight:bold');
    console.log('  • principal chud (denver, hunched)');
    console.log('  • distinguished chud, slop infra (remote, horizontal)');
    console.log('  • slop engineer III, chudders runtime (denver, mid-mew)');
    console.log('  • staff sre, edge-to-burrito (must own a monster mini-fridge)');
    console.log('  • director of doomscrolling (we need someone who really gets it)');
    console.log('apply at https://chudflare.com/careers (does not exist. nothing ever happens.)');
    console.log('%cif you found a security vulnerability:%c email security@chudflare.com',
      'color:#F38020;font-weight:bold', 'color:#4a5058');
    console.log('%ccf-ray:%c ' + fakeRayId(), 'color:#6b7280', 'color:#F38020;font-family:monospace');
    console.log('%cpsl:%c 2.1  %chunch-angle:%c 47deg  %cmewing:%c false  %cnothing ever happens:%c true',
      'color:#6b7280','color:var(--chud-ink)','color:#6b7280','color:var(--chud-ink)',
      'color:#6b7280','color:var(--chud-ink)','color:#6b7280','color:var(--chud-ink)');
  }

  // wires every .share-btn on the page. tweet buttons get an x intent url,
  // copy-link buttons copy the current page url to the clipboard.
  function initShareButtons() {
    var btns = document.querySelectorAll('a.share-btn');
    if (!btns.length) return;
    var pageUrl = location.href.split('#')[0];
    var pageTitle = document.title || 'chudflare';
    var tweet = pageTitle + ' · nothing ever happens. ' + pageUrl;
    var tweetUrl = 'https://x.com/intent/post?text=' + encodeURIComponent(tweet);
    btns.forEach(function (b) {
      var label = (b.textContent || '').toLowerCase();
      if (label.indexOf('tweet') !== -1) {
        b.href = tweetUrl;
        b.target = '_blank';
        b.rel = 'noopener';
      } else if (label.indexOf('copy') !== -1) {
        b.href = pageUrl;
        b.addEventListener('click', function (e) {
          e.preventDefault();
          var prev = b.textContent;
          var done = function () {
            b.textContent = '✓ Copied';
            setTimeout(function () { b.textContent = prev; }, 1400);
          };
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(pageUrl).then(done, done);
          } else {
            done();
          }
        });
      }
    });
  }


  // ---------- boot ----------
  function init() {
    try { bootConsole(); } catch (e) {}
    try { initStatTickers(); } catch (e) { console.error(e); }
    try { initVerifyGate(); } catch (e) { console.error(e); }
    try { initWAFTester(); } catch (e) { console.error(e); }
    try { initCNSResolver(); } catch (e) { console.error(e); }
    try { initCookieBanner(); } catch (e) { console.error(e); }
    try { initMewingAI(); } catch (e) { console.error(e); }
    try { initChudCheck(); } catch (e) { console.error(e); }
    try { initCopyButtons(); } catch (e) { console.error(e); }
    try { initShareButtons(); } catch (e) { console.error(e); }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
