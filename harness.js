// Menalars test harness — loads the game's <script> into a Node vm with a minimal fake DOM.
const fs = require("fs");
const vm = require("vm");
function extractScript(html){
  const m = html.match(/<script>([\s\S]*)<\/script>/);
  if(!m) throw new Error("no <script> block found");
  return m[1];
}
function makeClassList(){
  const set = new Set();
  return {
    add: (...c) => c.forEach(x => set.add(x)),
    remove: (...c) => c.forEach(x => set.delete(x)),
    toggle: (c, force) => { const on = force === undefined ? !set.has(c) : !!force; on ? set.add(c) : set.delete(c); return on; },
    contains: c => set.has(c),
    _set: set
  };
}
function makeCtx(){
  const base = {
    measureText: t => ({ width: String(t).length * 7 }),
    createLinearGradient: () => ({ addColorStop(){} }),
    createRadialGradient: () => ({ addColorStop(){} }),
    createPattern: () => ({}),
    getImageData: () => ({ data: new Uint8ClampedArray(4) }),
    canvas: { width: 800, height: 600 }
  };
  return new Proxy(base, { get: (t, k) => (k in t ? t[k] : () => {}) });
}
function makeEl(tag, id){
  const listeners = {};
  const el = {
    tagName: (tag || "div").toUpperCase(), id: id || "", className: "",
    style: { setProperty(k, v){ this[k] = v; }, removeProperty(k){ delete this[k]; }, getPropertyValue(k){ return this[k] || ""; } }, dataset: {}, classList: makeClassList(), children: [], parentNode: null,
    hidden: false, disabled: false, checked: false, value: "", title: "", draggable: false,
    textContent: "", width: 800, height: 600, _html: "",
    get innerHTML(){ return el._html; },
    set innerHTML(v){ el._html = String(v); el.children = []; },
    _listeners: listeners,
    addEventListener(t, f){ (listeners[t] = listeners[t] || []).push(f); },
    removeEventListener(t, f){ if(listeners[t]) listeners[t] = listeners[t].filter(x => x !== f); },
    dispatch(t, ev){ (listeners[t] || []).forEach(f => f(Object.assign({ preventDefault(){}, stopPropagation(){}, target: el }, ev))); },
    appendChild(c){ c.parentNode = el; el.children.push(c); return c; },
    removeChild(c){ el.children = el.children.filter(x => x !== c); return c; },
    remove(){ if(el.parentNode) el.parentNode.removeChild(el); },
    _q: {},
    querySelector(sel){
      if(el._strict){ const cls = sel.replace(/^\./, ""); return el.children.find(c => c.className.split(" ").includes(cls)) || null; }
      return el._q[sel] || (el._q[sel] = makeEl("div"));
    },
    querySelectorAll(){ return []; },
    closest(){ return null; },
    setAttribute(k, v){ el[k] = v; }, getAttribute(k){ return el[k]; },
    focus(){}, blur(){}, click(){ el.dispatch("click", {}); },
    getContext(){ return el._ctx || (el._ctx = makeCtx()); },
    getBoundingClientRect(){ return { left: 0, top: 0, width: el.width, height: el.height, right: el.width, bottom: el.height }; },
    scrollIntoView(){}
  };
  return el;
}
function loadGame(htmlPath, opts = {}){
  const html = fs.readFileSync(htmlPath, "utf8");
  const code = extractScript(html);
  const clock = { t: 10000, advance(ms){ this.t += ms; return this.t; } };
  const byId = {};
  const getById = id => byId[id] || (byId[id] = makeEl("div", id));
  const skillBtns = [...Array(8)].map((_, i) => {
    const b = makeEl("button"); b.className = "skill-btn"; b.dataset.slot = String(i); b._strict = true;
    const c = makeEl("div"); c.className = "skill-content"; b.appendChild(c);
    return b;
  });
  const logs = [];
  const document = {
    getElementById: getById,
    querySelector: () => makeEl(),
    querySelectorAll: sel => (sel.includes("skill-btn") ? skillBtns : []),
    createElement: tag => makeEl(tag),
    createTextNode: t => Object.assign(makeEl("#text"), { textContent: String(t) }),
    addEventListener(){}, body: makeEl("body"), documentElement: makeEl("html"),
    visibilityState: "visible", hidden: false
  };
  const windowListeners = {};
  const fakeAudioNode = () => new Proxy({}, { get: (t, k) => (k in t ? t[k] : (k === "gain" || k === "frequency" || k === "detune" || k === "Q" || k === "playbackRate") ? { value: 0, setValueAtTime(){}, linearRampToValueAtTime(){}, exponentialRampToValueAtTime(){}, cancelScheduledValues(){} } : () => fakeAudioNode()) });
  class AudioContext { constructor(){ this.currentTime = 0; this.destination = {}; this.state = "running"; this.sampleRate = 44100; }
    createOscillator(){ return fakeAudioNode(); } createGain(){ const n = fakeAudioNode(); n.context = this; return n; }
    createBiquadFilter(){ return fakeAudioNode(); } createBufferSource(){ return fakeAudioNode(); }
    createBuffer(){ return { getChannelData: () => new Float32Array(4410) }; } resume(){ return Promise.resolve(); } }
  // v43: fake <audio> — records what the game asks it to play
  const audios = [];
  class Audio { constructor(src){ this.src = src || ""; this._attr = src ? { src } : {}; this.paused = true; this.currentTime = 0; this.duration = 180; this.volume = 1; this.dataset = {}; this._l = {}; audios.push(this); }
    set src(v){ this._src = v; if(this._attr) this._attr.src = v; } get src(){ return this._src; }
    getAttribute(k){ return this._attr[k]; }
    play(){ this.paused = false; return Promise.resolve(); } pause(){ this.paused = true; }
    addEventListener(t, f){ (this._l[t] = this._l[t] || []).push(f); } }
  const ctx = {
    console: opts.quiet === false ? console : { log: (...a) => logs.push(a.join(" ")), warn: (...a) => logs.push(a.join(" ")), error: (...a) => logs.push("ERROR " + a.join(" ")), info(){} },
    document,
    performance: { now: () => clock.t },
    requestAnimationFrame: () => 0, cancelAnimationFrame(){},
    setTimeout: (f) => 0, clearTimeout(){}, setInterval: () => 0, clearInterval(){},
    localStorage: { _s: {}, getItem(k){ return this._s[k] ?? null; }, setItem(k, v){ this._s[k] = String(v); }, removeItem(k){ delete this._s[k]; } },
    AudioContext, webkitAudioContext: AudioContext, Audio,
    fetch: () => Promise.reject(new Error("no fetch in harness")), location: { protocol: "https:" },
    innerWidth: 1280, innerHeight: 720, devicePixelRatio: 1,
    addEventListener(t, f){ (windowListeners[t] = windowListeners[t] || []).push(f); },
    removeEventListener(){},
    Math: Object.create(Math), JSON, Date: Object.assign(function(...a){ return new Date(...(a.length ? a : [1.7e12 + clock.t])); }, { now: () => 1.7e12 + clock.t, parse: Date.parse, UTC: Date.UTC }), Set, Map, Array, Object, Number, String, Boolean, Promise, Proxy,
    Uint8ClampedArray, Float32Array, parseInt, parseFloat, isNaN, isFinite, Infinity, NaN
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(code, ctx, { filename: "game-script.js" });
  return {
    ctx, clock, logs, skillBtns, audios, byId: getById,
    run: src => vm.runInContext(src, ctx),
    get: expr => vm.runInContext(expr, ctx),
    fireWindow(type, ev){ (windowListeners[type] || []).forEach(f => f(Object.assign({ preventDefault(){}, stopPropagation(){} }, ev))); },
    errors: () => logs.filter(l => l.startsWith("ERROR"))
  };
}
module.exports = { loadGame, extractScript };
