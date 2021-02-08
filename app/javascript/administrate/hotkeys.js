/*! hotkeys-js v3.8.1 | MIT (c) 2021 kenny wong <wowohoo@qq.com> | http://jaywcjlove.github.io/hotkeys */
!function (e, t) {
  "object" == typeof exports && "undefined" != typeof module ? module.exports = t() : "function" == typeof define && define.amd ? define(t) : (e = e || self).hotkeys = t()
}(this, function () {
  "use strict";
  var e = "undefined" != typeof navigator && 0 < navigator.userAgent.toLowerCase().indexOf("firefox");

  function p(e, t, n) {
    e.addEventListener ? e.addEventListener(t, n, !1) : e.attachEvent && e.attachEvent("on".concat(t), function () {
      n(window.event)
    })
  }

  function y(e, t) {
    for (var n = t.slice(0, t.length - 1), o = 0; o < n.length; o++) n[o] = e[n[o].toLowerCase()];
    return n
  }

  function d(e) {
    "string" != typeof e && (e = "");
    for (var t = (e = e.replace(/\s/g, "")).split(","), n = t.lastIndexOf(""); 0 <= n;) t[n - 1] += ",", t.splice(n, 1), n = t.lastIndexOf("");
    return t
  }

  for (var t = {
    backspace: 8,
    tab: 9,
    clear: 12,
    enter: 13,
    return: 13,
    esc: 27,
    escape: 27,
    space: 32,
    left: 37,
    up: 38,
    right: 39,
    down: 40,
    del: 46,
    delete: 46,
    ins: 45,
    insert: 45,
    home: 36,
    end: 35,
    pageup: 33,
    pagedown: 34,
    capslock: 20,
    "\u21ea": 20,
    ",": 188,
    ".": 190,
    "/": 191,
    "`": 192,
    "-": e ? 173 : 189,
    "=": e ? 61 : 187,
    ";": e ? 59 : 186,
    "'": 222,
    "[": 219,
    "]": 221,
    "\\": 220
  }, u = {
    "\u21e7": 16,
    shift: 16,
    "\u2325": 18,
    alt: 18,
    option: 18,
    "\u2303": 17,
    ctrl: 17,
    control: 17,
    "\u2318": 91,
    cmd: 91,
    command: 91
  }, h = {
    16: "shiftKey",
    18: "altKey",
    17: "ctrlKey",
    91: "metaKey",
    shiftKey: 16,
    ctrlKey: 17,
    altKey: 18,
    metaKey: 91
  }, v = {16: !1, 18: !1, 17: !1, 91: !1}, g = {}, n = 1; n < 20; n++) t["f".concat(n)] = 111 + n;
  var w = [], o = "all", k = [], m = function (e) {
    return t[e.toLowerCase()] || u[e.toLowerCase()] || e.toUpperCase().charCodeAt(0)
  };

  function i(e) {
    o = e || "all"
  }

  function O() {
    return o || "all"
  }

  function f(e) {
    var f = e.scope, a = e.method, t = e.splitKey, c = void 0 === t ? "+" : t;
    d(e.key).forEach(function (e) {
      var t = e.split(c), n = t.length, o = t[n - 1], r = "*" === o ? "*" : m(o);
      if (g[r]) {
        f = f || O();
        var i = 1 < n ? y(u, t) : [];
        g[r] = g[r].map(function (e) {
          return a && e.method !== a || e.scope !== f || !function (e, t) {
            for (var n = e.length < t.length ? t : e, o = e.length < t.length ? e : t, r = !0, i = 0; i < n.length; i++) ~o.indexOf(n[i]) || (r = !1);
            return r
          }(e.mods, i) ? e : {}
        })
      }
    })
  }

  function K(e, t, n) {
    var o;
    if (t.scope === n || "all" === t.scope) {
      for (var r in o = 0 < t.mods.length, v) Object.prototype.hasOwnProperty.call(v, r) && (!v[r] && ~t.mods.indexOf(+r) || v[r] && !~t.mods.indexOf(+r)) && (o = !1);
      (0 !== t.mods.length || v[16] || v[18] || v[17] || v[91]) && !o && "*" !== t.shortcut || !1 === t.method(e, t) && (e.preventDefault ? e.preventDefault() : e.returnValue = !1, e.stopPropagation && e.stopPropagation(), e.cancelBubble && (e.cancelBubble = !0))
    }
  }

  function x(n) {
    var e = g["*"], t = n.keyCode || n.which || n.charCode;
    if (b.filter.call(this, n)) {
      if (93 !== t && 224 !== t || (t = 91), ~w.indexOf(t) || 229 === t || w.push(t), ["ctrlKey", "altKey", "shiftKey", "metaKey"].forEach(function (e) {
        var t = h[e];
        n[e] && !~w.indexOf(t) ? w.push(t) : !n[e] && ~w.indexOf(t) ? w.splice(w.indexOf(t), 1) : "metaKey" === e && n[e] && 3 === w.length && (n.ctrlKey || n.shiftKey || n.altKey || (w = w.slice(w.indexOf(t))))
      }), t in v) {
        for (var o in v[t] = !0, u) u[o] === t && (b[o] = !0);
        if (!e) return
      }
      for (var r in v) Object.prototype.hasOwnProperty.call(v, r) && (v[r] = n[h[r]]);
      n.getModifierState && (!n.altKey || n.ctrlKey) && n.getModifierState("AltGraph") && (~w.indexOf(17) || w.push(17), ~w.indexOf(18) || w.push(18), v[17] = !0, v[18] = !0);
      var i = O();
      if (e) for (var f = 0; f < e.length; f++) e[f].scope === i && ("keydown" === n.type && e[f].keydown || "keyup" === n.type && e[f].keyup) && K(n, e[f], i);
      if (t in g) for (var a = 0; a < g[t].length; a++) if (("keydown" === n.type && g[t][a].keydown || "keyup" === n.type && g[t][a].keyup) && g[t][a].key) {
        for (var c = g[t][a], l = c.key.split(c.splitKey), s = [], p = 0; p < l.length; p++) s.push(m(l[p]));
        s.sort().join("") === w.sort().join("") && K(n, c, i)
      }
    }
  }

  function b(e, t, n) {
    w = [];
    var o = d(e), r = [], i = "all", f = document, a = 0, c = !1, l = !0, s = "+";
    for (void 0 === n && "function" == typeof t && (n = t), "[object Object]" === Object.prototype.toString.call(t) && (t.scope && (i = t.scope), t.element && (f = t.element), t.keyup && (c = t.keyup), void 0 !== t.keydown && (l = t.keydown), "string" == typeof t.splitKey && (s = t.splitKey)), "string" == typeof t && (i = t); a < o.length; a++) r = [], 1 < (e = o[a].split(s)).length && (r = y(u, e)), (e = "*" === (e = e[e.length - 1]) ? "*" : m(e)) in g || (g[e] = []), g[e].push({
      keyup: c,
      keydown: l,
      scope: i,
      mods: r,
      shortcut: o[a],
      method: n,
      key: o[a],
      splitKey: s
    });
    void 0 !== f && !~k.indexOf(f) && window && (k.push(f), p(f, "keydown", function (e) {
      x(e)
    }), p(window, "focus", function () {
      w = []
    }), p(f, "keyup", function (e) {
      x(e), function (e) {
        var t = e.keyCode || e.which || e.charCode, n = w.indexOf(t);
        if (n < 0 || w.splice(n, 1), e.key && "meta" == e.key.toLowerCase() && w.splice(0, w.length), 93 !== t && 224 !== t || (t = 91), t in v) for (var o in v[t] = !1, u) u[o] === t && (b[o] = !1)
      }(e)
    }))
  }

  var r = {
    setScope: i, getScope: O, deleteScope: function (e, t) {
      var n, o;
      for (var r in e = e || O(), g) if (Object.prototype.hasOwnProperty.call(g, r)) for (n = g[r], o = 0; o < n.length;) n[o].scope === e ? n.splice(o, 1) : o++;
      O() === e && i(t || "all")
    }, getPressedKeyCodes: function () {
      return w.slice(0)
    }, isPressed: function (e) {
      return "string" == typeof e && (e = m(e)), !!~w.indexOf(e)
    }, filter: function (e) {
      var t = e.target || e.srcElement, n = t.tagName, o = !0;
      return !t.isContentEditable && ("INPUT" !== n && "TEXTAREA" !== n && "SELECT" !== n || t.readOnly) || (o = !1), o
    }, unbind: function (e) {
      if (e) {
        if (Array.isArray(e)) e.forEach(function (e) {
          e.key && f(e)
        }); else if ("object" == typeof e) e.key && f(e); else if ("string" == typeof e) {
          for (var t = arguments.length, n = Array(1 < t ? t - 1 : 0), o = 1; o < t; o++) n[o - 1] = arguments[o];
          var r = n[0], i = n[1];
          "function" == typeof r && (i = r, r = ""), f({key: e, scope: r, method: i, splitKey: "+"})
        }
      } else Object.keys(g).forEach(function (e) {
        return delete g[e]
      })
    }
  };
  for (var a in r) Object.prototype.hasOwnProperty.call(r, a) && (b[a] = r[a]);
  if ("undefined" != typeof window) {
    var c = window.hotkeys;
    b.noConflict = function (e) {
      return e && window.hotkeys === b && (window.hotkeys = c), b
    }, window.hotkeys = b
  }
  return b
});
