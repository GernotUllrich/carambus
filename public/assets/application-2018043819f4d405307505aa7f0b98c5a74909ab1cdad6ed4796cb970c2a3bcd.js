(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __esm = (fn2, res) => function __init() {
    return fn2 && (res = (0, fn2[__getOwnPropNames(fn2)[0]])(fn2 = 0)), res;
  };
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __export = (target, all) => {
    for (var name3 in all)
      __defProp(target, name3, { get: all[name3], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/adapters.js
  var adapters_default;
  var init_adapters = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/adapters.js"() {
      adapters_default = {
        logger: typeof console !== "undefined" ? console : void 0,
        WebSocket: typeof WebSocket !== "undefined" ? WebSocket : void 0
      };
    }
  });

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/logger.js
  var logger_default;
  var init_logger = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/logger.js"() {
      init_adapters();
      logger_default = {
        log(...messages) {
          if (this.enabled) {
            messages.push(Date.now());
            adapters_default.logger.log("[ActionCable]", ...messages);
          }
        }
      };
    }
  });

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/connection_monitor.js
  var now, secondsSince, ConnectionMonitor, connection_monitor_default;
  var init_connection_monitor = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/connection_monitor.js"() {
      init_logger();
      now = () => (/* @__PURE__ */ new Date()).getTime();
      secondsSince = (time) => (now() - time) / 1e3;
      ConnectionMonitor = class {
        constructor(connection) {
          this.visibilityDidChange = this.visibilityDidChange.bind(this);
          this.connection = connection;
          this.reconnectAttempts = 0;
        }
        start() {
          if (!this.isRunning()) {
            this.startedAt = now();
            delete this.stoppedAt;
            this.startPolling();
            addEventListener("visibilitychange", this.visibilityDidChange);
            logger_default.log(`ConnectionMonitor started. stale threshold = ${this.constructor.staleThreshold} s`);
          }
        }
        stop() {
          if (this.isRunning()) {
            this.stoppedAt = now();
            this.stopPolling();
            removeEventListener("visibilitychange", this.visibilityDidChange);
            logger_default.log("ConnectionMonitor stopped");
          }
        }
        isRunning() {
          return this.startedAt && !this.stoppedAt;
        }
        recordPing() {
          this.pingedAt = now();
        }
        recordConnect() {
          this.reconnectAttempts = 0;
          this.recordPing();
          delete this.disconnectedAt;
          logger_default.log("ConnectionMonitor recorded connect");
        }
        recordDisconnect() {
          this.disconnectedAt = now();
          logger_default.log("ConnectionMonitor recorded disconnect");
        }
        // Private
        startPolling() {
          this.stopPolling();
          this.poll();
        }
        stopPolling() {
          clearTimeout(this.pollTimeout);
        }
        poll() {
          this.pollTimeout = setTimeout(
            () => {
              this.reconnectIfStale();
              this.poll();
            },
            this.getPollInterval()
          );
        }
        getPollInterval() {
          const { staleThreshold, reconnectionBackoffRate } = this.constructor;
          const backoff = Math.pow(1 + reconnectionBackoffRate, Math.min(this.reconnectAttempts, 10));
          const jitterMax = this.reconnectAttempts === 0 ? 1 : reconnectionBackoffRate;
          const jitter = jitterMax * Math.random();
          return staleThreshold * 1e3 * backoff * (1 + jitter);
        }
        reconnectIfStale() {
          if (this.connectionIsStale()) {
            logger_default.log(`ConnectionMonitor detected stale connection. reconnectAttempts = ${this.reconnectAttempts}, time stale = ${secondsSince(this.refreshedAt)} s, stale threshold = ${this.constructor.staleThreshold} s`);
            this.reconnectAttempts++;
            if (this.disconnectedRecently()) {
              logger_default.log(`ConnectionMonitor skipping reopening recent disconnect. time disconnected = ${secondsSince(this.disconnectedAt)} s`);
            } else {
              logger_default.log("ConnectionMonitor reopening");
              this.connection.reopen();
            }
          }
        }
        get refreshedAt() {
          return this.pingedAt ? this.pingedAt : this.startedAt;
        }
        connectionIsStale() {
          return secondsSince(this.refreshedAt) > this.constructor.staleThreshold;
        }
        disconnectedRecently() {
          return this.disconnectedAt && secondsSince(this.disconnectedAt) < this.constructor.staleThreshold;
        }
        visibilityDidChange() {
          if (document.visibilityState === "visible") {
            setTimeout(
              () => {
                if (this.connectionIsStale() || !this.connection.isOpen()) {
                  logger_default.log(`ConnectionMonitor reopening stale connection on visibilitychange. visibilityState = ${document.visibilityState}`);
                  this.connection.reopen();
                }
              },
              200
            );
          }
        }
      };
      ConnectionMonitor.staleThreshold = 6;
      ConnectionMonitor.reconnectionBackoffRate = 0.15;
      connection_monitor_default = ConnectionMonitor;
    }
  });

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/internal.js
  var internal_default;
  var init_internal = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/internal.js"() {
      internal_default = {
        "message_types": {
          "welcome": "welcome",
          "disconnect": "disconnect",
          "ping": "ping",
          "confirmation": "confirm_subscription",
          "rejection": "reject_subscription"
        },
        "disconnect_reasons": {
          "unauthorized": "unauthorized",
          "invalid_request": "invalid_request",
          "server_restart": "server_restart",
          "remote": "remote"
        },
        "default_mount_path": "/cable",
        "protocols": [
          "actioncable-v1-json",
          "actioncable-unsupported"
        ]
      };
    }
  });

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/connection.js
  var message_types, protocols, supportedProtocols, indexOf, Connection, connection_default;
  var init_connection = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/connection.js"() {
      init_adapters();
      init_connection_monitor();
      init_internal();
      init_logger();
      ({ message_types, protocols } = internal_default);
      supportedProtocols = protocols.slice(0, protocols.length - 1);
      indexOf = [].indexOf;
      Connection = class {
        constructor(consumer5) {
          this.open = this.open.bind(this);
          this.consumer = consumer5;
          this.subscriptions = this.consumer.subscriptions;
          this.monitor = new connection_monitor_default(this);
          this.disconnected = true;
        }
        send(data) {
          if (this.isOpen()) {
            this.webSocket.send(JSON.stringify(data));
            return true;
          } else {
            return false;
          }
        }
        open() {
          if (this.isActive()) {
            logger_default.log(`Attempted to open WebSocket, but existing socket is ${this.getState()}`);
            return false;
          } else {
            const socketProtocols = [...protocols, ...this.consumer.subprotocols || []];
            logger_default.log(`Opening WebSocket, current state is ${this.getState()}, subprotocols: ${socketProtocols}`);
            if (this.webSocket) {
              this.uninstallEventHandlers();
            }
            this.webSocket = new adapters_default.WebSocket(this.consumer.url, socketProtocols);
            this.installEventHandlers();
            this.monitor.start();
            return true;
          }
        }
        close({ allowReconnect } = { allowReconnect: true }) {
          if (!allowReconnect) {
            this.monitor.stop();
          }
          if (this.isOpen()) {
            return this.webSocket.close();
          }
        }
        reopen() {
          logger_default.log(`Reopening WebSocket, current state is ${this.getState()}`);
          if (this.isActive()) {
            try {
              return this.close();
            } catch (error3) {
              logger_default.log("Failed to reopen WebSocket", error3);
            } finally {
              logger_default.log(`Reopening WebSocket in ${this.constructor.reopenDelay}ms`);
              setTimeout(this.open, this.constructor.reopenDelay);
            }
          } else {
            return this.open();
          }
        }
        getProtocol() {
          if (this.webSocket) {
            return this.webSocket.protocol;
          }
        }
        isOpen() {
          return this.isState("open");
        }
        isActive() {
          return this.isState("open", "connecting");
        }
        triedToReconnect() {
          return this.monitor.reconnectAttempts > 0;
        }
        // Private
        isProtocolSupported() {
          return indexOf.call(supportedProtocols, this.getProtocol()) >= 0;
        }
        isState(...states) {
          return indexOf.call(states, this.getState()) >= 0;
        }
        getState() {
          if (this.webSocket) {
            for (let state in adapters_default.WebSocket) {
              if (adapters_default.WebSocket[state] === this.webSocket.readyState) {
                return state.toLowerCase();
              }
            }
          }
          return null;
        }
        installEventHandlers() {
          for (let eventName in this.events) {
            const handler = this.events[eventName].bind(this);
            this.webSocket[`on${eventName}`] = handler;
          }
        }
        uninstallEventHandlers() {
          for (let eventName in this.events) {
            this.webSocket[`on${eventName}`] = function() {
            };
          }
        }
      };
      Connection.reopenDelay = 500;
      Connection.prototype.events = {
        message(event) {
          if (!this.isProtocolSupported()) {
            return;
          }
          const { identifier, message, reason, reconnect, type } = JSON.parse(event.data);
          switch (type) {
            case message_types.welcome:
              if (this.triedToReconnect()) {
                this.reconnectAttempted = true;
              }
              this.monitor.recordConnect();
              return this.subscriptions.reload();
            case message_types.disconnect:
              logger_default.log(`Disconnecting. Reason: ${reason}`);
              return this.close({ allowReconnect: reconnect });
            case message_types.ping:
              return this.monitor.recordPing();
            case message_types.confirmation:
              this.subscriptions.confirmSubscription(identifier);
              if (this.reconnectAttempted) {
                this.reconnectAttempted = false;
                return this.subscriptions.notify(identifier, "connected", { reconnected: true });
              } else {
                return this.subscriptions.notify(identifier, "connected", { reconnected: false });
              }
            case message_types.rejection:
              return this.subscriptions.reject(identifier);
            default:
              return this.subscriptions.notify(identifier, "received", message);
          }
        },
        open() {
          logger_default.log(`WebSocket onopen event, using '${this.getProtocol()}' subprotocol`);
          this.disconnected = false;
          if (!this.isProtocolSupported()) {
            logger_default.log("Protocol is unsupported. Stopping monitor and disconnecting.");
            return this.close({ allowReconnect: false });
          }
        },
        close(event) {
          logger_default.log("WebSocket onclose event");
          if (this.disconnected) {
            return;
          }
          this.disconnected = true;
          this.monitor.recordDisconnect();
          return this.subscriptions.notifyAll("disconnected", { willAttemptReconnect: this.monitor.isRunning() });
        },
        error() {
          logger_default.log("WebSocket onerror event");
        }
      };
      connection_default = Connection;
    }
  });

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/subscription.js
  var extend, Subscription;
  var init_subscription = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/subscription.js"() {
      extend = function(object, properties) {
        if (properties != null) {
          for (let key in properties) {
            const value = properties[key];
            object[key] = value;
          }
        }
        return object;
      };
      Subscription = class {
        constructor(consumer5, params2 = {}, mixin) {
          this.consumer = consumer5;
          this.identifier = JSON.stringify(params2);
          extend(this, mixin);
        }
        // Perform a channel action with the optional data passed as an attribute
        perform(action, data = {}) {
          data.action = action;
          return this.send(data);
        }
        send(data) {
          return this.consumer.send({ command: "message", identifier: this.identifier, data: JSON.stringify(data) });
        }
        unsubscribe() {
          return this.consumer.subscriptions.remove(this);
        }
      };
    }
  });

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/subscription_guarantor.js
  var SubscriptionGuarantor, subscription_guarantor_default;
  var init_subscription_guarantor = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/subscription_guarantor.js"() {
      init_logger();
      SubscriptionGuarantor = class {
        constructor(subscriptions) {
          this.subscriptions = subscriptions;
          this.pendingSubscriptions = [];
        }
        guarantee(subscription2) {
          if (this.pendingSubscriptions.indexOf(subscription2) == -1) {
            logger_default.log(`SubscriptionGuarantor guaranteeing ${subscription2.identifier}`);
            this.pendingSubscriptions.push(subscription2);
          } else {
            logger_default.log(`SubscriptionGuarantor already guaranteeing ${subscription2.identifier}`);
          }
          this.startGuaranteeing();
        }
        forget(subscription2) {
          logger_default.log(`SubscriptionGuarantor forgetting ${subscription2.identifier}`);
          this.pendingSubscriptions = this.pendingSubscriptions.filter((s2) => s2 !== subscription2);
        }
        startGuaranteeing() {
          this.stopGuaranteeing();
          this.retrySubscribing();
        }
        stopGuaranteeing() {
          clearTimeout(this.retryTimeout);
        }
        retrySubscribing() {
          this.retryTimeout = setTimeout(
            () => {
              if (this.subscriptions && typeof this.subscriptions.subscribe === "function") {
                this.pendingSubscriptions.map((subscription2) => {
                  logger_default.log(`SubscriptionGuarantor resubscribing ${subscription2.identifier}`);
                  this.subscriptions.subscribe(subscription2);
                });
              }
            },
            500
          );
        }
      };
      subscription_guarantor_default = SubscriptionGuarantor;
    }
  });

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/subscriptions.js
  var Subscriptions;
  var init_subscriptions = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/subscriptions.js"() {
      init_subscription();
      init_subscription_guarantor();
      init_logger();
      Subscriptions = class {
        constructor(consumer5) {
          this.consumer = consumer5;
          this.guarantor = new subscription_guarantor_default(this);
          this.subscriptions = [];
        }
        create(channelName, mixin) {
          const channel = channelName;
          const params2 = typeof channel === "object" ? channel : { channel };
          const subscription2 = new Subscription(this.consumer, params2, mixin);
          return this.add(subscription2);
        }
        // Private
        add(subscription2) {
          this.subscriptions.push(subscription2);
          this.consumer.ensureActiveConnection();
          this.notify(subscription2, "initialized");
          this.subscribe(subscription2);
          return subscription2;
        }
        remove(subscription2) {
          this.forget(subscription2);
          if (!this.findAll(subscription2.identifier).length) {
            this.sendCommand(subscription2, "unsubscribe");
          }
          return subscription2;
        }
        reject(identifier) {
          return this.findAll(identifier).map((subscription2) => {
            this.forget(subscription2);
            this.notify(subscription2, "rejected");
            return subscription2;
          });
        }
        forget(subscription2) {
          this.guarantor.forget(subscription2);
          this.subscriptions = this.subscriptions.filter((s2) => s2 !== subscription2);
          return subscription2;
        }
        findAll(identifier) {
          return this.subscriptions.filter((s2) => s2.identifier === identifier);
        }
        reload() {
          return this.subscriptions.map((subscription2) => this.subscribe(subscription2));
        }
        notifyAll(callbackName, ...args) {
          return this.subscriptions.map((subscription2) => this.notify(subscription2, callbackName, ...args));
        }
        notify(subscription2, callbackName, ...args) {
          let subscriptions;
          if (typeof subscription2 === "string") {
            subscriptions = this.findAll(subscription2);
          } else {
            subscriptions = [subscription2];
          }
          return subscriptions.map((subscription3) => typeof subscription3[callbackName] === "function" ? subscription3[callbackName](...args) : void 0);
        }
        subscribe(subscription2) {
          if (this.sendCommand(subscription2, "subscribe")) {
            this.guarantor.guarantee(subscription2);
          }
        }
        confirmSubscription(identifier) {
          logger_default.log(`Subscription confirmed ${identifier}`);
          this.findAll(identifier).map((subscription2) => this.guarantor.forget(subscription2));
        }
        sendCommand(subscription2, command) {
          const { identifier } = subscription2;
          return this.consumer.send({ command, identifier });
        }
      };
    }
  });

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/consumer.js
  function createWebSocketURL(url) {
    if (typeof url === "function") {
      url = url();
    }
    if (url && !/^wss?:/i.test(url)) {
      const a = document.createElement("a");
      a.href = url;
      a.href = a.href;
      a.protocol = a.protocol.replace("http", "ws");
      return a.href;
    } else {
      return url;
    }
  }
  var Consumer;
  var init_consumer = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/consumer.js"() {
      init_connection();
      init_subscriptions();
      Consumer = class {
        constructor(url) {
          this._url = url;
          this.subscriptions = new Subscriptions(this);
          this.connection = new connection_default(this);
          this.subprotocols = [];
        }
        get url() {
          return createWebSocketURL(this._url);
        }
        send(data) {
          return this.connection.send(data);
        }
        connect() {
          return this.connection.open();
        }
        disconnect() {
          return this.connection.close({ allowReconnect: false });
        }
        ensureActiveConnection() {
          if (!this.connection.isActive()) {
            return this.connection.open();
          }
        }
        addSubProtocol(subprotocol) {
          this.subprotocols = [...this.subprotocols, subprotocol];
        }
      };
    }
  });

  // ../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/index.js
  var src_exports = {};
  __export(src_exports, {
    Connection: () => connection_default,
    ConnectionMonitor: () => connection_monitor_default,
    Consumer: () => Consumer,
    INTERNAL: () => internal_default,
    Subscription: () => Subscription,
    SubscriptionGuarantor: () => subscription_guarantor_default,
    Subscriptions: () => Subscriptions,
    adapters: () => adapters_default,
    createConsumer: () => createConsumer,
    createWebSocketURL: () => createWebSocketURL,
    getConfig: () => getConfig,
    logger: () => logger_default
  });
  function createConsumer(url = getConfig("url") || internal_default.default_mount_path) {
    return new Consumer(url);
  }
  function getConfig(name3) {
    const element = document.head.querySelector(`meta[name='action-cable-${name3}']`);
    if (element) {
      return element.getAttribute("content");
    }
  }
  var init_src = __esm({
    "../../node_modules/@hotwired/turbo-rails/node_modules/@rails/actioncable/src/index.js"() {
      init_connection();
      init_connection_monitor();
      init_consumer();
      init_internal();
      init_subscription();
      init_subscriptions();
      init_subscription_guarantor();
      init_adapters();
      init_logger();
    }
  });

  // ../../node_modules/clipboard/dist/clipboard.js
  var require_clipboard = __commonJS({
    "../../node_modules/clipboard/dist/clipboard.js"(exports, module3) {
      (function webpackUniversalModuleDefinition(root, factory) {
        if (typeof exports === "object" && typeof module3 === "object")
          module3.exports = factory();
        else if (typeof define === "function" && define.amd)
          define([], factory);
        else if (typeof exports === "object")
          exports["ClipboardJS"] = factory();
        else
          root["ClipboardJS"] = factory();
      })(exports, function() {
        return (
          /******/
          function() {
            var __webpack_modules__ = {
              /***/
              686: (
                /***/
                function(__unused_webpack_module, __webpack_exports__, __webpack_require__2) {
                  "use strict";
                  __webpack_require__2.d(__webpack_exports__, {
                    "default": function() {
                      return (
                        /* binding */
                        clipboard
                      );
                    }
                  });
                  var tiny_emitter = __webpack_require__2(279);
                  var tiny_emitter_default = /* @__PURE__ */ __webpack_require__2.n(tiny_emitter);
                  var listen = __webpack_require__2(370);
                  var listen_default = /* @__PURE__ */ __webpack_require__2.n(listen);
                  var src_select = __webpack_require__2(817);
                  var select_default = /* @__PURE__ */ __webpack_require__2.n(src_select);
                  ;
                  function command(type) {
                    try {
                      return document.execCommand(type);
                    } catch (err) {
                      return false;
                    }
                  }
                  ;
                  var ClipboardActionCut = function ClipboardActionCut2(target) {
                    var selectedText = select_default()(target);
                    command("cut");
                    return selectedText;
                  };
                  var actions_cut = ClipboardActionCut;
                  ;
                  function createFakeElement(value) {
                    var isRTL = document.documentElement.getAttribute("dir") === "rtl";
                    var fakeElement = document.createElement("textarea");
                    fakeElement.style.fontSize = "12pt";
                    fakeElement.style.border = "0";
                    fakeElement.style.padding = "0";
                    fakeElement.style.margin = "0";
                    fakeElement.style.position = "absolute";
                    fakeElement.style[isRTL ? "right" : "left"] = "-9999px";
                    var yPosition = window.pageYOffset || document.documentElement.scrollTop;
                    fakeElement.style.top = "".concat(yPosition, "px");
                    fakeElement.setAttribute("readonly", "");
                    fakeElement.value = value;
                    return fakeElement;
                  }
                  ;
                  var fakeCopyAction = function fakeCopyAction2(value, options) {
                    var fakeElement = createFakeElement(value);
                    options.container.appendChild(fakeElement);
                    var selectedText = select_default()(fakeElement);
                    command("copy");
                    fakeElement.remove();
                    return selectedText;
                  };
                  var ClipboardActionCopy = function ClipboardActionCopy2(target) {
                    var options = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : {
                      container: document.body
                    };
                    var selectedText = "";
                    if (typeof target === "string") {
                      selectedText = fakeCopyAction(target, options);
                    } else if (target instanceof HTMLInputElement && !["text", "search", "url", "tel", "password"].includes(target === null || target === void 0 ? void 0 : target.type)) {
                      selectedText = fakeCopyAction(target.value, options);
                    } else {
                      selectedText = select_default()(target);
                      command("copy");
                    }
                    return selectedText;
                  };
                  var actions_copy = ClipboardActionCopy;
                  ;
                  function _typeof(obj) {
                    "@babel/helpers - typeof";
                    if (typeof Symbol === "function" && typeof Symbol.iterator === "symbol") {
                      _typeof = function _typeof2(obj2) {
                        return typeof obj2;
                      };
                    } else {
                      _typeof = function _typeof2(obj2) {
                        return obj2 && typeof Symbol === "function" && obj2.constructor === Symbol && obj2 !== Symbol.prototype ? "symbol" : typeof obj2;
                      };
                    }
                    return _typeof(obj);
                  }
                  var ClipboardActionDefault = function ClipboardActionDefault2() {
                    var options = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : {};
                    var _options$action = options.action, action = _options$action === void 0 ? "copy" : _options$action, container = options.container, target = options.target, text = options.text;
                    if (action !== "copy" && action !== "cut") {
                      throw new Error('Invalid "action" value, use either "copy" or "cut"');
                    }
                    if (target !== void 0) {
                      if (target && _typeof(target) === "object" && target.nodeType === 1) {
                        if (action === "copy" && target.hasAttribute("disabled")) {
                          throw new Error('Invalid "target" attribute. Please use "readonly" instead of "disabled" attribute');
                        }
                        if (action === "cut" && (target.hasAttribute("readonly") || target.hasAttribute("disabled"))) {
                          throw new Error(`Invalid "target" attribute. You can't cut text from elements with "readonly" or "disabled" attributes`);
                        }
                      } else {
                        throw new Error('Invalid "target" value, use a valid Element');
                      }
                    }
                    if (text) {
                      return actions_copy(text, {
                        container
                      });
                    }
                    if (target) {
                      return action === "cut" ? actions_cut(target) : actions_copy(target, {
                        container
                      });
                    }
                  };
                  var actions_default = ClipboardActionDefault;
                  ;
                  function clipboard_typeof(obj) {
                    "@babel/helpers - typeof";
                    if (typeof Symbol === "function" && typeof Symbol.iterator === "symbol") {
                      clipboard_typeof = function _typeof2(obj2) {
                        return typeof obj2;
                      };
                    } else {
                      clipboard_typeof = function _typeof2(obj2) {
                        return obj2 && typeof Symbol === "function" && obj2.constructor === Symbol && obj2 !== Symbol.prototype ? "symbol" : typeof obj2;
                      };
                    }
                    return clipboard_typeof(obj);
                  }
                  function _classCallCheck(instance, Constructor) {
                    if (!(instance instanceof Constructor)) {
                      throw new TypeError("Cannot call a class as a function");
                    }
                  }
                  function _defineProperties(target, props) {
                    for (var i = 0; i < props.length; i++) {
                      var descriptor = props[i];
                      descriptor.enumerable = descriptor.enumerable || false;
                      descriptor.configurable = true;
                      if ("value" in descriptor) descriptor.writable = true;
                      Object.defineProperty(target, descriptor.key, descriptor);
                    }
                  }
                  function _createClass(Constructor, protoProps, staticProps) {
                    if (protoProps) _defineProperties(Constructor.prototype, protoProps);
                    if (staticProps) _defineProperties(Constructor, staticProps);
                    return Constructor;
                  }
                  function _inherits(subClass, superClass) {
                    if (typeof superClass !== "function" && superClass !== null) {
                      throw new TypeError("Super expression must either be null or a function");
                    }
                    subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, writable: true, configurable: true } });
                    if (superClass) _setPrototypeOf(subClass, superClass);
                  }
                  function _setPrototypeOf(o, p2) {
                    _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p3) {
                      o2.__proto__ = p3;
                      return o2;
                    };
                    return _setPrototypeOf(o, p2);
                  }
                  function _createSuper(Derived) {
                    var hasNativeReflectConstruct = _isNativeReflectConstruct();
                    return function _createSuperInternal() {
                      var Super = _getPrototypeOf(Derived), result;
                      if (hasNativeReflectConstruct) {
                        var NewTarget = _getPrototypeOf(this).constructor;
                        result = Reflect.construct(Super, arguments, NewTarget);
                      } else {
                        result = Super.apply(this, arguments);
                      }
                      return _possibleConstructorReturn(this, result);
                    };
                  }
                  function _possibleConstructorReturn(self2, call) {
                    if (call && (clipboard_typeof(call) === "object" || typeof call === "function")) {
                      return call;
                    }
                    return _assertThisInitialized(self2);
                  }
                  function _assertThisInitialized(self2) {
                    if (self2 === void 0) {
                      throw new ReferenceError("this hasn't been initialised - super() hasn't been called");
                    }
                    return self2;
                  }
                  function _isNativeReflectConstruct() {
                    if (typeof Reflect === "undefined" || !Reflect.construct) return false;
                    if (Reflect.construct.sham) return false;
                    if (typeof Proxy === "function") return true;
                    try {
                      Date.prototype.toString.call(Reflect.construct(Date, [], function() {
                      }));
                      return true;
                    } catch (e) {
                      return false;
                    }
                  }
                  function _getPrototypeOf(o) {
                    _getPrototypeOf = Object.setPrototypeOf ? Object.getPrototypeOf : function _getPrototypeOf2(o2) {
                      return o2.__proto__ || Object.getPrototypeOf(o2);
                    };
                    return _getPrototypeOf(o);
                  }
                  function getAttributeValue(suffix, element) {
                    var attribute = "data-clipboard-".concat(suffix);
                    if (!element.hasAttribute(attribute)) {
                      return;
                    }
                    return element.getAttribute(attribute);
                  }
                  var Clipboard = /* @__PURE__ */ function(_Emitter) {
                    _inherits(Clipboard2, _Emitter);
                    var _super = _createSuper(Clipboard2);
                    function Clipboard2(trigger, options) {
                      var _this;
                      _classCallCheck(this, Clipboard2);
                      _this = _super.call(this);
                      _this.resolveOptions(options);
                      _this.listenClick(trigger);
                      return _this;
                    }
                    _createClass(Clipboard2, [{
                      key: "resolveOptions",
                      value: function resolveOptions() {
                        var options = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : {};
                        this.action = typeof options.action === "function" ? options.action : this.defaultAction;
                        this.target = typeof options.target === "function" ? options.target : this.defaultTarget;
                        this.text = typeof options.text === "function" ? options.text : this.defaultText;
                        this.container = clipboard_typeof(options.container) === "object" ? options.container : document.body;
                      }
                      /**
                       * Adds a click event listener to the passed trigger.
                       * @param {String|HTMLElement|HTMLCollection|NodeList} trigger
                       */
                    }, {
                      key: "listenClick",
                      value: function listenClick(trigger) {
                        var _this2 = this;
                        this.listener = listen_default()(trigger, "click", function(e) {
                          return _this2.onClick(e);
                        });
                      }
                      /**
                       * Defines a new `ClipboardAction` on each click event.
                       * @param {Event} e
                       */
                    }, {
                      key: "onClick",
                      value: function onClick(e) {
                        var trigger = e.delegateTarget || e.currentTarget;
                        var action = this.action(trigger) || "copy";
                        var text = actions_default({
                          action,
                          container: this.container,
                          target: this.target(trigger),
                          text: this.text(trigger)
                        });
                        this.emit(text ? "success" : "error", {
                          action,
                          text,
                          trigger,
                          clearSelection: function clearSelection() {
                            if (trigger) {
                              trigger.focus();
                            }
                            window.getSelection().removeAllRanges();
                          }
                        });
                      }
                      /**
                       * Default `action` lookup function.
                       * @param {Element} trigger
                       */
                    }, {
                      key: "defaultAction",
                      value: function defaultAction(trigger) {
                        return getAttributeValue("action", trigger);
                      }
                      /**
                       * Default `target` lookup function.
                       * @param {Element} trigger
                       */
                    }, {
                      key: "defaultTarget",
                      value: function defaultTarget(trigger) {
                        var selector = getAttributeValue("target", trigger);
                        if (selector) {
                          return document.querySelector(selector);
                        }
                      }
                      /**
                       * Allow fire programmatically a copy action
                       * @param {String|HTMLElement} target
                       * @param {Object} options
                       * @returns Text copied.
                       */
                    }, {
                      key: "defaultText",
                      /**
                       * Default `text` lookup function.
                       * @param {Element} trigger
                       */
                      value: function defaultText(trigger) {
                        return getAttributeValue("text", trigger);
                      }
                      /**
                       * Destroy lifecycle.
                       */
                    }, {
                      key: "destroy",
                      value: function destroy() {
                        this.listener.destroy();
                      }
                    }], [{
                      key: "copy",
                      value: function copy(target) {
                        var options = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : {
                          container: document.body
                        };
                        return actions_copy(target, options);
                      }
                      /**
                       * Allow fire programmatically a cut action
                       * @param {String|HTMLElement} target
                       * @returns Text cutted.
                       */
                    }, {
                      key: "cut",
                      value: function cut(target) {
                        return actions_cut(target);
                      }
                      /**
                       * Returns the support of the given action, or all actions if no action is
                       * given.
                       * @param {String} [action]
                       */
                    }, {
                      key: "isSupported",
                      value: function isSupported() {
                        var action = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : ["copy", "cut"];
                        var actions = typeof action === "string" ? [action] : action;
                        var support = !!document.queryCommandSupported;
                        actions.forEach(function(action2) {
                          support = support && !!document.queryCommandSupported(action2);
                        });
                        return support;
                      }
                    }]);
                    return Clipboard2;
                  }(tiny_emitter_default());
                  var clipboard = Clipboard;
                }
              ),
              /***/
              828: (
                /***/
                function(module4) {
                  var DOCUMENT_NODE_TYPE = 9;
                  if (typeof Element !== "undefined" && !Element.prototype.matches) {
                    var proto = Element.prototype;
                    proto.matches = proto.matchesSelector || proto.mozMatchesSelector || proto.msMatchesSelector || proto.oMatchesSelector || proto.webkitMatchesSelector;
                  }
                  function closest(element, selector) {
                    while (element && element.nodeType !== DOCUMENT_NODE_TYPE) {
                      if (typeof element.matches === "function" && element.matches(selector)) {
                        return element;
                      }
                      element = element.parentNode;
                    }
                  }
                  module4.exports = closest;
                }
              ),
              /***/
              438: (
                /***/
                function(module4, __unused_webpack_exports, __webpack_require__2) {
                  var closest = __webpack_require__2(828);
                  function _delegate(element, selector, type, callback, useCapture) {
                    var listenerFn = listener.apply(this, arguments);
                    element.addEventListener(type, listenerFn, useCapture);
                    return {
                      destroy: function() {
                        element.removeEventListener(type, listenerFn, useCapture);
                      }
                    };
                  }
                  function delegate(elements, selector, type, callback, useCapture) {
                    if (typeof elements.addEventListener === "function") {
                      return _delegate.apply(null, arguments);
                    }
                    if (typeof type === "function") {
                      return _delegate.bind(null, document).apply(null, arguments);
                    }
                    if (typeof elements === "string") {
                      elements = document.querySelectorAll(elements);
                    }
                    return Array.prototype.map.call(elements, function(element) {
                      return _delegate(element, selector, type, callback, useCapture);
                    });
                  }
                  function listener(element, selector, type, callback) {
                    return function(e) {
                      e.delegateTarget = closest(e.target, selector);
                      if (e.delegateTarget) {
                        callback.call(element, e);
                      }
                    };
                  }
                  module4.exports = delegate;
                }
              ),
              /***/
              879: (
                /***/
                function(__unused_webpack_module, exports2) {
                  exports2.node = function(value) {
                    return value !== void 0 && value instanceof HTMLElement && value.nodeType === 1;
                  };
                  exports2.nodeList = function(value) {
                    var type = Object.prototype.toString.call(value);
                    return value !== void 0 && (type === "[object NodeList]" || type === "[object HTMLCollection]") && "length" in value && (value.length === 0 || exports2.node(value[0]));
                  };
                  exports2.string = function(value) {
                    return typeof value === "string" || value instanceof String;
                  };
                  exports2.fn = function(value) {
                    var type = Object.prototype.toString.call(value);
                    return type === "[object Function]";
                  };
                }
              ),
              /***/
              370: (
                /***/
                function(module4, __unused_webpack_exports, __webpack_require__2) {
                  var is = __webpack_require__2(879);
                  var delegate = __webpack_require__2(438);
                  function listen(target, type, callback) {
                    if (!target && !type && !callback) {
                      throw new Error("Missing required arguments");
                    }
                    if (!is.string(type)) {
                      throw new TypeError("Second argument must be a String");
                    }
                    if (!is.fn(callback)) {
                      throw new TypeError("Third argument must be a Function");
                    }
                    if (is.node(target)) {
                      return listenNode(target, type, callback);
                    } else if (is.nodeList(target)) {
                      return listenNodeList(target, type, callback);
                    } else if (is.string(target)) {
                      return listenSelector(target, type, callback);
                    } else {
                      throw new TypeError("First argument must be a String, HTMLElement, HTMLCollection, or NodeList");
                    }
                  }
                  function listenNode(node, type, callback) {
                    node.addEventListener(type, callback);
                    return {
                      destroy: function() {
                        node.removeEventListener(type, callback);
                      }
                    };
                  }
                  function listenNodeList(nodeList, type, callback) {
                    Array.prototype.forEach.call(nodeList, function(node) {
                      node.addEventListener(type, callback);
                    });
                    return {
                      destroy: function() {
                        Array.prototype.forEach.call(nodeList, function(node) {
                          node.removeEventListener(type, callback);
                        });
                      }
                    };
                  }
                  function listenSelector(selector, type, callback) {
                    return delegate(document.body, selector, type, callback);
                  }
                  module4.exports = listen;
                }
              ),
              /***/
              817: (
                /***/
                function(module4) {
                  function select(element) {
                    var selectedText;
                    if (element.nodeName === "SELECT") {
                      element.focus();
                      selectedText = element.value;
                    } else if (element.nodeName === "INPUT" || element.nodeName === "TEXTAREA") {
                      var isReadOnly = element.hasAttribute("readonly");
                      if (!isReadOnly) {
                        element.setAttribute("readonly", "");
                      }
                      element.select();
                      element.setSelectionRange(0, element.value.length);
                      if (!isReadOnly) {
                        element.removeAttribute("readonly");
                      }
                      selectedText = element.value;
                    } else {
                      if (element.hasAttribute("contenteditable")) {
                        element.focus();
                      }
                      var selection = window.getSelection();
                      var range2 = document.createRange();
                      range2.selectNodeContents(element);
                      selection.removeAllRanges();
                      selection.addRange(range2);
                      selectedText = selection.toString();
                    }
                    return selectedText;
                  }
                  module4.exports = select;
                }
              ),
              /***/
              279: (
                /***/
                function(module4) {
                  function E() {
                  }
                  E.prototype = {
                    on: function(name3, callback, ctx) {
                      var e = this.e || (this.e = {});
                      (e[name3] || (e[name3] = [])).push({
                        fn: callback,
                        ctx
                      });
                      return this;
                    },
                    once: function(name3, callback, ctx) {
                      var self2 = this;
                      function listener() {
                        self2.off(name3, listener);
                        callback.apply(ctx, arguments);
                      }
                      ;
                      listener._ = callback;
                      return this.on(name3, listener, ctx);
                    },
                    emit: function(name3) {
                      var data = [].slice.call(arguments, 1);
                      var evtArr = ((this.e || (this.e = {}))[name3] || []).slice();
                      var i = 0;
                      var len = evtArr.length;
                      for (i; i < len; i++) {
                        evtArr[i].fn.apply(evtArr[i].ctx, data);
                      }
                      return this;
                    },
                    off: function(name3, callback) {
                      var e = this.e || (this.e = {});
                      var evts = e[name3];
                      var liveEvents = [];
                      if (evts && callback) {
                        for (var i = 0, len = evts.length; i < len; i++) {
                          if (evts[i].fn !== callback && evts[i].fn._ !== callback)
                            liveEvents.push(evts[i]);
                        }
                      }
                      liveEvents.length ? e[name3] = liveEvents : delete e[name3];
                      return this;
                    }
                  };
                  module4.exports = E;
                  module4.exports.TinyEmitter = E;
                }
              )
              /******/
            };
            var __webpack_module_cache__ = {};
            function __webpack_require__(moduleId) {
              if (__webpack_module_cache__[moduleId]) {
                return __webpack_module_cache__[moduleId].exports;
              }
              var module4 = __webpack_module_cache__[moduleId] = {
                /******/
                // no module.id needed
                /******/
                // no module.loaded needed
                /******/
                exports: {}
                /******/
              };
              __webpack_modules__[moduleId](module4, module4.exports, __webpack_require__);
              return module4.exports;
            }
            !function() {
              __webpack_require__.n = function(module4) {
                var getter = module4 && module4.__esModule ? (
                  /******/
                  function() {
                    return module4["default"];
                  }
                ) : (
                  /******/
                  function() {
                    return module4;
                  }
                );
                __webpack_require__.d(getter, { a: getter });
                return getter;
              };
            }();
            !function() {
              __webpack_require__.d = function(exports2, definition) {
                for (var key in definition) {
                  if (__webpack_require__.o(definition, key) && !__webpack_require__.o(exports2, key)) {
                    Object.defineProperty(exports2, key, { enumerable: true, get: definition[key] });
                  }
                }
              };
            }();
            !function() {
              __webpack_require__.o = function(obj, prop) {
                return Object.prototype.hasOwnProperty.call(obj, prop);
              };
            }();
            return __webpack_require__(686);
          }().default
        );
      });
    }
  });

  // controllers/scoreboard_controller.js
  var require_scoreboard_controller = __commonJS({
    "controllers/scoreboard_controller.js"() {
      document.addEventListener("alpine:init", () => {
        Alpine.data("scoreboardGameConfig", () => ({
          multiset: 0,
          games: 0,
          gametime: 0,
          warntime: 0,
          increment: 5,
          initConfig() {
          }
        }));
      });
    }
  });

  // ../../node_modules/core-js/internals/global-this.js
  var require_global_this = __commonJS({
    "../../node_modules/core-js/internals/global-this.js"(exports, module3) {
      "use strict";
      var check = function(it) {
        return it && it.Math === Math && it;
      };
      module3.exports = // eslint-disable-next-line es/no-global-this -- safe
      check(typeof globalThis == "object" && globalThis) || check(typeof window == "object" && window) || // eslint-disable-next-line no-restricted-globals -- safe
      check(typeof self == "object" && self) || check(typeof global == "object" && global) || check(typeof exports == "object" && exports) || // eslint-disable-next-line no-new-func -- fallback
      /* @__PURE__ */ function() {
        return this;
      }() || Function("return this")();
    }
  });

  // ../../node_modules/core-js/internals/fails.js
  var require_fails = __commonJS({
    "../../node_modules/core-js/internals/fails.js"(exports, module3) {
      "use strict";
      module3.exports = function(exec) {
        try {
          return !!exec();
        } catch (error3) {
          return true;
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/descriptors.js
  var require_descriptors = __commonJS({
    "../../node_modules/core-js/internals/descriptors.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      module3.exports = !fails(function() {
        return Object.defineProperty({}, 1, { get: function() {
          return 7;
        } })[1] !== 7;
      });
    }
  });

  // ../../node_modules/core-js/internals/function-bind-native.js
  var require_function_bind_native = __commonJS({
    "../../node_modules/core-js/internals/function-bind-native.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      module3.exports = !fails(function() {
        var test = function() {
        }.bind();
        return typeof test != "function" || test.hasOwnProperty("prototype");
      });
    }
  });

  // ../../node_modules/core-js/internals/function-call.js
  var require_function_call = __commonJS({
    "../../node_modules/core-js/internals/function-call.js"(exports, module3) {
      "use strict";
      var NATIVE_BIND = require_function_bind_native();
      var call = Function.prototype.call;
      module3.exports = NATIVE_BIND ? call.bind(call) : function() {
        return call.apply(call, arguments);
      };
    }
  });

  // ../../node_modules/core-js/internals/object-property-is-enumerable.js
  var require_object_property_is_enumerable = __commonJS({
    "../../node_modules/core-js/internals/object-property-is-enumerable.js"(exports) {
      "use strict";
      var $propertyIsEnumerable = {}.propertyIsEnumerable;
      var getOwnPropertyDescriptor = Object.getOwnPropertyDescriptor;
      var NASHORN_BUG = getOwnPropertyDescriptor && !$propertyIsEnumerable.call({ 1: 2 }, 1);
      exports.f = NASHORN_BUG ? function propertyIsEnumerable(V2) {
        var descriptor = getOwnPropertyDescriptor(this, V2);
        return !!descriptor && descriptor.enumerable;
      } : $propertyIsEnumerable;
    }
  });

  // ../../node_modules/core-js/internals/create-property-descriptor.js
  var require_create_property_descriptor = __commonJS({
    "../../node_modules/core-js/internals/create-property-descriptor.js"(exports, module3) {
      "use strict";
      module3.exports = function(bitmap, value) {
        return {
          enumerable: !(bitmap & 1),
          configurable: !(bitmap & 2),
          writable: !(bitmap & 4),
          value
        };
      };
    }
  });

  // ../../node_modules/core-js/internals/function-uncurry-this.js
  var require_function_uncurry_this = __commonJS({
    "../../node_modules/core-js/internals/function-uncurry-this.js"(exports, module3) {
      "use strict";
      var NATIVE_BIND = require_function_bind_native();
      var FunctionPrototype = Function.prototype;
      var call = FunctionPrototype.call;
      var uncurryThisWithBind = NATIVE_BIND && FunctionPrototype.bind.bind(call, call);
      module3.exports = NATIVE_BIND ? uncurryThisWithBind : function(fn2) {
        return function() {
          return call.apply(fn2, arguments);
        };
      };
    }
  });

  // ../../node_modules/core-js/internals/classof-raw.js
  var require_classof_raw = __commonJS({
    "../../node_modules/core-js/internals/classof-raw.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var toString = uncurryThis({}.toString);
      var stringSlice = uncurryThis("".slice);
      module3.exports = function(it) {
        return stringSlice(toString(it), 8, -1);
      };
    }
  });

  // ../../node_modules/core-js/internals/indexed-object.js
  var require_indexed_object = __commonJS({
    "../../node_modules/core-js/internals/indexed-object.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var fails = require_fails();
      var classof = require_classof_raw();
      var $Object = Object;
      var split = uncurryThis("".split);
      module3.exports = fails(function() {
        return !$Object("z").propertyIsEnumerable(0);
      }) ? function(it) {
        return classof(it) === "String" ? split(it, "") : $Object(it);
      } : $Object;
    }
  });

  // ../../node_modules/core-js/internals/is-null-or-undefined.js
  var require_is_null_or_undefined = __commonJS({
    "../../node_modules/core-js/internals/is-null-or-undefined.js"(exports, module3) {
      "use strict";
      module3.exports = function(it) {
        return it === null || it === void 0;
      };
    }
  });

  // ../../node_modules/core-js/internals/require-object-coercible.js
  var require_require_object_coercible = __commonJS({
    "../../node_modules/core-js/internals/require-object-coercible.js"(exports, module3) {
      "use strict";
      var isNullOrUndefined = require_is_null_or_undefined();
      var $TypeError = TypeError;
      module3.exports = function(it) {
        if (isNullOrUndefined(it)) throw new $TypeError("Can't call method on " + it);
        return it;
      };
    }
  });

  // ../../node_modules/core-js/internals/to-indexed-object.js
  var require_to_indexed_object = __commonJS({
    "../../node_modules/core-js/internals/to-indexed-object.js"(exports, module3) {
      "use strict";
      var IndexedObject = require_indexed_object();
      var requireObjectCoercible = require_require_object_coercible();
      module3.exports = function(it) {
        return IndexedObject(requireObjectCoercible(it));
      };
    }
  });

  // ../../node_modules/core-js/internals/is-callable.js
  var require_is_callable = __commonJS({
    "../../node_modules/core-js/internals/is-callable.js"(exports, module3) {
      "use strict";
      var documentAll = typeof document == "object" && document.all;
      module3.exports = typeof documentAll == "undefined" && documentAll !== void 0 ? function(argument) {
        return typeof argument == "function" || argument === documentAll;
      } : function(argument) {
        return typeof argument == "function";
      };
    }
  });

  // ../../node_modules/core-js/internals/is-object.js
  var require_is_object = __commonJS({
    "../../node_modules/core-js/internals/is-object.js"(exports, module3) {
      "use strict";
      var isCallable = require_is_callable();
      module3.exports = function(it) {
        return typeof it == "object" ? it !== null : isCallable(it);
      };
    }
  });

  // ../../node_modules/core-js/internals/get-built-in.js
  var require_get_built_in = __commonJS({
    "../../node_modules/core-js/internals/get-built-in.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var isCallable = require_is_callable();
      var aFunction = function(argument) {
        return isCallable(argument) ? argument : void 0;
      };
      module3.exports = function(namespace, method) {
        return arguments.length < 2 ? aFunction(globalThis2[namespace]) : globalThis2[namespace] && globalThis2[namespace][method];
      };
    }
  });

  // ../../node_modules/core-js/internals/object-is-prototype-of.js
  var require_object_is_prototype_of = __commonJS({
    "../../node_modules/core-js/internals/object-is-prototype-of.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      module3.exports = uncurryThis({}.isPrototypeOf);
    }
  });

  // ../../node_modules/core-js/internals/environment-user-agent.js
  var require_environment_user_agent = __commonJS({
    "../../node_modules/core-js/internals/environment-user-agent.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var navigator2 = globalThis2.navigator;
      var userAgent = navigator2 && navigator2.userAgent;
      module3.exports = userAgent ? String(userAgent) : "";
    }
  });

  // ../../node_modules/core-js/internals/environment-v8-version.js
  var require_environment_v8_version = __commonJS({
    "../../node_modules/core-js/internals/environment-v8-version.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var userAgent = require_environment_user_agent();
      var process2 = globalThis2.process;
      var Deno2 = globalThis2.Deno;
      var versions = process2 && process2.versions || Deno2 && Deno2.version;
      var v8 = versions && versions.v8;
      var match;
      var version3;
      if (v8) {
        match = v8.split(".");
        version3 = match[0] > 0 && match[0] < 4 ? 1 : +(match[0] + match[1]);
      }
      if (!version3 && userAgent) {
        match = userAgent.match(/Edge\/(\d+)/);
        if (!match || match[1] >= 74) {
          match = userAgent.match(/Chrome\/(\d+)/);
          if (match) version3 = +match[1];
        }
      }
      module3.exports = version3;
    }
  });

  // ../../node_modules/core-js/internals/symbol-constructor-detection.js
  var require_symbol_constructor_detection = __commonJS({
    "../../node_modules/core-js/internals/symbol-constructor-detection.js"(exports, module3) {
      "use strict";
      var V8_VERSION = require_environment_v8_version();
      var fails = require_fails();
      var globalThis2 = require_global_this();
      var $String = globalThis2.String;
      module3.exports = !!Object.getOwnPropertySymbols && !fails(function() {
        var symbol = Symbol("symbol detection");
        return !$String(symbol) || !(Object(symbol) instanceof Symbol) || // Chrome 38-40 symbols are not inherited from DOM collections prototypes to instances
        !Symbol.sham && V8_VERSION && V8_VERSION < 41;
      });
    }
  });

  // ../../node_modules/core-js/internals/use-symbol-as-uid.js
  var require_use_symbol_as_uid = __commonJS({
    "../../node_modules/core-js/internals/use-symbol-as-uid.js"(exports, module3) {
      "use strict";
      var NATIVE_SYMBOL = require_symbol_constructor_detection();
      module3.exports = NATIVE_SYMBOL && !Symbol.sham && typeof Symbol.iterator == "symbol";
    }
  });

  // ../../node_modules/core-js/internals/is-symbol.js
  var require_is_symbol = __commonJS({
    "../../node_modules/core-js/internals/is-symbol.js"(exports, module3) {
      "use strict";
      var getBuiltIn = require_get_built_in();
      var isCallable = require_is_callable();
      var isPrototypeOf = require_object_is_prototype_of();
      var USE_SYMBOL_AS_UID = require_use_symbol_as_uid();
      var $Object = Object;
      module3.exports = USE_SYMBOL_AS_UID ? function(it) {
        return typeof it == "symbol";
      } : function(it) {
        var $Symbol = getBuiltIn("Symbol");
        return isCallable($Symbol) && isPrototypeOf($Symbol.prototype, $Object(it));
      };
    }
  });

  // ../../node_modules/core-js/internals/try-to-string.js
  var require_try_to_string = __commonJS({
    "../../node_modules/core-js/internals/try-to-string.js"(exports, module3) {
      "use strict";
      var $String = String;
      module3.exports = function(argument) {
        try {
          return $String(argument);
        } catch (error3) {
          return "Object";
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/a-callable.js
  var require_a_callable = __commonJS({
    "../../node_modules/core-js/internals/a-callable.js"(exports, module3) {
      "use strict";
      var isCallable = require_is_callable();
      var tryToString = require_try_to_string();
      var $TypeError = TypeError;
      module3.exports = function(argument) {
        if (isCallable(argument)) return argument;
        throw new $TypeError(tryToString(argument) + " is not a function");
      };
    }
  });

  // ../../node_modules/core-js/internals/get-method.js
  var require_get_method = __commonJS({
    "../../node_modules/core-js/internals/get-method.js"(exports, module3) {
      "use strict";
      var aCallable = require_a_callable();
      var isNullOrUndefined = require_is_null_or_undefined();
      module3.exports = function(V2, P) {
        var func = V2[P];
        return isNullOrUndefined(func) ? void 0 : aCallable(func);
      };
    }
  });

  // ../../node_modules/core-js/internals/ordinary-to-primitive.js
  var require_ordinary_to_primitive = __commonJS({
    "../../node_modules/core-js/internals/ordinary-to-primitive.js"(exports, module3) {
      "use strict";
      var call = require_function_call();
      var isCallable = require_is_callable();
      var isObject = require_is_object();
      var $TypeError = TypeError;
      module3.exports = function(input, pref) {
        var fn2, val;
        if (pref === "string" && isCallable(fn2 = input.toString) && !isObject(val = call(fn2, input))) return val;
        if (isCallable(fn2 = input.valueOf) && !isObject(val = call(fn2, input))) return val;
        if (pref !== "string" && isCallable(fn2 = input.toString) && !isObject(val = call(fn2, input))) return val;
        throw new $TypeError("Can't convert object to primitive value");
      };
    }
  });

  // ../../node_modules/core-js/internals/is-pure.js
  var require_is_pure = __commonJS({
    "../../node_modules/core-js/internals/is-pure.js"(exports, module3) {
      "use strict";
      module3.exports = false;
    }
  });

  // ../../node_modules/core-js/internals/define-global-property.js
  var require_define_global_property = __commonJS({
    "../../node_modules/core-js/internals/define-global-property.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var defineProperty = Object.defineProperty;
      module3.exports = function(key, value) {
        try {
          defineProperty(globalThis2, key, { value, configurable: true, writable: true });
        } catch (error3) {
          globalThis2[key] = value;
        }
        return value;
      };
    }
  });

  // ../../node_modules/core-js/internals/shared-store.js
  var require_shared_store = __commonJS({
    "../../node_modules/core-js/internals/shared-store.js"(exports, module3) {
      "use strict";
      var IS_PURE = require_is_pure();
      var globalThis2 = require_global_this();
      var defineGlobalProperty = require_define_global_property();
      var SHARED = "__core-js_shared__";
      var store = module3.exports = globalThis2[SHARED] || defineGlobalProperty(SHARED, {});
      (store.versions || (store.versions = [])).push({
        version: "3.40.0",
        mode: IS_PURE ? "pure" : "global",
        copyright: "\xA9 2014-2025 Denis Pushkarev (zloirock.ru)",
        license: "https://github.com/zloirock/core-js/blob/v3.40.0/LICENSE",
        source: "https://github.com/zloirock/core-js"
      });
    }
  });

  // ../../node_modules/core-js/internals/shared.js
  var require_shared = __commonJS({
    "../../node_modules/core-js/internals/shared.js"(exports, module3) {
      "use strict";
      var store = require_shared_store();
      module3.exports = function(key, value) {
        return store[key] || (store[key] = value || {});
      };
    }
  });

  // ../../node_modules/core-js/internals/to-object.js
  var require_to_object = __commonJS({
    "../../node_modules/core-js/internals/to-object.js"(exports, module3) {
      "use strict";
      var requireObjectCoercible = require_require_object_coercible();
      var $Object = Object;
      module3.exports = function(argument) {
        return $Object(requireObjectCoercible(argument));
      };
    }
  });

  // ../../node_modules/core-js/internals/has-own-property.js
  var require_has_own_property = __commonJS({
    "../../node_modules/core-js/internals/has-own-property.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var toObject = require_to_object();
      var hasOwnProperty2 = uncurryThis({}.hasOwnProperty);
      module3.exports = Object.hasOwn || function hasOwn(it, key) {
        return hasOwnProperty2(toObject(it), key);
      };
    }
  });

  // ../../node_modules/core-js/internals/uid.js
  var require_uid = __commonJS({
    "../../node_modules/core-js/internals/uid.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var id = 0;
      var postfix = Math.random();
      var toString = uncurryThis(1 .toString);
      module3.exports = function(key) {
        return "Symbol(" + (key === void 0 ? "" : key) + ")_" + toString(++id + postfix, 36);
      };
    }
  });

  // ../../node_modules/core-js/internals/well-known-symbol.js
  var require_well_known_symbol = __commonJS({
    "../../node_modules/core-js/internals/well-known-symbol.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var shared = require_shared();
      var hasOwn = require_has_own_property();
      var uid = require_uid();
      var NATIVE_SYMBOL = require_symbol_constructor_detection();
      var USE_SYMBOL_AS_UID = require_use_symbol_as_uid();
      var Symbol2 = globalThis2.Symbol;
      var WellKnownSymbolsStore = shared("wks");
      var createWellKnownSymbol = USE_SYMBOL_AS_UID ? Symbol2["for"] || Symbol2 : Symbol2 && Symbol2.withoutSetter || uid;
      module3.exports = function(name3) {
        if (!hasOwn(WellKnownSymbolsStore, name3)) {
          WellKnownSymbolsStore[name3] = NATIVE_SYMBOL && hasOwn(Symbol2, name3) ? Symbol2[name3] : createWellKnownSymbol("Symbol." + name3);
        }
        return WellKnownSymbolsStore[name3];
      };
    }
  });

  // ../../node_modules/core-js/internals/to-primitive.js
  var require_to_primitive = __commonJS({
    "../../node_modules/core-js/internals/to-primitive.js"(exports, module3) {
      "use strict";
      var call = require_function_call();
      var isObject = require_is_object();
      var isSymbol = require_is_symbol();
      var getMethod2 = require_get_method();
      var ordinaryToPrimitive = require_ordinary_to_primitive();
      var wellKnownSymbol = require_well_known_symbol();
      var $TypeError = TypeError;
      var TO_PRIMITIVE = wellKnownSymbol("toPrimitive");
      module3.exports = function(input, pref) {
        if (!isObject(input) || isSymbol(input)) return input;
        var exoticToPrim = getMethod2(input, TO_PRIMITIVE);
        var result;
        if (exoticToPrim) {
          if (pref === void 0) pref = "default";
          result = call(exoticToPrim, input, pref);
          if (!isObject(result) || isSymbol(result)) return result;
          throw new $TypeError("Can't convert object to primitive value");
        }
        if (pref === void 0) pref = "number";
        return ordinaryToPrimitive(input, pref);
      };
    }
  });

  // ../../node_modules/core-js/internals/to-property-key.js
  var require_to_property_key = __commonJS({
    "../../node_modules/core-js/internals/to-property-key.js"(exports, module3) {
      "use strict";
      var toPrimitive = require_to_primitive();
      var isSymbol = require_is_symbol();
      module3.exports = function(argument) {
        var key = toPrimitive(argument, "string");
        return isSymbol(key) ? key : key + "";
      };
    }
  });

  // ../../node_modules/core-js/internals/document-create-element.js
  var require_document_create_element = __commonJS({
    "../../node_modules/core-js/internals/document-create-element.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var isObject = require_is_object();
      var document2 = globalThis2.document;
      var EXISTS = isObject(document2) && isObject(document2.createElement);
      module3.exports = function(it) {
        return EXISTS ? document2.createElement(it) : {};
      };
    }
  });

  // ../../node_modules/core-js/internals/ie8-dom-define.js
  var require_ie8_dom_define = __commonJS({
    "../../node_modules/core-js/internals/ie8-dom-define.js"(exports, module3) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var fails = require_fails();
      var createElement = require_document_create_element();
      module3.exports = !DESCRIPTORS && !fails(function() {
        return Object.defineProperty(createElement("div"), "a", {
          get: function() {
            return 7;
          }
        }).a !== 7;
      });
    }
  });

  // ../../node_modules/core-js/internals/object-get-own-property-descriptor.js
  var require_object_get_own_property_descriptor = __commonJS({
    "../../node_modules/core-js/internals/object-get-own-property-descriptor.js"(exports) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var call = require_function_call();
      var propertyIsEnumerableModule = require_object_property_is_enumerable();
      var createPropertyDescriptor = require_create_property_descriptor();
      var toIndexedObject = require_to_indexed_object();
      var toPropertyKey = require_to_property_key();
      var hasOwn = require_has_own_property();
      var IE8_DOM_DEFINE = require_ie8_dom_define();
      var $getOwnPropertyDescriptor = Object.getOwnPropertyDescriptor;
      exports.f = DESCRIPTORS ? $getOwnPropertyDescriptor : function getOwnPropertyDescriptor(O, P) {
        O = toIndexedObject(O);
        P = toPropertyKey(P);
        if (IE8_DOM_DEFINE) try {
          return $getOwnPropertyDescriptor(O, P);
        } catch (error3) {
        }
        if (hasOwn(O, P)) return createPropertyDescriptor(!call(propertyIsEnumerableModule.f, O, P), O[P]);
      };
    }
  });

  // ../../node_modules/core-js/internals/v8-prototype-define-bug.js
  var require_v8_prototype_define_bug = __commonJS({
    "../../node_modules/core-js/internals/v8-prototype-define-bug.js"(exports, module3) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var fails = require_fails();
      module3.exports = DESCRIPTORS && fails(function() {
        return Object.defineProperty(function() {
        }, "prototype", {
          value: 42,
          writable: false
        }).prototype !== 42;
      });
    }
  });

  // ../../node_modules/core-js/internals/an-object.js
  var require_an_object = __commonJS({
    "../../node_modules/core-js/internals/an-object.js"(exports, module3) {
      "use strict";
      var isObject = require_is_object();
      var $String = String;
      var $TypeError = TypeError;
      module3.exports = function(argument) {
        if (isObject(argument)) return argument;
        throw new $TypeError($String(argument) + " is not an object");
      };
    }
  });

  // ../../node_modules/core-js/internals/object-define-property.js
  var require_object_define_property = __commonJS({
    "../../node_modules/core-js/internals/object-define-property.js"(exports) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var IE8_DOM_DEFINE = require_ie8_dom_define();
      var V8_PROTOTYPE_DEFINE_BUG = require_v8_prototype_define_bug();
      var anObject = require_an_object();
      var toPropertyKey = require_to_property_key();
      var $TypeError = TypeError;
      var $defineProperty = Object.defineProperty;
      var $getOwnPropertyDescriptor = Object.getOwnPropertyDescriptor;
      var ENUMERABLE = "enumerable";
      var CONFIGURABLE = "configurable";
      var WRITABLE = "writable";
      exports.f = DESCRIPTORS ? V8_PROTOTYPE_DEFINE_BUG ? function defineProperty(O, P, Attributes) {
        anObject(O);
        P = toPropertyKey(P);
        anObject(Attributes);
        if (typeof O === "function" && P === "prototype" && "value" in Attributes && WRITABLE in Attributes && !Attributes[WRITABLE]) {
          var current = $getOwnPropertyDescriptor(O, P);
          if (current && current[WRITABLE]) {
            O[P] = Attributes.value;
            Attributes = {
              configurable: CONFIGURABLE in Attributes ? Attributes[CONFIGURABLE] : current[CONFIGURABLE],
              enumerable: ENUMERABLE in Attributes ? Attributes[ENUMERABLE] : current[ENUMERABLE],
              writable: false
            };
          }
        }
        return $defineProperty(O, P, Attributes);
      } : $defineProperty : function defineProperty(O, P, Attributes) {
        anObject(O);
        P = toPropertyKey(P);
        anObject(Attributes);
        if (IE8_DOM_DEFINE) try {
          return $defineProperty(O, P, Attributes);
        } catch (error3) {
        }
        if ("get" in Attributes || "set" in Attributes) throw new $TypeError("Accessors not supported");
        if ("value" in Attributes) O[P] = Attributes.value;
        return O;
      };
    }
  });

  // ../../node_modules/core-js/internals/create-non-enumerable-property.js
  var require_create_non_enumerable_property = __commonJS({
    "../../node_modules/core-js/internals/create-non-enumerable-property.js"(exports, module3) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var definePropertyModule = require_object_define_property();
      var createPropertyDescriptor = require_create_property_descriptor();
      module3.exports = DESCRIPTORS ? function(object, key, value) {
        return definePropertyModule.f(object, key, createPropertyDescriptor(1, value));
      } : function(object, key, value) {
        object[key] = value;
        return object;
      };
    }
  });

  // ../../node_modules/core-js/internals/function-name.js
  var require_function_name = __commonJS({
    "../../node_modules/core-js/internals/function-name.js"(exports, module3) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var hasOwn = require_has_own_property();
      var FunctionPrototype = Function.prototype;
      var getDescriptor = DESCRIPTORS && Object.getOwnPropertyDescriptor;
      var EXISTS = hasOwn(FunctionPrototype, "name");
      var PROPER = EXISTS && function something() {
      }.name === "something";
      var CONFIGURABLE = EXISTS && (!DESCRIPTORS || DESCRIPTORS && getDescriptor(FunctionPrototype, "name").configurable);
      module3.exports = {
        EXISTS,
        PROPER,
        CONFIGURABLE
      };
    }
  });

  // ../../node_modules/core-js/internals/inspect-source.js
  var require_inspect_source = __commonJS({
    "../../node_modules/core-js/internals/inspect-source.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var isCallable = require_is_callable();
      var store = require_shared_store();
      var functionToString = uncurryThis(Function.toString);
      if (!isCallable(store.inspectSource)) {
        store.inspectSource = function(it) {
          return functionToString(it);
        };
      }
      module3.exports = store.inspectSource;
    }
  });

  // ../../node_modules/core-js/internals/weak-map-basic-detection.js
  var require_weak_map_basic_detection = __commonJS({
    "../../node_modules/core-js/internals/weak-map-basic-detection.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var isCallable = require_is_callable();
      var WeakMap2 = globalThis2.WeakMap;
      module3.exports = isCallable(WeakMap2) && /native code/.test(String(WeakMap2));
    }
  });

  // ../../node_modules/core-js/internals/shared-key.js
  var require_shared_key = __commonJS({
    "../../node_modules/core-js/internals/shared-key.js"(exports, module3) {
      "use strict";
      var shared = require_shared();
      var uid = require_uid();
      var keys = shared("keys");
      module3.exports = function(key) {
        return keys[key] || (keys[key] = uid(key));
      };
    }
  });

  // ../../node_modules/core-js/internals/hidden-keys.js
  var require_hidden_keys = __commonJS({
    "../../node_modules/core-js/internals/hidden-keys.js"(exports, module3) {
      "use strict";
      module3.exports = {};
    }
  });

  // ../../node_modules/core-js/internals/internal-state.js
  var require_internal_state = __commonJS({
    "../../node_modules/core-js/internals/internal-state.js"(exports, module3) {
      "use strict";
      var NATIVE_WEAK_MAP = require_weak_map_basic_detection();
      var globalThis2 = require_global_this();
      var isObject = require_is_object();
      var createNonEnumerableProperty = require_create_non_enumerable_property();
      var hasOwn = require_has_own_property();
      var shared = require_shared_store();
      var sharedKey = require_shared_key();
      var hiddenKeys = require_hidden_keys();
      var OBJECT_ALREADY_INITIALIZED = "Object already initialized";
      var TypeError2 = globalThis2.TypeError;
      var WeakMap2 = globalThis2.WeakMap;
      var set;
      var get;
      var has;
      var enforce = function(it) {
        return has(it) ? get(it) : set(it, {});
      };
      var getterFor = function(TYPE) {
        return function(it) {
          var state;
          if (!isObject(it) || (state = get(it)).type !== TYPE) {
            throw new TypeError2("Incompatible receiver, " + TYPE + " required");
          }
          return state;
        };
      };
      if (NATIVE_WEAK_MAP || shared.state) {
        store = shared.state || (shared.state = new WeakMap2());
        store.get = store.get;
        store.has = store.has;
        store.set = store.set;
        set = function(it, metadata) {
          if (store.has(it)) throw new TypeError2(OBJECT_ALREADY_INITIALIZED);
          metadata.facade = it;
          store.set(it, metadata);
          return metadata;
        };
        get = function(it) {
          return store.get(it) || {};
        };
        has = function(it) {
          return store.has(it);
        };
      } else {
        STATE = sharedKey("state");
        hiddenKeys[STATE] = true;
        set = function(it, metadata) {
          if (hasOwn(it, STATE)) throw new TypeError2(OBJECT_ALREADY_INITIALIZED);
          metadata.facade = it;
          createNonEnumerableProperty(it, STATE, metadata);
          return metadata;
        };
        get = function(it) {
          return hasOwn(it, STATE) ? it[STATE] : {};
        };
        has = function(it) {
          return hasOwn(it, STATE);
        };
      }
      var store;
      var STATE;
      module3.exports = {
        set,
        get,
        has,
        enforce,
        getterFor
      };
    }
  });

  // ../../node_modules/core-js/internals/make-built-in.js
  var require_make_built_in = __commonJS({
    "../../node_modules/core-js/internals/make-built-in.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var fails = require_fails();
      var isCallable = require_is_callable();
      var hasOwn = require_has_own_property();
      var DESCRIPTORS = require_descriptors();
      var CONFIGURABLE_FUNCTION_NAME = require_function_name().CONFIGURABLE;
      var inspectSource = require_inspect_source();
      var InternalStateModule = require_internal_state();
      var enforceInternalState = InternalStateModule.enforce;
      var getInternalState = InternalStateModule.get;
      var $String = String;
      var defineProperty = Object.defineProperty;
      var stringSlice = uncurryThis("".slice);
      var replace = uncurryThis("".replace);
      var join = uncurryThis([].join);
      var CONFIGURABLE_LENGTH = DESCRIPTORS && !fails(function() {
        return defineProperty(function() {
        }, "length", { value: 8 }).length !== 8;
      });
      var TEMPLATE = String(String).split("String");
      var makeBuiltIn = module3.exports = function(value, name3, options) {
        if (stringSlice($String(name3), 0, 7) === "Symbol(") {
          name3 = "[" + replace($String(name3), /^Symbol\(([^)]*)\).*$/, "$1") + "]";
        }
        if (options && options.getter) name3 = "get " + name3;
        if (options && options.setter) name3 = "set " + name3;
        if (!hasOwn(value, "name") || CONFIGURABLE_FUNCTION_NAME && value.name !== name3) {
          if (DESCRIPTORS) defineProperty(value, "name", { value: name3, configurable: true });
          else value.name = name3;
        }
        if (CONFIGURABLE_LENGTH && options && hasOwn(options, "arity") && value.length !== options.arity) {
          defineProperty(value, "length", { value: options.arity });
        }
        try {
          if (options && hasOwn(options, "constructor") && options.constructor) {
            if (DESCRIPTORS) defineProperty(value, "prototype", { writable: false });
          } else if (value.prototype) value.prototype = void 0;
        } catch (error3) {
        }
        var state = enforceInternalState(value);
        if (!hasOwn(state, "source")) {
          state.source = join(TEMPLATE, typeof name3 == "string" ? name3 : "");
        }
        return value;
      };
      Function.prototype.toString = makeBuiltIn(function toString() {
        return isCallable(this) && getInternalState(this).source || inspectSource(this);
      }, "toString");
    }
  });

  // ../../node_modules/core-js/internals/define-built-in.js
  var require_define_built_in = __commonJS({
    "../../node_modules/core-js/internals/define-built-in.js"(exports, module3) {
      "use strict";
      var isCallable = require_is_callable();
      var definePropertyModule = require_object_define_property();
      var makeBuiltIn = require_make_built_in();
      var defineGlobalProperty = require_define_global_property();
      module3.exports = function(O, key, value, options) {
        if (!options) options = {};
        var simple = options.enumerable;
        var name3 = options.name !== void 0 ? options.name : key;
        if (isCallable(value)) makeBuiltIn(value, name3, options);
        if (options.global) {
          if (simple) O[key] = value;
          else defineGlobalProperty(key, value);
        } else {
          try {
            if (!options.unsafe) delete O[key];
            else if (O[key]) simple = true;
          } catch (error3) {
          }
          if (simple) O[key] = value;
          else definePropertyModule.f(O, key, {
            value,
            enumerable: false,
            configurable: !options.nonConfigurable,
            writable: !options.nonWritable
          });
        }
        return O;
      };
    }
  });

  // ../../node_modules/core-js/internals/math-trunc.js
  var require_math_trunc = __commonJS({
    "../../node_modules/core-js/internals/math-trunc.js"(exports, module3) {
      "use strict";
      var ceil = Math.ceil;
      var floor = Math.floor;
      module3.exports = Math.trunc || function trunc(x2) {
        var n2 = +x2;
        return (n2 > 0 ? floor : ceil)(n2);
      };
    }
  });

  // ../../node_modules/core-js/internals/to-integer-or-infinity.js
  var require_to_integer_or_infinity = __commonJS({
    "../../node_modules/core-js/internals/to-integer-or-infinity.js"(exports, module3) {
      "use strict";
      var trunc = require_math_trunc();
      module3.exports = function(argument) {
        var number = +argument;
        return number !== number || number === 0 ? 0 : trunc(number);
      };
    }
  });

  // ../../node_modules/core-js/internals/to-absolute-index.js
  var require_to_absolute_index = __commonJS({
    "../../node_modules/core-js/internals/to-absolute-index.js"(exports, module3) {
      "use strict";
      var toIntegerOrInfinity = require_to_integer_or_infinity();
      var max2 = Math.max;
      var min2 = Math.min;
      module3.exports = function(index, length) {
        var integer = toIntegerOrInfinity(index);
        return integer < 0 ? max2(integer + length, 0) : min2(integer, length);
      };
    }
  });

  // ../../node_modules/core-js/internals/to-length.js
  var require_to_length = __commonJS({
    "../../node_modules/core-js/internals/to-length.js"(exports, module3) {
      "use strict";
      var toIntegerOrInfinity = require_to_integer_or_infinity();
      var min2 = Math.min;
      module3.exports = function(argument) {
        var len = toIntegerOrInfinity(argument);
        return len > 0 ? min2(len, 9007199254740991) : 0;
      };
    }
  });

  // ../../node_modules/core-js/internals/length-of-array-like.js
  var require_length_of_array_like = __commonJS({
    "../../node_modules/core-js/internals/length-of-array-like.js"(exports, module3) {
      "use strict";
      var toLength = require_to_length();
      module3.exports = function(obj) {
        return toLength(obj.length);
      };
    }
  });

  // ../../node_modules/core-js/internals/array-includes.js
  var require_array_includes = __commonJS({
    "../../node_modules/core-js/internals/array-includes.js"(exports, module3) {
      "use strict";
      var toIndexedObject = require_to_indexed_object();
      var toAbsoluteIndex = require_to_absolute_index();
      var lengthOfArrayLike = require_length_of_array_like();
      var createMethod = function(IS_INCLUDES) {
        return function($this, el, fromIndex) {
          var O = toIndexedObject($this);
          var length = lengthOfArrayLike(O);
          if (length === 0) return !IS_INCLUDES && -1;
          var index = toAbsoluteIndex(fromIndex, length);
          var value;
          if (IS_INCLUDES && el !== el) while (length > index) {
            value = O[index++];
            if (value !== value) return true;
          }
          else for (; length > index; index++) {
            if ((IS_INCLUDES || index in O) && O[index] === el) return IS_INCLUDES || index || 0;
          }
          return !IS_INCLUDES && -1;
        };
      };
      module3.exports = {
        // `Array.prototype.includes` method
        // https://tc39.es/ecma262/#sec-array.prototype.includes
        includes: createMethod(true),
        // `Array.prototype.indexOf` method
        // https://tc39.es/ecma262/#sec-array.prototype.indexof
        indexOf: createMethod(false)
      };
    }
  });

  // ../../node_modules/core-js/internals/object-keys-internal.js
  var require_object_keys_internal = __commonJS({
    "../../node_modules/core-js/internals/object-keys-internal.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var hasOwn = require_has_own_property();
      var toIndexedObject = require_to_indexed_object();
      var indexOf4 = require_array_includes().indexOf;
      var hiddenKeys = require_hidden_keys();
      var push = uncurryThis([].push);
      module3.exports = function(object, names) {
        var O = toIndexedObject(object);
        var i = 0;
        var result = [];
        var key;
        for (key in O) !hasOwn(hiddenKeys, key) && hasOwn(O, key) && push(result, key);
        while (names.length > i) if (hasOwn(O, key = names[i++])) {
          ~indexOf4(result, key) || push(result, key);
        }
        return result;
      };
    }
  });

  // ../../node_modules/core-js/internals/enum-bug-keys.js
  var require_enum_bug_keys = __commonJS({
    "../../node_modules/core-js/internals/enum-bug-keys.js"(exports, module3) {
      "use strict";
      module3.exports = [
        "constructor",
        "hasOwnProperty",
        "isPrototypeOf",
        "propertyIsEnumerable",
        "toLocaleString",
        "toString",
        "valueOf"
      ];
    }
  });

  // ../../node_modules/core-js/internals/object-get-own-property-names.js
  var require_object_get_own_property_names = __commonJS({
    "../../node_modules/core-js/internals/object-get-own-property-names.js"(exports) {
      "use strict";
      var internalObjectKeys = require_object_keys_internal();
      var enumBugKeys = require_enum_bug_keys();
      var hiddenKeys = enumBugKeys.concat("length", "prototype");
      exports.f = Object.getOwnPropertyNames || function getOwnPropertyNames(O) {
        return internalObjectKeys(O, hiddenKeys);
      };
    }
  });

  // ../../node_modules/core-js/internals/object-get-own-property-symbols.js
  var require_object_get_own_property_symbols = __commonJS({
    "../../node_modules/core-js/internals/object-get-own-property-symbols.js"(exports) {
      "use strict";
      exports.f = Object.getOwnPropertySymbols;
    }
  });

  // ../../node_modules/core-js/internals/own-keys.js
  var require_own_keys = __commonJS({
    "../../node_modules/core-js/internals/own-keys.js"(exports, module3) {
      "use strict";
      var getBuiltIn = require_get_built_in();
      var uncurryThis = require_function_uncurry_this();
      var getOwnPropertyNamesModule = require_object_get_own_property_names();
      var getOwnPropertySymbolsModule = require_object_get_own_property_symbols();
      var anObject = require_an_object();
      var concat = uncurryThis([].concat);
      module3.exports = getBuiltIn("Reflect", "ownKeys") || function ownKeys(it) {
        var keys = getOwnPropertyNamesModule.f(anObject(it));
        var getOwnPropertySymbols = getOwnPropertySymbolsModule.f;
        return getOwnPropertySymbols ? concat(keys, getOwnPropertySymbols(it)) : keys;
      };
    }
  });

  // ../../node_modules/core-js/internals/copy-constructor-properties.js
  var require_copy_constructor_properties = __commonJS({
    "../../node_modules/core-js/internals/copy-constructor-properties.js"(exports, module3) {
      "use strict";
      var hasOwn = require_has_own_property();
      var ownKeys = require_own_keys();
      var getOwnPropertyDescriptorModule = require_object_get_own_property_descriptor();
      var definePropertyModule = require_object_define_property();
      module3.exports = function(target, source, exceptions) {
        var keys = ownKeys(source);
        var defineProperty = definePropertyModule.f;
        var getOwnPropertyDescriptor = getOwnPropertyDescriptorModule.f;
        for (var i = 0; i < keys.length; i++) {
          var key = keys[i];
          if (!hasOwn(target, key) && !(exceptions && hasOwn(exceptions, key))) {
            defineProperty(target, key, getOwnPropertyDescriptor(source, key));
          }
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/is-forced.js
  var require_is_forced = __commonJS({
    "../../node_modules/core-js/internals/is-forced.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      var isCallable = require_is_callable();
      var replacement = /#|\.prototype\./;
      var isForced = function(feature, detection) {
        var value = data[normalize(feature)];
        return value === POLYFILL ? true : value === NATIVE ? false : isCallable(detection) ? fails(detection) : !!detection;
      };
      var normalize = isForced.normalize = function(string) {
        return String(string).replace(replacement, ".").toLowerCase();
      };
      var data = isForced.data = {};
      var NATIVE = isForced.NATIVE = "N";
      var POLYFILL = isForced.POLYFILL = "P";
      module3.exports = isForced;
    }
  });

  // ../../node_modules/core-js/internals/export.js
  var require_export = __commonJS({
    "../../node_modules/core-js/internals/export.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var getOwnPropertyDescriptor = require_object_get_own_property_descriptor().f;
      var createNonEnumerableProperty = require_create_non_enumerable_property();
      var defineBuiltIn = require_define_built_in();
      var defineGlobalProperty = require_define_global_property();
      var copyConstructorProperties = require_copy_constructor_properties();
      var isForced = require_is_forced();
      module3.exports = function(options, source) {
        var TARGET = options.target;
        var GLOBAL = options.global;
        var STATIC = options.stat;
        var FORCED, target, key, targetProperty, sourceProperty, descriptor;
        if (GLOBAL) {
          target = globalThis2;
        } else if (STATIC) {
          target = globalThis2[TARGET] || defineGlobalProperty(TARGET, {});
        } else {
          target = globalThis2[TARGET] && globalThis2[TARGET].prototype;
        }
        if (target) for (key in source) {
          sourceProperty = source[key];
          if (options.dontCallGetSet) {
            descriptor = getOwnPropertyDescriptor(target, key);
            targetProperty = descriptor && descriptor.value;
          } else targetProperty = target[key];
          FORCED = isForced(GLOBAL ? key : TARGET + (STATIC ? "." : "#") + key, options.forced);
          if (!FORCED && targetProperty !== void 0) {
            if (typeof sourceProperty == typeof targetProperty) continue;
            copyConstructorProperties(sourceProperty, targetProperty);
          }
          if (options.sham || targetProperty && targetProperty.sham) {
            createNonEnumerableProperty(sourceProperty, "sham", true);
          }
          defineBuiltIn(target, key, sourceProperty, options);
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/function-uncurry-this-clause.js
  var require_function_uncurry_this_clause = __commonJS({
    "../../node_modules/core-js/internals/function-uncurry-this-clause.js"(exports, module3) {
      "use strict";
      var classofRaw = require_classof_raw();
      var uncurryThis = require_function_uncurry_this();
      module3.exports = function(fn2) {
        if (classofRaw(fn2) === "Function") return uncurryThis(fn2);
      };
    }
  });

  // ../../node_modules/core-js/internals/function-bind-context.js
  var require_function_bind_context = __commonJS({
    "../../node_modules/core-js/internals/function-bind-context.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this_clause();
      var aCallable = require_a_callable();
      var NATIVE_BIND = require_function_bind_native();
      var bind = uncurryThis(uncurryThis.bind);
      module3.exports = function(fn2, that) {
        aCallable(fn2);
        return that === void 0 ? fn2 : NATIVE_BIND ? bind(fn2, that) : function() {
          return fn2.apply(that, arguments);
        };
      };
    }
  });

  // ../../node_modules/core-js/internals/is-array.js
  var require_is_array = __commonJS({
    "../../node_modules/core-js/internals/is-array.js"(exports, module3) {
      "use strict";
      var classof = require_classof_raw();
      module3.exports = Array.isArray || function isArray(argument) {
        return classof(argument) === "Array";
      };
    }
  });

  // ../../node_modules/core-js/internals/to-string-tag-support.js
  var require_to_string_tag_support = __commonJS({
    "../../node_modules/core-js/internals/to-string-tag-support.js"(exports, module3) {
      "use strict";
      var wellKnownSymbol = require_well_known_symbol();
      var TO_STRING_TAG = wellKnownSymbol("toStringTag");
      var test = {};
      test[TO_STRING_TAG] = "z";
      module3.exports = String(test) === "[object z]";
    }
  });

  // ../../node_modules/core-js/internals/classof.js
  var require_classof = __commonJS({
    "../../node_modules/core-js/internals/classof.js"(exports, module3) {
      "use strict";
      var TO_STRING_TAG_SUPPORT = require_to_string_tag_support();
      var isCallable = require_is_callable();
      var classofRaw = require_classof_raw();
      var wellKnownSymbol = require_well_known_symbol();
      var TO_STRING_TAG = wellKnownSymbol("toStringTag");
      var $Object = Object;
      var CORRECT_ARGUMENTS = classofRaw(/* @__PURE__ */ function() {
        return arguments;
      }()) === "Arguments";
      var tryGet = function(it, key) {
        try {
          return it[key];
        } catch (error3) {
        }
      };
      module3.exports = TO_STRING_TAG_SUPPORT ? classofRaw : function(it) {
        var O, tag, result;
        return it === void 0 ? "Undefined" : it === null ? "Null" : typeof (tag = tryGet(O = $Object(it), TO_STRING_TAG)) == "string" ? tag : CORRECT_ARGUMENTS ? classofRaw(O) : (result = classofRaw(O)) === "Object" && isCallable(O.callee) ? "Arguments" : result;
      };
    }
  });

  // ../../node_modules/core-js/internals/is-constructor.js
  var require_is_constructor = __commonJS({
    "../../node_modules/core-js/internals/is-constructor.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var fails = require_fails();
      var isCallable = require_is_callable();
      var classof = require_classof();
      var getBuiltIn = require_get_built_in();
      var inspectSource = require_inspect_source();
      var noop2 = function() {
      };
      var construct = getBuiltIn("Reflect", "construct");
      var constructorRegExp = /^\s*(?:class|function)\b/;
      var exec = uncurryThis(constructorRegExp.exec);
      var INCORRECT_TO_STRING = !constructorRegExp.test(noop2);
      var isConstructorModern = function isConstructor(argument) {
        if (!isCallable(argument)) return false;
        try {
          construct(noop2, [], argument);
          return true;
        } catch (error3) {
          return false;
        }
      };
      var isConstructorLegacy = function isConstructor(argument) {
        if (!isCallable(argument)) return false;
        switch (classof(argument)) {
          case "AsyncFunction":
          case "GeneratorFunction":
          case "AsyncGeneratorFunction":
            return false;
        }
        try {
          return INCORRECT_TO_STRING || !!exec(constructorRegExp, inspectSource(argument));
        } catch (error3) {
          return true;
        }
      };
      isConstructorLegacy.sham = true;
      module3.exports = !construct || fails(function() {
        var called;
        return isConstructorModern(isConstructorModern.call) || !isConstructorModern(Object) || !isConstructorModern(function() {
          called = true;
        }) || called;
      }) ? isConstructorLegacy : isConstructorModern;
    }
  });

  // ../../node_modules/core-js/internals/array-species-constructor.js
  var require_array_species_constructor = __commonJS({
    "../../node_modules/core-js/internals/array-species-constructor.js"(exports, module3) {
      "use strict";
      var isArray = require_is_array();
      var isConstructor = require_is_constructor();
      var isObject = require_is_object();
      var wellKnownSymbol = require_well_known_symbol();
      var SPECIES = wellKnownSymbol("species");
      var $Array = Array;
      module3.exports = function(originalArray) {
        var C2;
        if (isArray(originalArray)) {
          C2 = originalArray.constructor;
          if (isConstructor(C2) && (C2 === $Array || isArray(C2.prototype))) C2 = void 0;
          else if (isObject(C2)) {
            C2 = C2[SPECIES];
            if (C2 === null) C2 = void 0;
          }
        }
        return C2 === void 0 ? $Array : C2;
      };
    }
  });

  // ../../node_modules/core-js/internals/array-species-create.js
  var require_array_species_create = __commonJS({
    "../../node_modules/core-js/internals/array-species-create.js"(exports, module3) {
      "use strict";
      var arraySpeciesConstructor = require_array_species_constructor();
      module3.exports = function(originalArray, length) {
        return new (arraySpeciesConstructor(originalArray))(length === 0 ? 0 : length);
      };
    }
  });

  // ../../node_modules/core-js/internals/array-iteration.js
  var require_array_iteration = __commonJS({
    "../../node_modules/core-js/internals/array-iteration.js"(exports, module3) {
      "use strict";
      var bind = require_function_bind_context();
      var uncurryThis = require_function_uncurry_this();
      var IndexedObject = require_indexed_object();
      var toObject = require_to_object();
      var lengthOfArrayLike = require_length_of_array_like();
      var arraySpeciesCreate = require_array_species_create();
      var push = uncurryThis([].push);
      var createMethod = function(TYPE) {
        var IS_MAP = TYPE === 1;
        var IS_FILTER = TYPE === 2;
        var IS_SOME = TYPE === 3;
        var IS_EVERY = TYPE === 4;
        var IS_FIND_INDEX = TYPE === 6;
        var IS_FILTER_REJECT = TYPE === 7;
        var NO_HOLES = TYPE === 5 || IS_FIND_INDEX;
        return function($this, callbackfn, that, specificCreate) {
          var O = toObject($this);
          var self2 = IndexedObject(O);
          var length = lengthOfArrayLike(self2);
          var boundFunction = bind(callbackfn, that);
          var index = 0;
          var create = specificCreate || arraySpeciesCreate;
          var target = IS_MAP ? create($this, length) : IS_FILTER || IS_FILTER_REJECT ? create($this, 0) : void 0;
          var value, result;
          for (; length > index; index++) if (NO_HOLES || index in self2) {
            value = self2[index];
            result = boundFunction(value, index, O);
            if (TYPE) {
              if (IS_MAP) target[index] = result;
              else if (result) switch (TYPE) {
                case 3:
                  return true;
                // some
                case 5:
                  return value;
                // find
                case 6:
                  return index;
                // findIndex
                case 2:
                  push(target, value);
              }
              else switch (TYPE) {
                case 4:
                  return false;
                // every
                case 7:
                  push(target, value);
              }
            }
          }
          return IS_FIND_INDEX ? -1 : IS_SOME || IS_EVERY ? IS_EVERY : target;
        };
      };
      module3.exports = {
        // `Array.prototype.forEach` method
        // https://tc39.es/ecma262/#sec-array.prototype.foreach
        forEach: createMethod(0),
        // `Array.prototype.map` method
        // https://tc39.es/ecma262/#sec-array.prototype.map
        map: createMethod(1),
        // `Array.prototype.filter` method
        // https://tc39.es/ecma262/#sec-array.prototype.filter
        filter: createMethod(2),
        // `Array.prototype.some` method
        // https://tc39.es/ecma262/#sec-array.prototype.some
        some: createMethod(3),
        // `Array.prototype.every` method
        // https://tc39.es/ecma262/#sec-array.prototype.every
        every: createMethod(4),
        // `Array.prototype.find` method
        // https://tc39.es/ecma262/#sec-array.prototype.find
        find: createMethod(5),
        // `Array.prototype.findIndex` method
        // https://tc39.es/ecma262/#sec-array.prototype.findIndex
        findIndex: createMethod(6),
        // `Array.prototype.filterReject` method
        // https://github.com/tc39/proposal-array-filtering
        filterReject: createMethod(7)
      };
    }
  });

  // ../../node_modules/core-js/internals/object-keys.js
  var require_object_keys = __commonJS({
    "../../node_modules/core-js/internals/object-keys.js"(exports, module3) {
      "use strict";
      var internalObjectKeys = require_object_keys_internal();
      var enumBugKeys = require_enum_bug_keys();
      module3.exports = Object.keys || function keys(O) {
        return internalObjectKeys(O, enumBugKeys);
      };
    }
  });

  // ../../node_modules/core-js/internals/object-define-properties.js
  var require_object_define_properties = __commonJS({
    "../../node_modules/core-js/internals/object-define-properties.js"(exports) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var V8_PROTOTYPE_DEFINE_BUG = require_v8_prototype_define_bug();
      var definePropertyModule = require_object_define_property();
      var anObject = require_an_object();
      var toIndexedObject = require_to_indexed_object();
      var objectKeys = require_object_keys();
      exports.f = DESCRIPTORS && !V8_PROTOTYPE_DEFINE_BUG ? Object.defineProperties : function defineProperties(O, Properties) {
        anObject(O);
        var props = toIndexedObject(Properties);
        var keys = objectKeys(Properties);
        var length = keys.length;
        var index = 0;
        var key;
        while (length > index) definePropertyModule.f(O, key = keys[index++], props[key]);
        return O;
      };
    }
  });

  // ../../node_modules/core-js/internals/html.js
  var require_html = __commonJS({
    "../../node_modules/core-js/internals/html.js"(exports, module3) {
      "use strict";
      var getBuiltIn = require_get_built_in();
      module3.exports = getBuiltIn("document", "documentElement");
    }
  });

  // ../../node_modules/core-js/internals/object-create.js
  var require_object_create = __commonJS({
    "../../node_modules/core-js/internals/object-create.js"(exports, module3) {
      "use strict";
      var anObject = require_an_object();
      var definePropertiesModule = require_object_define_properties();
      var enumBugKeys = require_enum_bug_keys();
      var hiddenKeys = require_hidden_keys();
      var html = require_html();
      var documentCreateElement = require_document_create_element();
      var sharedKey = require_shared_key();
      var GT = ">";
      var LT = "<";
      var PROTOTYPE = "prototype";
      var SCRIPT = "script";
      var IE_PROTO = sharedKey("IE_PROTO");
      var EmptyConstructor = function() {
      };
      var scriptTag = function(content) {
        return LT + SCRIPT + GT + content + LT + "/" + SCRIPT + GT;
      };
      var NullProtoObjectViaActiveX = function(activeXDocument2) {
        activeXDocument2.write(scriptTag(""));
        activeXDocument2.close();
        var temp = activeXDocument2.parentWindow.Object;
        activeXDocument2 = null;
        return temp;
      };
      var NullProtoObjectViaIFrame = function() {
        var iframe = documentCreateElement("iframe");
        var JS = "java" + SCRIPT + ":";
        var iframeDocument;
        iframe.style.display = "none";
        html.appendChild(iframe);
        iframe.src = String(JS);
        iframeDocument = iframe.contentWindow.document;
        iframeDocument.open();
        iframeDocument.write(scriptTag("document.F=Object"));
        iframeDocument.close();
        return iframeDocument.F;
      };
      var activeXDocument;
      var NullProtoObject = function() {
        try {
          activeXDocument = new ActiveXObject("htmlfile");
        } catch (error3) {
        }
        NullProtoObject = typeof document != "undefined" ? document.domain && activeXDocument ? NullProtoObjectViaActiveX(activeXDocument) : NullProtoObjectViaIFrame() : NullProtoObjectViaActiveX(activeXDocument);
        var length = enumBugKeys.length;
        while (length--) delete NullProtoObject[PROTOTYPE][enumBugKeys[length]];
        return NullProtoObject();
      };
      hiddenKeys[IE_PROTO] = true;
      module3.exports = Object.create || function create(O, Properties) {
        var result;
        if (O !== null) {
          EmptyConstructor[PROTOTYPE] = anObject(O);
          result = new EmptyConstructor();
          EmptyConstructor[PROTOTYPE] = null;
          result[IE_PROTO] = O;
        } else result = NullProtoObject();
        return Properties === void 0 ? result : definePropertiesModule.f(result, Properties);
      };
    }
  });

  // ../../node_modules/core-js/internals/add-to-unscopables.js
  var require_add_to_unscopables = __commonJS({
    "../../node_modules/core-js/internals/add-to-unscopables.js"(exports, module3) {
      "use strict";
      var wellKnownSymbol = require_well_known_symbol();
      var create = require_object_create();
      var defineProperty = require_object_define_property().f;
      var UNSCOPABLES = wellKnownSymbol("unscopables");
      var ArrayPrototype = Array.prototype;
      if (ArrayPrototype[UNSCOPABLES] === void 0) {
        defineProperty(ArrayPrototype, UNSCOPABLES, {
          configurable: true,
          value: create(null)
        });
      }
      module3.exports = function(key) {
        ArrayPrototype[UNSCOPABLES][key] = true;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.array.find.js
  var require_es_array_find = __commonJS({
    "../../node_modules/core-js/modules/es.array.find.js"() {
      "use strict";
      var $ = require_export();
      var $find = require_array_iteration().find;
      var addToUnscopables = require_add_to_unscopables();
      var FIND = "find";
      var SKIPS_HOLES = true;
      if (FIND in []) Array(1)[FIND](function() {
        SKIPS_HOLES = false;
      });
      $({ target: "Array", proto: true, forced: SKIPS_HOLES }, {
        find: function find(callbackfn) {
          return $find(this, callbackfn, arguments.length > 1 ? arguments[1] : void 0);
        }
      });
      addToUnscopables(FIND);
    }
  });

  // ../../node_modules/core-js/internals/entry-unbind.js
  var require_entry_unbind = __commonJS({
    "../../node_modules/core-js/internals/entry-unbind.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var uncurryThis = require_function_uncurry_this();
      module3.exports = function(CONSTRUCTOR, METHOD) {
        return uncurryThis(globalThis2[CONSTRUCTOR].prototype[METHOD]);
      };
    }
  });

  // ../../node_modules/core-js/es/array/find.js
  var require_find = __commonJS({
    "../../node_modules/core-js/es/array/find.js"(exports, module3) {
      "use strict";
      require_es_array_find();
      var entryUnbind = require_entry_unbind();
      module3.exports = entryUnbind("Array", "find");
    }
  });

  // ../../node_modules/core-js/modules/es.array.find-index.js
  var require_es_array_find_index = __commonJS({
    "../../node_modules/core-js/modules/es.array.find-index.js"() {
      "use strict";
      var $ = require_export();
      var $findIndex = require_array_iteration().findIndex;
      var addToUnscopables = require_add_to_unscopables();
      var FIND_INDEX = "findIndex";
      var SKIPS_HOLES = true;
      if (FIND_INDEX in []) Array(1)[FIND_INDEX](function() {
        SKIPS_HOLES = false;
      });
      $({ target: "Array", proto: true, forced: SKIPS_HOLES }, {
        findIndex: function findIndex(callbackfn) {
          return $findIndex(this, callbackfn, arguments.length > 1 ? arguments[1] : void 0);
        }
      });
      addToUnscopables(FIND_INDEX);
    }
  });

  // ../../node_modules/core-js/es/array/find-index.js
  var require_find_index = __commonJS({
    "../../node_modules/core-js/es/array/find-index.js"(exports, module3) {
      "use strict";
      require_es_array_find_index();
      var entryUnbind = require_entry_unbind();
      module3.exports = entryUnbind("Array", "findIndex");
    }
  });

  // ../../node_modules/core-js/internals/to-string.js
  var require_to_string = __commonJS({
    "../../node_modules/core-js/internals/to-string.js"(exports, module3) {
      "use strict";
      var classof = require_classof();
      var $String = String;
      module3.exports = function(argument) {
        if (classof(argument) === "Symbol") throw new TypeError("Cannot convert a Symbol value to a string");
        return $String(argument);
      };
    }
  });

  // ../../node_modules/core-js/internals/string-multibyte.js
  var require_string_multibyte = __commonJS({
    "../../node_modules/core-js/internals/string-multibyte.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var toIntegerOrInfinity = require_to_integer_or_infinity();
      var toString = require_to_string();
      var requireObjectCoercible = require_require_object_coercible();
      var charAt = uncurryThis("".charAt);
      var charCodeAt = uncurryThis("".charCodeAt);
      var stringSlice = uncurryThis("".slice);
      var createMethod = function(CONVERT_TO_STRING) {
        return function($this, pos) {
          var S = toString(requireObjectCoercible($this));
          var position = toIntegerOrInfinity(pos);
          var size = S.length;
          var first, second;
          if (position < 0 || position >= size) return CONVERT_TO_STRING ? "" : void 0;
          first = charCodeAt(S, position);
          return first < 55296 || first > 56319 || position + 1 === size || (second = charCodeAt(S, position + 1)) < 56320 || second > 57343 ? CONVERT_TO_STRING ? charAt(S, position) : first : CONVERT_TO_STRING ? stringSlice(S, position, position + 2) : (first - 55296 << 10) + (second - 56320) + 65536;
        };
      };
      module3.exports = {
        // `String.prototype.codePointAt` method
        // https://tc39.es/ecma262/#sec-string.prototype.codepointat
        codeAt: createMethod(false),
        // `String.prototype.at` method
        // https://github.com/mathiasbynens/String.prototype.at
        charAt: createMethod(true)
      };
    }
  });

  // ../../node_modules/core-js/internals/correct-prototype-getter.js
  var require_correct_prototype_getter = __commonJS({
    "../../node_modules/core-js/internals/correct-prototype-getter.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      module3.exports = !fails(function() {
        function F() {
        }
        F.prototype.constructor = null;
        return Object.getPrototypeOf(new F()) !== F.prototype;
      });
    }
  });

  // ../../node_modules/core-js/internals/object-get-prototype-of.js
  var require_object_get_prototype_of = __commonJS({
    "../../node_modules/core-js/internals/object-get-prototype-of.js"(exports, module3) {
      "use strict";
      var hasOwn = require_has_own_property();
      var isCallable = require_is_callable();
      var toObject = require_to_object();
      var sharedKey = require_shared_key();
      var CORRECT_PROTOTYPE_GETTER = require_correct_prototype_getter();
      var IE_PROTO = sharedKey("IE_PROTO");
      var $Object = Object;
      var ObjectPrototype = $Object.prototype;
      module3.exports = CORRECT_PROTOTYPE_GETTER ? $Object.getPrototypeOf : function(O) {
        var object = toObject(O);
        if (hasOwn(object, IE_PROTO)) return object[IE_PROTO];
        var constructor = object.constructor;
        if (isCallable(constructor) && object instanceof constructor) {
          return constructor.prototype;
        }
        return object instanceof $Object ? ObjectPrototype : null;
      };
    }
  });

  // ../../node_modules/core-js/internals/iterators-core.js
  var require_iterators_core = __commonJS({
    "../../node_modules/core-js/internals/iterators-core.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      var isCallable = require_is_callable();
      var isObject = require_is_object();
      var create = require_object_create();
      var getPrototypeOf = require_object_get_prototype_of();
      var defineBuiltIn = require_define_built_in();
      var wellKnownSymbol = require_well_known_symbol();
      var IS_PURE = require_is_pure();
      var ITERATOR = wellKnownSymbol("iterator");
      var BUGGY_SAFARI_ITERATORS = false;
      var IteratorPrototype;
      var PrototypeOfArrayIteratorPrototype;
      var arrayIterator;
      if ([].keys) {
        arrayIterator = [].keys();
        if (!("next" in arrayIterator)) BUGGY_SAFARI_ITERATORS = true;
        else {
          PrototypeOfArrayIteratorPrototype = getPrototypeOf(getPrototypeOf(arrayIterator));
          if (PrototypeOfArrayIteratorPrototype !== Object.prototype) IteratorPrototype = PrototypeOfArrayIteratorPrototype;
        }
      }
      var NEW_ITERATOR_PROTOTYPE = !isObject(IteratorPrototype) || fails(function() {
        var test = {};
        return IteratorPrototype[ITERATOR].call(test) !== test;
      });
      if (NEW_ITERATOR_PROTOTYPE) IteratorPrototype = {};
      else if (IS_PURE) IteratorPrototype = create(IteratorPrototype);
      if (!isCallable(IteratorPrototype[ITERATOR])) {
        defineBuiltIn(IteratorPrototype, ITERATOR, function() {
          return this;
        });
      }
      module3.exports = {
        IteratorPrototype,
        BUGGY_SAFARI_ITERATORS
      };
    }
  });

  // ../../node_modules/core-js/internals/set-to-string-tag.js
  var require_set_to_string_tag = __commonJS({
    "../../node_modules/core-js/internals/set-to-string-tag.js"(exports, module3) {
      "use strict";
      var defineProperty = require_object_define_property().f;
      var hasOwn = require_has_own_property();
      var wellKnownSymbol = require_well_known_symbol();
      var TO_STRING_TAG = wellKnownSymbol("toStringTag");
      module3.exports = function(target, TAG, STATIC) {
        if (target && !STATIC) target = target.prototype;
        if (target && !hasOwn(target, TO_STRING_TAG)) {
          defineProperty(target, TO_STRING_TAG, { configurable: true, value: TAG });
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/iterators.js
  var require_iterators = __commonJS({
    "../../node_modules/core-js/internals/iterators.js"(exports, module3) {
      "use strict";
      module3.exports = {};
    }
  });

  // ../../node_modules/core-js/internals/iterator-create-constructor.js
  var require_iterator_create_constructor = __commonJS({
    "../../node_modules/core-js/internals/iterator-create-constructor.js"(exports, module3) {
      "use strict";
      var IteratorPrototype = require_iterators_core().IteratorPrototype;
      var create = require_object_create();
      var createPropertyDescriptor = require_create_property_descriptor();
      var setToStringTag = require_set_to_string_tag();
      var Iterators = require_iterators();
      var returnThis = function() {
        return this;
      };
      module3.exports = function(IteratorConstructor, NAME, next, ENUMERABLE_NEXT) {
        var TO_STRING_TAG = NAME + " Iterator";
        IteratorConstructor.prototype = create(IteratorPrototype, { next: createPropertyDescriptor(+!ENUMERABLE_NEXT, next) });
        setToStringTag(IteratorConstructor, TO_STRING_TAG, false, true);
        Iterators[TO_STRING_TAG] = returnThis;
        return IteratorConstructor;
      };
    }
  });

  // ../../node_modules/core-js/internals/function-uncurry-this-accessor.js
  var require_function_uncurry_this_accessor = __commonJS({
    "../../node_modules/core-js/internals/function-uncurry-this-accessor.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var aCallable = require_a_callable();
      module3.exports = function(object, key, method) {
        try {
          return uncurryThis(aCallable(Object.getOwnPropertyDescriptor(object, key)[method]));
        } catch (error3) {
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/is-possible-prototype.js
  var require_is_possible_prototype = __commonJS({
    "../../node_modules/core-js/internals/is-possible-prototype.js"(exports, module3) {
      "use strict";
      var isObject = require_is_object();
      module3.exports = function(argument) {
        return isObject(argument) || argument === null;
      };
    }
  });

  // ../../node_modules/core-js/internals/a-possible-prototype.js
  var require_a_possible_prototype = __commonJS({
    "../../node_modules/core-js/internals/a-possible-prototype.js"(exports, module3) {
      "use strict";
      var isPossiblePrototype = require_is_possible_prototype();
      var $String = String;
      var $TypeError = TypeError;
      module3.exports = function(argument) {
        if (isPossiblePrototype(argument)) return argument;
        throw new $TypeError("Can't set " + $String(argument) + " as a prototype");
      };
    }
  });

  // ../../node_modules/core-js/internals/object-set-prototype-of.js
  var require_object_set_prototype_of = __commonJS({
    "../../node_modules/core-js/internals/object-set-prototype-of.js"(exports, module3) {
      "use strict";
      var uncurryThisAccessor = require_function_uncurry_this_accessor();
      var isObject = require_is_object();
      var requireObjectCoercible = require_require_object_coercible();
      var aPossiblePrototype = require_a_possible_prototype();
      module3.exports = Object.setPrototypeOf || ("__proto__" in {} ? function() {
        var CORRECT_SETTER = false;
        var test = {};
        var setter;
        try {
          setter = uncurryThisAccessor(Object.prototype, "__proto__", "set");
          setter(test, []);
          CORRECT_SETTER = test instanceof Array;
        } catch (error3) {
        }
        return function setPrototypeOf(O, proto) {
          requireObjectCoercible(O);
          aPossiblePrototype(proto);
          if (!isObject(O)) return O;
          if (CORRECT_SETTER) setter(O, proto);
          else O.__proto__ = proto;
          return O;
        };
      }() : void 0);
    }
  });

  // ../../node_modules/core-js/internals/iterator-define.js
  var require_iterator_define = __commonJS({
    "../../node_modules/core-js/internals/iterator-define.js"(exports, module3) {
      "use strict";
      var $ = require_export();
      var call = require_function_call();
      var IS_PURE = require_is_pure();
      var FunctionName = require_function_name();
      var isCallable = require_is_callable();
      var createIteratorConstructor = require_iterator_create_constructor();
      var getPrototypeOf = require_object_get_prototype_of();
      var setPrototypeOf = require_object_set_prototype_of();
      var setToStringTag = require_set_to_string_tag();
      var createNonEnumerableProperty = require_create_non_enumerable_property();
      var defineBuiltIn = require_define_built_in();
      var wellKnownSymbol = require_well_known_symbol();
      var Iterators = require_iterators();
      var IteratorsCore = require_iterators_core();
      var PROPER_FUNCTION_NAME = FunctionName.PROPER;
      var CONFIGURABLE_FUNCTION_NAME = FunctionName.CONFIGURABLE;
      var IteratorPrototype = IteratorsCore.IteratorPrototype;
      var BUGGY_SAFARI_ITERATORS = IteratorsCore.BUGGY_SAFARI_ITERATORS;
      var ITERATOR = wellKnownSymbol("iterator");
      var KEYS = "keys";
      var VALUES = "values";
      var ENTRIES = "entries";
      var returnThis = function() {
        return this;
      };
      module3.exports = function(Iterable, NAME, IteratorConstructor, next, DEFAULT, IS_SET, FORCED) {
        createIteratorConstructor(IteratorConstructor, NAME, next);
        var getIterationMethod = function(KIND) {
          if (KIND === DEFAULT && defaultIterator) return defaultIterator;
          if (!BUGGY_SAFARI_ITERATORS && KIND && KIND in IterablePrototype) return IterablePrototype[KIND];
          switch (KIND) {
            case KEYS:
              return function keys() {
                return new IteratorConstructor(this, KIND);
              };
            case VALUES:
              return function values() {
                return new IteratorConstructor(this, KIND);
              };
            case ENTRIES:
              return function entries() {
                return new IteratorConstructor(this, KIND);
              };
          }
          return function() {
            return new IteratorConstructor(this);
          };
        };
        var TO_STRING_TAG = NAME + " Iterator";
        var INCORRECT_VALUES_NAME = false;
        var IterablePrototype = Iterable.prototype;
        var nativeIterator = IterablePrototype[ITERATOR] || IterablePrototype["@@iterator"] || DEFAULT && IterablePrototype[DEFAULT];
        var defaultIterator = !BUGGY_SAFARI_ITERATORS && nativeIterator || getIterationMethod(DEFAULT);
        var anyNativeIterator = NAME === "Array" ? IterablePrototype.entries || nativeIterator : nativeIterator;
        var CurrentIteratorPrototype, methods, KEY;
        if (anyNativeIterator) {
          CurrentIteratorPrototype = getPrototypeOf(anyNativeIterator.call(new Iterable()));
          if (CurrentIteratorPrototype !== Object.prototype && CurrentIteratorPrototype.next) {
            if (!IS_PURE && getPrototypeOf(CurrentIteratorPrototype) !== IteratorPrototype) {
              if (setPrototypeOf) {
                setPrototypeOf(CurrentIteratorPrototype, IteratorPrototype);
              } else if (!isCallable(CurrentIteratorPrototype[ITERATOR])) {
                defineBuiltIn(CurrentIteratorPrototype, ITERATOR, returnThis);
              }
            }
            setToStringTag(CurrentIteratorPrototype, TO_STRING_TAG, true, true);
            if (IS_PURE) Iterators[TO_STRING_TAG] = returnThis;
          }
        }
        if (PROPER_FUNCTION_NAME && DEFAULT === VALUES && nativeIterator && nativeIterator.name !== VALUES) {
          if (!IS_PURE && CONFIGURABLE_FUNCTION_NAME) {
            createNonEnumerableProperty(IterablePrototype, "name", VALUES);
          } else {
            INCORRECT_VALUES_NAME = true;
            defaultIterator = function values() {
              return call(nativeIterator, this);
            };
          }
        }
        if (DEFAULT) {
          methods = {
            values: getIterationMethod(VALUES),
            keys: IS_SET ? defaultIterator : getIterationMethod(KEYS),
            entries: getIterationMethod(ENTRIES)
          };
          if (FORCED) for (KEY in methods) {
            if (BUGGY_SAFARI_ITERATORS || INCORRECT_VALUES_NAME || !(KEY in IterablePrototype)) {
              defineBuiltIn(IterablePrototype, KEY, methods[KEY]);
            }
          }
          else $({ target: NAME, proto: true, forced: BUGGY_SAFARI_ITERATORS || INCORRECT_VALUES_NAME }, methods);
        }
        if ((!IS_PURE || FORCED) && IterablePrototype[ITERATOR] !== defaultIterator) {
          defineBuiltIn(IterablePrototype, ITERATOR, defaultIterator, { name: DEFAULT });
        }
        Iterators[NAME] = defaultIterator;
        return methods;
      };
    }
  });

  // ../../node_modules/core-js/internals/create-iter-result-object.js
  var require_create_iter_result_object = __commonJS({
    "../../node_modules/core-js/internals/create-iter-result-object.js"(exports, module3) {
      "use strict";
      module3.exports = function(value, done) {
        return { value, done };
      };
    }
  });

  // ../../node_modules/core-js/modules/es.string.iterator.js
  var require_es_string_iterator = __commonJS({
    "../../node_modules/core-js/modules/es.string.iterator.js"() {
      "use strict";
      var charAt = require_string_multibyte().charAt;
      var toString = require_to_string();
      var InternalStateModule = require_internal_state();
      var defineIterator = require_iterator_define();
      var createIterResultObject = require_create_iter_result_object();
      var STRING_ITERATOR = "String Iterator";
      var setInternalState = InternalStateModule.set;
      var getInternalState = InternalStateModule.getterFor(STRING_ITERATOR);
      defineIterator(String, "String", function(iterated) {
        setInternalState(this, {
          type: STRING_ITERATOR,
          string: toString(iterated),
          index: 0
        });
      }, function next() {
        var state = getInternalState(this);
        var string = state.string;
        var index = state.index;
        var point;
        if (index >= string.length) return createIterResultObject(void 0, true);
        point = charAt(string, index);
        state.index += point.length;
        return createIterResultObject(point, false);
      });
    }
  });

  // ../../node_modules/core-js/internals/iterator-close.js
  var require_iterator_close = __commonJS({
    "../../node_modules/core-js/internals/iterator-close.js"(exports, module3) {
      "use strict";
      var call = require_function_call();
      var anObject = require_an_object();
      var getMethod2 = require_get_method();
      module3.exports = function(iterator, kind, value) {
        var innerResult, innerError;
        anObject(iterator);
        try {
          innerResult = getMethod2(iterator, "return");
          if (!innerResult) {
            if (kind === "throw") throw value;
            return value;
          }
          innerResult = call(innerResult, iterator);
        } catch (error3) {
          innerError = true;
          innerResult = error3;
        }
        if (kind === "throw") throw value;
        if (innerError) throw innerResult;
        anObject(innerResult);
        return value;
      };
    }
  });

  // ../../node_modules/core-js/internals/call-with-safe-iteration-closing.js
  var require_call_with_safe_iteration_closing = __commonJS({
    "../../node_modules/core-js/internals/call-with-safe-iteration-closing.js"(exports, module3) {
      "use strict";
      var anObject = require_an_object();
      var iteratorClose = require_iterator_close();
      module3.exports = function(iterator, fn2, value, ENTRIES) {
        try {
          return ENTRIES ? fn2(anObject(value)[0], value[1]) : fn2(value);
        } catch (error3) {
          iteratorClose(iterator, "throw", error3);
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/is-array-iterator-method.js
  var require_is_array_iterator_method = __commonJS({
    "../../node_modules/core-js/internals/is-array-iterator-method.js"(exports, module3) {
      "use strict";
      var wellKnownSymbol = require_well_known_symbol();
      var Iterators = require_iterators();
      var ITERATOR = wellKnownSymbol("iterator");
      var ArrayPrototype = Array.prototype;
      module3.exports = function(it) {
        return it !== void 0 && (Iterators.Array === it || ArrayPrototype[ITERATOR] === it);
      };
    }
  });

  // ../../node_modules/core-js/internals/create-property.js
  var require_create_property = __commonJS({
    "../../node_modules/core-js/internals/create-property.js"(exports, module3) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var definePropertyModule = require_object_define_property();
      var createPropertyDescriptor = require_create_property_descriptor();
      module3.exports = function(object, key, value) {
        if (DESCRIPTORS) definePropertyModule.f(object, key, createPropertyDescriptor(0, value));
        else object[key] = value;
      };
    }
  });

  // ../../node_modules/core-js/internals/get-iterator-method.js
  var require_get_iterator_method = __commonJS({
    "../../node_modules/core-js/internals/get-iterator-method.js"(exports, module3) {
      "use strict";
      var classof = require_classof();
      var getMethod2 = require_get_method();
      var isNullOrUndefined = require_is_null_or_undefined();
      var Iterators = require_iterators();
      var wellKnownSymbol = require_well_known_symbol();
      var ITERATOR = wellKnownSymbol("iterator");
      module3.exports = function(it) {
        if (!isNullOrUndefined(it)) return getMethod2(it, ITERATOR) || getMethod2(it, "@@iterator") || Iterators[classof(it)];
      };
    }
  });

  // ../../node_modules/core-js/internals/get-iterator.js
  var require_get_iterator = __commonJS({
    "../../node_modules/core-js/internals/get-iterator.js"(exports, module3) {
      "use strict";
      var call = require_function_call();
      var aCallable = require_a_callable();
      var anObject = require_an_object();
      var tryToString = require_try_to_string();
      var getIteratorMethod = require_get_iterator_method();
      var $TypeError = TypeError;
      module3.exports = function(argument, usingIterator) {
        var iteratorMethod = arguments.length < 2 ? getIteratorMethod(argument) : usingIterator;
        if (aCallable(iteratorMethod)) return anObject(call(iteratorMethod, argument));
        throw new $TypeError(tryToString(argument) + " is not iterable");
      };
    }
  });

  // ../../node_modules/core-js/internals/array-from.js
  var require_array_from = __commonJS({
    "../../node_modules/core-js/internals/array-from.js"(exports, module3) {
      "use strict";
      var bind = require_function_bind_context();
      var call = require_function_call();
      var toObject = require_to_object();
      var callWithSafeIterationClosing = require_call_with_safe_iteration_closing();
      var isArrayIteratorMethod = require_is_array_iterator_method();
      var isConstructor = require_is_constructor();
      var lengthOfArrayLike = require_length_of_array_like();
      var createProperty = require_create_property();
      var getIterator = require_get_iterator();
      var getIteratorMethod = require_get_iterator_method();
      var $Array = Array;
      module3.exports = function from(arrayLike) {
        var O = toObject(arrayLike);
        var IS_CONSTRUCTOR = isConstructor(this);
        var argumentsLength = arguments.length;
        var mapfn = argumentsLength > 1 ? arguments[1] : void 0;
        var mapping = mapfn !== void 0;
        if (mapping) mapfn = bind(mapfn, argumentsLength > 2 ? arguments[2] : void 0);
        var iteratorMethod = getIteratorMethod(O);
        var index = 0;
        var length, result, step, iterator, next, value;
        if (iteratorMethod && !(this === $Array && isArrayIteratorMethod(iteratorMethod))) {
          result = IS_CONSTRUCTOR ? new this() : [];
          iterator = getIterator(O, iteratorMethod);
          next = iterator.next;
          for (; !(step = call(next, iterator)).done; index++) {
            value = mapping ? callWithSafeIterationClosing(iterator, mapfn, [step.value, index], true) : step.value;
            createProperty(result, index, value);
          }
        } else {
          length = lengthOfArrayLike(O);
          result = IS_CONSTRUCTOR ? new this(length) : $Array(length);
          for (; length > index; index++) {
            value = mapping ? mapfn(O[index], index) : O[index];
            createProperty(result, index, value);
          }
        }
        result.length = index;
        return result;
      };
    }
  });

  // ../../node_modules/core-js/internals/check-correctness-of-iteration.js
  var require_check_correctness_of_iteration = __commonJS({
    "../../node_modules/core-js/internals/check-correctness-of-iteration.js"(exports, module3) {
      "use strict";
      var wellKnownSymbol = require_well_known_symbol();
      var ITERATOR = wellKnownSymbol("iterator");
      var SAFE_CLOSING = false;
      try {
        called = 0;
        iteratorWithReturn = {
          next: function() {
            return { done: !!called++ };
          },
          "return": function() {
            SAFE_CLOSING = true;
          }
        };
        iteratorWithReturn[ITERATOR] = function() {
          return this;
        };
        Array.from(iteratorWithReturn, function() {
          throw 2;
        });
      } catch (error3) {
      }
      var called;
      var iteratorWithReturn;
      module3.exports = function(exec, SKIP_CLOSING) {
        try {
          if (!SKIP_CLOSING && !SAFE_CLOSING) return false;
        } catch (error3) {
          return false;
        }
        var ITERATION_SUPPORT = false;
        try {
          var object = {};
          object[ITERATOR] = function() {
            return {
              next: function() {
                return { done: ITERATION_SUPPORT = true };
              }
            };
          };
          exec(object);
        } catch (error3) {
        }
        return ITERATION_SUPPORT;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.array.from.js
  var require_es_array_from = __commonJS({
    "../../node_modules/core-js/modules/es.array.from.js"() {
      "use strict";
      var $ = require_export();
      var from = require_array_from();
      var checkCorrectnessOfIteration = require_check_correctness_of_iteration();
      var INCORRECT_ITERATION = !checkCorrectnessOfIteration(function(iterable) {
        Array.from(iterable);
      });
      $({ target: "Array", stat: true, forced: INCORRECT_ITERATION }, {
        from
      });
    }
  });

  // ../../node_modules/core-js/internals/path.js
  var require_path = __commonJS({
    "../../node_modules/core-js/internals/path.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      module3.exports = globalThis2;
    }
  });

  // ../../node_modules/core-js/es/array/from.js
  var require_from = __commonJS({
    "../../node_modules/core-js/es/array/from.js"(exports, module3) {
      "use strict";
      require_es_string_iterator();
      require_es_array_from();
      var path = require_path();
      module3.exports = path.Array.from;
    }
  });

  // ../../node_modules/core-js/modules/es.array.iterator.js
  var require_es_array_iterator = __commonJS({
    "../../node_modules/core-js/modules/es.array.iterator.js"(exports, module3) {
      "use strict";
      var toIndexedObject = require_to_indexed_object();
      var addToUnscopables = require_add_to_unscopables();
      var Iterators = require_iterators();
      var InternalStateModule = require_internal_state();
      var defineProperty = require_object_define_property().f;
      var defineIterator = require_iterator_define();
      var createIterResultObject = require_create_iter_result_object();
      var IS_PURE = require_is_pure();
      var DESCRIPTORS = require_descriptors();
      var ARRAY_ITERATOR = "Array Iterator";
      var setInternalState = InternalStateModule.set;
      var getInternalState = InternalStateModule.getterFor(ARRAY_ITERATOR);
      module3.exports = defineIterator(Array, "Array", function(iterated, kind) {
        setInternalState(this, {
          type: ARRAY_ITERATOR,
          target: toIndexedObject(iterated),
          // target
          index: 0,
          // next index
          kind
          // kind
        });
      }, function() {
        var state = getInternalState(this);
        var target = state.target;
        var index = state.index++;
        if (!target || index >= target.length) {
          state.target = null;
          return createIterResultObject(void 0, true);
        }
        switch (state.kind) {
          case "keys":
            return createIterResultObject(index, false);
          case "values":
            return createIterResultObject(target[index], false);
        }
        return createIterResultObject([index, target[index]], false);
      }, "values");
      var values = Iterators.Arguments = Iterators.Array;
      addToUnscopables("keys");
      addToUnscopables("values");
      addToUnscopables("entries");
      if (!IS_PURE && DESCRIPTORS && values.name !== "values") try {
        defineProperty(values, "name", { value: "values" });
      } catch (error3) {
      }
    }
  });

  // ../../node_modules/core-js/internals/array-slice.js
  var require_array_slice = __commonJS({
    "../../node_modules/core-js/internals/array-slice.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      module3.exports = uncurryThis([].slice);
    }
  });

  // ../../node_modules/core-js/internals/object-get-own-property-names-external.js
  var require_object_get_own_property_names_external = __commonJS({
    "../../node_modules/core-js/internals/object-get-own-property-names-external.js"(exports, module3) {
      "use strict";
      var classof = require_classof_raw();
      var toIndexedObject = require_to_indexed_object();
      var $getOwnPropertyNames = require_object_get_own_property_names().f;
      var arraySlice = require_array_slice();
      var windowNames = typeof window == "object" && window && Object.getOwnPropertyNames ? Object.getOwnPropertyNames(window) : [];
      var getWindowNames = function(it) {
        try {
          return $getOwnPropertyNames(it);
        } catch (error3) {
          return arraySlice(windowNames);
        }
      };
      module3.exports.f = function getOwnPropertyNames(it) {
        return windowNames && classof(it) === "Window" ? getWindowNames(it) : $getOwnPropertyNames(toIndexedObject(it));
      };
    }
  });

  // ../../node_modules/core-js/internals/array-buffer-non-extensible.js
  var require_array_buffer_non_extensible = __commonJS({
    "../../node_modules/core-js/internals/array-buffer-non-extensible.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      module3.exports = fails(function() {
        if (typeof ArrayBuffer == "function") {
          var buffer = new ArrayBuffer(8);
          if (Object.isExtensible(buffer)) Object.defineProperty(buffer, "a", { value: 8 });
        }
      });
    }
  });

  // ../../node_modules/core-js/internals/object-is-extensible.js
  var require_object_is_extensible = __commonJS({
    "../../node_modules/core-js/internals/object-is-extensible.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      var isObject = require_is_object();
      var classof = require_classof_raw();
      var ARRAY_BUFFER_NON_EXTENSIBLE = require_array_buffer_non_extensible();
      var $isExtensible = Object.isExtensible;
      var FAILS_ON_PRIMITIVES = fails(function() {
        $isExtensible(1);
      });
      module3.exports = FAILS_ON_PRIMITIVES || ARRAY_BUFFER_NON_EXTENSIBLE ? function isExtensible(it) {
        if (!isObject(it)) return false;
        if (ARRAY_BUFFER_NON_EXTENSIBLE && classof(it) === "ArrayBuffer") return false;
        return $isExtensible ? $isExtensible(it) : true;
      } : $isExtensible;
    }
  });

  // ../../node_modules/core-js/internals/freezing.js
  var require_freezing = __commonJS({
    "../../node_modules/core-js/internals/freezing.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      module3.exports = !fails(function() {
        return Object.isExtensible(Object.preventExtensions({}));
      });
    }
  });

  // ../../node_modules/core-js/internals/internal-metadata.js
  var require_internal_metadata = __commonJS({
    "../../node_modules/core-js/internals/internal-metadata.js"(exports, module3) {
      "use strict";
      var $ = require_export();
      var uncurryThis = require_function_uncurry_this();
      var hiddenKeys = require_hidden_keys();
      var isObject = require_is_object();
      var hasOwn = require_has_own_property();
      var defineProperty = require_object_define_property().f;
      var getOwnPropertyNamesModule = require_object_get_own_property_names();
      var getOwnPropertyNamesExternalModule = require_object_get_own_property_names_external();
      var isExtensible = require_object_is_extensible();
      var uid = require_uid();
      var FREEZING = require_freezing();
      var REQUIRED = false;
      var METADATA = uid("meta");
      var id = 0;
      var setMetadata = function(it) {
        defineProperty(it, METADATA, { value: {
          objectID: "O" + id++,
          // object ID
          weakData: {}
          // weak collections IDs
        } });
      };
      var fastKey = function(it, create) {
        if (!isObject(it)) return typeof it == "symbol" ? it : (typeof it == "string" ? "S" : "P") + it;
        if (!hasOwn(it, METADATA)) {
          if (!isExtensible(it)) return "F";
          if (!create) return "E";
          setMetadata(it);
        }
        return it[METADATA].objectID;
      };
      var getWeakData = function(it, create) {
        if (!hasOwn(it, METADATA)) {
          if (!isExtensible(it)) return true;
          if (!create) return false;
          setMetadata(it);
        }
        return it[METADATA].weakData;
      };
      var onFreeze = function(it) {
        if (FREEZING && REQUIRED && isExtensible(it) && !hasOwn(it, METADATA)) setMetadata(it);
        return it;
      };
      var enable = function() {
        meta.enable = function() {
        };
        REQUIRED = true;
        var getOwnPropertyNames = getOwnPropertyNamesModule.f;
        var splice = uncurryThis([].splice);
        var test = {};
        test[METADATA] = 1;
        if (getOwnPropertyNames(test).length) {
          getOwnPropertyNamesModule.f = function(it) {
            var result = getOwnPropertyNames(it);
            for (var i = 0, length = result.length; i < length; i++) {
              if (result[i] === METADATA) {
                splice(result, i, 1);
                break;
              }
            }
            return result;
          };
          $({ target: "Object", stat: true, forced: true }, {
            getOwnPropertyNames: getOwnPropertyNamesExternalModule.f
          });
        }
      };
      var meta = module3.exports = {
        enable,
        fastKey,
        getWeakData,
        onFreeze
      };
      hiddenKeys[METADATA] = true;
    }
  });

  // ../../node_modules/core-js/internals/iterate.js
  var require_iterate = __commonJS({
    "../../node_modules/core-js/internals/iterate.js"(exports, module3) {
      "use strict";
      var bind = require_function_bind_context();
      var call = require_function_call();
      var anObject = require_an_object();
      var tryToString = require_try_to_string();
      var isArrayIteratorMethod = require_is_array_iterator_method();
      var lengthOfArrayLike = require_length_of_array_like();
      var isPrototypeOf = require_object_is_prototype_of();
      var getIterator = require_get_iterator();
      var getIteratorMethod = require_get_iterator_method();
      var iteratorClose = require_iterator_close();
      var $TypeError = TypeError;
      var Result = function(stopped, result) {
        this.stopped = stopped;
        this.result = result;
      };
      var ResultPrototype = Result.prototype;
      module3.exports = function(iterable, unboundFunction, options) {
        var that = options && options.that;
        var AS_ENTRIES = !!(options && options.AS_ENTRIES);
        var IS_RECORD = !!(options && options.IS_RECORD);
        var IS_ITERATOR = !!(options && options.IS_ITERATOR);
        var INTERRUPTED = !!(options && options.INTERRUPTED);
        var fn2 = bind(unboundFunction, that);
        var iterator, iterFn, index, length, result, next, step;
        var stop = function(condition) {
          if (iterator) iteratorClose(iterator, "normal", condition);
          return new Result(true, condition);
        };
        var callFn = function(value) {
          if (AS_ENTRIES) {
            anObject(value);
            return INTERRUPTED ? fn2(value[0], value[1], stop) : fn2(value[0], value[1]);
          }
          return INTERRUPTED ? fn2(value, stop) : fn2(value);
        };
        if (IS_RECORD) {
          iterator = iterable.iterator;
        } else if (IS_ITERATOR) {
          iterator = iterable;
        } else {
          iterFn = getIteratorMethod(iterable);
          if (!iterFn) throw new $TypeError(tryToString(iterable) + " is not iterable");
          if (isArrayIteratorMethod(iterFn)) {
            for (index = 0, length = lengthOfArrayLike(iterable); length > index; index++) {
              result = callFn(iterable[index]);
              if (result && isPrototypeOf(ResultPrototype, result)) return result;
            }
            return new Result(false);
          }
          iterator = getIterator(iterable, iterFn);
        }
        next = IS_RECORD ? iterable.next : iterator.next;
        while (!(step = call(next, iterator)).done) {
          try {
            result = callFn(step.value);
          } catch (error3) {
            iteratorClose(iterator, "throw", error3);
          }
          if (typeof result == "object" && result && isPrototypeOf(ResultPrototype, result)) return result;
        }
        return new Result(false);
      };
    }
  });

  // ../../node_modules/core-js/internals/an-instance.js
  var require_an_instance = __commonJS({
    "../../node_modules/core-js/internals/an-instance.js"(exports, module3) {
      "use strict";
      var isPrototypeOf = require_object_is_prototype_of();
      var $TypeError = TypeError;
      module3.exports = function(it, Prototype) {
        if (isPrototypeOf(Prototype, it)) return it;
        throw new $TypeError("Incorrect invocation");
      };
    }
  });

  // ../../node_modules/core-js/internals/inherit-if-required.js
  var require_inherit_if_required = __commonJS({
    "../../node_modules/core-js/internals/inherit-if-required.js"(exports, module3) {
      "use strict";
      var isCallable = require_is_callable();
      var isObject = require_is_object();
      var setPrototypeOf = require_object_set_prototype_of();
      module3.exports = function($this, dummy, Wrapper) {
        var NewTarget, NewTargetPrototype;
        if (
          // it can work only with native `setPrototypeOf`
          setPrototypeOf && // we haven't completely correct pre-ES6 way for getting `new.target`, so use this
          isCallable(NewTarget = dummy.constructor) && NewTarget !== Wrapper && isObject(NewTargetPrototype = NewTarget.prototype) && NewTargetPrototype !== Wrapper.prototype
        ) setPrototypeOf($this, NewTargetPrototype);
        return $this;
      };
    }
  });

  // ../../node_modules/core-js/internals/collection.js
  var require_collection = __commonJS({
    "../../node_modules/core-js/internals/collection.js"(exports, module3) {
      "use strict";
      var $ = require_export();
      var globalThis2 = require_global_this();
      var uncurryThis = require_function_uncurry_this();
      var isForced = require_is_forced();
      var defineBuiltIn = require_define_built_in();
      var InternalMetadataModule = require_internal_metadata();
      var iterate = require_iterate();
      var anInstance = require_an_instance();
      var isCallable = require_is_callable();
      var isNullOrUndefined = require_is_null_or_undefined();
      var isObject = require_is_object();
      var fails = require_fails();
      var checkCorrectnessOfIteration = require_check_correctness_of_iteration();
      var setToStringTag = require_set_to_string_tag();
      var inheritIfRequired = require_inherit_if_required();
      module3.exports = function(CONSTRUCTOR_NAME, wrapper, common) {
        var IS_MAP = CONSTRUCTOR_NAME.indexOf("Map") !== -1;
        var IS_WEAK = CONSTRUCTOR_NAME.indexOf("Weak") !== -1;
        var ADDER = IS_MAP ? "set" : "add";
        var NativeConstructor = globalThis2[CONSTRUCTOR_NAME];
        var NativePrototype = NativeConstructor && NativeConstructor.prototype;
        var Constructor = NativeConstructor;
        var exported = {};
        var fixMethod = function(KEY) {
          var uncurriedNativeMethod = uncurryThis(NativePrototype[KEY]);
          defineBuiltIn(
            NativePrototype,
            KEY,
            KEY === "add" ? function add3(value) {
              uncurriedNativeMethod(this, value === 0 ? 0 : value);
              return this;
            } : KEY === "delete" ? function(key) {
              return IS_WEAK && !isObject(key) ? false : uncurriedNativeMethod(this, key === 0 ? 0 : key);
            } : KEY === "get" ? function get(key) {
              return IS_WEAK && !isObject(key) ? void 0 : uncurriedNativeMethod(this, key === 0 ? 0 : key);
            } : KEY === "has" ? function has(key) {
              return IS_WEAK && !isObject(key) ? false : uncurriedNativeMethod(this, key === 0 ? 0 : key);
            } : function set(key, value) {
              uncurriedNativeMethod(this, key === 0 ? 0 : key, value);
              return this;
            }
          );
        };
        var REPLACE = isForced(
          CONSTRUCTOR_NAME,
          !isCallable(NativeConstructor) || !(IS_WEAK || NativePrototype.forEach && !fails(function() {
            new NativeConstructor().entries().next();
          }))
        );
        if (REPLACE) {
          Constructor = common.getConstructor(wrapper, CONSTRUCTOR_NAME, IS_MAP, ADDER);
          InternalMetadataModule.enable();
        } else if (isForced(CONSTRUCTOR_NAME, true)) {
          var instance = new Constructor();
          var HASNT_CHAINING = instance[ADDER](IS_WEAK ? {} : -0, 1) !== instance;
          var THROWS_ON_PRIMITIVES = fails(function() {
            instance.has(1);
          });
          var ACCEPT_ITERABLES = checkCorrectnessOfIteration(function(iterable) {
            new NativeConstructor(iterable);
          });
          var BUGGY_ZERO = !IS_WEAK && fails(function() {
            var $instance = new NativeConstructor();
            var index = 5;
            while (index--) $instance[ADDER](index, index);
            return !$instance.has(-0);
          });
          if (!ACCEPT_ITERABLES) {
            Constructor = wrapper(function(dummy, iterable) {
              anInstance(dummy, NativePrototype);
              var that = inheritIfRequired(new NativeConstructor(), dummy, Constructor);
              if (!isNullOrUndefined(iterable)) iterate(iterable, that[ADDER], { that, AS_ENTRIES: IS_MAP });
              return that;
            });
            Constructor.prototype = NativePrototype;
            NativePrototype.constructor = Constructor;
          }
          if (THROWS_ON_PRIMITIVES || BUGGY_ZERO) {
            fixMethod("delete");
            fixMethod("has");
            IS_MAP && fixMethod("get");
          }
          if (BUGGY_ZERO || HASNT_CHAINING) fixMethod(ADDER);
          if (IS_WEAK && NativePrototype.clear) delete NativePrototype.clear;
        }
        exported[CONSTRUCTOR_NAME] = Constructor;
        $({ global: true, constructor: true, forced: Constructor !== NativeConstructor }, exported);
        setToStringTag(Constructor, CONSTRUCTOR_NAME);
        if (!IS_WEAK) common.setStrong(Constructor, CONSTRUCTOR_NAME, IS_MAP);
        return Constructor;
      };
    }
  });

  // ../../node_modules/core-js/internals/define-built-in-accessor.js
  var require_define_built_in_accessor = __commonJS({
    "../../node_modules/core-js/internals/define-built-in-accessor.js"(exports, module3) {
      "use strict";
      var makeBuiltIn = require_make_built_in();
      var defineProperty = require_object_define_property();
      module3.exports = function(target, name3, descriptor) {
        if (descriptor.get) makeBuiltIn(descriptor.get, name3, { getter: true });
        if (descriptor.set) makeBuiltIn(descriptor.set, name3, { setter: true });
        return defineProperty.f(target, name3, descriptor);
      };
    }
  });

  // ../../node_modules/core-js/internals/define-built-ins.js
  var require_define_built_ins = __commonJS({
    "../../node_modules/core-js/internals/define-built-ins.js"(exports, module3) {
      "use strict";
      var defineBuiltIn = require_define_built_in();
      module3.exports = function(target, src, options) {
        for (var key in src) defineBuiltIn(target, key, src[key], options);
        return target;
      };
    }
  });

  // ../../node_modules/core-js/internals/set-species.js
  var require_set_species = __commonJS({
    "../../node_modules/core-js/internals/set-species.js"(exports, module3) {
      "use strict";
      var getBuiltIn = require_get_built_in();
      var defineBuiltInAccessor = require_define_built_in_accessor();
      var wellKnownSymbol = require_well_known_symbol();
      var DESCRIPTORS = require_descriptors();
      var SPECIES = wellKnownSymbol("species");
      module3.exports = function(CONSTRUCTOR_NAME) {
        var Constructor = getBuiltIn(CONSTRUCTOR_NAME);
        if (DESCRIPTORS && Constructor && !Constructor[SPECIES]) {
          defineBuiltInAccessor(Constructor, SPECIES, {
            configurable: true,
            get: function() {
              return this;
            }
          });
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/collection-strong.js
  var require_collection_strong = __commonJS({
    "../../node_modules/core-js/internals/collection-strong.js"(exports, module3) {
      "use strict";
      var create = require_object_create();
      var defineBuiltInAccessor = require_define_built_in_accessor();
      var defineBuiltIns = require_define_built_ins();
      var bind = require_function_bind_context();
      var anInstance = require_an_instance();
      var isNullOrUndefined = require_is_null_or_undefined();
      var iterate = require_iterate();
      var defineIterator = require_iterator_define();
      var createIterResultObject = require_create_iter_result_object();
      var setSpecies = require_set_species();
      var DESCRIPTORS = require_descriptors();
      var fastKey = require_internal_metadata().fastKey;
      var InternalStateModule = require_internal_state();
      var setInternalState = InternalStateModule.set;
      var internalStateGetterFor = InternalStateModule.getterFor;
      module3.exports = {
        getConstructor: function(wrapper, CONSTRUCTOR_NAME, IS_MAP, ADDER) {
          var Constructor = wrapper(function(that, iterable) {
            anInstance(that, Prototype);
            setInternalState(that, {
              type: CONSTRUCTOR_NAME,
              index: create(null),
              first: null,
              last: null,
              size: 0
            });
            if (!DESCRIPTORS) that.size = 0;
            if (!isNullOrUndefined(iterable)) iterate(iterable, that[ADDER], { that, AS_ENTRIES: IS_MAP });
          });
          var Prototype = Constructor.prototype;
          var getInternalState = internalStateGetterFor(CONSTRUCTOR_NAME);
          var define2 = function(that, key, value) {
            var state = getInternalState(that);
            var entry = getEntry(that, key);
            var previous, index;
            if (entry) {
              entry.value = value;
            } else {
              state.last = entry = {
                index: index = fastKey(key, true),
                key,
                value,
                previous: previous = state.last,
                next: null,
                removed: false
              };
              if (!state.first) state.first = entry;
              if (previous) previous.next = entry;
              if (DESCRIPTORS) state.size++;
              else that.size++;
              if (index !== "F") state.index[index] = entry;
            }
            return that;
          };
          var getEntry = function(that, key) {
            var state = getInternalState(that);
            var index = fastKey(key);
            var entry;
            if (index !== "F") return state.index[index];
            for (entry = state.first; entry; entry = entry.next) {
              if (entry.key === key) return entry;
            }
          };
          defineBuiltIns(Prototype, {
            // `{ Map, Set }.prototype.clear()` methods
            // https://tc39.es/ecma262/#sec-map.prototype.clear
            // https://tc39.es/ecma262/#sec-set.prototype.clear
            clear: function clear() {
              var that = this;
              var state = getInternalState(that);
              var entry = state.first;
              while (entry) {
                entry.removed = true;
                if (entry.previous) entry.previous = entry.previous.next = null;
                entry = entry.next;
              }
              state.first = state.last = null;
              state.index = create(null);
              if (DESCRIPTORS) state.size = 0;
              else that.size = 0;
            },
            // `{ Map, Set }.prototype.delete(key)` methods
            // https://tc39.es/ecma262/#sec-map.prototype.delete
            // https://tc39.es/ecma262/#sec-set.prototype.delete
            "delete": function(key) {
              var that = this;
              var state = getInternalState(that);
              var entry = getEntry(that, key);
              if (entry) {
                var next = entry.next;
                var prev = entry.previous;
                delete state.index[entry.index];
                entry.removed = true;
                if (prev) prev.next = next;
                if (next) next.previous = prev;
                if (state.first === entry) state.first = next;
                if (state.last === entry) state.last = prev;
                if (DESCRIPTORS) state.size--;
                else that.size--;
              }
              return !!entry;
            },
            // `{ Map, Set }.prototype.forEach(callbackfn, thisArg = undefined)` methods
            // https://tc39.es/ecma262/#sec-map.prototype.foreach
            // https://tc39.es/ecma262/#sec-set.prototype.foreach
            forEach: function forEach(callbackfn) {
              var state = getInternalState(this);
              var boundFunction = bind(callbackfn, arguments.length > 1 ? arguments[1] : void 0);
              var entry;
              while (entry = entry ? entry.next : state.first) {
                boundFunction(entry.value, entry.key, this);
                while (entry && entry.removed) entry = entry.previous;
              }
            },
            // `{ Map, Set}.prototype.has(key)` methods
            // https://tc39.es/ecma262/#sec-map.prototype.has
            // https://tc39.es/ecma262/#sec-set.prototype.has
            has: function has(key) {
              return !!getEntry(this, key);
            }
          });
          defineBuiltIns(Prototype, IS_MAP ? {
            // `Map.prototype.get(key)` method
            // https://tc39.es/ecma262/#sec-map.prototype.get
            get: function get(key) {
              var entry = getEntry(this, key);
              return entry && entry.value;
            },
            // `Map.prototype.set(key, value)` method
            // https://tc39.es/ecma262/#sec-map.prototype.set
            set: function set(key, value) {
              return define2(this, key === 0 ? 0 : key, value);
            }
          } : {
            // `Set.prototype.add(value)` method
            // https://tc39.es/ecma262/#sec-set.prototype.add
            add: function add3(value) {
              return define2(this, value = value === 0 ? 0 : value, value);
            }
          });
          if (DESCRIPTORS) defineBuiltInAccessor(Prototype, "size", {
            configurable: true,
            get: function() {
              return getInternalState(this).size;
            }
          });
          return Constructor;
        },
        setStrong: function(Constructor, CONSTRUCTOR_NAME, IS_MAP) {
          var ITERATOR_NAME = CONSTRUCTOR_NAME + " Iterator";
          var getInternalCollectionState = internalStateGetterFor(CONSTRUCTOR_NAME);
          var getInternalIteratorState = internalStateGetterFor(ITERATOR_NAME);
          defineIterator(Constructor, CONSTRUCTOR_NAME, function(iterated, kind) {
            setInternalState(this, {
              type: ITERATOR_NAME,
              target: iterated,
              state: getInternalCollectionState(iterated),
              kind,
              last: null
            });
          }, function() {
            var state = getInternalIteratorState(this);
            var kind = state.kind;
            var entry = state.last;
            while (entry && entry.removed) entry = entry.previous;
            if (!state.target || !(state.last = entry = entry ? entry.next : state.state.first)) {
              state.target = null;
              return createIterResultObject(void 0, true);
            }
            if (kind === "keys") return createIterResultObject(entry.key, false);
            if (kind === "values") return createIterResultObject(entry.value, false);
            return createIterResultObject([entry.key, entry.value], false);
          }, IS_MAP ? "entries" : "values", !IS_MAP, true);
          setSpecies(CONSTRUCTOR_NAME);
        }
      };
    }
  });

  // ../../node_modules/core-js/modules/es.map.constructor.js
  var require_es_map_constructor = __commonJS({
    "../../node_modules/core-js/modules/es.map.constructor.js"() {
      "use strict";
      var collection = require_collection();
      var collectionStrong = require_collection_strong();
      collection("Map", function(init) {
        return function Map2() {
          return init(this, arguments.length ? arguments[0] : void 0);
        };
      }, collectionStrong);
    }
  });

  // ../../node_modules/core-js/modules/es.map.js
  var require_es_map = __commonJS({
    "../../node_modules/core-js/modules/es.map.js"() {
      "use strict";
      require_es_map_constructor();
    }
  });

  // ../../node_modules/core-js/internals/map-helpers.js
  var require_map_helpers = __commonJS({
    "../../node_modules/core-js/internals/map-helpers.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var MapPrototype = Map.prototype;
      module3.exports = {
        // eslint-disable-next-line es/no-map -- safe
        Map,
        set: uncurryThis(MapPrototype.set),
        get: uncurryThis(MapPrototype.get),
        has: uncurryThis(MapPrototype.has),
        remove: uncurryThis(MapPrototype["delete"]),
        proto: MapPrototype
      };
    }
  });

  // ../../node_modules/core-js/modules/es.map.group-by.js
  var require_es_map_group_by = __commonJS({
    "../../node_modules/core-js/modules/es.map.group-by.js"() {
      "use strict";
      var $ = require_export();
      var uncurryThis = require_function_uncurry_this();
      var aCallable = require_a_callable();
      var requireObjectCoercible = require_require_object_coercible();
      var iterate = require_iterate();
      var MapHelpers = require_map_helpers();
      var IS_PURE = require_is_pure();
      var fails = require_fails();
      var Map2 = MapHelpers.Map;
      var has = MapHelpers.has;
      var get = MapHelpers.get;
      var set = MapHelpers.set;
      var push = uncurryThis([].push);
      var DOES_NOT_WORK_WITH_PRIMITIVES = IS_PURE || fails(function() {
        return Map2.groupBy("ab", function(it) {
          return it;
        }).get("a").length !== 1;
      });
      $({ target: "Map", stat: true, forced: IS_PURE || DOES_NOT_WORK_WITH_PRIMITIVES }, {
        groupBy: function groupBy(items, callbackfn) {
          requireObjectCoercible(items);
          aCallable(callbackfn);
          var map = new Map2();
          var k = 0;
          iterate(items, function(value) {
            var key = callbackfn(value, k++);
            if (!has(map, key)) set(map, key, [value]);
            else push(get(map, key), value);
          });
          return map;
        }
      });
    }
  });

  // ../../node_modules/core-js/internals/object-to-string.js
  var require_object_to_string = __commonJS({
    "../../node_modules/core-js/internals/object-to-string.js"(exports, module3) {
      "use strict";
      var TO_STRING_TAG_SUPPORT = require_to_string_tag_support();
      var classof = require_classof();
      module3.exports = TO_STRING_TAG_SUPPORT ? {}.toString : function toString() {
        return "[object " + classof(this) + "]";
      };
    }
  });

  // ../../node_modules/core-js/modules/es.object.to-string.js
  var require_es_object_to_string = __commonJS({
    "../../node_modules/core-js/modules/es.object.to-string.js"() {
      "use strict";
      var TO_STRING_TAG_SUPPORT = require_to_string_tag_support();
      var defineBuiltIn = require_define_built_in();
      var toString = require_object_to_string();
      if (!TO_STRING_TAG_SUPPORT) {
        defineBuiltIn(Object.prototype, "toString", toString, { unsafe: true });
      }
    }
  });

  // ../../node_modules/core-js/es/map/index.js
  var require_map = __commonJS({
    "../../node_modules/core-js/es/map/index.js"(exports, module3) {
      "use strict";
      require_es_array_iterator();
      require_es_map();
      require_es_map_group_by();
      require_es_object_to_string();
      require_es_string_iterator();
      var path = require_path();
      module3.exports = path.Map;
    }
  });

  // ../../node_modules/core-js/internals/object-assign.js
  var require_object_assign = __commonJS({
    "../../node_modules/core-js/internals/object-assign.js"(exports, module3) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var uncurryThis = require_function_uncurry_this();
      var call = require_function_call();
      var fails = require_fails();
      var objectKeys = require_object_keys();
      var getOwnPropertySymbolsModule = require_object_get_own_property_symbols();
      var propertyIsEnumerableModule = require_object_property_is_enumerable();
      var toObject = require_to_object();
      var IndexedObject = require_indexed_object();
      var $assign = Object.assign;
      var defineProperty = Object.defineProperty;
      var concat = uncurryThis([].concat);
      module3.exports = !$assign || fails(function() {
        if (DESCRIPTORS && $assign({ b: 1 }, $assign(defineProperty({}, "a", {
          enumerable: true,
          get: function() {
            defineProperty(this, "b", {
              value: 3,
              enumerable: false
            });
          }
        }), { b: 2 })).b !== 1) return true;
        var A = {};
        var B = {};
        var symbol = Symbol("assign detection");
        var alphabet = "abcdefghijklmnopqrst";
        A[symbol] = 7;
        alphabet.split("").forEach(function(chr) {
          B[chr] = chr;
        });
        return $assign({}, A)[symbol] !== 7 || objectKeys($assign({}, B)).join("") !== alphabet;
      }) ? function assign(target, source) {
        var T2 = toObject(target);
        var argumentsLength = arguments.length;
        var index = 1;
        var getOwnPropertySymbols = getOwnPropertySymbolsModule.f;
        var propertyIsEnumerable = propertyIsEnumerableModule.f;
        while (argumentsLength > index) {
          var S = IndexedObject(arguments[index++]);
          var keys = getOwnPropertySymbols ? concat(objectKeys(S), getOwnPropertySymbols(S)) : objectKeys(S);
          var length = keys.length;
          var j = 0;
          var key;
          while (length > j) {
            key = keys[j++];
            if (!DESCRIPTORS || call(propertyIsEnumerable, S, key)) T2[key] = S[key];
          }
        }
        return T2;
      } : $assign;
    }
  });

  // ../../node_modules/core-js/modules/es.object.assign.js
  var require_es_object_assign = __commonJS({
    "../../node_modules/core-js/modules/es.object.assign.js"() {
      "use strict";
      var $ = require_export();
      var assign = require_object_assign();
      $({ target: "Object", stat: true, arity: 2, forced: Object.assign !== assign }, {
        assign
      });
    }
  });

  // ../../node_modules/core-js/es/object/assign.js
  var require_assign = __commonJS({
    "../../node_modules/core-js/es/object/assign.js"(exports, module3) {
      "use strict";
      require_es_object_assign();
      var path = require_path();
      module3.exports = path.Object.assign;
    }
  });

  // ../../node_modules/core-js/internals/install-error-cause.js
  var require_install_error_cause = __commonJS({
    "../../node_modules/core-js/internals/install-error-cause.js"(exports, module3) {
      "use strict";
      var isObject = require_is_object();
      var createNonEnumerableProperty = require_create_non_enumerable_property();
      module3.exports = function(O, options) {
        if (isObject(options) && "cause" in options) {
          createNonEnumerableProperty(O, "cause", options.cause);
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/error-stack-clear.js
  var require_error_stack_clear = __commonJS({
    "../../node_modules/core-js/internals/error-stack-clear.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var $Error = Error;
      var replace = uncurryThis("".replace);
      var TEST = function(arg) {
        return String(new $Error(arg).stack);
      }("zxcasd");
      var V8_OR_CHAKRA_STACK_ENTRY = /\n\s*at [^:]*:[^\n]*/;
      var IS_V8_OR_CHAKRA_STACK = V8_OR_CHAKRA_STACK_ENTRY.test(TEST);
      module3.exports = function(stack, dropEntries) {
        if (IS_V8_OR_CHAKRA_STACK && typeof stack == "string" && !$Error.prepareStackTrace) {
          while (dropEntries--) stack = replace(stack, V8_OR_CHAKRA_STACK_ENTRY, "");
        }
        return stack;
      };
    }
  });

  // ../../node_modules/core-js/internals/error-stack-installable.js
  var require_error_stack_installable = __commonJS({
    "../../node_modules/core-js/internals/error-stack-installable.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      var createPropertyDescriptor = require_create_property_descriptor();
      module3.exports = !fails(function() {
        var error3 = new Error("a");
        if (!("stack" in error3)) return true;
        Object.defineProperty(error3, "stack", createPropertyDescriptor(1, 7));
        return error3.stack !== 7;
      });
    }
  });

  // ../../node_modules/core-js/internals/error-stack-install.js
  var require_error_stack_install = __commonJS({
    "../../node_modules/core-js/internals/error-stack-install.js"(exports, module3) {
      "use strict";
      var createNonEnumerableProperty = require_create_non_enumerable_property();
      var clearErrorStack = require_error_stack_clear();
      var ERROR_STACK_INSTALLABLE = require_error_stack_installable();
      var captureStackTrace = Error.captureStackTrace;
      module3.exports = function(error3, C2, stack, dropEntries) {
        if (ERROR_STACK_INSTALLABLE) {
          if (captureStackTrace) captureStackTrace(error3, C2);
          else createNonEnumerableProperty(error3, "stack", clearErrorStack(stack, dropEntries));
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/normalize-string-argument.js
  var require_normalize_string_argument = __commonJS({
    "../../node_modules/core-js/internals/normalize-string-argument.js"(exports, module3) {
      "use strict";
      var toString = require_to_string();
      module3.exports = function(argument, $default) {
        return argument === void 0 ? arguments.length < 2 ? "" : $default : toString(argument);
      };
    }
  });

  // ../../node_modules/core-js/modules/es.aggregate-error.constructor.js
  var require_es_aggregate_error_constructor = __commonJS({
    "../../node_modules/core-js/modules/es.aggregate-error.constructor.js"() {
      "use strict";
      var $ = require_export();
      var isPrototypeOf = require_object_is_prototype_of();
      var getPrototypeOf = require_object_get_prototype_of();
      var setPrototypeOf = require_object_set_prototype_of();
      var copyConstructorProperties = require_copy_constructor_properties();
      var create = require_object_create();
      var createNonEnumerableProperty = require_create_non_enumerable_property();
      var createPropertyDescriptor = require_create_property_descriptor();
      var installErrorCause = require_install_error_cause();
      var installErrorStack = require_error_stack_install();
      var iterate = require_iterate();
      var normalizeStringArgument = require_normalize_string_argument();
      var wellKnownSymbol = require_well_known_symbol();
      var TO_STRING_TAG = wellKnownSymbol("toStringTag");
      var $Error = Error;
      var push = [].push;
      var $AggregateError = function AggregateError(errors, message) {
        var isInstance = isPrototypeOf(AggregateErrorPrototype, this);
        var that;
        if (setPrototypeOf) {
          that = setPrototypeOf(new $Error(), isInstance ? getPrototypeOf(this) : AggregateErrorPrototype);
        } else {
          that = isInstance ? this : create(AggregateErrorPrototype);
          createNonEnumerableProperty(that, TO_STRING_TAG, "Error");
        }
        if (message !== void 0) createNonEnumerableProperty(that, "message", normalizeStringArgument(message));
        installErrorStack(that, $AggregateError, that.stack, 1);
        if (arguments.length > 2) installErrorCause(that, arguments[2]);
        var errorsArray = [];
        iterate(errors, push, { that: errorsArray });
        createNonEnumerableProperty(that, "errors", errorsArray);
        return that;
      };
      if (setPrototypeOf) setPrototypeOf($AggregateError, $Error);
      else copyConstructorProperties($AggregateError, $Error, { name: true });
      var AggregateErrorPrototype = $AggregateError.prototype = create($Error.prototype, {
        constructor: createPropertyDescriptor(1, $AggregateError),
        message: createPropertyDescriptor(1, ""),
        name: createPropertyDescriptor(1, "AggregateError")
      });
      $({ global: true, constructor: true, arity: 2 }, {
        AggregateError: $AggregateError
      });
    }
  });

  // ../../node_modules/core-js/modules/es.aggregate-error.js
  var require_es_aggregate_error = __commonJS({
    "../../node_modules/core-js/modules/es.aggregate-error.js"() {
      "use strict";
      require_es_aggregate_error_constructor();
    }
  });

  // ../../node_modules/core-js/internals/environment.js
  var require_environment = __commonJS({
    "../../node_modules/core-js/internals/environment.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var userAgent = require_environment_user_agent();
      var classof = require_classof_raw();
      var userAgentStartsWith = function(string) {
        return userAgent.slice(0, string.length) === string;
      };
      module3.exports = function() {
        if (userAgentStartsWith("Bun/")) return "BUN";
        if (userAgentStartsWith("Cloudflare-Workers")) return "CLOUDFLARE";
        if (userAgentStartsWith("Deno/")) return "DENO";
        if (userAgentStartsWith("Node.js/")) return "NODE";
        if (globalThis2.Bun && typeof Bun.version == "string") return "BUN";
        if (globalThis2.Deno && typeof Deno.version == "object") return "DENO";
        if (classof(globalThis2.process) === "process") return "NODE";
        if (globalThis2.window && globalThis2.document) return "BROWSER";
        return "REST";
      }();
    }
  });

  // ../../node_modules/core-js/internals/environment-is-node.js
  var require_environment_is_node = __commonJS({
    "../../node_modules/core-js/internals/environment-is-node.js"(exports, module3) {
      "use strict";
      var ENVIRONMENT = require_environment();
      module3.exports = ENVIRONMENT === "NODE";
    }
  });

  // ../../node_modules/core-js/internals/a-constructor.js
  var require_a_constructor = __commonJS({
    "../../node_modules/core-js/internals/a-constructor.js"(exports, module3) {
      "use strict";
      var isConstructor = require_is_constructor();
      var tryToString = require_try_to_string();
      var $TypeError = TypeError;
      module3.exports = function(argument) {
        if (isConstructor(argument)) return argument;
        throw new $TypeError(tryToString(argument) + " is not a constructor");
      };
    }
  });

  // ../../node_modules/core-js/internals/species-constructor.js
  var require_species_constructor = __commonJS({
    "../../node_modules/core-js/internals/species-constructor.js"(exports, module3) {
      "use strict";
      var anObject = require_an_object();
      var aConstructor = require_a_constructor();
      var isNullOrUndefined = require_is_null_or_undefined();
      var wellKnownSymbol = require_well_known_symbol();
      var SPECIES = wellKnownSymbol("species");
      module3.exports = function(O, defaultConstructor) {
        var C2 = anObject(O).constructor;
        var S;
        return C2 === void 0 || isNullOrUndefined(S = anObject(C2)[SPECIES]) ? defaultConstructor : aConstructor(S);
      };
    }
  });

  // ../../node_modules/core-js/internals/function-apply.js
  var require_function_apply = __commonJS({
    "../../node_modules/core-js/internals/function-apply.js"(exports, module3) {
      "use strict";
      var NATIVE_BIND = require_function_bind_native();
      var FunctionPrototype = Function.prototype;
      var apply = FunctionPrototype.apply;
      var call = FunctionPrototype.call;
      module3.exports = typeof Reflect == "object" && Reflect.apply || (NATIVE_BIND ? call.bind(apply) : function() {
        return call.apply(apply, arguments);
      });
    }
  });

  // ../../node_modules/core-js/internals/validate-arguments-length.js
  var require_validate_arguments_length = __commonJS({
    "../../node_modules/core-js/internals/validate-arguments-length.js"(exports, module3) {
      "use strict";
      var $TypeError = TypeError;
      module3.exports = function(passed, required) {
        if (passed < required) throw new $TypeError("Not enough arguments");
        return passed;
      };
    }
  });

  // ../../node_modules/core-js/internals/environment-is-ios.js
  var require_environment_is_ios = __commonJS({
    "../../node_modules/core-js/internals/environment-is-ios.js"(exports, module3) {
      "use strict";
      var userAgent = require_environment_user_agent();
      module3.exports = /(?:ipad|iphone|ipod).*applewebkit/i.test(userAgent);
    }
  });

  // ../../node_modules/core-js/internals/task.js
  var require_task = __commonJS({
    "../../node_modules/core-js/internals/task.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var apply = require_function_apply();
      var bind = require_function_bind_context();
      var isCallable = require_is_callable();
      var hasOwn = require_has_own_property();
      var fails = require_fails();
      var html = require_html();
      var arraySlice = require_array_slice();
      var createElement = require_document_create_element();
      var validateArgumentsLength = require_validate_arguments_length();
      var IS_IOS = require_environment_is_ios();
      var IS_NODE = require_environment_is_node();
      var set = globalThis2.setImmediate;
      var clear = globalThis2.clearImmediate;
      var process2 = globalThis2.process;
      var Dispatch = globalThis2.Dispatch;
      var Function2 = globalThis2.Function;
      var MessageChannel = globalThis2.MessageChannel;
      var String2 = globalThis2.String;
      var counter = 0;
      var queue = {};
      var ONREADYSTATECHANGE = "onreadystatechange";
      var $location;
      var defer;
      var channel;
      var port;
      fails(function() {
        $location = globalThis2.location;
      });
      var run = function(id) {
        if (hasOwn(queue, id)) {
          var fn2 = queue[id];
          delete queue[id];
          fn2();
        }
      };
      var runner = function(id) {
        return function() {
          run(id);
        };
      };
      var eventListener = function(event) {
        run(event.data);
      };
      var globalPostMessageDefer = function(id) {
        globalThis2.postMessage(String2(id), $location.protocol + "//" + $location.host);
      };
      if (!set || !clear) {
        set = function setImmediate(handler) {
          validateArgumentsLength(arguments.length, 1);
          var fn2 = isCallable(handler) ? handler : Function2(handler);
          var args = arraySlice(arguments, 1);
          queue[++counter] = function() {
            apply(fn2, void 0, args);
          };
          defer(counter);
          return counter;
        };
        clear = function clearImmediate(id) {
          delete queue[id];
        };
        if (IS_NODE) {
          defer = function(id) {
            process2.nextTick(runner(id));
          };
        } else if (Dispatch && Dispatch.now) {
          defer = function(id) {
            Dispatch.now(runner(id));
          };
        } else if (MessageChannel && !IS_IOS) {
          channel = new MessageChannel();
          port = channel.port2;
          channel.port1.onmessage = eventListener;
          defer = bind(port.postMessage, port);
        } else if (globalThis2.addEventListener && isCallable(globalThis2.postMessage) && !globalThis2.importScripts && $location && $location.protocol !== "file:" && !fails(globalPostMessageDefer)) {
          defer = globalPostMessageDefer;
          globalThis2.addEventListener("message", eventListener, false);
        } else if (ONREADYSTATECHANGE in createElement("script")) {
          defer = function(id) {
            html.appendChild(createElement("script"))[ONREADYSTATECHANGE] = function() {
              html.removeChild(this);
              run(id);
            };
          };
        } else {
          defer = function(id) {
            setTimeout(runner(id), 0);
          };
        }
      }
      module3.exports = {
        set,
        clear
      };
    }
  });

  // ../../node_modules/core-js/internals/safe-get-built-in.js
  var require_safe_get_built_in = __commonJS({
    "../../node_modules/core-js/internals/safe-get-built-in.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var DESCRIPTORS = require_descriptors();
      var getOwnPropertyDescriptor = Object.getOwnPropertyDescriptor;
      module3.exports = function(name3) {
        if (!DESCRIPTORS) return globalThis2[name3];
        var descriptor = getOwnPropertyDescriptor(globalThis2, name3);
        return descriptor && descriptor.value;
      };
    }
  });

  // ../../node_modules/core-js/internals/queue.js
  var require_queue = __commonJS({
    "../../node_modules/core-js/internals/queue.js"(exports, module3) {
      "use strict";
      var Queue = function() {
        this.head = null;
        this.tail = null;
      };
      Queue.prototype = {
        add: function(item) {
          var entry = { item, next: null };
          var tail = this.tail;
          if (tail) tail.next = entry;
          else this.head = entry;
          this.tail = entry;
        },
        get: function() {
          var entry = this.head;
          if (entry) {
            var next = this.head = entry.next;
            if (next === null) this.tail = null;
            return entry.item;
          }
        }
      };
      module3.exports = Queue;
    }
  });

  // ../../node_modules/core-js/internals/environment-is-ios-pebble.js
  var require_environment_is_ios_pebble = __commonJS({
    "../../node_modules/core-js/internals/environment-is-ios-pebble.js"(exports, module3) {
      "use strict";
      var userAgent = require_environment_user_agent();
      module3.exports = /ipad|iphone|ipod/i.test(userAgent) && typeof Pebble != "undefined";
    }
  });

  // ../../node_modules/core-js/internals/environment-is-webos-webkit.js
  var require_environment_is_webos_webkit = __commonJS({
    "../../node_modules/core-js/internals/environment-is-webos-webkit.js"(exports, module3) {
      "use strict";
      var userAgent = require_environment_user_agent();
      module3.exports = /web0s(?!.*chrome)/i.test(userAgent);
    }
  });

  // ../../node_modules/core-js/internals/microtask.js
  var require_microtask = __commonJS({
    "../../node_modules/core-js/internals/microtask.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var safeGetBuiltIn = require_safe_get_built_in();
      var bind = require_function_bind_context();
      var macrotask = require_task().set;
      var Queue = require_queue();
      var IS_IOS = require_environment_is_ios();
      var IS_IOS_PEBBLE = require_environment_is_ios_pebble();
      var IS_WEBOS_WEBKIT = require_environment_is_webos_webkit();
      var IS_NODE = require_environment_is_node();
      var MutationObserver2 = globalThis2.MutationObserver || globalThis2.WebKitMutationObserver;
      var document2 = globalThis2.document;
      var process2 = globalThis2.process;
      var Promise2 = globalThis2.Promise;
      var microtask = safeGetBuiltIn("queueMicrotask");
      var notify;
      var toggle;
      var node;
      var promise;
      var then;
      if (!microtask) {
        queue = new Queue();
        flush = function() {
          var parent, fn2;
          if (IS_NODE && (parent = process2.domain)) parent.exit();
          while (fn2 = queue.get()) try {
            fn2();
          } catch (error3) {
            if (queue.head) notify();
            throw error3;
          }
          if (parent) parent.enter();
        };
        if (!IS_IOS && !IS_NODE && !IS_WEBOS_WEBKIT && MutationObserver2 && document2) {
          toggle = true;
          node = document2.createTextNode("");
          new MutationObserver2(flush).observe(node, { characterData: true });
          notify = function() {
            node.data = toggle = !toggle;
          };
        } else if (!IS_IOS_PEBBLE && Promise2 && Promise2.resolve) {
          promise = Promise2.resolve(void 0);
          promise.constructor = Promise2;
          then = bind(promise.then, promise);
          notify = function() {
            then(flush);
          };
        } else if (IS_NODE) {
          notify = function() {
            process2.nextTick(flush);
          };
        } else {
          macrotask = bind(macrotask, globalThis2);
          notify = function() {
            macrotask(flush);
          };
        }
        microtask = function(fn2) {
          if (!queue.head) notify();
          queue.add(fn2);
        };
      }
      var queue;
      var flush;
      module3.exports = microtask;
    }
  });

  // ../../node_modules/core-js/internals/host-report-errors.js
  var require_host_report_errors = __commonJS({
    "../../node_modules/core-js/internals/host-report-errors.js"(exports, module3) {
      "use strict";
      module3.exports = function(a, b2) {
        try {
          arguments.length === 1 ? console.error(a) : console.error(a, b2);
        } catch (error3) {
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/perform.js
  var require_perform = __commonJS({
    "../../node_modules/core-js/internals/perform.js"(exports, module3) {
      "use strict";
      module3.exports = function(exec) {
        try {
          return { error: false, value: exec() };
        } catch (error3) {
          return { error: true, value: error3 };
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/promise-native-constructor.js
  var require_promise_native_constructor = __commonJS({
    "../../node_modules/core-js/internals/promise-native-constructor.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      module3.exports = globalThis2.Promise;
    }
  });

  // ../../node_modules/core-js/internals/promise-constructor-detection.js
  var require_promise_constructor_detection = __commonJS({
    "../../node_modules/core-js/internals/promise-constructor-detection.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      var NativePromiseConstructor = require_promise_native_constructor();
      var isCallable = require_is_callable();
      var isForced = require_is_forced();
      var inspectSource = require_inspect_source();
      var wellKnownSymbol = require_well_known_symbol();
      var ENVIRONMENT = require_environment();
      var IS_PURE = require_is_pure();
      var V8_VERSION = require_environment_v8_version();
      var NativePromisePrototype = NativePromiseConstructor && NativePromiseConstructor.prototype;
      var SPECIES = wellKnownSymbol("species");
      var SUBCLASSING = false;
      var NATIVE_PROMISE_REJECTION_EVENT = isCallable(globalThis2.PromiseRejectionEvent);
      var FORCED_PROMISE_CONSTRUCTOR = isForced("Promise", function() {
        var PROMISE_CONSTRUCTOR_SOURCE = inspectSource(NativePromiseConstructor);
        var GLOBAL_CORE_JS_PROMISE = PROMISE_CONSTRUCTOR_SOURCE !== String(NativePromiseConstructor);
        if (!GLOBAL_CORE_JS_PROMISE && V8_VERSION === 66) return true;
        if (IS_PURE && !(NativePromisePrototype["catch"] && NativePromisePrototype["finally"])) return true;
        if (!V8_VERSION || V8_VERSION < 51 || !/native code/.test(PROMISE_CONSTRUCTOR_SOURCE)) {
          var promise = new NativePromiseConstructor(function(resolve) {
            resolve(1);
          });
          var FakePromise = function(exec) {
            exec(function() {
            }, function() {
            });
          };
          var constructor = promise.constructor = {};
          constructor[SPECIES] = FakePromise;
          SUBCLASSING = promise.then(function() {
          }) instanceof FakePromise;
          if (!SUBCLASSING) return true;
        }
        return !GLOBAL_CORE_JS_PROMISE && (ENVIRONMENT === "BROWSER" || ENVIRONMENT === "DENO") && !NATIVE_PROMISE_REJECTION_EVENT;
      });
      module3.exports = {
        CONSTRUCTOR: FORCED_PROMISE_CONSTRUCTOR,
        REJECTION_EVENT: NATIVE_PROMISE_REJECTION_EVENT,
        SUBCLASSING
      };
    }
  });

  // ../../node_modules/core-js/internals/new-promise-capability.js
  var require_new_promise_capability = __commonJS({
    "../../node_modules/core-js/internals/new-promise-capability.js"(exports, module3) {
      "use strict";
      var aCallable = require_a_callable();
      var $TypeError = TypeError;
      var PromiseCapability = function(C2) {
        var resolve, reject;
        this.promise = new C2(function($$resolve, $$reject) {
          if (resolve !== void 0 || reject !== void 0) throw new $TypeError("Bad Promise constructor");
          resolve = $$resolve;
          reject = $$reject;
        });
        this.resolve = aCallable(resolve);
        this.reject = aCallable(reject);
      };
      module3.exports.f = function(C2) {
        return new PromiseCapability(C2);
      };
    }
  });

  // ../../node_modules/core-js/modules/es.promise.constructor.js
  var require_es_promise_constructor = __commonJS({
    "../../node_modules/core-js/modules/es.promise.constructor.js"() {
      "use strict";
      var $ = require_export();
      var IS_PURE = require_is_pure();
      var IS_NODE = require_environment_is_node();
      var globalThis2 = require_global_this();
      var call = require_function_call();
      var defineBuiltIn = require_define_built_in();
      var setPrototypeOf = require_object_set_prototype_of();
      var setToStringTag = require_set_to_string_tag();
      var setSpecies = require_set_species();
      var aCallable = require_a_callable();
      var isCallable = require_is_callable();
      var isObject = require_is_object();
      var anInstance = require_an_instance();
      var speciesConstructor = require_species_constructor();
      var task = require_task().set;
      var microtask = require_microtask();
      var hostReportErrors = require_host_report_errors();
      var perform2 = require_perform();
      var Queue = require_queue();
      var InternalStateModule = require_internal_state();
      var NativePromiseConstructor = require_promise_native_constructor();
      var PromiseConstructorDetection = require_promise_constructor_detection();
      var newPromiseCapabilityModule = require_new_promise_capability();
      var PROMISE = "Promise";
      var FORCED_PROMISE_CONSTRUCTOR = PromiseConstructorDetection.CONSTRUCTOR;
      var NATIVE_PROMISE_REJECTION_EVENT = PromiseConstructorDetection.REJECTION_EVENT;
      var NATIVE_PROMISE_SUBCLASSING = PromiseConstructorDetection.SUBCLASSING;
      var getInternalPromiseState = InternalStateModule.getterFor(PROMISE);
      var setInternalState = InternalStateModule.set;
      var NativePromisePrototype = NativePromiseConstructor && NativePromiseConstructor.prototype;
      var PromiseConstructor = NativePromiseConstructor;
      var PromisePrototype = NativePromisePrototype;
      var TypeError2 = globalThis2.TypeError;
      var document2 = globalThis2.document;
      var process2 = globalThis2.process;
      var newPromiseCapability = newPromiseCapabilityModule.f;
      var newGenericPromiseCapability = newPromiseCapability;
      var DISPATCH_EVENT = !!(document2 && document2.createEvent && globalThis2.dispatchEvent);
      var UNHANDLED_REJECTION = "unhandledrejection";
      var REJECTION_HANDLED = "rejectionhandled";
      var PENDING = 0;
      var FULFILLED = 1;
      var REJECTED = 2;
      var HANDLED = 1;
      var UNHANDLED = 2;
      var Internal;
      var OwnPromiseCapability;
      var PromiseWrapper;
      var nativeThen;
      var isThenable = function(it) {
        var then;
        return isObject(it) && isCallable(then = it.then) ? then : false;
      };
      var callReaction = function(reaction, state) {
        var value = state.value;
        var ok = state.state === FULFILLED;
        var handler = ok ? reaction.ok : reaction.fail;
        var resolve = reaction.resolve;
        var reject = reaction.reject;
        var domain = reaction.domain;
        var result, then, exited;
        try {
          if (handler) {
            if (!ok) {
              if (state.rejection === UNHANDLED) onHandleUnhandled(state);
              state.rejection = HANDLED;
            }
            if (handler === true) result = value;
            else {
              if (domain) domain.enter();
              result = handler(value);
              if (domain) {
                domain.exit();
                exited = true;
              }
            }
            if (result === reaction.promise) {
              reject(new TypeError2("Promise-chain cycle"));
            } else if (then = isThenable(result)) {
              call(then, result, resolve, reject);
            } else resolve(result);
          } else reject(value);
        } catch (error3) {
          if (domain && !exited) domain.exit();
          reject(error3);
        }
      };
      var notify = function(state, isReject) {
        if (state.notified) return;
        state.notified = true;
        microtask(function() {
          var reactions = state.reactions;
          var reaction;
          while (reaction = reactions.get()) {
            callReaction(reaction, state);
          }
          state.notified = false;
          if (isReject && !state.rejection) onUnhandled(state);
        });
      };
      var dispatchEvent2 = function(name3, promise, reason) {
        var event, handler;
        if (DISPATCH_EVENT) {
          event = document2.createEvent("Event");
          event.promise = promise;
          event.reason = reason;
          event.initEvent(name3, false, true);
          globalThis2.dispatchEvent(event);
        } else event = { promise, reason };
        if (!NATIVE_PROMISE_REJECTION_EVENT && (handler = globalThis2["on" + name3])) handler(event);
        else if (name3 === UNHANDLED_REJECTION) hostReportErrors("Unhandled promise rejection", reason);
      };
      var onUnhandled = function(state) {
        call(task, globalThis2, function() {
          var promise = state.facade;
          var value = state.value;
          var IS_UNHANDLED = isUnhandled(state);
          var result;
          if (IS_UNHANDLED) {
            result = perform2(function() {
              if (IS_NODE) {
                process2.emit("unhandledRejection", value, promise);
              } else dispatchEvent2(UNHANDLED_REJECTION, promise, value);
            });
            state.rejection = IS_NODE || isUnhandled(state) ? UNHANDLED : HANDLED;
            if (result.error) throw result.value;
          }
        });
      };
      var isUnhandled = function(state) {
        return state.rejection !== HANDLED && !state.parent;
      };
      var onHandleUnhandled = function(state) {
        call(task, globalThis2, function() {
          var promise = state.facade;
          if (IS_NODE) {
            process2.emit("rejectionHandled", promise);
          } else dispatchEvent2(REJECTION_HANDLED, promise, state.value);
        });
      };
      var bind = function(fn2, state, unwrap) {
        return function(value) {
          fn2(state, value, unwrap);
        };
      };
      var internalReject = function(state, value, unwrap) {
        if (state.done) return;
        state.done = true;
        if (unwrap) state = unwrap;
        state.value = value;
        state.state = REJECTED;
        notify(state, true);
      };
      var internalResolve = function(state, value, unwrap) {
        if (state.done) return;
        state.done = true;
        if (unwrap) state = unwrap;
        try {
          if (state.facade === value) throw new TypeError2("Promise can't be resolved itself");
          var then = isThenable(value);
          if (then) {
            microtask(function() {
              var wrapper = { done: false };
              try {
                call(
                  then,
                  value,
                  bind(internalResolve, wrapper, state),
                  bind(internalReject, wrapper, state)
                );
              } catch (error3) {
                internalReject(wrapper, error3, state);
              }
            });
          } else {
            state.value = value;
            state.state = FULFILLED;
            notify(state, false);
          }
        } catch (error3) {
          internalReject({ done: false }, error3, state);
        }
      };
      if (FORCED_PROMISE_CONSTRUCTOR) {
        PromiseConstructor = function Promise2(executor) {
          anInstance(this, PromisePrototype);
          aCallable(executor);
          call(Internal, this);
          var state = getInternalPromiseState(this);
          try {
            executor(bind(internalResolve, state), bind(internalReject, state));
          } catch (error3) {
            internalReject(state, error3);
          }
        };
        PromisePrototype = PromiseConstructor.prototype;
        Internal = function Promise2(executor) {
          setInternalState(this, {
            type: PROMISE,
            done: false,
            notified: false,
            parent: false,
            reactions: new Queue(),
            rejection: false,
            state: PENDING,
            value: null
          });
        };
        Internal.prototype = defineBuiltIn(PromisePrototype, "then", function then(onFulfilled, onRejected) {
          var state = getInternalPromiseState(this);
          var reaction = newPromiseCapability(speciesConstructor(this, PromiseConstructor));
          state.parent = true;
          reaction.ok = isCallable(onFulfilled) ? onFulfilled : true;
          reaction.fail = isCallable(onRejected) && onRejected;
          reaction.domain = IS_NODE ? process2.domain : void 0;
          if (state.state === PENDING) state.reactions.add(reaction);
          else microtask(function() {
            callReaction(reaction, state);
          });
          return reaction.promise;
        });
        OwnPromiseCapability = function() {
          var promise = new Internal();
          var state = getInternalPromiseState(promise);
          this.promise = promise;
          this.resolve = bind(internalResolve, state);
          this.reject = bind(internalReject, state);
        };
        newPromiseCapabilityModule.f = newPromiseCapability = function(C2) {
          return C2 === PromiseConstructor || C2 === PromiseWrapper ? new OwnPromiseCapability(C2) : newGenericPromiseCapability(C2);
        };
        if (!IS_PURE && isCallable(NativePromiseConstructor) && NativePromisePrototype !== Object.prototype) {
          nativeThen = NativePromisePrototype.then;
          if (!NATIVE_PROMISE_SUBCLASSING) {
            defineBuiltIn(NativePromisePrototype, "then", function then(onFulfilled, onRejected) {
              var that = this;
              return new PromiseConstructor(function(resolve, reject) {
                call(nativeThen, that, resolve, reject);
              }).then(onFulfilled, onRejected);
            }, { unsafe: true });
          }
          try {
            delete NativePromisePrototype.constructor;
          } catch (error3) {
          }
          if (setPrototypeOf) {
            setPrototypeOf(NativePromisePrototype, PromisePrototype);
          }
        }
      }
      $({ global: true, constructor: true, wrap: true, forced: FORCED_PROMISE_CONSTRUCTOR }, {
        Promise: PromiseConstructor
      });
      setToStringTag(PromiseConstructor, PROMISE, false, true);
      setSpecies(PROMISE);
    }
  });

  // ../../node_modules/core-js/internals/promise-statics-incorrect-iteration.js
  var require_promise_statics_incorrect_iteration = __commonJS({
    "../../node_modules/core-js/internals/promise-statics-incorrect-iteration.js"(exports, module3) {
      "use strict";
      var NativePromiseConstructor = require_promise_native_constructor();
      var checkCorrectnessOfIteration = require_check_correctness_of_iteration();
      var FORCED_PROMISE_CONSTRUCTOR = require_promise_constructor_detection().CONSTRUCTOR;
      module3.exports = FORCED_PROMISE_CONSTRUCTOR || !checkCorrectnessOfIteration(function(iterable) {
        NativePromiseConstructor.all(iterable).then(void 0, function() {
        });
      });
    }
  });

  // ../../node_modules/core-js/modules/es.promise.all.js
  var require_es_promise_all = __commonJS({
    "../../node_modules/core-js/modules/es.promise.all.js"() {
      "use strict";
      var $ = require_export();
      var call = require_function_call();
      var aCallable = require_a_callable();
      var newPromiseCapabilityModule = require_new_promise_capability();
      var perform2 = require_perform();
      var iterate = require_iterate();
      var PROMISE_STATICS_INCORRECT_ITERATION = require_promise_statics_incorrect_iteration();
      $({ target: "Promise", stat: true, forced: PROMISE_STATICS_INCORRECT_ITERATION }, {
        all: function all(iterable) {
          var C2 = this;
          var capability = newPromiseCapabilityModule.f(C2);
          var resolve = capability.resolve;
          var reject = capability.reject;
          var result = perform2(function() {
            var $promiseResolve = aCallable(C2.resolve);
            var values = [];
            var counter = 0;
            var remaining = 1;
            iterate(iterable, function(promise) {
              var index = counter++;
              var alreadyCalled = false;
              remaining++;
              call($promiseResolve, C2, promise).then(function(value) {
                if (alreadyCalled) return;
                alreadyCalled = true;
                values[index] = value;
                --remaining || resolve(values);
              }, reject);
            });
            --remaining || resolve(values);
          });
          if (result.error) reject(result.value);
          return capability.promise;
        }
      });
    }
  });

  // ../../node_modules/core-js/modules/es.promise.catch.js
  var require_es_promise_catch = __commonJS({
    "../../node_modules/core-js/modules/es.promise.catch.js"() {
      "use strict";
      var $ = require_export();
      var IS_PURE = require_is_pure();
      var FORCED_PROMISE_CONSTRUCTOR = require_promise_constructor_detection().CONSTRUCTOR;
      var NativePromiseConstructor = require_promise_native_constructor();
      var getBuiltIn = require_get_built_in();
      var isCallable = require_is_callable();
      var defineBuiltIn = require_define_built_in();
      var NativePromisePrototype = NativePromiseConstructor && NativePromiseConstructor.prototype;
      $({ target: "Promise", proto: true, forced: FORCED_PROMISE_CONSTRUCTOR, real: true }, {
        "catch": function(onRejected) {
          return this.then(void 0, onRejected);
        }
      });
      if (!IS_PURE && isCallable(NativePromiseConstructor)) {
        method = getBuiltIn("Promise").prototype["catch"];
        if (NativePromisePrototype["catch"] !== method) {
          defineBuiltIn(NativePromisePrototype, "catch", method, { unsafe: true });
        }
      }
      var method;
    }
  });

  // ../../node_modules/core-js/modules/es.promise.race.js
  var require_es_promise_race = __commonJS({
    "../../node_modules/core-js/modules/es.promise.race.js"() {
      "use strict";
      var $ = require_export();
      var call = require_function_call();
      var aCallable = require_a_callable();
      var newPromiseCapabilityModule = require_new_promise_capability();
      var perform2 = require_perform();
      var iterate = require_iterate();
      var PROMISE_STATICS_INCORRECT_ITERATION = require_promise_statics_incorrect_iteration();
      $({ target: "Promise", stat: true, forced: PROMISE_STATICS_INCORRECT_ITERATION }, {
        race: function race(iterable) {
          var C2 = this;
          var capability = newPromiseCapabilityModule.f(C2);
          var reject = capability.reject;
          var result = perform2(function() {
            var $promiseResolve = aCallable(C2.resolve);
            iterate(iterable, function(promise) {
              call($promiseResolve, C2, promise).then(capability.resolve, reject);
            });
          });
          if (result.error) reject(result.value);
          return capability.promise;
        }
      });
    }
  });

  // ../../node_modules/core-js/modules/es.promise.reject.js
  var require_es_promise_reject = __commonJS({
    "../../node_modules/core-js/modules/es.promise.reject.js"() {
      "use strict";
      var $ = require_export();
      var newPromiseCapabilityModule = require_new_promise_capability();
      var FORCED_PROMISE_CONSTRUCTOR = require_promise_constructor_detection().CONSTRUCTOR;
      $({ target: "Promise", stat: true, forced: FORCED_PROMISE_CONSTRUCTOR }, {
        reject: function reject(r2) {
          var capability = newPromiseCapabilityModule.f(this);
          var capabilityReject = capability.reject;
          capabilityReject(r2);
          return capability.promise;
        }
      });
    }
  });

  // ../../node_modules/core-js/internals/promise-resolve.js
  var require_promise_resolve = __commonJS({
    "../../node_modules/core-js/internals/promise-resolve.js"(exports, module3) {
      "use strict";
      var anObject = require_an_object();
      var isObject = require_is_object();
      var newPromiseCapability = require_new_promise_capability();
      module3.exports = function(C2, x2) {
        anObject(C2);
        if (isObject(x2) && x2.constructor === C2) return x2;
        var promiseCapability = newPromiseCapability.f(C2);
        var resolve = promiseCapability.resolve;
        resolve(x2);
        return promiseCapability.promise;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.promise.resolve.js
  var require_es_promise_resolve = __commonJS({
    "../../node_modules/core-js/modules/es.promise.resolve.js"() {
      "use strict";
      var $ = require_export();
      var getBuiltIn = require_get_built_in();
      var IS_PURE = require_is_pure();
      var NativePromiseConstructor = require_promise_native_constructor();
      var FORCED_PROMISE_CONSTRUCTOR = require_promise_constructor_detection().CONSTRUCTOR;
      var promiseResolve = require_promise_resolve();
      var PromiseConstructorWrapper = getBuiltIn("Promise");
      var CHECK_WRAPPER = IS_PURE && !FORCED_PROMISE_CONSTRUCTOR;
      $({ target: "Promise", stat: true, forced: IS_PURE || FORCED_PROMISE_CONSTRUCTOR }, {
        resolve: function resolve(x2) {
          return promiseResolve(CHECK_WRAPPER && this === PromiseConstructorWrapper ? NativePromiseConstructor : this, x2);
        }
      });
    }
  });

  // ../../node_modules/core-js/modules/es.promise.js
  var require_es_promise = __commonJS({
    "../../node_modules/core-js/modules/es.promise.js"() {
      "use strict";
      require_es_promise_constructor();
      require_es_promise_all();
      require_es_promise_catch();
      require_es_promise_race();
      require_es_promise_reject();
      require_es_promise_resolve();
    }
  });

  // ../../node_modules/core-js/modules/es.promise.all-settled.js
  var require_es_promise_all_settled = __commonJS({
    "../../node_modules/core-js/modules/es.promise.all-settled.js"() {
      "use strict";
      var $ = require_export();
      var call = require_function_call();
      var aCallable = require_a_callable();
      var newPromiseCapabilityModule = require_new_promise_capability();
      var perform2 = require_perform();
      var iterate = require_iterate();
      var PROMISE_STATICS_INCORRECT_ITERATION = require_promise_statics_incorrect_iteration();
      $({ target: "Promise", stat: true, forced: PROMISE_STATICS_INCORRECT_ITERATION }, {
        allSettled: function allSettled(iterable) {
          var C2 = this;
          var capability = newPromiseCapabilityModule.f(C2);
          var resolve = capability.resolve;
          var reject = capability.reject;
          var result = perform2(function() {
            var promiseResolve = aCallable(C2.resolve);
            var values = [];
            var counter = 0;
            var remaining = 1;
            iterate(iterable, function(promise) {
              var index = counter++;
              var alreadyCalled = false;
              remaining++;
              call(promiseResolve, C2, promise).then(function(value) {
                if (alreadyCalled) return;
                alreadyCalled = true;
                values[index] = { status: "fulfilled", value };
                --remaining || resolve(values);
              }, function(error3) {
                if (alreadyCalled) return;
                alreadyCalled = true;
                values[index] = { status: "rejected", reason: error3 };
                --remaining || resolve(values);
              });
            });
            --remaining || resolve(values);
          });
          if (result.error) reject(result.value);
          return capability.promise;
        }
      });
    }
  });

  // ../../node_modules/core-js/modules/es.promise.any.js
  var require_es_promise_any = __commonJS({
    "../../node_modules/core-js/modules/es.promise.any.js"() {
      "use strict";
      var $ = require_export();
      var call = require_function_call();
      var aCallable = require_a_callable();
      var getBuiltIn = require_get_built_in();
      var newPromiseCapabilityModule = require_new_promise_capability();
      var perform2 = require_perform();
      var iterate = require_iterate();
      var PROMISE_STATICS_INCORRECT_ITERATION = require_promise_statics_incorrect_iteration();
      var PROMISE_ANY_ERROR = "No one promise resolved";
      $({ target: "Promise", stat: true, forced: PROMISE_STATICS_INCORRECT_ITERATION }, {
        any: function any(iterable) {
          var C2 = this;
          var AggregateError = getBuiltIn("AggregateError");
          var capability = newPromiseCapabilityModule.f(C2);
          var resolve = capability.resolve;
          var reject = capability.reject;
          var result = perform2(function() {
            var promiseResolve = aCallable(C2.resolve);
            var errors = [];
            var counter = 0;
            var remaining = 1;
            var alreadyResolved = false;
            iterate(iterable, function(promise) {
              var index = counter++;
              var alreadyRejected = false;
              remaining++;
              call(promiseResolve, C2, promise).then(function(value) {
                if (alreadyRejected || alreadyResolved) return;
                alreadyResolved = true;
                resolve(value);
              }, function(error3) {
                if (alreadyRejected || alreadyResolved) return;
                alreadyRejected = true;
                errors[index] = error3;
                --remaining || reject(new AggregateError(errors, PROMISE_ANY_ERROR));
              });
            });
            --remaining || reject(new AggregateError(errors, PROMISE_ANY_ERROR));
          });
          if (result.error) reject(result.value);
          return capability.promise;
        }
      });
    }
  });

  // ../../node_modules/core-js/modules/es.promise.try.js
  var require_es_promise_try = __commonJS({
    "../../node_modules/core-js/modules/es.promise.try.js"() {
      "use strict";
      var $ = require_export();
      var globalThis2 = require_global_this();
      var apply = require_function_apply();
      var slice = require_array_slice();
      var newPromiseCapabilityModule = require_new_promise_capability();
      var aCallable = require_a_callable();
      var perform2 = require_perform();
      var Promise2 = globalThis2.Promise;
      var ACCEPT_ARGUMENTS = false;
      var FORCED = !Promise2 || !Promise2["try"] || perform2(function() {
        Promise2["try"](function(argument) {
          ACCEPT_ARGUMENTS = argument === 8;
        }, 8);
      }).error || !ACCEPT_ARGUMENTS;
      $({ target: "Promise", stat: true, forced: FORCED }, {
        "try": function(callbackfn) {
          var args = arguments.length > 1 ? slice(arguments, 1) : [];
          var promiseCapability = newPromiseCapabilityModule.f(this);
          var result = perform2(function() {
            return apply(aCallable(callbackfn), void 0, args);
          });
          (result.error ? promiseCapability.reject : promiseCapability.resolve)(result.value);
          return promiseCapability.promise;
        }
      });
    }
  });

  // ../../node_modules/core-js/modules/es.promise.with-resolvers.js
  var require_es_promise_with_resolvers = __commonJS({
    "../../node_modules/core-js/modules/es.promise.with-resolvers.js"() {
      "use strict";
      var $ = require_export();
      var newPromiseCapabilityModule = require_new_promise_capability();
      $({ target: "Promise", stat: true }, {
        withResolvers: function withResolvers() {
          var promiseCapability = newPromiseCapabilityModule.f(this);
          return {
            promise: promiseCapability.promise,
            resolve: promiseCapability.resolve,
            reject: promiseCapability.reject
          };
        }
      });
    }
  });

  // ../../node_modules/core-js/modules/es.promise.finally.js
  var require_es_promise_finally = __commonJS({
    "../../node_modules/core-js/modules/es.promise.finally.js"() {
      "use strict";
      var $ = require_export();
      var IS_PURE = require_is_pure();
      var NativePromiseConstructor = require_promise_native_constructor();
      var fails = require_fails();
      var getBuiltIn = require_get_built_in();
      var isCallable = require_is_callable();
      var speciesConstructor = require_species_constructor();
      var promiseResolve = require_promise_resolve();
      var defineBuiltIn = require_define_built_in();
      var NativePromisePrototype = NativePromiseConstructor && NativePromiseConstructor.prototype;
      var NON_GENERIC = !!NativePromiseConstructor && fails(function() {
        NativePromisePrototype["finally"].call({ then: function() {
        } }, function() {
        });
      });
      $({ target: "Promise", proto: true, real: true, forced: NON_GENERIC }, {
        "finally": function(onFinally) {
          var C2 = speciesConstructor(this, getBuiltIn("Promise"));
          var isFunction = isCallable(onFinally);
          return this.then(
            isFunction ? function(x2) {
              return promiseResolve(C2, onFinally()).then(function() {
                return x2;
              });
            } : onFinally,
            isFunction ? function(e) {
              return promiseResolve(C2, onFinally()).then(function() {
                throw e;
              });
            } : onFinally
          );
        }
      });
      if (!IS_PURE && isCallable(NativePromiseConstructor)) {
        method = getBuiltIn("Promise").prototype["finally"];
        if (NativePromisePrototype["finally"] !== method) {
          defineBuiltIn(NativePromisePrototype, "finally", method, { unsafe: true });
        }
      }
      var method;
    }
  });

  // ../../node_modules/core-js/es/promise/index.js
  var require_promise = __commonJS({
    "../../node_modules/core-js/es/promise/index.js"(exports, module3) {
      "use strict";
      require_es_aggregate_error();
      require_es_array_iterator();
      require_es_object_to_string();
      require_es_promise();
      require_es_promise_all_settled();
      require_es_promise_any();
      require_es_promise_try();
      require_es_promise_with_resolvers();
      require_es_promise_finally();
      require_es_string_iterator();
      var path = require_path();
      module3.exports = path.Promise;
    }
  });

  // ../../node_modules/core-js/modules/es.set.constructor.js
  var require_es_set_constructor = __commonJS({
    "../../node_modules/core-js/modules/es.set.constructor.js"() {
      "use strict";
      var collection = require_collection();
      var collectionStrong = require_collection_strong();
      collection("Set", function(init) {
        return function Set2() {
          return init(this, arguments.length ? arguments[0] : void 0);
        };
      }, collectionStrong);
    }
  });

  // ../../node_modules/core-js/modules/es.set.js
  var require_es_set = __commonJS({
    "../../node_modules/core-js/modules/es.set.js"() {
      "use strict";
      require_es_set_constructor();
    }
  });

  // ../../node_modules/core-js/internals/set-helpers.js
  var require_set_helpers = __commonJS({
    "../../node_modules/core-js/internals/set-helpers.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var SetPrototype = Set.prototype;
      module3.exports = {
        // eslint-disable-next-line es/no-set -- safe
        Set,
        add: uncurryThis(SetPrototype.add),
        has: uncurryThis(SetPrototype.has),
        remove: uncurryThis(SetPrototype["delete"]),
        proto: SetPrototype
      };
    }
  });

  // ../../node_modules/core-js/internals/a-set.js
  var require_a_set = __commonJS({
    "../../node_modules/core-js/internals/a-set.js"(exports, module3) {
      "use strict";
      var has = require_set_helpers().has;
      module3.exports = function(it) {
        has(it);
        return it;
      };
    }
  });

  // ../../node_modules/core-js/internals/iterate-simple.js
  var require_iterate_simple = __commonJS({
    "../../node_modules/core-js/internals/iterate-simple.js"(exports, module3) {
      "use strict";
      var call = require_function_call();
      module3.exports = function(record, fn2, ITERATOR_INSTEAD_OF_RECORD) {
        var iterator = ITERATOR_INSTEAD_OF_RECORD ? record : record.iterator;
        var next = record.next;
        var step, result;
        while (!(step = call(next, iterator)).done) {
          result = fn2(step.value);
          if (result !== void 0) return result;
        }
      };
    }
  });

  // ../../node_modules/core-js/internals/set-iterate.js
  var require_set_iterate = __commonJS({
    "../../node_modules/core-js/internals/set-iterate.js"(exports, module3) {
      "use strict";
      var uncurryThis = require_function_uncurry_this();
      var iterateSimple = require_iterate_simple();
      var SetHelpers = require_set_helpers();
      var Set2 = SetHelpers.Set;
      var SetPrototype = SetHelpers.proto;
      var forEach = uncurryThis(SetPrototype.forEach);
      var keys = uncurryThis(SetPrototype.keys);
      var next = keys(new Set2()).next;
      module3.exports = function(set, fn2, interruptible) {
        return interruptible ? iterateSimple({ iterator: keys(set), next }, fn2) : forEach(set, fn2);
      };
    }
  });

  // ../../node_modules/core-js/internals/set-clone.js
  var require_set_clone = __commonJS({
    "../../node_modules/core-js/internals/set-clone.js"(exports, module3) {
      "use strict";
      var SetHelpers = require_set_helpers();
      var iterate = require_set_iterate();
      var Set2 = SetHelpers.Set;
      var add3 = SetHelpers.add;
      module3.exports = function(set) {
        var result = new Set2();
        iterate(set, function(it) {
          add3(result, it);
        });
        return result;
      };
    }
  });

  // ../../node_modules/core-js/internals/set-size.js
  var require_set_size = __commonJS({
    "../../node_modules/core-js/internals/set-size.js"(exports, module3) {
      "use strict";
      var uncurryThisAccessor = require_function_uncurry_this_accessor();
      var SetHelpers = require_set_helpers();
      module3.exports = uncurryThisAccessor(SetHelpers.proto, "size", "get") || function(set) {
        return set.size;
      };
    }
  });

  // ../../node_modules/core-js/internals/get-iterator-direct.js
  var require_get_iterator_direct = __commonJS({
    "../../node_modules/core-js/internals/get-iterator-direct.js"(exports, module3) {
      "use strict";
      module3.exports = function(obj) {
        return {
          iterator: obj,
          next: obj.next,
          done: false
        };
      };
    }
  });

  // ../../node_modules/core-js/internals/get-set-record.js
  var require_get_set_record = __commonJS({
    "../../node_modules/core-js/internals/get-set-record.js"(exports, module3) {
      "use strict";
      var aCallable = require_a_callable();
      var anObject = require_an_object();
      var call = require_function_call();
      var toIntegerOrInfinity = require_to_integer_or_infinity();
      var getIteratorDirect = require_get_iterator_direct();
      var INVALID_SIZE = "Invalid size";
      var $RangeError = RangeError;
      var $TypeError = TypeError;
      var max2 = Math.max;
      var SetRecord = function(set, intSize) {
        this.set = set;
        this.size = max2(intSize, 0);
        this.has = aCallable(set.has);
        this.keys = aCallable(set.keys);
      };
      SetRecord.prototype = {
        getIterator: function() {
          return getIteratorDirect(anObject(call(this.keys, this.set)));
        },
        includes: function(it) {
          return call(this.has, this.set, it);
        }
      };
      module3.exports = function(obj) {
        anObject(obj);
        var numSize = +obj.size;
        if (numSize !== numSize) throw new $TypeError(INVALID_SIZE);
        var intSize = toIntegerOrInfinity(numSize);
        if (intSize < 0) throw new $RangeError(INVALID_SIZE);
        return new SetRecord(obj, intSize);
      };
    }
  });

  // ../../node_modules/core-js/internals/set-difference.js
  var require_set_difference = __commonJS({
    "../../node_modules/core-js/internals/set-difference.js"(exports, module3) {
      "use strict";
      var aSet = require_a_set();
      var SetHelpers = require_set_helpers();
      var clone = require_set_clone();
      var size = require_set_size();
      var getSetRecord = require_get_set_record();
      var iterateSet = require_set_iterate();
      var iterateSimple = require_iterate_simple();
      var has = SetHelpers.has;
      var remove = SetHelpers.remove;
      module3.exports = function difference(other) {
        var O = aSet(this);
        var otherRec = getSetRecord(other);
        var result = clone(O);
        if (size(O) <= otherRec.size) iterateSet(O, function(e) {
          if (otherRec.includes(e)) remove(result, e);
        });
        else iterateSimple(otherRec.getIterator(), function(e) {
          if (has(O, e)) remove(result, e);
        });
        return result;
      };
    }
  });

  // ../../node_modules/core-js/internals/set-method-accept-set-like.js
  var require_set_method_accept_set_like = __commonJS({
    "../../node_modules/core-js/internals/set-method-accept-set-like.js"(exports, module3) {
      "use strict";
      var getBuiltIn = require_get_built_in();
      var createSetLike = function(size) {
        return {
          size,
          has: function() {
            return false;
          },
          keys: function() {
            return {
              next: function() {
                return { done: true };
              }
            };
          }
        };
      };
      var createSetLikeWithInfinitySize = function(size) {
        return {
          size,
          has: function() {
            return true;
          },
          keys: function() {
            throw new Error("e");
          }
        };
      };
      module3.exports = function(name3, callback) {
        var Set2 = getBuiltIn("Set");
        try {
          new Set2()[name3](createSetLike(0));
          try {
            new Set2()[name3](createSetLike(-1));
            return false;
          } catch (error22) {
            if (!callback) return true;
            try {
              new Set2()[name3](createSetLikeWithInfinitySize(-Infinity));
              return false;
            } catch (error3) {
              var set = new Set2();
              set.add(1);
              set.add(2);
              return callback(set[name3](createSetLikeWithInfinitySize(Infinity)));
            }
          }
        } catch (error3) {
          return false;
        }
      };
    }
  });

  // ../../node_modules/core-js/modules/es.set.difference.v2.js
  var require_es_set_difference_v2 = __commonJS({
    "../../node_modules/core-js/modules/es.set.difference.v2.js"() {
      "use strict";
      var $ = require_export();
      var difference = require_set_difference();
      var setMethodAcceptSetLike = require_set_method_accept_set_like();
      var INCORRECT = !setMethodAcceptSetLike("difference", function(result) {
        return result.size === 0;
      });
      $({ target: "Set", proto: true, real: true, forced: INCORRECT }, {
        difference
      });
    }
  });

  // ../../node_modules/core-js/internals/set-intersection.js
  var require_set_intersection = __commonJS({
    "../../node_modules/core-js/internals/set-intersection.js"(exports, module3) {
      "use strict";
      var aSet = require_a_set();
      var SetHelpers = require_set_helpers();
      var size = require_set_size();
      var getSetRecord = require_get_set_record();
      var iterateSet = require_set_iterate();
      var iterateSimple = require_iterate_simple();
      var Set2 = SetHelpers.Set;
      var add3 = SetHelpers.add;
      var has = SetHelpers.has;
      module3.exports = function intersection(other) {
        var O = aSet(this);
        var otherRec = getSetRecord(other);
        var result = new Set2();
        if (size(O) > otherRec.size) {
          iterateSimple(otherRec.getIterator(), function(e) {
            if (has(O, e)) add3(result, e);
          });
        } else {
          iterateSet(O, function(e) {
            if (otherRec.includes(e)) add3(result, e);
          });
        }
        return result;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.set.intersection.v2.js
  var require_es_set_intersection_v2 = __commonJS({
    "../../node_modules/core-js/modules/es.set.intersection.v2.js"() {
      "use strict";
      var $ = require_export();
      var fails = require_fails();
      var intersection = require_set_intersection();
      var setMethodAcceptSetLike = require_set_method_accept_set_like();
      var INCORRECT = !setMethodAcceptSetLike("intersection", function(result) {
        return result.size === 2 && result.has(1) && result.has(2);
      }) || fails(function() {
        return String(Array.from((/* @__PURE__ */ new Set([1, 2, 3])).intersection(/* @__PURE__ */ new Set([3, 2])))) !== "3,2";
      });
      $({ target: "Set", proto: true, real: true, forced: INCORRECT }, {
        intersection
      });
    }
  });

  // ../../node_modules/core-js/internals/set-is-disjoint-from.js
  var require_set_is_disjoint_from = __commonJS({
    "../../node_modules/core-js/internals/set-is-disjoint-from.js"(exports, module3) {
      "use strict";
      var aSet = require_a_set();
      var has = require_set_helpers().has;
      var size = require_set_size();
      var getSetRecord = require_get_set_record();
      var iterateSet = require_set_iterate();
      var iterateSimple = require_iterate_simple();
      var iteratorClose = require_iterator_close();
      module3.exports = function isDisjointFrom(other) {
        var O = aSet(this);
        var otherRec = getSetRecord(other);
        if (size(O) <= otherRec.size) return iterateSet(O, function(e) {
          if (otherRec.includes(e)) return false;
        }, true) !== false;
        var iterator = otherRec.getIterator();
        return iterateSimple(iterator, function(e) {
          if (has(O, e)) return iteratorClose(iterator, "normal", false);
        }) !== false;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.set.is-disjoint-from.v2.js
  var require_es_set_is_disjoint_from_v2 = __commonJS({
    "../../node_modules/core-js/modules/es.set.is-disjoint-from.v2.js"() {
      "use strict";
      var $ = require_export();
      var isDisjointFrom = require_set_is_disjoint_from();
      var setMethodAcceptSetLike = require_set_method_accept_set_like();
      var INCORRECT = !setMethodAcceptSetLike("isDisjointFrom", function(result) {
        return !result;
      });
      $({ target: "Set", proto: true, real: true, forced: INCORRECT }, {
        isDisjointFrom
      });
    }
  });

  // ../../node_modules/core-js/internals/set-is-subset-of.js
  var require_set_is_subset_of = __commonJS({
    "../../node_modules/core-js/internals/set-is-subset-of.js"(exports, module3) {
      "use strict";
      var aSet = require_a_set();
      var size = require_set_size();
      var iterate = require_set_iterate();
      var getSetRecord = require_get_set_record();
      module3.exports = function isSubsetOf(other) {
        var O = aSet(this);
        var otherRec = getSetRecord(other);
        if (size(O) > otherRec.size) return false;
        return iterate(O, function(e) {
          if (!otherRec.includes(e)) return false;
        }, true) !== false;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.set.is-subset-of.v2.js
  var require_es_set_is_subset_of_v2 = __commonJS({
    "../../node_modules/core-js/modules/es.set.is-subset-of.v2.js"() {
      "use strict";
      var $ = require_export();
      var isSubsetOf = require_set_is_subset_of();
      var setMethodAcceptSetLike = require_set_method_accept_set_like();
      var INCORRECT = !setMethodAcceptSetLike("isSubsetOf", function(result) {
        return result;
      });
      $({ target: "Set", proto: true, real: true, forced: INCORRECT }, {
        isSubsetOf
      });
    }
  });

  // ../../node_modules/core-js/internals/set-is-superset-of.js
  var require_set_is_superset_of = __commonJS({
    "../../node_modules/core-js/internals/set-is-superset-of.js"(exports, module3) {
      "use strict";
      var aSet = require_a_set();
      var has = require_set_helpers().has;
      var size = require_set_size();
      var getSetRecord = require_get_set_record();
      var iterateSimple = require_iterate_simple();
      var iteratorClose = require_iterator_close();
      module3.exports = function isSupersetOf(other) {
        var O = aSet(this);
        var otherRec = getSetRecord(other);
        if (size(O) < otherRec.size) return false;
        var iterator = otherRec.getIterator();
        return iterateSimple(iterator, function(e) {
          if (!has(O, e)) return iteratorClose(iterator, "normal", false);
        }) !== false;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.set.is-superset-of.v2.js
  var require_es_set_is_superset_of_v2 = __commonJS({
    "../../node_modules/core-js/modules/es.set.is-superset-of.v2.js"() {
      "use strict";
      var $ = require_export();
      var isSupersetOf = require_set_is_superset_of();
      var setMethodAcceptSetLike = require_set_method_accept_set_like();
      var INCORRECT = !setMethodAcceptSetLike("isSupersetOf", function(result) {
        return !result;
      });
      $({ target: "Set", proto: true, real: true, forced: INCORRECT }, {
        isSupersetOf
      });
    }
  });

  // ../../node_modules/core-js/internals/set-symmetric-difference.js
  var require_set_symmetric_difference = __commonJS({
    "../../node_modules/core-js/internals/set-symmetric-difference.js"(exports, module3) {
      "use strict";
      var aSet = require_a_set();
      var SetHelpers = require_set_helpers();
      var clone = require_set_clone();
      var getSetRecord = require_get_set_record();
      var iterateSimple = require_iterate_simple();
      var add3 = SetHelpers.add;
      var has = SetHelpers.has;
      var remove = SetHelpers.remove;
      module3.exports = function symmetricDifference(other) {
        var O = aSet(this);
        var keysIter = getSetRecord(other).getIterator();
        var result = clone(O);
        iterateSimple(keysIter, function(e) {
          if (has(O, e)) remove(result, e);
          else add3(result, e);
        });
        return result;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.set.symmetric-difference.v2.js
  var require_es_set_symmetric_difference_v2 = __commonJS({
    "../../node_modules/core-js/modules/es.set.symmetric-difference.v2.js"() {
      "use strict";
      var $ = require_export();
      var symmetricDifference = require_set_symmetric_difference();
      var setMethodAcceptSetLike = require_set_method_accept_set_like();
      $({ target: "Set", proto: true, real: true, forced: !setMethodAcceptSetLike("symmetricDifference") }, {
        symmetricDifference
      });
    }
  });

  // ../../node_modules/core-js/internals/set-union.js
  var require_set_union = __commonJS({
    "../../node_modules/core-js/internals/set-union.js"(exports, module3) {
      "use strict";
      var aSet = require_a_set();
      var add3 = require_set_helpers().add;
      var clone = require_set_clone();
      var getSetRecord = require_get_set_record();
      var iterateSimple = require_iterate_simple();
      module3.exports = function union(other) {
        var O = aSet(this);
        var keysIter = getSetRecord(other).getIterator();
        var result = clone(O);
        iterateSimple(keysIter, function(it) {
          add3(result, it);
        });
        return result;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.set.union.v2.js
  var require_es_set_union_v2 = __commonJS({
    "../../node_modules/core-js/modules/es.set.union.v2.js"() {
      "use strict";
      var $ = require_export();
      var union = require_set_union();
      var setMethodAcceptSetLike = require_set_method_accept_set_like();
      $({ target: "Set", proto: true, real: true, forced: !setMethodAcceptSetLike("union") }, {
        union
      });
    }
  });

  // ../../node_modules/core-js/es/set/index.js
  var require_set = __commonJS({
    "../../node_modules/core-js/es/set/index.js"(exports, module3) {
      "use strict";
      require_es_array_iterator();
      require_es_object_to_string();
      require_es_set();
      require_es_set_difference_v2();
      require_es_set_intersection_v2();
      require_es_set_is_disjoint_from_v2();
      require_es_set_is_subset_of_v2();
      require_es_set_is_superset_of_v2();
      require_es_set_symmetric_difference_v2();
      require_es_set_union_v2();
      require_es_string_iterator();
      var path = require_path();
      module3.exports = path.Set;
    }
  });

  // ../../node_modules/core-js/internals/is-regexp.js
  var require_is_regexp = __commonJS({
    "../../node_modules/core-js/internals/is-regexp.js"(exports, module3) {
      "use strict";
      var isObject = require_is_object();
      var classof = require_classof_raw();
      var wellKnownSymbol = require_well_known_symbol();
      var MATCH = wellKnownSymbol("match");
      module3.exports = function(it) {
        var isRegExp;
        return isObject(it) && ((isRegExp = it[MATCH]) !== void 0 ? !!isRegExp : classof(it) === "RegExp");
      };
    }
  });

  // ../../node_modules/core-js/internals/not-a-regexp.js
  var require_not_a_regexp = __commonJS({
    "../../node_modules/core-js/internals/not-a-regexp.js"(exports, module3) {
      "use strict";
      var isRegExp = require_is_regexp();
      var $TypeError = TypeError;
      module3.exports = function(it) {
        if (isRegExp(it)) {
          throw new $TypeError("The method doesn't accept regular expressions");
        }
        return it;
      };
    }
  });

  // ../../node_modules/core-js/internals/correct-is-regexp-logic.js
  var require_correct_is_regexp_logic = __commonJS({
    "../../node_modules/core-js/internals/correct-is-regexp-logic.js"(exports, module3) {
      "use strict";
      var wellKnownSymbol = require_well_known_symbol();
      var MATCH = wellKnownSymbol("match");
      module3.exports = function(METHOD_NAME) {
        var regexp = /./;
        try {
          "/./"[METHOD_NAME](regexp);
        } catch (error1) {
          try {
            regexp[MATCH] = false;
            return "/./"[METHOD_NAME](regexp);
          } catch (error22) {
          }
        }
        return false;
      };
    }
  });

  // ../../node_modules/core-js/modules/es.string.starts-with.js
  var require_es_string_starts_with = __commonJS({
    "../../node_modules/core-js/modules/es.string.starts-with.js"() {
      "use strict";
      var $ = require_export();
      var uncurryThis = require_function_uncurry_this_clause();
      var getOwnPropertyDescriptor = require_object_get_own_property_descriptor().f;
      var toLength = require_to_length();
      var toString = require_to_string();
      var notARegExp = require_not_a_regexp();
      var requireObjectCoercible = require_require_object_coercible();
      var correctIsRegExpLogic = require_correct_is_regexp_logic();
      var IS_PURE = require_is_pure();
      var stringSlice = uncurryThis("".slice);
      var min2 = Math.min;
      var CORRECT_IS_REGEXP_LOGIC = correctIsRegExpLogic("startsWith");
      var MDN_POLYFILL_BUG = !IS_PURE && !CORRECT_IS_REGEXP_LOGIC && !!function() {
        var descriptor = getOwnPropertyDescriptor(String.prototype, "startsWith");
        return descriptor && !descriptor.writable;
      }();
      $({ target: "String", proto: true, forced: !MDN_POLYFILL_BUG && !CORRECT_IS_REGEXP_LOGIC }, {
        startsWith: function startsWith(searchString) {
          var that = toString(requireObjectCoercible(this));
          notARegExp(searchString);
          var index = toLength(min2(arguments.length > 1 ? arguments[1] : void 0, that.length));
          var search = toString(searchString);
          return stringSlice(that, index, index + search.length) === search;
        }
      });
    }
  });

  // ../../node_modules/core-js/es/string/starts-with.js
  var require_starts_with = __commonJS({
    "../../node_modules/core-js/es/string/starts-with.js"(exports, module3) {
      "use strict";
      require_es_string_starts_with();
      var entryUnbind = require_entry_unbind();
      module3.exports = entryUnbind("String", "startsWith");
    }
  });

  // ../../node_modules/eventlistener-polyfill/src/index.js
  var require_src = __commonJS({
    "../../node_modules/eventlistener-polyfill/src/index.js"(exports, module3) {
      var passiveSupported = false;
      var onceSupported = false;
      function noop2() {
      }
      try {
        options = Object.create({}, {
          passive: { get: function() {
            passiveSupported = true;
          } },
          once: { get: function() {
            onceSupported = true;
          } }
        });
        window.addEventListener("test", noop2, options);
        window.removeEventListener("test", noop2, options);
      } catch (e) {
      }
      var options;
      var enhance = module3.exports = function enhance2(proto) {
        var originalAddEventListener = proto.addEventListener;
        var originalRemoveEventListener = proto.removeEventListener;
        var listeners = /* @__PURE__ */ new WeakMap();
        proto.addEventListener = function(name3, originalCallback, optionsOrCapture) {
          if (optionsOrCapture === void 0 || optionsOrCapture === true || optionsOrCapture === false || (!originalCallback || typeof originalCallback !== "function" && typeof originalCallback !== "object")) {
            return originalAddEventListener.call(this, name3, originalCallback, optionsOrCapture);
          }
          var callback = typeof originalCallback !== "function" && typeof originalCallback.handleEvent === "function" ? originalCallback.handleEvent.bind(originalCallback) : originalCallback;
          var options2 = typeof optionsOrCapture === "boolean" ? { capture: optionsOrCapture } : optionsOrCapture || {};
          var passive2 = Boolean(options2.passive);
          var once = Boolean(options2.once);
          var capture = Boolean(options2.capture);
          var oldCallback = callback;
          if (!onceSupported && once) {
            callback = function(event) {
              this.removeEventListener(name3, originalCallback, options2);
              oldCallback.call(this, event);
            };
          }
          if (!passiveSupported && passive2) {
            callback = function(event) {
              event.preventDefault = noop2;
              oldCallback.call(this, event);
            };
          }
          if (!listeners.has(this)) listeners.set(this, /* @__PURE__ */ new WeakMap());
          var elementMap = listeners.get(this);
          if (!elementMap.has(originalCallback)) elementMap.set(originalCallback, []);
          var optionsOctal = passive2 * 1 + once * 2 + capture * 4;
          elementMap.get(originalCallback)[optionsOctal] = callback;
          originalAddEventListener.call(this, name3, callback, capture);
        };
        proto.removeEventListener = function(name3, originalCallback, optionsOrCapture) {
          var capture = Boolean(typeof optionsOrCapture === "object" ? optionsOrCapture.capture : optionsOrCapture);
          var elementMap = listeners.get(this);
          if (!elementMap) return originalRemoveEventListener.call(this, name3, originalCallback, optionsOrCapture);
          var callbacks = elementMap.get(originalCallback);
          if (!callbacks) return originalRemoveEventListener.call(this, name3, originalCallback, optionsOrCapture);
          for (var optionsOctal in callbacks) {
            var callbackIsCapture = Boolean(optionsOctal & 4);
            if (callbackIsCapture !== capture) continue;
            originalRemoveEventListener.call(this, name3, callbacks[optionsOctal], callbackIsCapture);
          }
        };
      };
      if (!passiveSupported || !onceSupported) {
        if (typeof EventTarget !== "undefined") {
          enhance(EventTarget.prototype);
        } else {
          enhance(Text.prototype);
          enhance(HTMLElement.prototype);
          enhance(HTMLDocument.prototype);
          enhance(Window.prototype);
          enhance(XMLHttpRequest.prototype);
        }
      }
    }
  });

  // ../../node_modules/core-js/internals/does-not-exceed-safe-integer.js
  var require_does_not_exceed_safe_integer = __commonJS({
    "../../node_modules/core-js/internals/does-not-exceed-safe-integer.js"(exports, module3) {
      "use strict";
      var $TypeError = TypeError;
      var MAX_SAFE_INTEGER = 9007199254740991;
      module3.exports = function(it) {
        if (it > MAX_SAFE_INTEGER) throw $TypeError("Maximum allowed index exceeded");
        return it;
      };
    }
  });

  // ../../node_modules/core-js/internals/flatten-into-array.js
  var require_flatten_into_array = __commonJS({
    "../../node_modules/core-js/internals/flatten-into-array.js"(exports, module3) {
      "use strict";
      var isArray = require_is_array();
      var lengthOfArrayLike = require_length_of_array_like();
      var doesNotExceedSafeInteger = require_does_not_exceed_safe_integer();
      var bind = require_function_bind_context();
      var flattenIntoArray = function(target, original, source, sourceLen, start3, depth, mapper, thisArg) {
        var targetIndex = start3;
        var sourceIndex = 0;
        var mapFn = mapper ? bind(mapper, thisArg) : false;
        var element, elementLen;
        while (sourceIndex < sourceLen) {
          if (sourceIndex in source) {
            element = mapFn ? mapFn(source[sourceIndex], sourceIndex, original) : source[sourceIndex];
            if (depth > 0 && isArray(element)) {
              elementLen = lengthOfArrayLike(element);
              targetIndex = flattenIntoArray(target, original, element, elementLen, targetIndex, depth - 1) - 1;
            } else {
              doesNotExceedSafeInteger(targetIndex + 1);
              target[targetIndex] = element;
            }
            targetIndex++;
          }
          sourceIndex++;
        }
        return targetIndex;
      };
      module3.exports = flattenIntoArray;
    }
  });

  // ../../node_modules/core-js/modules/es.array.flat.js
  var require_es_array_flat = __commonJS({
    "../../node_modules/core-js/modules/es.array.flat.js"() {
      "use strict";
      var $ = require_export();
      var flattenIntoArray = require_flatten_into_array();
      var toObject = require_to_object();
      var lengthOfArrayLike = require_length_of_array_like();
      var toIntegerOrInfinity = require_to_integer_or_infinity();
      var arraySpeciesCreate = require_array_species_create();
      $({ target: "Array", proto: true }, {
        flat: function flat() {
          var depthArg = arguments.length ? arguments[0] : void 0;
          var O = toObject(this);
          var sourceLen = lengthOfArrayLike(O);
          var A = arraySpeciesCreate(O, 0);
          A.length = flattenIntoArray(A, O, O, sourceLen, 0, depthArg === void 0 ? 1 : toIntegerOrInfinity(depthArg));
          return A;
        }
      });
    }
  });

  // ../../node_modules/core-js/modules/es.array.unscopables.flat.js
  var require_es_array_unscopables_flat = __commonJS({
    "../../node_modules/core-js/modules/es.array.unscopables.flat.js"() {
      "use strict";
      var addToUnscopables = require_add_to_unscopables();
      addToUnscopables("flat");
    }
  });

  // ../../node_modules/core-js/es/array/flat.js
  var require_flat = __commonJS({
    "../../node_modules/core-js/es/array/flat.js"(exports, module3) {
      "use strict";
      require_es_array_flat();
      require_es_array_unscopables_flat();
      var entryUnbind = require_entry_unbind();
      module3.exports = entryUnbind("Array", "flat");
    }
  });

  // ../../node_modules/core-js/internals/array-method-is-strict.js
  var require_array_method_is_strict = __commonJS({
    "../../node_modules/core-js/internals/array-method-is-strict.js"(exports, module3) {
      "use strict";
      var fails = require_fails();
      module3.exports = function(METHOD_NAME, argument) {
        var method = [][METHOD_NAME];
        return !!method && fails(function() {
          method.call(null, argument || function() {
            return 1;
          }, 1);
        });
      };
    }
  });

  // ../../node_modules/core-js/internals/array-for-each.js
  var require_array_for_each = __commonJS({
    "../../node_modules/core-js/internals/array-for-each.js"(exports, module3) {
      "use strict";
      var $forEach = require_array_iteration().forEach;
      var arrayMethodIsStrict = require_array_method_is_strict();
      var STRICT_METHOD = arrayMethodIsStrict("forEach");
      module3.exports = !STRICT_METHOD ? function forEach(callbackfn) {
        return $forEach(this, callbackfn, arguments.length > 1 ? arguments[1] : void 0);
      } : [].forEach;
    }
  });

  // ../../node_modules/core-js/modules/es.array.for-each.js
  var require_es_array_for_each = __commonJS({
    "../../node_modules/core-js/modules/es.array.for-each.js"() {
      "use strict";
      var $ = require_export();
      var forEach = require_array_for_each();
      $({ target: "Array", proto: true, forced: [].forEach !== forEach }, {
        forEach
      });
    }
  });

  // ../../node_modules/core-js/es/array/for-each.js
  var require_for_each = __commonJS({
    "../../node_modules/core-js/es/array/for-each.js"(exports, module3) {
      "use strict";
      require_es_array_for_each();
      var entryUnbind = require_entry_unbind();
      module3.exports = entryUnbind("Array", "forEach");
    }
  });

  // ../../node_modules/core-js/modules/es.array.includes.js
  var require_es_array_includes = __commonJS({
    "../../node_modules/core-js/modules/es.array.includes.js"() {
      "use strict";
      var $ = require_export();
      var $includes = require_array_includes().includes;
      var fails = require_fails();
      var addToUnscopables = require_add_to_unscopables();
      var BROKEN_ON_SPARSE = fails(function() {
        return !Array(1).includes();
      });
      $({ target: "Array", proto: true, forced: BROKEN_ON_SPARSE }, {
        includes: function includes(el) {
          return $includes(this, el, arguments.length > 1 ? arguments[1] : void 0);
        }
      });
      addToUnscopables("includes");
    }
  });

  // ../../node_modules/core-js/es/array/includes.js
  var require_includes = __commonJS({
    "../../node_modules/core-js/es/array/includes.js"(exports, module3) {
      "use strict";
      require_es_array_includes();
      var entryUnbind = require_entry_unbind();
      module3.exports = entryUnbind("Array", "includes");
    }
  });

  // ../../node_modules/core-js/internals/object-to-array.js
  var require_object_to_array = __commonJS({
    "../../node_modules/core-js/internals/object-to-array.js"(exports, module3) {
      "use strict";
      var DESCRIPTORS = require_descriptors();
      var fails = require_fails();
      var uncurryThis = require_function_uncurry_this();
      var objectGetPrototypeOf = require_object_get_prototype_of();
      var objectKeys = require_object_keys();
      var toIndexedObject = require_to_indexed_object();
      var $propertyIsEnumerable = require_object_property_is_enumerable().f;
      var propertyIsEnumerable = uncurryThis($propertyIsEnumerable);
      var push = uncurryThis([].push);
      var IE_BUG = DESCRIPTORS && fails(function() {
        var O = /* @__PURE__ */ Object.create(null);
        O[2] = 2;
        return !propertyIsEnumerable(O, 2);
      });
      var createMethod = function(TO_ENTRIES) {
        return function(it) {
          var O = toIndexedObject(it);
          var keys = objectKeys(O);
          var IE_WORKAROUND = IE_BUG && objectGetPrototypeOf(O) === null;
          var length = keys.length;
          var i = 0;
          var result = [];
          var key;
          while (length > i) {
            key = keys[i++];
            if (!DESCRIPTORS || (IE_WORKAROUND ? key in O : propertyIsEnumerable(O, key))) {
              push(result, TO_ENTRIES ? [key, O[key]] : O[key]);
            }
          }
          return result;
        };
      };
      module3.exports = {
        // `Object.entries` method
        // https://tc39.es/ecma262/#sec-object.entries
        entries: createMethod(true),
        // `Object.values` method
        // https://tc39.es/ecma262/#sec-object.values
        values: createMethod(false)
      };
    }
  });

  // ../../node_modules/core-js/modules/es.object.entries.js
  var require_es_object_entries = __commonJS({
    "../../node_modules/core-js/modules/es.object.entries.js"() {
      "use strict";
      var $ = require_export();
      var $entries = require_object_to_array().entries;
      $({ target: "Object", stat: true }, {
        entries: function entries(O) {
          return $entries(O);
        }
      });
    }
  });

  // ../../node_modules/core-js/es/object/entries.js
  var require_entries = __commonJS({
    "../../node_modules/core-js/es/object/entries.js"(exports, module3) {
      "use strict";
      require_es_object_entries();
      var path = require_path();
      module3.exports = path.Object.entries;
    }
  });

  // ../../node_modules/core-js/modules/es.string.includes.js
  var require_es_string_includes = __commonJS({
    "../../node_modules/core-js/modules/es.string.includes.js"() {
      "use strict";
      var $ = require_export();
      var uncurryThis = require_function_uncurry_this();
      var notARegExp = require_not_a_regexp();
      var requireObjectCoercible = require_require_object_coercible();
      var toString = require_to_string();
      var correctIsRegExpLogic = require_correct_is_regexp_logic();
      var stringIndexOf = uncurryThis("".indexOf);
      $({ target: "String", proto: true, forced: !correctIsRegExpLogic("includes") }, {
        includes: function includes(searchString) {
          return !!~stringIndexOf(
            toString(requireObjectCoercible(this)),
            toString(notARegExp(searchString)),
            arguments.length > 1 ? arguments[1] : void 0
          );
        }
      });
    }
  });

  // ../../node_modules/core-js/internals/get-built-in-prototype-method.js
  var require_get_built_in_prototype_method = __commonJS({
    "../../node_modules/core-js/internals/get-built-in-prototype-method.js"(exports, module3) {
      "use strict";
      var globalThis2 = require_global_this();
      module3.exports = function(CONSTRUCTOR, METHOD) {
        var Constructor = globalThis2[CONSTRUCTOR];
        var Prototype = Constructor && Constructor.prototype;
        return Prototype && Prototype[METHOD];
      };
    }
  });

  // ../../node_modules/core-js/es/string/virtual/includes.js
  var require_includes2 = __commonJS({
    "../../node_modules/core-js/es/string/virtual/includes.js"(exports, module3) {
      "use strict";
      require_es_string_includes();
      var getBuiltInPrototypeMethod = require_get_built_in_prototype_method();
      module3.exports = getBuiltInPrototypeMethod("String", "includes");
    }
  });

  // ../../node_modules/core-js/modules/es.reflect.delete-property.js
  var require_es_reflect_delete_property = __commonJS({
    "../../node_modules/core-js/modules/es.reflect.delete-property.js"() {
      "use strict";
      var $ = require_export();
      var anObject = require_an_object();
      var getOwnPropertyDescriptor = require_object_get_own_property_descriptor().f;
      $({ target: "Reflect", stat: true }, {
        deleteProperty: function deleteProperty(target, propertyKey) {
          var descriptor = getOwnPropertyDescriptor(anObject(target), propertyKey);
          return descriptor && !descriptor.configurable ? false : delete target[propertyKey];
        }
      });
    }
  });

  // ../../node_modules/core-js/es/reflect/delete-property.js
  var require_delete_property = __commonJS({
    "../../node_modules/core-js/es/reflect/delete-property.js"(exports, module3) {
      "use strict";
      require_es_reflect_delete_property();
      var path = require_path();
      module3.exports = path.Reflect.deleteProperty;
    }
  });

  // src/hotkeys.js
  var require_hotkeys = __commonJS({
    "src/hotkeys.js"(exports, module3) {
      (function(global4, factory) {
        typeof exports === "object" && typeof module3 !== "undefined" ? module3.exports = factory() : typeof define === "function" && define.amd ? define(factory) : (global4 = typeof globalThis !== "undefined" ? globalThis : global4 || self, function() {
          global4.hotkeys = factory();
        }());
      })(exports, function() {
        "use strict";
        const isff = typeof navigator !== "undefined" ? navigator.userAgent.toLowerCase().indexOf("firefox") > 0 : false;
        function addEvent(object, event, method, useCapture) {
          if (object.addEventListener) {
            object.addEventListener(event, method, useCapture);
          } else if (object.attachEvent) {
            object.attachEvent("on".concat(event), method);
          }
        }
        function removeEvent(object, event, method, useCapture) {
          if (object.removeEventListener) {
            object.removeEventListener(event, method, useCapture);
          } else if (object.detachEvent) {
            object.detachEvent("on".concat(event), method);
          }
        }
        function getMods(modifier, key) {
          const mods = key.slice(0, key.length - 1);
          for (let i = 0; i < mods.length; i++) mods[i] = modifier[mods[i].toLowerCase()];
          return mods;
        }
        function getKeys(key) {
          if (typeof key !== "string") key = "";
          key = key.replace(/\s/g, "");
          const keys = key.split(",");
          let index = keys.lastIndexOf("");
          for (; index >= 0; ) {
            keys[index - 1] += ",";
            keys.splice(index, 1);
            index = keys.lastIndexOf("");
          }
          return keys;
        }
        function compareArray(a1, a2) {
          const arr1 = a1.length >= a2.length ? a1 : a2;
          const arr2 = a1.length >= a2.length ? a2 : a1;
          let isIndex = true;
          for (let i = 0; i < arr1.length; i++) {
            if (arr2.indexOf(arr1[i]) === -1) isIndex = false;
          }
          return isIndex;
        }
        const _keyMap = {
          backspace: 8,
          "\u232B": 8,
          tab: 9,
          clear: 12,
          enter: 13,
          "\u21A9": 13,
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
          num_0: 96,
          num_1: 97,
          num_2: 98,
          num_3: 99,
          num_4: 100,
          num_5: 101,
          num_6: 102,
          num_7: 103,
          num_8: 104,
          num_9: 105,
          num_multiply: 106,
          num_add: 107,
          num_enter: 108,
          num_subtract: 109,
          num_decimal: 110,
          num_divide: 111,
          "\u21EA": 20,
          ",": 188,
          ".": 190,
          "/": 191,
          "`": 192,
          "-": isff ? 173 : 189,
          "=": isff ? 61 : 187,
          ";": isff ? 59 : 186,
          "'": 222,
          "[": 219,
          "]": 221,
          "\\": 220
        };
        const _modifier = {
          // shiftKey
          "\u21E7": 16,
          shift: 16,
          // altKey
          "\u2325": 18,
          alt: 18,
          option: 18,
          // ctrlKey
          "\u2303": 17,
          ctrl: 17,
          control: 17,
          // metaKey
          "\u2318": 91,
          cmd: 91,
          command: 91
        };
        const modifierMap = {
          16: "shiftKey",
          18: "altKey",
          17: "ctrlKey",
          91: "metaKey",
          shiftKey: 16,
          ctrlKey: 17,
          altKey: 18,
          metaKey: 91
        };
        const _mods = {
          16: false,
          18: false,
          17: false,
          91: false
        };
        const _handlers = {};
        for (let k = 1; k < 20; k++) {
          _keyMap["f".concat(k)] = 111 + k;
        }
        let _downKeys = [];
        let winListendFocus = null;
        let _scope = "all";
        const elementEventMap = /* @__PURE__ */ new Map();
        const code = (x2) => _keyMap[x2.toLowerCase()] || _modifier[x2.toLowerCase()] || x2.toUpperCase().charCodeAt(0);
        const getKey = (x2) => Object.keys(_keyMap).find((k) => _keyMap[k] === x2);
        const getModifier = (x2) => Object.keys(_modifier).find((k) => _modifier[k] === x2);
        function setScope(scope) {
          _scope = scope || "all";
        }
        function getScope() {
          return _scope || "all";
        }
        function getPressedKeyCodes() {
          return _downKeys.slice(0);
        }
        function getPressedKeyString() {
          return _downKeys.map((c2) => getKey(c2) || getModifier(c2) || String.fromCharCode(c2));
        }
        function getAllKeyCodes() {
          const result = [];
          Object.keys(_handlers).forEach((k) => {
            _handlers[k].forEach((_ref) => {
              let {
                key,
                scope,
                mods,
                shortcut
              } = _ref;
              result.push({
                scope,
                shortcut,
                mods,
                keys: key.split("+").map((v2) => code(v2))
              });
            });
          });
          return result;
        }
        function filter(event) {
          const target = event.target || event.srcElement;
          const {
            tagName
          } = target;
          let flag = true;
          const isInput = tagName === "INPUT" && !["checkbox", "radio", "range", "button", "file", "reset", "submit", "color"].includes(target.type);
          if (target.isContentEditable || (isInput || tagName === "TEXTAREA" || tagName === "SELECT") && !target.readOnly) {
            flag = false;
          }
          return flag;
        }
        function isPressed(keyCode) {
          if (typeof keyCode === "string") {
            keyCode = code(keyCode);
          }
          return _downKeys.indexOf(keyCode) !== -1;
        }
        function deleteScope(scope, newScope) {
          let handlers;
          let i;
          if (!scope) scope = getScope();
          for (const key in _handlers) {
            if (Object.prototype.hasOwnProperty.call(_handlers, key)) {
              handlers = _handlers[key];
              for (i = 0; i < handlers.length; ) {
                if (handlers[i].scope === scope) {
                  const deleteItems = handlers.splice(i, 1);
                  deleteItems.forEach((_ref2) => {
                    let {
                      element
                    } = _ref2;
                    return removeKeyEvent(element);
                  });
                } else {
                  i++;
                }
              }
            }
          }
          if (getScope() === scope) setScope(newScope || "all");
        }
        function clearModifier(event) {
          let key = event.keyCode || event.which || event.charCode;
          const i = _downKeys.indexOf(key);
          if (i >= 0) {
            _downKeys.splice(i, 1);
          }
          if (event.key && event.key.toLowerCase() === "meta") {
            _downKeys.splice(0, _downKeys.length);
          }
          if (key === 93 || key === 224) key = 91;
          if (key in _mods) {
            _mods[key] = false;
            for (const k in _modifier) if (_modifier[k] === key) hotkeys2[k] = false;
          }
        }
        function unbind(keysInfo) {
          if (typeof keysInfo === "undefined") {
            Object.keys(_handlers).forEach((key) => {
              Array.isArray(_handlers[key]) && _handlers[key].forEach((info) => eachUnbind(info));
              delete _handlers[key];
            });
            removeKeyEvent(null);
          } else if (Array.isArray(keysInfo)) {
            keysInfo.forEach((info) => {
              if (info.key) eachUnbind(info);
            });
          } else if (typeof keysInfo === "object") {
            if (keysInfo.key) eachUnbind(keysInfo);
          } else if (typeof keysInfo === "string") {
            for (var _len = arguments.length, args = new Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
              args[_key - 1] = arguments[_key];
            }
            let [scope, method] = args;
            if (typeof scope === "function") {
              method = scope;
              scope = "";
            }
            eachUnbind({
              key: keysInfo,
              scope,
              method,
              splitKey: "+"
            });
          }
        }
        const eachUnbind = (_ref3) => {
          let {
            key,
            scope,
            method,
            splitKey = "+"
          } = _ref3;
          const multipleKeys = getKeys(key);
          multipleKeys.forEach((originKey) => {
            const unbindKeys = originKey.split(splitKey);
            const len = unbindKeys.length;
            const lastKey = unbindKeys[len - 1];
            const keyCode = lastKey === "*" ? "*" : code(lastKey);
            if (!_handlers[keyCode]) return;
            if (!scope) scope = getScope();
            const mods = len > 1 ? getMods(_modifier, unbindKeys) : [];
            const unbindElements = [];
            _handlers[keyCode] = _handlers[keyCode].filter((record) => {
              const isMatchingMethod = method ? record.method === method : true;
              const isUnbind = isMatchingMethod && record.scope === scope && compareArray(record.mods, mods);
              if (isUnbind) unbindElements.push(record.element);
              return !isUnbind;
            });
            unbindElements.forEach((element) => removeKeyEvent(element));
          });
        };
        function eventHandler(event, handler, scope, element) {
          if (handler.element !== element) {
            return;
          }
          let modifiersMatch;
          if (handler.scope === scope || handler.scope === "all") {
            modifiersMatch = handler.mods.length > 0;
            for (const y in _mods) {
              if (Object.prototype.hasOwnProperty.call(_mods, y)) {
                if (!_mods[y] && handler.mods.indexOf(+y) > -1 || _mods[y] && handler.mods.indexOf(+y) === -1) {
                  modifiersMatch = false;
                }
              }
            }
            if (handler.mods.length === 0 && !_mods[16] && !_mods[18] && !_mods[17] && !_mods[91] || modifiersMatch || handler.shortcut === "*") {
              handler.keys = [];
              handler.keys = handler.keys.concat(_downKeys);
              if (handler.method(event, handler) === false) {
                if (event.preventDefault) event.preventDefault();
                else event.returnValue = false;
                if (event.stopPropagation) event.stopPropagation();
                if (event.cancelBubble) event.cancelBubble = true;
              }
            }
          }
        }
        function dispatch4(event, element) {
          const asterisk = _handlers["*"];
          let key = event.keyCode || event.which || event.charCode;
          if (!hotkeys2.filter.call(this, event)) return;
          if (key === 93 || key === 224) key = 91;
          if (_downKeys.indexOf(key) === -1 && key !== 229) _downKeys.push(key);
          ["ctrlKey", "altKey", "shiftKey", "metaKey"].forEach((keyName) => {
            const keyNum = modifierMap[keyName];
            if (event[keyName] && _downKeys.indexOf(keyNum) === -1) {
              _downKeys.push(keyNum);
            } else if (!event[keyName] && _downKeys.indexOf(keyNum) > -1) {
              _downKeys.splice(_downKeys.indexOf(keyNum), 1);
            } else if (keyName === "metaKey" && event[keyName] && _downKeys.length === 3) {
              if (!(event.ctrlKey || event.shiftKey || event.altKey)) {
                _downKeys = _downKeys.slice(_downKeys.indexOf(keyNum));
              }
            }
          });
          if (key in _mods) {
            _mods[key] = true;
            for (const k in _modifier) {
              if (_modifier[k] === key) hotkeys2[k] = true;
            }
            if (!asterisk) return;
          }
          for (const e in _mods) {
            if (Object.prototype.hasOwnProperty.call(_mods, e)) {
              _mods[e] = event[modifierMap[e]];
            }
          }
          if (event.getModifierState && !(event.altKey && !event.ctrlKey) && event.getModifierState("AltGraph")) {
            if (_downKeys.indexOf(17) === -1) {
              _downKeys.push(17);
            }
            if (_downKeys.indexOf(18) === -1) {
              _downKeys.push(18);
            }
            _mods[17] = true;
            _mods[18] = true;
          }
          const scope = getScope();
          if (asterisk) {
            for (let i = 0; i < asterisk.length; i++) {
              if (asterisk[i].scope === scope && (event.type === "keydown" && asterisk[i].keydown || event.type === "keyup" && asterisk[i].keyup)) {
                eventHandler(event, asterisk[i], scope, element);
              }
            }
          }
          if (!(key in _handlers)) return;
          const handlerKey = _handlers[key];
          const keyLen = handlerKey.length;
          for (let i = 0; i < keyLen; i++) {
            if (event.type === "keydown" && handlerKey[i].keydown || event.type === "keyup" && handlerKey[i].keyup) {
              if (handlerKey[i].key) {
                const record = handlerKey[i];
                const {
                  splitKey
                } = record;
                const keyShortcut = record.key.split(splitKey);
                const _downKeysCurrent = [];
                for (let a = 0; a < keyShortcut.length; a++) {
                  _downKeysCurrent.push(code(keyShortcut[a]));
                }
                if (_downKeysCurrent.sort().join("") === _downKeys.sort().join("")) {
                  eventHandler(event, record, scope, element);
                }
              }
            }
          }
        }
        function hotkeys2(key, option, method) {
          _downKeys = [];
          const keys = getKeys(key);
          let mods = [];
          let scope = "all";
          let element = document;
          let i = 0;
          let keyup = false;
          let keydown = true;
          let splitKey = "+";
          let capture = false;
          let single = false;
          if (method === void 0 && typeof option === "function") {
            method = option;
          }
          if (Object.prototype.toString.call(option) === "[object Object]") {
            if (option.scope) scope = option.scope;
            if (option.element) element = option.element;
            if (option.keyup) keyup = option.keyup;
            if (option.keydown !== void 0) keydown = option.keydown;
            if (option.capture !== void 0) capture = option.capture;
            if (typeof option.splitKey === "string") splitKey = option.splitKey;
            if (option.single === true) single = true;
          }
          if (typeof option === "string") scope = option;
          if (single) unbind(key, scope);
          for (; i < keys.length; i++) {
            key = keys[i].split(splitKey);
            mods = [];
            if (key.length > 1) mods = getMods(_modifier, key);
            key = key[key.length - 1];
            key = key === "*" ? "*" : code(key);
            if (!(key in _handlers)) _handlers[key] = [];
            _handlers[key].push({
              keyup,
              keydown,
              scope,
              mods,
              shortcut: keys[i],
              method,
              key: keys[i],
              splitKey,
              element
            });
          }
          if (typeof element !== "undefined" && window) {
            if (!elementEventMap.has(element)) {
              const keydownListener = function() {
                let event = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : window.event;
                return dispatch4(event, element);
              };
              const keyupListenr = function() {
                let event = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : window.event;
                dispatch4(event, element);
                clearModifier(event);
              };
              elementEventMap.set(element, {
                keydownListener,
                keyupListenr,
                capture
              });
              addEvent(element, "keydown", keydownListener, capture);
              addEvent(element, "keyup", keyupListenr, capture);
            }
            if (!winListendFocus) {
              const listener = () => {
                _downKeys = [];
              };
              winListendFocus = {
                listener,
                capture
              };
              addEvent(window, "focus", listener, capture);
            }
          }
        }
        function trigger(shortcut) {
          let scope = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : "all";
          Object.keys(_handlers).forEach((key) => {
            const dataList = _handlers[key].filter((item) => item.scope === scope && item.shortcut === shortcut);
            dataList.forEach((data) => {
              if (data && data.method) {
                data.method();
              }
            });
          });
        }
        function removeKeyEvent(element) {
          const values = Object.values(_handlers).flat();
          const findindex = values.findIndex((_ref4) => {
            let {
              element: el
            } = _ref4;
            return el === element;
          });
          if (findindex < 0) {
            const {
              keydownListener,
              keyupListenr,
              capture
            } = elementEventMap.get(element) || {};
            if (keydownListener && keyupListenr) {
              removeEvent(element, "keyup", keyupListenr, capture);
              removeEvent(element, "keydown", keydownListener, capture);
              elementEventMap.delete(element);
            }
          }
          if (values.length <= 0 || elementEventMap.size <= 0) {
            const eventKeys = Object.keys(elementEventMap);
            eventKeys.forEach((el) => {
              const {
                keydownListener,
                keyupListenr,
                capture
              } = elementEventMap.get(el) || {};
              if (keydownListener && keyupListenr) {
                removeEvent(el, "keyup", keyupListenr, capture);
                removeEvent(el, "keydown", keydownListener, capture);
                elementEventMap.delete(el);
              }
            });
            elementEventMap.clear();
            Object.keys(_handlers).forEach((key) => delete _handlers[key]);
            if (winListendFocus) {
              const {
                listener,
                capture
              } = winListendFocus;
              removeEvent(window, "focus", listener, capture);
              winListendFocus = null;
            }
          }
        }
        const _api = {
          getPressedKeyString,
          setScope,
          getScope,
          deleteScope,
          getPressedKeyCodes,
          getAllKeyCodes,
          isPressed,
          filter,
          trigger,
          unbind,
          keyMap: _keyMap,
          modifier: _modifier,
          modifierMap
        };
        for (const a in _api) {
          if (Object.prototype.hasOwnProperty.call(_api, a)) {
            hotkeys2[a] = _api[a];
          }
        }
        if (typeof window !== "undefined") {
          const _hotkeys = window.hotkeys;
          hotkeys2.noConflict = (deep) => {
            if (deep && window.hotkeys === hotkeys2) {
              window.hotkeys = _hotkeys;
            }
            return hotkeys2;
          };
          window.hotkeys = hotkeys2;
        }
        return hotkeys2;
      });
    }
  });

  // ../../node_modules/@rails/activestorage/app/assets/javascripts/activestorage.js
  var require_activestorage = __commonJS({
    "../../node_modules/@rails/activestorage/app/assets/javascripts/activestorage.js"(exports, module3) {
      (function(global4, factory) {
        typeof exports === "object" && typeof module3 !== "undefined" ? factory(exports) : typeof define === "function" && define.amd ? define(["exports"], factory) : (global4 = typeof globalThis !== "undefined" ? globalThis : global4 || self, factory(global4.ActiveStorage = {}));
      })(exports, function(exports2) {
        "use strict";
        var sparkMd5 = {
          exports: {}
        };
        (function(module4, exports3) {
          (function(factory) {
            {
              module4.exports = factory();
            }
          })(function(undefined$1) {
            var hex_chr = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"];
            function md5cycle(x2, k) {
              var a = x2[0], b2 = x2[1], c2 = x2[2], d2 = x2[3];
              a += (b2 & c2 | ~b2 & d2) + k[0] - 680876936 | 0;
              a = (a << 7 | a >>> 25) + b2 | 0;
              d2 += (a & b2 | ~a & c2) + k[1] - 389564586 | 0;
              d2 = (d2 << 12 | d2 >>> 20) + a | 0;
              c2 += (d2 & a | ~d2 & b2) + k[2] + 606105819 | 0;
              c2 = (c2 << 17 | c2 >>> 15) + d2 | 0;
              b2 += (c2 & d2 | ~c2 & a) + k[3] - 1044525330 | 0;
              b2 = (b2 << 22 | b2 >>> 10) + c2 | 0;
              a += (b2 & c2 | ~b2 & d2) + k[4] - 176418897 | 0;
              a = (a << 7 | a >>> 25) + b2 | 0;
              d2 += (a & b2 | ~a & c2) + k[5] + 1200080426 | 0;
              d2 = (d2 << 12 | d2 >>> 20) + a | 0;
              c2 += (d2 & a | ~d2 & b2) + k[6] - 1473231341 | 0;
              c2 = (c2 << 17 | c2 >>> 15) + d2 | 0;
              b2 += (c2 & d2 | ~c2 & a) + k[7] - 45705983 | 0;
              b2 = (b2 << 22 | b2 >>> 10) + c2 | 0;
              a += (b2 & c2 | ~b2 & d2) + k[8] + 1770035416 | 0;
              a = (a << 7 | a >>> 25) + b2 | 0;
              d2 += (a & b2 | ~a & c2) + k[9] - 1958414417 | 0;
              d2 = (d2 << 12 | d2 >>> 20) + a | 0;
              c2 += (d2 & a | ~d2 & b2) + k[10] - 42063 | 0;
              c2 = (c2 << 17 | c2 >>> 15) + d2 | 0;
              b2 += (c2 & d2 | ~c2 & a) + k[11] - 1990404162 | 0;
              b2 = (b2 << 22 | b2 >>> 10) + c2 | 0;
              a += (b2 & c2 | ~b2 & d2) + k[12] + 1804603682 | 0;
              a = (a << 7 | a >>> 25) + b2 | 0;
              d2 += (a & b2 | ~a & c2) + k[13] - 40341101 | 0;
              d2 = (d2 << 12 | d2 >>> 20) + a | 0;
              c2 += (d2 & a | ~d2 & b2) + k[14] - 1502002290 | 0;
              c2 = (c2 << 17 | c2 >>> 15) + d2 | 0;
              b2 += (c2 & d2 | ~c2 & a) + k[15] + 1236535329 | 0;
              b2 = (b2 << 22 | b2 >>> 10) + c2 | 0;
              a += (b2 & d2 | c2 & ~d2) + k[1] - 165796510 | 0;
              a = (a << 5 | a >>> 27) + b2 | 0;
              d2 += (a & c2 | b2 & ~c2) + k[6] - 1069501632 | 0;
              d2 = (d2 << 9 | d2 >>> 23) + a | 0;
              c2 += (d2 & b2 | a & ~b2) + k[11] + 643717713 | 0;
              c2 = (c2 << 14 | c2 >>> 18) + d2 | 0;
              b2 += (c2 & a | d2 & ~a) + k[0] - 373897302 | 0;
              b2 = (b2 << 20 | b2 >>> 12) + c2 | 0;
              a += (b2 & d2 | c2 & ~d2) + k[5] - 701558691 | 0;
              a = (a << 5 | a >>> 27) + b2 | 0;
              d2 += (a & c2 | b2 & ~c2) + k[10] + 38016083 | 0;
              d2 = (d2 << 9 | d2 >>> 23) + a | 0;
              c2 += (d2 & b2 | a & ~b2) + k[15] - 660478335 | 0;
              c2 = (c2 << 14 | c2 >>> 18) + d2 | 0;
              b2 += (c2 & a | d2 & ~a) + k[4] - 405537848 | 0;
              b2 = (b2 << 20 | b2 >>> 12) + c2 | 0;
              a += (b2 & d2 | c2 & ~d2) + k[9] + 568446438 | 0;
              a = (a << 5 | a >>> 27) + b2 | 0;
              d2 += (a & c2 | b2 & ~c2) + k[14] - 1019803690 | 0;
              d2 = (d2 << 9 | d2 >>> 23) + a | 0;
              c2 += (d2 & b2 | a & ~b2) + k[3] - 187363961 | 0;
              c2 = (c2 << 14 | c2 >>> 18) + d2 | 0;
              b2 += (c2 & a | d2 & ~a) + k[8] + 1163531501 | 0;
              b2 = (b2 << 20 | b2 >>> 12) + c2 | 0;
              a += (b2 & d2 | c2 & ~d2) + k[13] - 1444681467 | 0;
              a = (a << 5 | a >>> 27) + b2 | 0;
              d2 += (a & c2 | b2 & ~c2) + k[2] - 51403784 | 0;
              d2 = (d2 << 9 | d2 >>> 23) + a | 0;
              c2 += (d2 & b2 | a & ~b2) + k[7] + 1735328473 | 0;
              c2 = (c2 << 14 | c2 >>> 18) + d2 | 0;
              b2 += (c2 & a | d2 & ~a) + k[12] - 1926607734 | 0;
              b2 = (b2 << 20 | b2 >>> 12) + c2 | 0;
              a += (b2 ^ c2 ^ d2) + k[5] - 378558 | 0;
              a = (a << 4 | a >>> 28) + b2 | 0;
              d2 += (a ^ b2 ^ c2) + k[8] - 2022574463 | 0;
              d2 = (d2 << 11 | d2 >>> 21) + a | 0;
              c2 += (d2 ^ a ^ b2) + k[11] + 1839030562 | 0;
              c2 = (c2 << 16 | c2 >>> 16) + d2 | 0;
              b2 += (c2 ^ d2 ^ a) + k[14] - 35309556 | 0;
              b2 = (b2 << 23 | b2 >>> 9) + c2 | 0;
              a += (b2 ^ c2 ^ d2) + k[1] - 1530992060 | 0;
              a = (a << 4 | a >>> 28) + b2 | 0;
              d2 += (a ^ b2 ^ c2) + k[4] + 1272893353 | 0;
              d2 = (d2 << 11 | d2 >>> 21) + a | 0;
              c2 += (d2 ^ a ^ b2) + k[7] - 155497632 | 0;
              c2 = (c2 << 16 | c2 >>> 16) + d2 | 0;
              b2 += (c2 ^ d2 ^ a) + k[10] - 1094730640 | 0;
              b2 = (b2 << 23 | b2 >>> 9) + c2 | 0;
              a += (b2 ^ c2 ^ d2) + k[13] + 681279174 | 0;
              a = (a << 4 | a >>> 28) + b2 | 0;
              d2 += (a ^ b2 ^ c2) + k[0] - 358537222 | 0;
              d2 = (d2 << 11 | d2 >>> 21) + a | 0;
              c2 += (d2 ^ a ^ b2) + k[3] - 722521979 | 0;
              c2 = (c2 << 16 | c2 >>> 16) + d2 | 0;
              b2 += (c2 ^ d2 ^ a) + k[6] + 76029189 | 0;
              b2 = (b2 << 23 | b2 >>> 9) + c2 | 0;
              a += (b2 ^ c2 ^ d2) + k[9] - 640364487 | 0;
              a = (a << 4 | a >>> 28) + b2 | 0;
              d2 += (a ^ b2 ^ c2) + k[12] - 421815835 | 0;
              d2 = (d2 << 11 | d2 >>> 21) + a | 0;
              c2 += (d2 ^ a ^ b2) + k[15] + 530742520 | 0;
              c2 = (c2 << 16 | c2 >>> 16) + d2 | 0;
              b2 += (c2 ^ d2 ^ a) + k[2] - 995338651 | 0;
              b2 = (b2 << 23 | b2 >>> 9) + c2 | 0;
              a += (c2 ^ (b2 | ~d2)) + k[0] - 198630844 | 0;
              a = (a << 6 | a >>> 26) + b2 | 0;
              d2 += (b2 ^ (a | ~c2)) + k[7] + 1126891415 | 0;
              d2 = (d2 << 10 | d2 >>> 22) + a | 0;
              c2 += (a ^ (d2 | ~b2)) + k[14] - 1416354905 | 0;
              c2 = (c2 << 15 | c2 >>> 17) + d2 | 0;
              b2 += (d2 ^ (c2 | ~a)) + k[5] - 57434055 | 0;
              b2 = (b2 << 21 | b2 >>> 11) + c2 | 0;
              a += (c2 ^ (b2 | ~d2)) + k[12] + 1700485571 | 0;
              a = (a << 6 | a >>> 26) + b2 | 0;
              d2 += (b2 ^ (a | ~c2)) + k[3] - 1894986606 | 0;
              d2 = (d2 << 10 | d2 >>> 22) + a | 0;
              c2 += (a ^ (d2 | ~b2)) + k[10] - 1051523 | 0;
              c2 = (c2 << 15 | c2 >>> 17) + d2 | 0;
              b2 += (d2 ^ (c2 | ~a)) + k[1] - 2054922799 | 0;
              b2 = (b2 << 21 | b2 >>> 11) + c2 | 0;
              a += (c2 ^ (b2 | ~d2)) + k[8] + 1873313359 | 0;
              a = (a << 6 | a >>> 26) + b2 | 0;
              d2 += (b2 ^ (a | ~c2)) + k[15] - 30611744 | 0;
              d2 = (d2 << 10 | d2 >>> 22) + a | 0;
              c2 += (a ^ (d2 | ~b2)) + k[6] - 1560198380 | 0;
              c2 = (c2 << 15 | c2 >>> 17) + d2 | 0;
              b2 += (d2 ^ (c2 | ~a)) + k[13] + 1309151649 | 0;
              b2 = (b2 << 21 | b2 >>> 11) + c2 | 0;
              a += (c2 ^ (b2 | ~d2)) + k[4] - 145523070 | 0;
              a = (a << 6 | a >>> 26) + b2 | 0;
              d2 += (b2 ^ (a | ~c2)) + k[11] - 1120210379 | 0;
              d2 = (d2 << 10 | d2 >>> 22) + a | 0;
              c2 += (a ^ (d2 | ~b2)) + k[2] + 718787259 | 0;
              c2 = (c2 << 15 | c2 >>> 17) + d2 | 0;
              b2 += (d2 ^ (c2 | ~a)) + k[9] - 343485551 | 0;
              b2 = (b2 << 21 | b2 >>> 11) + c2 | 0;
              x2[0] = a + x2[0] | 0;
              x2[1] = b2 + x2[1] | 0;
              x2[2] = c2 + x2[2] | 0;
              x2[3] = d2 + x2[3] | 0;
            }
            function md5blk(s2) {
              var md5blks = [], i;
              for (i = 0; i < 64; i += 4) {
                md5blks[i >> 2] = s2.charCodeAt(i) + (s2.charCodeAt(i + 1) << 8) + (s2.charCodeAt(i + 2) << 16) + (s2.charCodeAt(i + 3) << 24);
              }
              return md5blks;
            }
            function md5blk_array(a) {
              var md5blks = [], i;
              for (i = 0; i < 64; i += 4) {
                md5blks[i >> 2] = a[i] + (a[i + 1] << 8) + (a[i + 2] << 16) + (a[i + 3] << 24);
              }
              return md5blks;
            }
            function md51(s2) {
              var n2 = s2.length, state = [1732584193, -271733879, -1732584194, 271733878], i, length, tail, tmp, lo, hi;
              for (i = 64; i <= n2; i += 64) {
                md5cycle(state, md5blk(s2.substring(i - 64, i)));
              }
              s2 = s2.substring(i - 64);
              length = s2.length;
              tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
              for (i = 0; i < length; i += 1) {
                tail[i >> 2] |= s2.charCodeAt(i) << (i % 4 << 3);
              }
              tail[i >> 2] |= 128 << (i % 4 << 3);
              if (i > 55) {
                md5cycle(state, tail);
                for (i = 0; i < 16; i += 1) {
                  tail[i] = 0;
                }
              }
              tmp = n2 * 8;
              tmp = tmp.toString(16).match(/(.*?)(.{0,8})$/);
              lo = parseInt(tmp[2], 16);
              hi = parseInt(tmp[1], 16) || 0;
              tail[14] = lo;
              tail[15] = hi;
              md5cycle(state, tail);
              return state;
            }
            function md51_array(a) {
              var n2 = a.length, state = [1732584193, -271733879, -1732584194, 271733878], i, length, tail, tmp, lo, hi;
              for (i = 64; i <= n2; i += 64) {
                md5cycle(state, md5blk_array(a.subarray(i - 64, i)));
              }
              a = i - 64 < n2 ? a.subarray(i - 64) : new Uint8Array(0);
              length = a.length;
              tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
              for (i = 0; i < length; i += 1) {
                tail[i >> 2] |= a[i] << (i % 4 << 3);
              }
              tail[i >> 2] |= 128 << (i % 4 << 3);
              if (i > 55) {
                md5cycle(state, tail);
                for (i = 0; i < 16; i += 1) {
                  tail[i] = 0;
                }
              }
              tmp = n2 * 8;
              tmp = tmp.toString(16).match(/(.*?)(.{0,8})$/);
              lo = parseInt(tmp[2], 16);
              hi = parseInt(tmp[1], 16) || 0;
              tail[14] = lo;
              tail[15] = hi;
              md5cycle(state, tail);
              return state;
            }
            function rhex(n2) {
              var s2 = "", j;
              for (j = 0; j < 4; j += 1) {
                s2 += hex_chr[n2 >> j * 8 + 4 & 15] + hex_chr[n2 >> j * 8 & 15];
              }
              return s2;
            }
            function hex(x2) {
              var i;
              for (i = 0; i < x2.length; i += 1) {
                x2[i] = rhex(x2[i]);
              }
              return x2.join("");
            }
            if (hex(md51("hello")) !== "5d41402abc4b2a76b9719d911017c592") ;
            if (typeof ArrayBuffer !== "undefined" && !ArrayBuffer.prototype.slice) {
              (function() {
                function clamp(val, length) {
                  val = val | 0 || 0;
                  if (val < 0) {
                    return Math.max(val + length, 0);
                  }
                  return Math.min(val, length);
                }
                ArrayBuffer.prototype.slice = function(from, to) {
                  var length = this.byteLength, begin = clamp(from, length), end2 = length, num, target, targetArray, sourceArray;
                  if (to !== undefined$1) {
                    end2 = clamp(to, length);
                  }
                  if (begin > end2) {
                    return new ArrayBuffer(0);
                  }
                  num = end2 - begin;
                  target = new ArrayBuffer(num);
                  targetArray = new Uint8Array(target);
                  sourceArray = new Uint8Array(this, begin, num);
                  targetArray.set(sourceArray);
                  return target;
                };
              })();
            }
            function toUtf8(str) {
              if (/[\u0080-\uFFFF]/.test(str)) {
                str = unescape(encodeURIComponent(str));
              }
              return str;
            }
            function utf8Str2ArrayBuffer(str, returnUInt8Array) {
              var length = str.length, buff = new ArrayBuffer(length), arr = new Uint8Array(buff), i;
              for (i = 0; i < length; i += 1) {
                arr[i] = str.charCodeAt(i);
              }
              return returnUInt8Array ? arr : buff;
            }
            function arrayBuffer2Utf8Str(buff) {
              return String.fromCharCode.apply(null, new Uint8Array(buff));
            }
            function concatenateArrayBuffers(first, second, returnUInt8Array) {
              var result = new Uint8Array(first.byteLength + second.byteLength);
              result.set(new Uint8Array(first));
              result.set(new Uint8Array(second), first.byteLength);
              return returnUInt8Array ? result : result.buffer;
            }
            function hexToBinaryString(hex2) {
              var bytes = [], length = hex2.length, x2;
              for (x2 = 0; x2 < length - 1; x2 += 2) {
                bytes.push(parseInt(hex2.substr(x2, 2), 16));
              }
              return String.fromCharCode.apply(String, bytes);
            }
            function SparkMD52() {
              this.reset();
            }
            SparkMD52.prototype.append = function(str) {
              this.appendBinary(toUtf8(str));
              return this;
            };
            SparkMD52.prototype.appendBinary = function(contents) {
              this._buff += contents;
              this._length += contents.length;
              var length = this._buff.length, i;
              for (i = 64; i <= length; i += 64) {
                md5cycle(this._hash, md5blk(this._buff.substring(i - 64, i)));
              }
              this._buff = this._buff.substring(i - 64);
              return this;
            };
            SparkMD52.prototype.end = function(raw) {
              var buff = this._buff, length = buff.length, i, tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], ret;
              for (i = 0; i < length; i += 1) {
                tail[i >> 2] |= buff.charCodeAt(i) << (i % 4 << 3);
              }
              this._finish(tail, length);
              ret = hex(this._hash);
              if (raw) {
                ret = hexToBinaryString(ret);
              }
              this.reset();
              return ret;
            };
            SparkMD52.prototype.reset = function() {
              this._buff = "";
              this._length = 0;
              this._hash = [1732584193, -271733879, -1732584194, 271733878];
              return this;
            };
            SparkMD52.prototype.getState = function() {
              return {
                buff: this._buff,
                length: this._length,
                hash: this._hash.slice()
              };
            };
            SparkMD52.prototype.setState = function(state) {
              this._buff = state.buff;
              this._length = state.length;
              this._hash = state.hash;
              return this;
            };
            SparkMD52.prototype.destroy = function() {
              delete this._hash;
              delete this._buff;
              delete this._length;
            };
            SparkMD52.prototype._finish = function(tail, length) {
              var i = length, tmp, lo, hi;
              tail[i >> 2] |= 128 << (i % 4 << 3);
              if (i > 55) {
                md5cycle(this._hash, tail);
                for (i = 0; i < 16; i += 1) {
                  tail[i] = 0;
                }
              }
              tmp = this._length * 8;
              tmp = tmp.toString(16).match(/(.*?)(.{0,8})$/);
              lo = parseInt(tmp[2], 16);
              hi = parseInt(tmp[1], 16) || 0;
              tail[14] = lo;
              tail[15] = hi;
              md5cycle(this._hash, tail);
            };
            SparkMD52.hash = function(str, raw) {
              return SparkMD52.hashBinary(toUtf8(str), raw);
            };
            SparkMD52.hashBinary = function(content, raw) {
              var hash3 = md51(content), ret = hex(hash3);
              return raw ? hexToBinaryString(ret) : ret;
            };
            SparkMD52.ArrayBuffer = function() {
              this.reset();
            };
            SparkMD52.ArrayBuffer.prototype.append = function(arr) {
              var buff = concatenateArrayBuffers(this._buff.buffer, arr, true), length = buff.length, i;
              this._length += arr.byteLength;
              for (i = 64; i <= length; i += 64) {
                md5cycle(this._hash, md5blk_array(buff.subarray(i - 64, i)));
              }
              this._buff = i - 64 < length ? new Uint8Array(buff.buffer.slice(i - 64)) : new Uint8Array(0);
              return this;
            };
            SparkMD52.ArrayBuffer.prototype.end = function(raw) {
              var buff = this._buff, length = buff.length, tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], i, ret;
              for (i = 0; i < length; i += 1) {
                tail[i >> 2] |= buff[i] << (i % 4 << 3);
              }
              this._finish(tail, length);
              ret = hex(this._hash);
              if (raw) {
                ret = hexToBinaryString(ret);
              }
              this.reset();
              return ret;
            };
            SparkMD52.ArrayBuffer.prototype.reset = function() {
              this._buff = new Uint8Array(0);
              this._length = 0;
              this._hash = [1732584193, -271733879, -1732584194, 271733878];
              return this;
            };
            SparkMD52.ArrayBuffer.prototype.getState = function() {
              var state = SparkMD52.prototype.getState.call(this);
              state.buff = arrayBuffer2Utf8Str(state.buff);
              return state;
            };
            SparkMD52.ArrayBuffer.prototype.setState = function(state) {
              state.buff = utf8Str2ArrayBuffer(state.buff, true);
              return SparkMD52.prototype.setState.call(this, state);
            };
            SparkMD52.ArrayBuffer.prototype.destroy = SparkMD52.prototype.destroy;
            SparkMD52.ArrayBuffer.prototype._finish = SparkMD52.prototype._finish;
            SparkMD52.ArrayBuffer.hash = function(arr, raw) {
              var hash3 = md51_array(new Uint8Array(arr)), ret = hex(hash3);
              return raw ? hexToBinaryString(ret) : ret;
            };
            return SparkMD52;
          });
        })(sparkMd5);
        var SparkMD5 = sparkMd5.exports;
        const fileSlice = File.prototype.slice || File.prototype.mozSlice || File.prototype.webkitSlice;
        class FileChecksum {
          static create(file, callback) {
            const instance = new FileChecksum(file);
            instance.create(callback);
          }
          constructor(file) {
            this.file = file;
            this.chunkSize = 2097152;
            this.chunkCount = Math.ceil(this.file.size / this.chunkSize);
            this.chunkIndex = 0;
          }
          create(callback) {
            this.callback = callback;
            this.md5Buffer = new SparkMD5.ArrayBuffer();
            this.fileReader = new FileReader();
            this.fileReader.addEventListener("load", (event) => this.fileReaderDidLoad(event));
            this.fileReader.addEventListener("error", (event) => this.fileReaderDidError(event));
            this.readNextChunk();
          }
          fileReaderDidLoad(event) {
            this.md5Buffer.append(event.target.result);
            if (!this.readNextChunk()) {
              const binaryDigest = this.md5Buffer.end(true);
              const base64digest = btoa(binaryDigest);
              this.callback(null, base64digest);
            }
          }
          fileReaderDidError(event) {
            this.callback(`Error reading ${this.file.name}`);
          }
          readNextChunk() {
            if (this.chunkIndex < this.chunkCount || this.chunkIndex == 0 && this.chunkCount == 0) {
              const start4 = this.chunkIndex * this.chunkSize;
              const end2 = Math.min(start4 + this.chunkSize, this.file.size);
              const bytes = fileSlice.call(this.file, start4, end2);
              this.fileReader.readAsArrayBuffer(bytes);
              this.chunkIndex++;
              return true;
            } else {
              return false;
            }
          }
        }
        function getMetaValue(name3) {
          const element = findElement(document.head, `meta[name="${name3}"]`);
          if (element) {
            return element.getAttribute("content");
          }
        }
        function findElements(root, selector) {
          if (typeof root == "string") {
            selector = root;
            root = document;
          }
          const elements = root.querySelectorAll(selector);
          return toArray(elements);
        }
        function findElement(root, selector) {
          if (typeof root == "string") {
            selector = root;
            root = document;
          }
          return root.querySelector(selector);
        }
        function dispatchEvent2(element, type, eventInit = {}) {
          const { disabled } = element;
          const { bubbles, cancelable, detail } = eventInit;
          const event = document.createEvent("Event");
          event.initEvent(type, bubbles || true, cancelable || true);
          event.detail = detail || {};
          try {
            element.disabled = false;
            element.dispatchEvent(event);
          } finally {
            element.disabled = disabled;
          }
          return event;
        }
        function toArray(value) {
          if (Array.isArray(value)) {
            return value;
          } else if (Array.from) {
            return Array.from(value);
          } else {
            return [].slice.call(value);
          }
        }
        class BlobRecord {
          constructor(file, checksum, url, customHeaders = {}) {
            this.file = file;
            this.attributes = {
              filename: file.name,
              content_type: file.type || "application/octet-stream",
              byte_size: file.size,
              checksum
            };
            this.xhr = new XMLHttpRequest();
            this.xhr.open("POST", url, true);
            this.xhr.responseType = "json";
            this.xhr.setRequestHeader("Content-Type", "application/json");
            this.xhr.setRequestHeader("Accept", "application/json");
            this.xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest");
            Object.keys(customHeaders).forEach((headerKey) => {
              this.xhr.setRequestHeader(headerKey, customHeaders[headerKey]);
            });
            const csrfToken = getMetaValue("csrf-token");
            if (csrfToken != void 0) {
              this.xhr.setRequestHeader("X-CSRF-Token", csrfToken);
            }
            this.xhr.addEventListener("load", (event) => this.requestDidLoad(event));
            this.xhr.addEventListener("error", (event) => this.requestDidError(event));
          }
          get status() {
            return this.xhr.status;
          }
          get response() {
            const { responseType, response: response2 } = this.xhr;
            if (responseType == "json") {
              return response2;
            } else {
              return JSON.parse(response2);
            }
          }
          create(callback) {
            this.callback = callback;
            this.xhr.send(JSON.stringify({
              blob: this.attributes
            }));
          }
          requestDidLoad(event) {
            if (this.status >= 200 && this.status < 300) {
              const { response: response2 } = this;
              const { direct_upload } = response2;
              delete response2.direct_upload;
              this.attributes = response2;
              this.directUploadData = direct_upload;
              this.callback(null, this.toJSON());
            } else {
              this.requestDidError(event);
            }
          }
          requestDidError(event) {
            this.callback(`Error creating Blob for "${this.file.name}". Status: ${this.status}`);
          }
          toJSON() {
            const result = {};
            for (const key in this.attributes) {
              result[key] = this.attributes[key];
            }
            return result;
          }
        }
        class BlobUpload {
          constructor(blob) {
            this.blob = blob;
            this.file = blob.file;
            const { url, headers } = blob.directUploadData;
            this.xhr = new XMLHttpRequest();
            this.xhr.open("PUT", url, true);
            this.xhr.responseType = "text";
            for (const key in headers) {
              this.xhr.setRequestHeader(key, headers[key]);
            }
            this.xhr.addEventListener("load", (event) => this.requestDidLoad(event));
            this.xhr.addEventListener("error", (event) => this.requestDidError(event));
          }
          create(callback) {
            this.callback = callback;
            this.xhr.send(this.file.slice());
          }
          requestDidLoad(event) {
            const { status, response: response2 } = this.xhr;
            if (status >= 200 && status < 300) {
              this.callback(null, response2);
            } else {
              this.requestDidError(event);
            }
          }
          requestDidError(event) {
            this.callback(`Error storing "${this.file.name}". Status: ${this.xhr.status}`);
          }
        }
        let id = 0;
        class DirectUpload {
          constructor(file, url, delegate, customHeaders = {}) {
            this.id = ++id;
            this.file = file;
            this.url = url;
            this.delegate = delegate;
            this.customHeaders = customHeaders;
          }
          create(callback) {
            FileChecksum.create(this.file, (error3, checksum) => {
              if (error3) {
                callback(error3);
                return;
              }
              const blob = new BlobRecord(this.file, checksum, this.url, this.customHeaders);
              notify(this.delegate, "directUploadWillCreateBlobWithXHR", blob.xhr);
              blob.create((error4) => {
                if (error4) {
                  callback(error4);
                } else {
                  const upload = new BlobUpload(blob);
                  notify(this.delegate, "directUploadWillStoreFileWithXHR", upload.xhr);
                  upload.create((error5) => {
                    if (error5) {
                      callback(error5);
                    } else {
                      callback(null, blob.toJSON());
                    }
                  });
                }
              });
            });
          }
        }
        function notify(object, methodName, ...messages) {
          if (object && typeof object[methodName] == "function") {
            return object[methodName](...messages);
          }
        }
        class DirectUploadController {
          constructor(input, file) {
            this.input = input;
            this.file = file;
            this.directUpload = new DirectUpload(this.file, this.url, this);
            this.dispatch("initialize");
          }
          start(callback) {
            const hiddenInput = document.createElement("input");
            hiddenInput.type = "hidden";
            hiddenInput.name = this.input.name;
            this.input.insertAdjacentElement("beforebegin", hiddenInput);
            this.dispatch("start");
            this.directUpload.create((error3, attributes) => {
              if (error3) {
                hiddenInput.parentNode.removeChild(hiddenInput);
                this.dispatchError(error3);
              } else {
                hiddenInput.value = attributes.signed_id;
              }
              this.dispatch("end");
              callback(error3);
            });
          }
          uploadRequestDidProgress(event) {
            const progress2 = event.loaded / event.total * 100;
            if (progress2) {
              this.dispatch("progress", {
                progress: progress2
              });
            }
          }
          get url() {
            return this.input.getAttribute("data-direct-upload-url");
          }
          dispatch(name3, detail = {}) {
            detail.file = this.file;
            detail.id = this.directUpload.id;
            return dispatchEvent2(this.input, `direct-upload:${name3}`, {
              detail
            });
          }
          dispatchError(error3) {
            const event = this.dispatch("error", {
              error: error3
            });
            if (!event.defaultPrevented) {
              alert(error3);
            }
          }
          directUploadWillCreateBlobWithXHR(xhr) {
            this.dispatch("before-blob-request", {
              xhr
            });
          }
          directUploadWillStoreFileWithXHR(xhr) {
            this.dispatch("before-storage-request", {
              xhr
            });
            xhr.upload.addEventListener("progress", (event) => this.uploadRequestDidProgress(event));
          }
        }
        const inputSelector = "input[type=file][data-direct-upload-url]:not([disabled])";
        class DirectUploadsController {
          constructor(form) {
            this.form = form;
            this.inputs = findElements(form, inputSelector).filter((input) => input.files.length);
          }
          start(callback) {
            const controllers = this.createDirectUploadControllers();
            const startNextController = () => {
              const controller = controllers.shift();
              if (controller) {
                controller.start((error3) => {
                  if (error3) {
                    callback(error3);
                    this.dispatch("end");
                  } else {
                    startNextController();
                  }
                });
              } else {
                callback();
                this.dispatch("end");
              }
            };
            this.dispatch("start");
            startNextController();
          }
          createDirectUploadControllers() {
            const controllers = [];
            this.inputs.forEach((input) => {
              toArray(input.files).forEach((file) => {
                const controller = new DirectUploadController(input, file);
                controllers.push(controller);
              });
            });
            return controllers;
          }
          dispatch(name3, detail = {}) {
            return dispatchEvent2(this.form, `direct-uploads:${name3}`, {
              detail
            });
          }
        }
        const processingAttribute = "data-direct-uploads-processing";
        const submitButtonsByForm = /* @__PURE__ */ new WeakMap();
        let started = false;
        function start3() {
          if (!started) {
            started = true;
            document.addEventListener("click", didClick, true);
            document.addEventListener("submit", didSubmitForm, true);
            document.addEventListener("ajax:before", didSubmitRemoteElement);
          }
        }
        function didClick(event) {
          const button = event.target.closest("button, input");
          if (button && button.type === "submit" && button.form) {
            submitButtonsByForm.set(button.form, button);
          }
        }
        function didSubmitForm(event) {
          handleFormSubmissionEvent(event);
        }
        function didSubmitRemoteElement(event) {
          if (event.target.tagName == "FORM") {
            handleFormSubmissionEvent(event);
          }
        }
        function handleFormSubmissionEvent(event) {
          const form = event.target;
          if (form.hasAttribute(processingAttribute)) {
            event.preventDefault();
            return;
          }
          const controller = new DirectUploadsController(form);
          const { inputs } = controller;
          if (inputs.length) {
            event.preventDefault();
            form.setAttribute(processingAttribute, "");
            inputs.forEach(disable);
            controller.start((error3) => {
              form.removeAttribute(processingAttribute);
              if (error3) {
                inputs.forEach(enable);
              } else {
                submitForm(form);
              }
            });
          }
        }
        function submitForm(form) {
          let button = submitButtonsByForm.get(form) || findElement(form, "input[type=submit], button[type=submit]");
          if (button) {
            const { disabled } = button;
            button.disabled = false;
            button.focus();
            button.click();
            button.disabled = disabled;
          } else {
            button = document.createElement("input");
            button.type = "submit";
            button.style.display = "none";
            form.appendChild(button);
            button.click();
            form.removeChild(button);
          }
          submitButtonsByForm.delete(form);
        }
        function disable(input) {
          input.disabled = true;
        }
        function enable(input) {
          input.disabled = false;
        }
        function autostart() {
          if (window.ActiveStorage) {
            start3();
          }
        }
        setTimeout(autostart, 1);
        exports2.DirectUpload = DirectUpload;
        exports2.DirectUploadController = DirectUploadController;
        exports2.DirectUploadsController = DirectUploadsController;
        exports2.dispatchEvent = dispatchEvent2;
        exports2.start = start3;
        Object.defineProperty(exports2, "__esModule", {
          value: true
        });
      });
    }
  });

  // ../../node_modules/local-time/app/assets/javascripts/local-time.es2017-umd.js
  var require_local_time_es2017_umd = __commonJS({
    "../../node_modules/local-time/app/assets/javascripts/local-time.es2017-umd.js"(exports, module3) {
      !function(e, t) {
        "object" == typeof exports && "undefined" != typeof module3 ? module3.exports = t() : "function" == typeof define && define.amd ? define(t) : (e = "undefined" != typeof globalThis ? globalThis : e || self).LocalTime = t();
      }(exports, function() {
        "use strict";
        var e;
        e = { config: {}, run: function() {
          return this.getController().processElements();
        }, process: function(...e2) {
          var t2, r3, n3;
          for (r3 = 0, n3 = e2.length; r3 < n3; r3++) t2 = e2[r3], this.getController().processElement(t2);
          return e2.length;
        }, getController: function() {
          return null != this.controller ? this.controller : this.controller = new e.Controller();
        } };
        var t, r2, n2, a, i, s2, o, u2, l2, c2, d2, m2, h2, f2, g, p2, y, S, v2, T2, b2, M, D, w, E, I, C2, N, A, O, $, F, Y, k, L, W = e;
        return W.config.useFormat24 = false, W.config.i18n = { en: { date: { dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], abbrDayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], abbrMonthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], yesterday: "yesterday", today: "today", tomorrow: "tomorrow", on: "on {date}", formats: { default: "%b %e, %Y", thisYear: "%b %e" } }, time: { am: "am", pm: "pm", singular: "a {time}", singularAn: "an {time}", elapsed: "{time} ago", second: "second", seconds: "seconds", minute: "minute", minutes: "minutes", hour: "hour", hours: "hours", formats: { default: "%l:%M%P", default_24h: "%H:%M" } }, datetime: { at: "{date} at {time}", formats: { default: "%B %e, %Y at %l:%M%P %Z", default_24h: "%B %e, %Y at %H:%M %Z" } } } }, W.config.locale = "en", W.config.defaultLocale = "en", W.config.timerInterval = 6e4, n2 = !isNaN(Date.parse("2011-01-01T12:00:00-05:00")), W.parseDate = function(e2) {
          return e2 = e2.toString(), n2 || (e2 = r2(e2)), new Date(Date.parse(e2));
        }, t = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(Z|[-+]?[\d:]+)$/, r2 = function(e2) {
          var r3, n3, a2, i2, s3, o2, u3, l3, c3, d3;
          if (i2 = e2.match(t)) return [r3, c3, o2, n3, a2, s3, l3, d3] = i2, "Z" !== d3 && (u3 = d3.replace(":", "")), `${c3}/${o2}/${n3} ${a2}:${s3}:${l3} GMT${[u3]}`;
        }, W.elementMatchesSelector = (a = document.documentElement, i = null != (s2 = null != (o = null != (u2 = null != (l2 = a.matches) ? l2 : a.matchesSelector) ? u2 : a.webkitMatchesSelector) ? o : a.mozMatchesSelector) ? s2 : a.msMatchesSelector, function(e2, t2) {
          if ((null != e2 ? e2.nodeType : void 0) === Node.ELEMENT_NODE) return i.call(e2, t2);
        }), { config: c2 } = W, { i18n: m2 } = c2, W.getI18nValue = function(e2 = "", { locale: t2 } = { locale: c2.locale }) {
          var r3;
          return null != (r3 = d2(m2[t2], e2)) ? r3 : t2 !== c2.defaultLocale ? W.getI18nValue(e2, { locale: c2.defaultLocale }) : void 0;
        }, W.translate = function(e2, t2 = {}, r3) {
          var n3, a2, i2;
          for (n3 in i2 = W.getI18nValue(e2, r3), t2) a2 = t2[n3], i2 = i2.replace(`{${n3}}`, a2);
          return i2;
        }, d2 = function(e2, t2) {
          var r3, n3, a2, i2, s3;
          for (s3 = e2, r3 = 0, a2 = (i2 = t2.split(".")).length; r3 < a2; r3++) {
            if (null == s3[n3 = i2[r3]]) return null;
            s3 = s3[n3];
          }
          return s3;
        }, { getI18nValue: f2, translate: M } = W, b2 = "function" == typeof ("undefined" != typeof Intl && null !== Intl ? Intl.DateTimeFormat : void 0), g = { "Central European Standard Time": "CET", "Central European Summer Time": "CEST", "China Standard Time": "CST", "Israel Daylight Time": "IDT", "Israel Standard Time": "IST", "Moscow Standard Time": "MSK", "Philippine Standard Time": "PHT", "Singapore Standard Time": "SGT", "Western Indonesia Time": "WIB" }, W.knownEdgeCaseTimeZones = g, W.strftime = T2 = function(e2, t2) {
          var r3, n3, a2, i2, s3, o2, u3;
          return n3 = e2.getDay(), r3 = e2.getDate(), s3 = e2.getMonth(), u3 = e2.getFullYear(), a2 = e2.getHours(), i2 = e2.getMinutes(), o2 = e2.getSeconds(), t2.replace(/%(-?)([%aAbBcdeHIlmMpPSwyYZ])/g, function(t3, l3, c3) {
            switch (c3) {
              case "%":
                return "%";
              case "a":
                return f2("date.abbrDayNames")[n3];
              case "A":
                return f2("date.dayNames")[n3];
              case "b":
                return f2("date.abbrMonthNames")[s3];
              case "B":
                return f2("date.monthNames")[s3];
              case "c":
                return e2.toString();
              case "d":
                return p2(r3, l3);
              case "e":
                return r3;
              case "H":
                return p2(a2, l3);
              case "I":
                return p2(T2(e2, "%l"), l3);
              case "l":
                return 0 === a2 || 12 === a2 ? 12 : (a2 + 12) % 12;
              case "m":
                return p2(s3 + 1, l3);
              case "M":
                return p2(i2, l3);
              case "p":
                return M("time." + (a2 > 11 ? "pm" : "am")).toUpperCase();
              case "P":
                return M("time." + (a2 > 11 ? "pm" : "am"));
              case "S":
                return p2(o2, l3);
              case "w":
                return n3;
              case "y":
                return p2(u3 % 100, l3);
              case "Y":
                return u3;
              case "Z":
                return y(e2);
            }
          });
        }, p2 = function(e2, t2) {
          return "-" === t2 ? e2 : `0${e2}`.slice(-2);
        }, y = function(e2) {
          var t2, r3, n3;
          return (r3 = h2(e2)) ? g[r3] : (n3 = v2(e2, { allowGMT: false })) || (n3 = S(e2)) ? n3 : (t2 = v2(e2, { allowGMT: true })) ? t2 : "";
        }, h2 = function(e2) {
          return Object.keys(g).find(function(t2) {
            return b2 ? new Date(e2).toLocaleString("en-US", { timeZoneName: "long" }).includes(t2) : e2.toString().includes(t2);
          });
        }, v2 = function(e2, { allowGMT: t2 }) {
          var r3;
          if (b2 && (r3 = new Date(e2).toLocaleString("en-US", { timeZoneName: "short" }).split(" ").pop(), t2 || !r3.includes("GMT"))) return r3;
        }, S = function(e2) {
          var t2, r3, n3, a2, i2;
          return (t2 = null != (r3 = (i2 = e2.toString()).match(/\(([\w\s]+)\)$/)) ? r3[1] : void 0) ? /\s/.test(t2) ? t2.match(/\b(\w)/g).join("") : t2 : (t2 = null != (n3 = i2.match(/(\w{3,4})\s\d{4}$/)) ? n3[1] : void 0) || (t2 = null != (a2 = i2.match(/(UTC[\+\-]\d+)/)) ? a2[1] : void 0) ? t2 : void 0;
        }, W.CalendarDate = class {
          static fromDate(e2) {
            return new this(e2.getFullYear(), e2.getMonth() + 1, e2.getDate());
          }
          static today() {
            return this.fromDate(/* @__PURE__ */ new Date());
          }
          constructor(e2, t2, r3) {
            this.date = new Date(Date.UTC(e2, t2 - 1)), this.date.setUTCDate(r3), this.year = this.date.getUTCFullYear(), this.month = this.date.getUTCMonth() + 1, this.day = this.date.getUTCDate(), this.value = this.date.getTime();
          }
          equals(e2) {
            return (null != e2 ? e2.value : void 0) === this.value;
          }
          is(e2) {
            return this.equals(e2);
          }
          isToday() {
            return this.is(this.constructor.today());
          }
          occursOnSameYearAs(e2) {
            return this.year === (null != e2 ? e2.year : void 0);
          }
          occursThisYear() {
            return this.occursOnSameYearAs(this.constructor.today());
          }
          daysSince(e2) {
            if (e2) return (this.date - e2.date) / 864e5;
          }
          daysPassed() {
            return this.constructor.today().daysSince(this);
          }
        }, { strftime: E, translate: I, getI18nValue: w, config: D } = W, W.RelativeTime = class {
          constructor(e2) {
            this.date = e2, this.calendarDate = W.CalendarDate.fromDate(this.date);
          }
          toString() {
            var e2, t2;
            return (t2 = this.toTimeElapsedString()) ? I("time.elapsed", { time: t2 }) : (e2 = this.toWeekdayString()) ? (t2 = this.toTimeString(), I("datetime.at", { date: e2, time: t2 })) : I("date.on", { date: this.toDateString() });
          }
          toTimeOrDateString() {
            return this.calendarDate.isToday() ? this.toTimeString() : this.toDateString();
          }
          toTimeElapsedString() {
            var e2, t2, r3, n3, a2;
            return r3 = (/* @__PURE__ */ new Date()).getTime() - this.date.getTime(), n3 = Math.round(r3 / 1e3), t2 = Math.round(n3 / 60), e2 = Math.round(t2 / 60), r3 < 0 ? null : n3 < 10 ? (a2 = I("time.second"), I("time.singular", { time: a2 })) : n3 < 45 ? `${n3} ${I("time.seconds")}` : n3 < 90 ? (a2 = I("time.minute"), I("time.singular", { time: a2 })) : t2 < 45 ? `${t2} ${I("time.minutes")}` : t2 < 90 ? (a2 = I("time.hour"), I("time.singularAn", { time: a2 })) : e2 < 24 ? `${e2} ${I("time.hours")}` : "";
          }
          toWeekdayString() {
            switch (this.calendarDate.daysPassed()) {
              case 0:
                return I("date.today");
              case 1:
                return I("date.yesterday");
              case -1:
                return I("date.tomorrow");
              case 2:
              case 3:
              case 4:
              case 5:
              case 6:
                return E(this.date, "%A");
              default:
                return "";
            }
          }
          toDateString() {
            var e2;
            return e2 = this.calendarDate.occursThisYear() ? w("date.formats.thisYear") : w("date.formats.default"), E(this.date, e2);
          }
          toTimeString() {
            var e2;
            return e2 = D.useFormat24 ? "default_24h" : "default", E(this.date, w(`time.formats.${e2}`));
          }
        }, { elementMatchesSelector: C2 } = W, W.PageObserver = class {
          constructor(e2, t2) {
            this.processMutations = this.processMutations.bind(this), this.processInsertion = this.processInsertion.bind(this), this.selector = e2, this.callback = t2;
          }
          start() {
            if (!this.started) return this.observeWithMutationObserver() || this.observeWithMutationEvent(), this.started = true;
          }
          observeWithMutationObserver() {
            if ("undefined" != typeof MutationObserver && null !== MutationObserver) return new MutationObserver(this.processMutations).observe(document.documentElement, { childList: true, subtree: true }), true;
          }
          observeWithMutationEvent() {
            return addEventListener("DOMNodeInserted", this.processInsertion, false), true;
          }
          findSignificantElements(e2) {
            var t2;
            return t2 = [], (null != e2 ? e2.nodeType : void 0) === Node.ELEMENT_NODE && (C2(e2, this.selector) && t2.push(e2), t2.push(...e2.querySelectorAll(this.selector))), t2;
          }
          processMutations(e2) {
            var t2, r3, n3, a2, i2, s3, o2, u3;
            for (t2 = [], r3 = 0, a2 = e2.length; r3 < a2; r3++) if ("childList" === (s3 = e2[r3]).type) for (n3 = 0, i2 = (u3 = s3.addedNodes).length; n3 < i2; n3++) o2 = u3[n3], t2.push(...this.findSignificantElements(o2));
            return this.notify(t2);
          }
          processInsertion(e2) {
            var t2;
            return t2 = this.findSignificantElements(e2.target), this.notify(t2);
          }
          notify(e2) {
            if (null != e2 ? e2.length : void 0) return "function" == typeof this.callback ? this.callback(e2) : void 0;
          }
        }, { parseDate: O, strftime: $, getI18nValue: A, config: N } = W, W.Controller = function() {
          var e2, t2, r3, n3;
          return e2 = "time[data-local]:not([data-localized])", t2 = function(e3) {
            return e3.setAttribute("data-localized", "");
          }, r3 = function(e3) {
            return e3.setAttribute("data-processed-at", (/* @__PURE__ */ new Date()).toISOString());
          }, n3 = function(e3) {
            return new W.RelativeTime(e3);
          }, class {
            constructor() {
              this.processElements = this.processElements.bind(this), this.pageObserver = new W.PageObserver(e2, this.processElements);
            }
            start() {
              if (!this.started) return this.processElements(), this.startTimer(), this.pageObserver.start(), this.started = true;
            }
            startTimer() {
              var e3;
              if (e3 = N.timerInterval) return null != this.timer ? this.timer : this.timer = setInterval(this.processElements, e3);
            }
            processElements(t3 = document.querySelectorAll(e2)) {
              var r4, n4, a2;
              for (n4 = 0, a2 = t3.length; n4 < a2; n4++) r4 = t3[n4], this.processElement(r4);
              return t3.length;
            }
            processElement(e3) {
              var a2, i2, s3, o2, u3, l3;
              if (a2 = e3.getAttribute("datetime"), s3 = e3.getAttribute("data-local"), i2 = N.useFormat24 && e3.getAttribute("data-format24") || e3.getAttribute("data-format"), o2 = O(a2), !isNaN(o2)) return e3.hasAttribute("title") || (l3 = N.useFormat24 ? "default_24h" : "default", u3 = $(o2, A(`datetime.formats.${l3}`)), e3.setAttribute("title", u3)), r3(e3), e3.textContent = function() {
                switch (s3) {
                  case "time":
                    return t2(e3), $(o2, i2);
                  case "date":
                    return t2(e3), n3(o2).toDateString();
                  case "time-ago":
                    return n3(o2).toString();
                  case "time-or-date":
                    return n3(o2).toTimeOrDateString();
                  case "weekday":
                    return n3(o2).toWeekdayString();
                  case "weekday-or-date":
                    return n3(o2).toWeekdayString() || n3(o2).toDateString();
                }
              }();
            }
          };
        }.call(window), L = false, F = function() {
          return document.attachEvent ? "complete" === document.readyState : "loading" !== document.readyState;
        }, Y = function(e2) {
          var t2;
          return null != (t2 = "function" == typeof requestAnimationFrame ? requestAnimationFrame(e2) : void 0) ? t2 : setTimeout(e2, 17);
        }, k = function() {
          return W.getController().start();
        }, W.start = function() {
          return L ? W.run() : (L = true, "undefined" != typeof MutationObserver && null !== MutationObserver || F() ? k() : Y(k));
        }, W.processing = function() {
          return W.getController().started;
        }, window.LocalTime === W && W.start(), W;
      });
    }
  });

  // ../../node_modules/@hotwired/turbo/dist/turbo.es2017-esm.js
  var turbo_es2017_esm_exports = {};
  __export(turbo_es2017_esm_exports, {
    FetchEnctype: () => FetchEnctype,
    FetchMethod: () => FetchMethod,
    FetchRequest: () => FetchRequest,
    FetchResponse: () => FetchResponse,
    FrameElement: () => FrameElement,
    FrameLoadingStyle: () => FrameLoadingStyle,
    FrameRenderer: () => FrameRenderer,
    PageRenderer: () => PageRenderer,
    PageSnapshot: () => PageSnapshot,
    StreamActions: () => StreamActions,
    StreamElement: () => StreamElement,
    StreamSourceElement: () => StreamSourceElement,
    cache: () => cache,
    clearCache: () => clearCache,
    connectStreamSource: () => connectStreamSource,
    disconnectStreamSource: () => disconnectStreamSource,
    fetch: () => fetchWithTurboHeaders,
    fetchEnctypeFromString: () => fetchEnctypeFromString,
    fetchMethodFromString: () => fetchMethodFromString,
    isSafe: () => isSafe,
    navigator: () => navigator$1,
    registerAdapter: () => registerAdapter,
    renderStreamMessage: () => renderStreamMessage,
    session: () => session,
    setConfirmMethod: () => setConfirmMethod,
    setFormMode: () => setFormMode,
    setProgressBarDelay: () => setProgressBarDelay,
    start: () => start,
    visit: () => visit
  });
  (function(prototype) {
    if (typeof prototype.requestSubmit == "function") return;
    prototype.requestSubmit = function(submitter) {
      if (submitter) {
        validateSubmitter(submitter, this);
        submitter.click();
      } else {
        submitter = document.createElement("input");
        submitter.type = "submit";
        submitter.hidden = true;
        this.appendChild(submitter);
        submitter.click();
        this.removeChild(submitter);
      }
    };
    function validateSubmitter(submitter, form) {
      submitter instanceof HTMLElement || raise(TypeError, "parameter 1 is not of type 'HTMLElement'");
      submitter.type == "submit" || raise(TypeError, "The specified element is not a submit button");
      submitter.form == form || raise(DOMException, "The specified element is not owned by this form element", "NotFoundError");
    }
    function raise(errorConstructor, message, name3) {
      throw new errorConstructor("Failed to execute 'requestSubmit' on 'HTMLFormElement': " + message + ".", name3);
    }
  })(HTMLFormElement.prototype);
  var submittersByForm = /* @__PURE__ */ new WeakMap();
  function findSubmitterFromClickTarget(target) {
    const element = target instanceof Element ? target : target instanceof Node ? target.parentElement : null;
    const candidate = element ? element.closest("input, button") : null;
    return candidate?.type == "submit" ? candidate : null;
  }
  function clickCaptured(event) {
    const submitter = findSubmitterFromClickTarget(event.target);
    if (submitter && submitter.form) {
      submittersByForm.set(submitter.form, submitter);
    }
  }
  (function() {
    if ("submitter" in Event.prototype) return;
    let prototype = window.Event.prototype;
    if ("SubmitEvent" in window) {
      const prototypeOfSubmitEvent = window.SubmitEvent.prototype;
      if (/Apple Computer/.test(navigator.vendor) && !("submitter" in prototypeOfSubmitEvent)) {
        prototype = prototypeOfSubmitEvent;
      } else {
        return;
      }
    }
    addEventListener("click", clickCaptured, true);
    Object.defineProperty(prototype, "submitter", {
      get() {
        if (this.type == "submit" && this.target instanceof HTMLFormElement) {
          return submittersByForm.get(this.target);
        }
      }
    });
  })();
  var FrameLoadingStyle = {
    eager: "eager",
    lazy: "lazy"
  };
  var FrameElement = class _FrameElement extends HTMLElement {
    static delegateConstructor = void 0;
    loaded = Promise.resolve();
    static get observedAttributes() {
      return ["disabled", "loading", "src"];
    }
    constructor() {
      super();
      this.delegate = new _FrameElement.delegateConstructor(this);
    }
    connectedCallback() {
      this.delegate.connect();
    }
    disconnectedCallback() {
      this.delegate.disconnect();
    }
    reload() {
      return this.delegate.sourceURLReloaded();
    }
    attributeChangedCallback(name3) {
      if (name3 == "loading") {
        this.delegate.loadingStyleChanged();
      } else if (name3 == "src") {
        this.delegate.sourceURLChanged();
      } else if (name3 == "disabled") {
        this.delegate.disabledChanged();
      }
    }
    /**
     * Gets the URL to lazily load source HTML from
     */
    get src() {
      return this.getAttribute("src");
    }
    /**
     * Sets the URL to lazily load source HTML from
     */
    set src(value) {
      if (value) {
        this.setAttribute("src", value);
      } else {
        this.removeAttribute("src");
      }
    }
    /**
     * Gets the refresh mode for the frame.
     */
    get refresh() {
      return this.getAttribute("refresh");
    }
    /**
     * Sets the refresh mode for the frame.
     */
    set refresh(value) {
      if (value) {
        this.setAttribute("refresh", value);
      } else {
        this.removeAttribute("refresh");
      }
    }
    /**
     * Determines if the element is loading
     */
    get loading() {
      return frameLoadingStyleFromString(this.getAttribute("loading") || "");
    }
    /**
     * Sets the value of if the element is loading
     */
    set loading(value) {
      if (value) {
        this.setAttribute("loading", value);
      } else {
        this.removeAttribute("loading");
      }
    }
    /**
     * Gets the disabled state of the frame.
     *
     * If disabled, no requests will be intercepted by the frame.
     */
    get disabled() {
      return this.hasAttribute("disabled");
    }
    /**
     * Sets the disabled state of the frame.
     *
     * If disabled, no requests will be intercepted by the frame.
     */
    set disabled(value) {
      if (value) {
        this.setAttribute("disabled", "");
      } else {
        this.removeAttribute("disabled");
      }
    }
    /**
     * Gets the autoscroll state of the frame.
     *
     * If true, the frame will be scrolled into view automatically on update.
     */
    get autoscroll() {
      return this.hasAttribute("autoscroll");
    }
    /**
     * Sets the autoscroll state of the frame.
     *
     * If true, the frame will be scrolled into view automatically on update.
     */
    set autoscroll(value) {
      if (value) {
        this.setAttribute("autoscroll", "");
      } else {
        this.removeAttribute("autoscroll");
      }
    }
    /**
     * Determines if the element has finished loading
     */
    get complete() {
      return !this.delegate.isLoading;
    }
    /**
     * Gets the active state of the frame.
     *
     * If inactive, source changes will not be observed.
     */
    get isActive() {
      return this.ownerDocument === document && !this.isPreview;
    }
    /**
     * Sets the active state of the frame.
     *
     * If inactive, source changes will not be observed.
     */
    get isPreview() {
      return this.ownerDocument?.documentElement?.hasAttribute("data-turbo-preview");
    }
  };
  function frameLoadingStyleFromString(style) {
    switch (style.toLowerCase()) {
      case "lazy":
        return FrameLoadingStyle.lazy;
      default:
        return FrameLoadingStyle.eager;
    }
  }
  function expandURL(locatable) {
    return new URL(locatable.toString(), document.baseURI);
  }
  function getAnchor(url) {
    let anchorMatch;
    if (url.hash) {
      return url.hash.slice(1);
    } else if (anchorMatch = url.href.match(/#(.*)$/)) {
      return anchorMatch[1];
    }
  }
  function getAction$1(form, submitter) {
    const action = submitter?.getAttribute("formaction") || form.getAttribute("action") || form.action;
    return expandURL(action);
  }
  function getExtension(url) {
    return (getLastPathComponent(url).match(/\.[^.]*$/) || [])[0] || "";
  }
  function isHTML(url) {
    return !!getExtension(url).match(/^(?:|\.(?:htm|html|xhtml|php))$/);
  }
  function isPrefixedBy(baseURL, url) {
    const prefix = getPrefix(url);
    return baseURL.href === expandURL(prefix).href || baseURL.href.startsWith(prefix);
  }
  function locationIsVisitable(location2, rootLocation) {
    return isPrefixedBy(location2, rootLocation) && isHTML(location2);
  }
  function getRequestURL(url) {
    const anchor = getAnchor(url);
    return anchor != null ? url.href.slice(0, -(anchor.length + 1)) : url.href;
  }
  function toCacheKey(url) {
    return getRequestURL(url);
  }
  function urlsAreEqual(left2, right2) {
    return expandURL(left2).href == expandURL(right2).href;
  }
  function getPathComponents(url) {
    return url.pathname.split("/").slice(1);
  }
  function getLastPathComponent(url) {
    return getPathComponents(url).slice(-1)[0];
  }
  function getPrefix(url) {
    return addTrailingSlash(url.origin + url.pathname);
  }
  function addTrailingSlash(value) {
    return value.endsWith("/") ? value : value + "/";
  }
  var FetchResponse = class {
    constructor(response2) {
      this.response = response2;
    }
    get succeeded() {
      return this.response.ok;
    }
    get failed() {
      return !this.succeeded;
    }
    get clientError() {
      return this.statusCode >= 400 && this.statusCode <= 499;
    }
    get serverError() {
      return this.statusCode >= 500 && this.statusCode <= 599;
    }
    get redirected() {
      return this.response.redirected;
    }
    get location() {
      return expandURL(this.response.url);
    }
    get isHTML() {
      return this.contentType && this.contentType.match(/^(?:text\/([^\s;,]+\b)?html|application\/xhtml\+xml)\b/);
    }
    get statusCode() {
      return this.response.status;
    }
    get contentType() {
      return this.header("Content-Type");
    }
    get responseText() {
      return this.response.clone().text();
    }
    get responseHTML() {
      if (this.isHTML) {
        return this.response.clone().text();
      } else {
        return Promise.resolve(void 0);
      }
    }
    header(name3) {
      return this.response.headers.get(name3);
    }
  };
  function activateScriptElement(element) {
    if (element.getAttribute("data-turbo-eval") == "false") {
      return element;
    } else {
      const createdScriptElement = document.createElement("script");
      const cspNonce = getMetaContent("csp-nonce");
      if (cspNonce) {
        createdScriptElement.nonce = cspNonce;
      }
      createdScriptElement.textContent = element.textContent;
      createdScriptElement.async = false;
      copyElementAttributes(createdScriptElement, element);
      return createdScriptElement;
    }
  }
  function copyElementAttributes(destinationElement, sourceElement) {
    for (const { name: name3, value } of sourceElement.attributes) {
      destinationElement.setAttribute(name3, value);
    }
  }
  function createDocumentFragment(html) {
    const template2 = document.createElement("template");
    template2.innerHTML = html;
    return template2.content;
  }
  function dispatch(eventName, { target, cancelable, detail } = {}) {
    const event = new CustomEvent(eventName, {
      cancelable,
      bubbles: true,
      composed: true,
      detail
    });
    if (target && target.isConnected) {
      target.dispatchEvent(event);
    } else {
      document.documentElement.dispatchEvent(event);
    }
    return event;
  }
  function nextRepaint() {
    if (document.visibilityState === "hidden") {
      return nextEventLoopTick();
    } else {
      return nextAnimationFrame();
    }
  }
  function nextAnimationFrame() {
    return new Promise((resolve) => requestAnimationFrame(() => resolve()));
  }
  function nextEventLoopTick() {
    return new Promise((resolve) => setTimeout(() => resolve(), 0));
  }
  function nextMicrotask() {
    return Promise.resolve();
  }
  function parseHTMLDocument(html = "") {
    return new DOMParser().parseFromString(html, "text/html");
  }
  function unindent(strings, ...values) {
    const lines = interpolate(strings, values).replace(/^\n/, "").split("\n");
    const match = lines[0].match(/^\s+/);
    const indent = match ? match[0].length : 0;
    return lines.map((line) => line.slice(indent)).join("\n");
  }
  function interpolate(strings, values) {
    return strings.reduce((result, string, i) => {
      const value = values[i] == void 0 ? "" : values[i];
      return result + string + value;
    }, "");
  }
  function uuid() {
    return Array.from({ length: 36 }).map((_, i) => {
      if (i == 8 || i == 13 || i == 18 || i == 23) {
        return "-";
      } else if (i == 14) {
        return "4";
      } else if (i == 19) {
        return (Math.floor(Math.random() * 4) + 8).toString(16);
      } else {
        return Math.floor(Math.random() * 15).toString(16);
      }
    }).join("");
  }
  function getAttribute(attributeName, ...elements) {
    for (const value of elements.map((element) => element?.getAttribute(attributeName))) {
      if (typeof value == "string") return value;
    }
    return null;
  }
  function hasAttribute(attributeName, ...elements) {
    return elements.some((element) => element && element.hasAttribute(attributeName));
  }
  function markAsBusy(...elements) {
    for (const element of elements) {
      if (element.localName == "turbo-frame") {
        element.setAttribute("busy", "");
      }
      element.setAttribute("aria-busy", "true");
    }
  }
  function clearBusyState(...elements) {
    for (const element of elements) {
      if (element.localName == "turbo-frame") {
        element.removeAttribute("busy");
      }
      element.removeAttribute("aria-busy");
    }
  }
  function waitForLoad(element, timeoutInMilliseconds = 2e3) {
    return new Promise((resolve) => {
      const onComplete = () => {
        element.removeEventListener("error", onComplete);
        element.removeEventListener("load", onComplete);
        resolve();
      };
      element.addEventListener("load", onComplete, { once: true });
      element.addEventListener("error", onComplete, { once: true });
      setTimeout(resolve, timeoutInMilliseconds);
    });
  }
  function getHistoryMethodForAction(action) {
    switch (action) {
      case "replace":
        return history.replaceState;
      case "advance":
      case "restore":
        return history.pushState;
    }
  }
  function isAction(action) {
    return action == "advance" || action == "replace" || action == "restore";
  }
  function getVisitAction(...elements) {
    const action = getAttribute("data-turbo-action", ...elements);
    return isAction(action) ? action : null;
  }
  function getMetaElement(name3) {
    return document.querySelector(`meta[name="${name3}"]`);
  }
  function getMetaContent(name3) {
    const element = getMetaElement(name3);
    return element && element.content;
  }
  function setMetaContent(name3, content) {
    let element = getMetaElement(name3);
    if (!element) {
      element = document.createElement("meta");
      element.setAttribute("name", name3);
      document.head.appendChild(element);
    }
    element.setAttribute("content", content);
    return element;
  }
  function findClosestRecursively(element, selector) {
    if (element instanceof Element) {
      return element.closest(selector) || findClosestRecursively(element.assignedSlot || element.getRootNode()?.host, selector);
    }
  }
  function elementIsFocusable(element) {
    const inertDisabledOrHidden = "[inert], :disabled, [hidden], details:not([open]), dialog:not([open])";
    return !!element && element.closest(inertDisabledOrHidden) == null && typeof element.focus == "function";
  }
  function queryAutofocusableElement(elementOrDocumentFragment) {
    return Array.from(elementOrDocumentFragment.querySelectorAll("[autofocus]")).find(elementIsFocusable);
  }
  async function around(callback, reader) {
    const before2 = reader();
    callback();
    await nextAnimationFrame();
    const after2 = reader();
    return [before2, after2];
  }
  function doesNotTargetIFrame(anchor) {
    if (anchor.hasAttribute("target")) {
      for (const element of document.getElementsByName(anchor.target)) {
        if (element instanceof HTMLIFrameElement) return false;
      }
    }
    return true;
  }
  function findLinkFromClickTarget(target) {
    return findClosestRecursively(target, "a[href]:not([target^=_]):not([download])");
  }
  function getLocationForLink(link) {
    return expandURL(link.getAttribute("href") || "");
  }
  function debounce(fn2, delay) {
    let timeoutId = null;
    return (...args) => {
      const callback = () => fn2.apply(this, args);
      clearTimeout(timeoutId);
      timeoutId = setTimeout(callback, delay);
    };
  }
  var LimitedSet = class extends Set {
    constructor(maxSize) {
      super();
      this.maxSize = maxSize;
    }
    add(value) {
      if (this.size >= this.maxSize) {
        const iterator = this.values();
        const oldestValue = iterator.next().value;
        this.delete(oldestValue);
      }
      super.add(value);
    }
  };
  var recentRequests = new LimitedSet(20);
  var nativeFetch = window.fetch;
  function fetchWithTurboHeaders(url, options = {}) {
    const modifiedHeaders = new Headers(options.headers || {});
    const requestUID = uuid();
    recentRequests.add(requestUID);
    modifiedHeaders.append("X-Turbo-Request-Id", requestUID);
    return nativeFetch(url, {
      ...options,
      headers: modifiedHeaders
    });
  }
  function fetchMethodFromString(method) {
    switch (method.toLowerCase()) {
      case "get":
        return FetchMethod.get;
      case "post":
        return FetchMethod.post;
      case "put":
        return FetchMethod.put;
      case "patch":
        return FetchMethod.patch;
      case "delete":
        return FetchMethod.delete;
    }
  }
  var FetchMethod = {
    get: "get",
    post: "post",
    put: "put",
    patch: "patch",
    delete: "delete"
  };
  function fetchEnctypeFromString(encoding) {
    switch (encoding.toLowerCase()) {
      case FetchEnctype.multipart:
        return FetchEnctype.multipart;
      case FetchEnctype.plain:
        return FetchEnctype.plain;
      default:
        return FetchEnctype.urlEncoded;
    }
  }
  var FetchEnctype = {
    urlEncoded: "application/x-www-form-urlencoded",
    multipart: "multipart/form-data",
    plain: "text/plain"
  };
  var FetchRequest = class {
    abortController = new AbortController();
    #resolveRequestPromise = (_value) => {
    };
    constructor(delegate, method, location2, requestBody = new URLSearchParams(), target = null, enctype = FetchEnctype.urlEncoded) {
      const [url, body] = buildResourceAndBody(expandURL(location2), method, requestBody, enctype);
      this.delegate = delegate;
      this.url = url;
      this.target = target;
      this.fetchOptions = {
        credentials: "same-origin",
        redirect: "follow",
        method,
        headers: { ...this.defaultHeaders },
        body,
        signal: this.abortSignal,
        referrer: this.delegate.referrer?.href
      };
      this.enctype = enctype;
    }
    get method() {
      return this.fetchOptions.method;
    }
    set method(value) {
      const fetchBody = this.isSafe ? this.url.searchParams : this.fetchOptions.body || new FormData();
      const fetchMethod = fetchMethodFromString(value) || FetchMethod.get;
      this.url.search = "";
      const [url, body] = buildResourceAndBody(this.url, fetchMethod, fetchBody, this.enctype);
      this.url = url;
      this.fetchOptions.body = body;
      this.fetchOptions.method = fetchMethod;
    }
    get headers() {
      return this.fetchOptions.headers;
    }
    set headers(value) {
      this.fetchOptions.headers = value;
    }
    get body() {
      if (this.isSafe) {
        return this.url.searchParams;
      } else {
        return this.fetchOptions.body;
      }
    }
    set body(value) {
      this.fetchOptions.body = value;
    }
    get location() {
      return this.url;
    }
    get params() {
      return this.url.searchParams;
    }
    get entries() {
      return this.body ? Array.from(this.body.entries()) : [];
    }
    cancel() {
      this.abortController.abort();
    }
    async perform() {
      const { fetchOptions } = this;
      this.delegate.prepareRequest(this);
      const event = await this.#allowRequestToBeIntercepted(fetchOptions);
      try {
        this.delegate.requestStarted(this);
        if (event.detail.fetchRequest) {
          this.response = event.detail.fetchRequest.response;
        } else {
          this.response = fetchWithTurboHeaders(this.url.href, fetchOptions);
        }
        const response2 = await this.response;
        return await this.receive(response2);
      } catch (error3) {
        if (error3.name !== "AbortError") {
          if (this.#willDelegateErrorHandling(error3)) {
            this.delegate.requestErrored(this, error3);
          }
          throw error3;
        }
      } finally {
        this.delegate.requestFinished(this);
      }
    }
    async receive(response2) {
      const fetchResponse = new FetchResponse(response2);
      const event = dispatch("turbo:before-fetch-response", {
        cancelable: true,
        detail: { fetchResponse },
        target: this.target
      });
      if (event.defaultPrevented) {
        this.delegate.requestPreventedHandlingResponse(this, fetchResponse);
      } else if (fetchResponse.succeeded) {
        this.delegate.requestSucceededWithResponse(this, fetchResponse);
      } else {
        this.delegate.requestFailedWithResponse(this, fetchResponse);
      }
      return fetchResponse;
    }
    get defaultHeaders() {
      return {
        Accept: "text/html, application/xhtml+xml"
      };
    }
    get isSafe() {
      return isSafe(this.method);
    }
    get abortSignal() {
      return this.abortController.signal;
    }
    acceptResponseType(mimeType) {
      this.headers["Accept"] = [mimeType, this.headers["Accept"]].join(", ");
    }
    async #allowRequestToBeIntercepted(fetchOptions) {
      const requestInterception = new Promise((resolve) => this.#resolveRequestPromise = resolve);
      const event = dispatch("turbo:before-fetch-request", {
        cancelable: true,
        detail: {
          fetchOptions,
          url: this.url,
          resume: this.#resolveRequestPromise
        },
        target: this.target
      });
      this.url = event.detail.url;
      if (event.defaultPrevented) await requestInterception;
      return event;
    }
    #willDelegateErrorHandling(error3) {
      const event = dispatch("turbo:fetch-request-error", {
        target: this.target,
        cancelable: true,
        detail: { request: this, error: error3 }
      });
      return !event.defaultPrevented;
    }
  };
  function isSafe(fetchMethod) {
    return fetchMethodFromString(fetchMethod) == FetchMethod.get;
  }
  function buildResourceAndBody(resource, method, requestBody, enctype) {
    const searchParams = Array.from(requestBody).length > 0 ? new URLSearchParams(entriesExcludingFiles(requestBody)) : resource.searchParams;
    if (isSafe(method)) {
      return [mergeIntoURLSearchParams(resource, searchParams), null];
    } else if (enctype == FetchEnctype.urlEncoded) {
      return [resource, searchParams];
    } else {
      return [resource, requestBody];
    }
  }
  function entriesExcludingFiles(requestBody) {
    const entries = [];
    for (const [name3, value] of requestBody) {
      if (value instanceof File) continue;
      else entries.push([name3, value]);
    }
    return entries;
  }
  function mergeIntoURLSearchParams(url, requestBody) {
    const searchParams = new URLSearchParams(entriesExcludingFiles(requestBody));
    url.search = searchParams.toString();
    return url;
  }
  var AppearanceObserver = class {
    started = false;
    constructor(delegate, element) {
      this.delegate = delegate;
      this.element = element;
      this.intersectionObserver = new IntersectionObserver(this.intersect);
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.intersectionObserver.observe(this.element);
      }
    }
    stop() {
      if (this.started) {
        this.started = false;
        this.intersectionObserver.unobserve(this.element);
      }
    }
    intersect = (entries) => {
      const lastEntry = entries.slice(-1)[0];
      if (lastEntry?.isIntersecting) {
        this.delegate.elementAppearedInViewport(this.element);
      }
    };
  };
  var StreamMessage = class {
    static contentType = "text/vnd.turbo-stream.html";
    static wrap(message) {
      if (typeof message == "string") {
        return new this(createDocumentFragment(message));
      } else {
        return message;
      }
    }
    constructor(fragment) {
      this.fragment = importStreamElements(fragment);
    }
  };
  function importStreamElements(fragment) {
    for (const element of fragment.querySelectorAll("turbo-stream")) {
      const streamElement = document.importNode(element, true);
      for (const inertScriptElement of streamElement.templateElement.content.querySelectorAll("script")) {
        inertScriptElement.replaceWith(activateScriptElement(inertScriptElement));
      }
      element.replaceWith(streamElement);
    }
    return fragment;
  }
  var PREFETCH_DELAY = 100;
  var PrefetchCache = class {
    #prefetchTimeout = null;
    #prefetched = null;
    get(url) {
      if (this.#prefetched && this.#prefetched.url === url && this.#prefetched.expire > Date.now()) {
        return this.#prefetched.request;
      }
    }
    setLater(url, request3, ttl) {
      this.clear();
      this.#prefetchTimeout = setTimeout(() => {
        request3.perform();
        this.set(url, request3, ttl);
        this.#prefetchTimeout = null;
      }, PREFETCH_DELAY);
    }
    set(url, request3, ttl) {
      this.#prefetched = { url, request: request3, expire: new Date((/* @__PURE__ */ new Date()).getTime() + ttl) };
    }
    clear() {
      if (this.#prefetchTimeout) clearTimeout(this.#prefetchTimeout);
      this.#prefetched = null;
    }
  };
  var cacheTtl = 10 * 1e3;
  var prefetchCache = new PrefetchCache();
  var FormSubmissionState = {
    initialized: "initialized",
    requesting: "requesting",
    waiting: "waiting",
    receiving: "receiving",
    stopping: "stopping",
    stopped: "stopped"
  };
  var FormSubmission = class _FormSubmission {
    state = FormSubmissionState.initialized;
    static confirmMethod(message, _element, _submitter) {
      return Promise.resolve(confirm(message));
    }
    constructor(delegate, formElement, submitter, mustRedirect = false) {
      const method = getMethod(formElement, submitter);
      const action = getAction(getFormAction(formElement, submitter), method);
      const body = buildFormData(formElement, submitter);
      const enctype = getEnctype(formElement, submitter);
      this.delegate = delegate;
      this.formElement = formElement;
      this.submitter = submitter;
      this.fetchRequest = new FetchRequest(this, method, action, body, formElement, enctype);
      this.mustRedirect = mustRedirect;
    }
    get method() {
      return this.fetchRequest.method;
    }
    set method(value) {
      this.fetchRequest.method = value;
    }
    get action() {
      return this.fetchRequest.url.toString();
    }
    set action(value) {
      this.fetchRequest.url = expandURL(value);
    }
    get body() {
      return this.fetchRequest.body;
    }
    get enctype() {
      return this.fetchRequest.enctype;
    }
    get isSafe() {
      return this.fetchRequest.isSafe;
    }
    get location() {
      return this.fetchRequest.url;
    }
    // The submission process
    async start() {
      const { initialized, requesting } = FormSubmissionState;
      const confirmationMessage = getAttribute("data-turbo-confirm", this.submitter, this.formElement);
      if (typeof confirmationMessage === "string") {
        const answer = await _FormSubmission.confirmMethod(confirmationMessage, this.formElement, this.submitter);
        if (!answer) {
          return;
        }
      }
      if (this.state == initialized) {
        this.state = requesting;
        return this.fetchRequest.perform();
      }
    }
    stop() {
      const { stopping, stopped } = FormSubmissionState;
      if (this.state != stopping && this.state != stopped) {
        this.state = stopping;
        this.fetchRequest.cancel();
        return true;
      }
    }
    // Fetch request delegate
    prepareRequest(request3) {
      if (!request3.isSafe) {
        const token = getCookieValue(getMetaContent("csrf-param")) || getMetaContent("csrf-token");
        if (token) {
          request3.headers["X-CSRF-Token"] = token;
        }
      }
      if (this.requestAcceptsTurboStreamResponse(request3)) {
        request3.acceptResponseType(StreamMessage.contentType);
      }
    }
    requestStarted(_request) {
      this.state = FormSubmissionState.waiting;
      this.submitter?.setAttribute("disabled", "");
      this.setSubmitsWith();
      markAsBusy(this.formElement);
      dispatch("turbo:submit-start", {
        target: this.formElement,
        detail: { formSubmission: this }
      });
      this.delegate.formSubmissionStarted(this);
    }
    requestPreventedHandlingResponse(request3, response2) {
      prefetchCache.clear();
      this.result = { success: response2.succeeded, fetchResponse: response2 };
    }
    requestSucceededWithResponse(request3, response2) {
      if (response2.clientError || response2.serverError) {
        this.delegate.formSubmissionFailedWithResponse(this, response2);
        return;
      }
      prefetchCache.clear();
      if (this.requestMustRedirect(request3) && responseSucceededWithoutRedirect(response2)) {
        const error3 = new Error("Form responses must redirect to another location");
        this.delegate.formSubmissionErrored(this, error3);
      } else {
        this.state = FormSubmissionState.receiving;
        this.result = { success: true, fetchResponse: response2 };
        this.delegate.formSubmissionSucceededWithResponse(this, response2);
      }
    }
    requestFailedWithResponse(request3, response2) {
      this.result = { success: false, fetchResponse: response2 };
      this.delegate.formSubmissionFailedWithResponse(this, response2);
    }
    requestErrored(request3, error3) {
      this.result = { success: false, error: error3 };
      this.delegate.formSubmissionErrored(this, error3);
    }
    requestFinished(_request) {
      this.state = FormSubmissionState.stopped;
      this.submitter?.removeAttribute("disabled");
      this.resetSubmitterText();
      clearBusyState(this.formElement);
      dispatch("turbo:submit-end", {
        target: this.formElement,
        detail: { formSubmission: this, ...this.result }
      });
      this.delegate.formSubmissionFinished(this);
    }
    // Private
    setSubmitsWith() {
      if (!this.submitter || !this.submitsWith) return;
      if (this.submitter.matches("button")) {
        this.originalSubmitText = this.submitter.innerHTML;
        this.submitter.innerHTML = this.submitsWith;
      } else if (this.submitter.matches("input")) {
        const input = this.submitter;
        this.originalSubmitText = input.value;
        input.value = this.submitsWith;
      }
    }
    resetSubmitterText() {
      if (!this.submitter || !this.originalSubmitText) return;
      if (this.submitter.matches("button")) {
        this.submitter.innerHTML = this.originalSubmitText;
      } else if (this.submitter.matches("input")) {
        const input = this.submitter;
        input.value = this.originalSubmitText;
      }
    }
    requestMustRedirect(request3) {
      return !request3.isSafe && this.mustRedirect;
    }
    requestAcceptsTurboStreamResponse(request3) {
      return !request3.isSafe || hasAttribute("data-turbo-stream", this.submitter, this.formElement);
    }
    get submitsWith() {
      return this.submitter?.getAttribute("data-turbo-submits-with");
    }
  };
  function buildFormData(formElement, submitter) {
    const formData = new FormData(formElement);
    const name3 = submitter?.getAttribute("name");
    const value = submitter?.getAttribute("value");
    if (name3) {
      formData.append(name3, value || "");
    }
    return formData;
  }
  function getCookieValue(cookieName) {
    if (cookieName != null) {
      const cookies = document.cookie ? document.cookie.split("; ") : [];
      const cookie = cookies.find((cookie2) => cookie2.startsWith(cookieName));
      if (cookie) {
        const value = cookie.split("=").slice(1).join("=");
        return value ? decodeURIComponent(value) : void 0;
      }
    }
  }
  function responseSucceededWithoutRedirect(response2) {
    return response2.statusCode == 200 && !response2.redirected;
  }
  function getFormAction(formElement, submitter) {
    const formElementAction = typeof formElement.action === "string" ? formElement.action : null;
    if (submitter?.hasAttribute("formaction")) {
      return submitter.getAttribute("formaction") || "";
    } else {
      return formElement.getAttribute("action") || formElementAction || "";
    }
  }
  function getAction(formAction, fetchMethod) {
    const action = expandURL(formAction);
    if (isSafe(fetchMethod)) {
      action.search = "";
    }
    return action;
  }
  function getMethod(formElement, submitter) {
    const method = submitter?.getAttribute("formmethod") || formElement.getAttribute("method") || "";
    return fetchMethodFromString(method.toLowerCase()) || FetchMethod.get;
  }
  function getEnctype(formElement, submitter) {
    return fetchEnctypeFromString(submitter?.getAttribute("formenctype") || formElement.enctype);
  }
  var Snapshot = class {
    constructor(element) {
      this.element = element;
    }
    get activeElement() {
      return this.element.ownerDocument.activeElement;
    }
    get children() {
      return [...this.element.children];
    }
    hasAnchor(anchor) {
      return this.getElementForAnchor(anchor) != null;
    }
    getElementForAnchor(anchor) {
      return anchor ? this.element.querySelector(`[id='${anchor}'], a[name='${anchor}']`) : null;
    }
    get isConnected() {
      return this.element.isConnected;
    }
    get firstAutofocusableElement() {
      return queryAutofocusableElement(this.element);
    }
    get permanentElements() {
      return queryPermanentElementsAll(this.element);
    }
    getPermanentElementById(id) {
      return getPermanentElementById(this.element, id);
    }
    getPermanentElementMapForSnapshot(snapshot) {
      const permanentElementMap = {};
      for (const currentPermanentElement of this.permanentElements) {
        const { id } = currentPermanentElement;
        const newPermanentElement = snapshot.getPermanentElementById(id);
        if (newPermanentElement) {
          permanentElementMap[id] = [currentPermanentElement, newPermanentElement];
        }
      }
      return permanentElementMap;
    }
  };
  function getPermanentElementById(node, id) {
    return node.querySelector(`#${id}[data-turbo-permanent]`);
  }
  function queryPermanentElementsAll(node) {
    return node.querySelectorAll("[id][data-turbo-permanent]");
  }
  var FormSubmitObserver = class {
    started = false;
    constructor(delegate, eventTarget) {
      this.delegate = delegate;
      this.eventTarget = eventTarget;
    }
    start() {
      if (!this.started) {
        this.eventTarget.addEventListener("submit", this.submitCaptured, true);
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        this.eventTarget.removeEventListener("submit", this.submitCaptured, true);
        this.started = false;
      }
    }
    submitCaptured = () => {
      this.eventTarget.removeEventListener("submit", this.submitBubbled, false);
      this.eventTarget.addEventListener("submit", this.submitBubbled, false);
    };
    submitBubbled = (event) => {
      if (!event.defaultPrevented) {
        const form = event.target instanceof HTMLFormElement ? event.target : void 0;
        const submitter = event.submitter || void 0;
        if (form && submissionDoesNotDismissDialog(form, submitter) && submissionDoesNotTargetIFrame(form, submitter) && this.delegate.willSubmitForm(form, submitter)) {
          event.preventDefault();
          event.stopImmediatePropagation();
          this.delegate.formSubmitted(form, submitter);
        }
      }
    };
  };
  function submissionDoesNotDismissDialog(form, submitter) {
    const method = submitter?.getAttribute("formmethod") || form.getAttribute("method");
    return method != "dialog";
  }
  function submissionDoesNotTargetIFrame(form, submitter) {
    if (submitter?.hasAttribute("formtarget") || form.hasAttribute("target")) {
      const target = submitter?.getAttribute("formtarget") || form.target;
      for (const element of document.getElementsByName(target)) {
        if (element instanceof HTMLIFrameElement) return false;
      }
      return true;
    } else {
      return true;
    }
  }
  var View = class {
    #resolveRenderPromise = (_value) => {
    };
    #resolveInterceptionPromise = (_value) => {
    };
    constructor(delegate, element) {
      this.delegate = delegate;
      this.element = element;
    }
    // Scrolling
    scrollToAnchor(anchor) {
      const element = this.snapshot.getElementForAnchor(anchor);
      if (element) {
        this.scrollToElement(element);
        this.focusElement(element);
      } else {
        this.scrollToPosition({ x: 0, y: 0 });
      }
    }
    scrollToAnchorFromLocation(location2) {
      this.scrollToAnchor(getAnchor(location2));
    }
    scrollToElement(element) {
      element.scrollIntoView();
    }
    focusElement(element) {
      if (element instanceof HTMLElement) {
        if (element.hasAttribute("tabindex")) {
          element.focus();
        } else {
          element.setAttribute("tabindex", "-1");
          element.focus();
          element.removeAttribute("tabindex");
        }
      }
    }
    scrollToPosition({ x: x2, y }) {
      this.scrollRoot.scrollTo(x2, y);
    }
    scrollToTop() {
      this.scrollToPosition({ x: 0, y: 0 });
    }
    get scrollRoot() {
      return window;
    }
    // Rendering
    async render(renderer) {
      const { isPreview, shouldRender, willRender, newSnapshot: snapshot } = renderer;
      const shouldInvalidate = willRender;
      if (shouldRender) {
        try {
          this.renderPromise = new Promise((resolve) => this.#resolveRenderPromise = resolve);
          this.renderer = renderer;
          await this.prepareToRenderSnapshot(renderer);
          const renderInterception = new Promise((resolve) => this.#resolveInterceptionPromise = resolve);
          const options = { resume: this.#resolveInterceptionPromise, render: this.renderer.renderElement, renderMethod: this.renderer.renderMethod };
          const immediateRender = this.delegate.allowsImmediateRender(snapshot, options);
          if (!immediateRender) await renderInterception;
          await this.renderSnapshot(renderer);
          this.delegate.viewRenderedSnapshot(snapshot, isPreview, this.renderer.renderMethod);
          this.delegate.preloadOnLoadLinksForView(this.element);
          this.finishRenderingSnapshot(renderer);
        } finally {
          delete this.renderer;
          this.#resolveRenderPromise(void 0);
          delete this.renderPromise;
        }
      } else if (shouldInvalidate) {
        this.invalidate(renderer.reloadReason);
      }
    }
    invalidate(reason) {
      this.delegate.viewInvalidated(reason);
    }
    async prepareToRenderSnapshot(renderer) {
      this.markAsPreview(renderer.isPreview);
      await renderer.prepareToRender();
    }
    markAsPreview(isPreview) {
      if (isPreview) {
        this.element.setAttribute("data-turbo-preview", "");
      } else {
        this.element.removeAttribute("data-turbo-preview");
      }
    }
    markVisitDirection(direction) {
      this.element.setAttribute("data-turbo-visit-direction", direction);
    }
    unmarkVisitDirection() {
      this.element.removeAttribute("data-turbo-visit-direction");
    }
    async renderSnapshot(renderer) {
      await renderer.render();
    }
    finishRenderingSnapshot(renderer) {
      renderer.finishRendering();
    }
  };
  var FrameView = class extends View {
    missing() {
      this.element.innerHTML = `<strong class="turbo-frame-error">Content missing</strong>`;
    }
    get snapshot() {
      return new Snapshot(this.element);
    }
  };
  var LinkInterceptor = class {
    constructor(delegate, element) {
      this.delegate = delegate;
      this.element = element;
    }
    start() {
      this.element.addEventListener("click", this.clickBubbled);
      document.addEventListener("turbo:click", this.linkClicked);
      document.addEventListener("turbo:before-visit", this.willVisit);
    }
    stop() {
      this.element.removeEventListener("click", this.clickBubbled);
      document.removeEventListener("turbo:click", this.linkClicked);
      document.removeEventListener("turbo:before-visit", this.willVisit);
    }
    clickBubbled = (event) => {
      if (this.respondsToEventTarget(event.target)) {
        this.clickEvent = event;
      } else {
        delete this.clickEvent;
      }
    };
    linkClicked = (event) => {
      if (this.clickEvent && this.respondsToEventTarget(event.target) && event.target instanceof Element) {
        if (this.delegate.shouldInterceptLinkClick(event.target, event.detail.url, event.detail.originalEvent)) {
          this.clickEvent.preventDefault();
          event.preventDefault();
          this.delegate.linkClickIntercepted(event.target, event.detail.url, event.detail.originalEvent);
        }
      }
      delete this.clickEvent;
    };
    willVisit = (_event) => {
      delete this.clickEvent;
    };
    respondsToEventTarget(target) {
      const element = target instanceof Element ? target : target instanceof Node ? target.parentElement : null;
      return element && element.closest("turbo-frame, html") == this.element;
    }
  };
  var LinkClickObserver = class {
    started = false;
    constructor(delegate, eventTarget) {
      this.delegate = delegate;
      this.eventTarget = eventTarget;
    }
    start() {
      if (!this.started) {
        this.eventTarget.addEventListener("click", this.clickCaptured, true);
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        this.eventTarget.removeEventListener("click", this.clickCaptured, true);
        this.started = false;
      }
    }
    clickCaptured = () => {
      this.eventTarget.removeEventListener("click", this.clickBubbled, false);
      this.eventTarget.addEventListener("click", this.clickBubbled, false);
    };
    clickBubbled = (event) => {
      if (event instanceof MouseEvent && this.clickEventIsSignificant(event)) {
        const target = event.composedPath && event.composedPath()[0] || event.target;
        const link = findLinkFromClickTarget(target);
        if (link && doesNotTargetIFrame(link)) {
          const location2 = getLocationForLink(link);
          if (this.delegate.willFollowLinkToLocation(link, location2, event)) {
            event.preventDefault();
            this.delegate.followedLinkToLocation(link, location2);
          }
        }
      }
    };
    clickEventIsSignificant(event) {
      return !(event.target && event.target.isContentEditable || event.defaultPrevented || event.which > 1 || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey);
    }
  };
  var FormLinkClickObserver = class {
    constructor(delegate, element) {
      this.delegate = delegate;
      this.linkInterceptor = new LinkClickObserver(this, element);
    }
    start() {
      this.linkInterceptor.start();
    }
    stop() {
      this.linkInterceptor.stop();
    }
    // Link hover observer delegate
    canPrefetchRequestToLocation(link, location2) {
      return false;
    }
    prefetchAndCacheRequestToLocation(link, location2) {
      return;
    }
    // Link click observer delegate
    willFollowLinkToLocation(link, location2, originalEvent) {
      return this.delegate.willSubmitFormLinkToLocation(link, location2, originalEvent) && (link.hasAttribute("data-turbo-method") || link.hasAttribute("data-turbo-stream"));
    }
    followedLinkToLocation(link, location2) {
      const form = document.createElement("form");
      const type = "hidden";
      for (const [name3, value] of location2.searchParams) {
        form.append(Object.assign(document.createElement("input"), { type, name: name3, value }));
      }
      const action = Object.assign(location2, { search: "" });
      form.setAttribute("data-turbo", "true");
      form.setAttribute("action", action.href);
      form.setAttribute("hidden", "");
      const method = link.getAttribute("data-turbo-method");
      if (method) form.setAttribute("method", method);
      const turboFrame = link.getAttribute("data-turbo-frame");
      if (turboFrame) form.setAttribute("data-turbo-frame", turboFrame);
      const turboAction = getVisitAction(link);
      if (turboAction) form.setAttribute("data-turbo-action", turboAction);
      const turboConfirm = link.getAttribute("data-turbo-confirm");
      if (turboConfirm) form.setAttribute("data-turbo-confirm", turboConfirm);
      const turboStream = link.hasAttribute("data-turbo-stream");
      if (turboStream) form.setAttribute("data-turbo-stream", "");
      this.delegate.submittedFormLinkToLocation(link, location2, form);
      document.body.appendChild(form);
      form.addEventListener("turbo:submit-end", () => form.remove(), { once: true });
      requestAnimationFrame(() => form.requestSubmit());
    }
  };
  var Bardo = class {
    static async preservingPermanentElements(delegate, permanentElementMap, callback) {
      const bardo = new this(delegate, permanentElementMap);
      bardo.enter();
      await callback();
      bardo.leave();
    }
    constructor(delegate, permanentElementMap) {
      this.delegate = delegate;
      this.permanentElementMap = permanentElementMap;
    }
    enter() {
      for (const id in this.permanentElementMap) {
        const [currentPermanentElement, newPermanentElement] = this.permanentElementMap[id];
        this.delegate.enteringBardo(currentPermanentElement, newPermanentElement);
        this.replaceNewPermanentElementWithPlaceholder(newPermanentElement);
      }
    }
    leave() {
      for (const id in this.permanentElementMap) {
        const [currentPermanentElement] = this.permanentElementMap[id];
        this.replaceCurrentPermanentElementWithClone(currentPermanentElement);
        this.replacePlaceholderWithPermanentElement(currentPermanentElement);
        this.delegate.leavingBardo(currentPermanentElement);
      }
    }
    replaceNewPermanentElementWithPlaceholder(permanentElement) {
      const placeholder = createPlaceholderForPermanentElement(permanentElement);
      permanentElement.replaceWith(placeholder);
    }
    replaceCurrentPermanentElementWithClone(permanentElement) {
      const clone = permanentElement.cloneNode(true);
      permanentElement.replaceWith(clone);
    }
    replacePlaceholderWithPermanentElement(permanentElement) {
      const placeholder = this.getPlaceholderById(permanentElement.id);
      placeholder?.replaceWith(permanentElement);
    }
    getPlaceholderById(id) {
      return this.placeholders.find((element) => element.content == id);
    }
    get placeholders() {
      return [...document.querySelectorAll("meta[name=turbo-permanent-placeholder][content]")];
    }
  };
  function createPlaceholderForPermanentElement(permanentElement) {
    const element = document.createElement("meta");
    element.setAttribute("name", "turbo-permanent-placeholder");
    element.setAttribute("content", permanentElement.id);
    return element;
  }
  var Renderer = class {
    #activeElement = null;
    constructor(currentSnapshot, newSnapshot, renderElement, isPreview, willRender = true) {
      this.currentSnapshot = currentSnapshot;
      this.newSnapshot = newSnapshot;
      this.isPreview = isPreview;
      this.willRender = willRender;
      this.renderElement = renderElement;
      this.promise = new Promise((resolve, reject) => this.resolvingFunctions = { resolve, reject });
    }
    get shouldRender() {
      return true;
    }
    get reloadReason() {
      return;
    }
    prepareToRender() {
      return;
    }
    render() {
    }
    finishRendering() {
      if (this.resolvingFunctions) {
        this.resolvingFunctions.resolve();
        delete this.resolvingFunctions;
      }
    }
    async preservingPermanentElements(callback) {
      await Bardo.preservingPermanentElements(this, this.permanentElementMap, callback);
    }
    focusFirstAutofocusableElement() {
      const element = this.connectedSnapshot.firstAutofocusableElement;
      if (element) {
        element.focus();
      }
    }
    // Bardo delegate
    enteringBardo(currentPermanentElement) {
      if (this.#activeElement) return;
      if (currentPermanentElement.contains(this.currentSnapshot.activeElement)) {
        this.#activeElement = this.currentSnapshot.activeElement;
      }
    }
    leavingBardo(currentPermanentElement) {
      if (currentPermanentElement.contains(this.#activeElement) && this.#activeElement instanceof HTMLElement) {
        this.#activeElement.focus();
        this.#activeElement = null;
      }
    }
    get connectedSnapshot() {
      return this.newSnapshot.isConnected ? this.newSnapshot : this.currentSnapshot;
    }
    get currentElement() {
      return this.currentSnapshot.element;
    }
    get newElement() {
      return this.newSnapshot.element;
    }
    get permanentElementMap() {
      return this.currentSnapshot.getPermanentElementMapForSnapshot(this.newSnapshot);
    }
    get renderMethod() {
      return "replace";
    }
  };
  var FrameRenderer = class extends Renderer {
    static renderElement(currentElement, newElement) {
      const destinationRange = document.createRange();
      destinationRange.selectNodeContents(currentElement);
      destinationRange.deleteContents();
      const frameElement = newElement;
      const sourceRange = frameElement.ownerDocument?.createRange();
      if (sourceRange) {
        sourceRange.selectNodeContents(frameElement);
        currentElement.appendChild(sourceRange.extractContents());
      }
    }
    constructor(delegate, currentSnapshot, newSnapshot, renderElement, isPreview, willRender = true) {
      super(currentSnapshot, newSnapshot, renderElement, isPreview, willRender);
      this.delegate = delegate;
    }
    get shouldRender() {
      return true;
    }
    async render() {
      await nextRepaint();
      this.preservingPermanentElements(() => {
        this.loadFrameElement();
      });
      this.scrollFrameIntoView();
      await nextRepaint();
      this.focusFirstAutofocusableElement();
      await nextRepaint();
      this.activateScriptElements();
    }
    loadFrameElement() {
      this.delegate.willRenderFrame(this.currentElement, this.newElement);
      this.renderElement(this.currentElement, this.newElement);
    }
    scrollFrameIntoView() {
      if (this.currentElement.autoscroll || this.newElement.autoscroll) {
        const element = this.currentElement.firstElementChild;
        const block = readScrollLogicalPosition(this.currentElement.getAttribute("data-autoscroll-block"), "end");
        const behavior = readScrollBehavior(this.currentElement.getAttribute("data-autoscroll-behavior"), "auto");
        if (element) {
          element.scrollIntoView({ block, behavior });
          return true;
        }
      }
      return false;
    }
    activateScriptElements() {
      for (const inertScriptElement of this.newScriptElements) {
        const activatedScriptElement = activateScriptElement(inertScriptElement);
        inertScriptElement.replaceWith(activatedScriptElement);
      }
    }
    get newScriptElements() {
      return this.currentElement.querySelectorAll("script");
    }
  };
  function readScrollLogicalPosition(value, defaultValue) {
    if (value == "end" || value == "start" || value == "center" || value == "nearest") {
      return value;
    } else {
      return defaultValue;
    }
  }
  function readScrollBehavior(value, defaultValue) {
    if (value == "auto" || value == "smooth") {
      return value;
    } else {
      return defaultValue;
    }
  }
  var ProgressBar = class _ProgressBar {
    static animationDuration = 300;
    /*ms*/
    static get defaultCSS() {
      return unindent`
      .turbo-progress-bar {
        position: fixed;
        display: block;
        top: 0;
        left: 0;
        height: 3px;
        background: #0076ff;
        z-index: 2147483647;
        transition:
          width ${_ProgressBar.animationDuration}ms ease-out,
          opacity ${_ProgressBar.animationDuration / 2}ms ${_ProgressBar.animationDuration / 2}ms ease-in;
        transform: translate3d(0, 0, 0);
      }
    `;
    }
    hiding = false;
    value = 0;
    visible = false;
    constructor() {
      this.stylesheetElement = this.createStylesheetElement();
      this.progressElement = this.createProgressElement();
      this.installStylesheetElement();
      this.setValue(0);
    }
    show() {
      if (!this.visible) {
        this.visible = true;
        this.installProgressElement();
        this.startTrickling();
      }
    }
    hide() {
      if (this.visible && !this.hiding) {
        this.hiding = true;
        this.fadeProgressElement(() => {
          this.uninstallProgressElement();
          this.stopTrickling();
          this.visible = false;
          this.hiding = false;
        });
      }
    }
    setValue(value) {
      this.value = value;
      this.refresh();
    }
    // Private
    installStylesheetElement() {
      document.head.insertBefore(this.stylesheetElement, document.head.firstChild);
    }
    installProgressElement() {
      this.progressElement.style.width = "0";
      this.progressElement.style.opacity = "1";
      document.documentElement.insertBefore(this.progressElement, document.body);
      this.refresh();
    }
    fadeProgressElement(callback) {
      this.progressElement.style.opacity = "0";
      setTimeout(callback, _ProgressBar.animationDuration * 1.5);
    }
    uninstallProgressElement() {
      if (this.progressElement.parentNode) {
        document.documentElement.removeChild(this.progressElement);
      }
    }
    startTrickling() {
      if (!this.trickleInterval) {
        this.trickleInterval = window.setInterval(this.trickle, _ProgressBar.animationDuration);
      }
    }
    stopTrickling() {
      window.clearInterval(this.trickleInterval);
      delete this.trickleInterval;
    }
    trickle = () => {
      this.setValue(this.value + Math.random() / 100);
    };
    refresh() {
      requestAnimationFrame(() => {
        this.progressElement.style.width = `${10 + this.value * 90}%`;
      });
    }
    createStylesheetElement() {
      const element = document.createElement("style");
      element.type = "text/css";
      element.textContent = _ProgressBar.defaultCSS;
      if (this.cspNonce) {
        element.nonce = this.cspNonce;
      }
      return element;
    }
    createProgressElement() {
      const element = document.createElement("div");
      element.className = "turbo-progress-bar";
      return element;
    }
    get cspNonce() {
      return getMetaContent("csp-nonce");
    }
  };
  var HeadSnapshot = class extends Snapshot {
    detailsByOuterHTML = this.children.filter((element) => !elementIsNoscript(element)).map((element) => elementWithoutNonce(element)).reduce((result, element) => {
      const { outerHTML } = element;
      const details = outerHTML in result ? result[outerHTML] : {
        type: elementType(element),
        tracked: elementIsTracked(element),
        elements: []
      };
      return {
        ...result,
        [outerHTML]: {
          ...details,
          elements: [...details.elements, element]
        }
      };
    }, {});
    get trackedElementSignature() {
      return Object.keys(this.detailsByOuterHTML).filter((outerHTML) => this.detailsByOuterHTML[outerHTML].tracked).join("");
    }
    getScriptElementsNotInSnapshot(snapshot) {
      return this.getElementsMatchingTypeNotInSnapshot("script", snapshot);
    }
    getStylesheetElementsNotInSnapshot(snapshot) {
      return this.getElementsMatchingTypeNotInSnapshot("stylesheet", snapshot);
    }
    getElementsMatchingTypeNotInSnapshot(matchedType, snapshot) {
      return Object.keys(this.detailsByOuterHTML).filter((outerHTML) => !(outerHTML in snapshot.detailsByOuterHTML)).map((outerHTML) => this.detailsByOuterHTML[outerHTML]).filter(({ type }) => type == matchedType).map(({ elements: [element] }) => element);
    }
    get provisionalElements() {
      return Object.keys(this.detailsByOuterHTML).reduce((result, outerHTML) => {
        const { type, tracked, elements } = this.detailsByOuterHTML[outerHTML];
        if (type == null && !tracked) {
          return [...result, ...elements];
        } else if (elements.length > 1) {
          return [...result, ...elements.slice(1)];
        } else {
          return result;
        }
      }, []);
    }
    getMetaValue(name3) {
      const element = this.findMetaElementByName(name3);
      return element ? element.getAttribute("content") : null;
    }
    findMetaElementByName(name3) {
      return Object.keys(this.detailsByOuterHTML).reduce((result, outerHTML) => {
        const {
          elements: [element]
        } = this.detailsByOuterHTML[outerHTML];
        return elementIsMetaElementWithName(element, name3) ? element : result;
      }, void 0 | void 0);
    }
  };
  function elementType(element) {
    if (elementIsScript(element)) {
      return "script";
    } else if (elementIsStylesheet(element)) {
      return "stylesheet";
    }
  }
  function elementIsTracked(element) {
    return element.getAttribute("data-turbo-track") == "reload";
  }
  function elementIsScript(element) {
    const tagName = element.localName;
    return tagName == "script";
  }
  function elementIsNoscript(element) {
    const tagName = element.localName;
    return tagName == "noscript";
  }
  function elementIsStylesheet(element) {
    const tagName = element.localName;
    return tagName == "style" || tagName == "link" && element.getAttribute("rel") == "stylesheet";
  }
  function elementIsMetaElementWithName(element, name3) {
    const tagName = element.localName;
    return tagName == "meta" && element.getAttribute("name") == name3;
  }
  function elementWithoutNonce(element) {
    if (element.hasAttribute("nonce")) {
      element.setAttribute("nonce", "");
    }
    return element;
  }
  var PageSnapshot = class _PageSnapshot extends Snapshot {
    static fromHTMLString(html = "") {
      return this.fromDocument(parseHTMLDocument(html));
    }
    static fromElement(element) {
      return this.fromDocument(element.ownerDocument);
    }
    static fromDocument({ documentElement, body, head }) {
      return new this(documentElement, body, new HeadSnapshot(head));
    }
    constructor(documentElement, body, headSnapshot) {
      super(body);
      this.documentElement = documentElement;
      this.headSnapshot = headSnapshot;
    }
    clone() {
      const clonedElement = this.element.cloneNode(true);
      const selectElements = this.element.querySelectorAll("select");
      const clonedSelectElements = clonedElement.querySelectorAll("select");
      for (const [index, source] of selectElements.entries()) {
        const clone = clonedSelectElements[index];
        for (const option of clone.selectedOptions) option.selected = false;
        for (const option of source.selectedOptions) clone.options[option.index].selected = true;
      }
      for (const clonedPasswordInput of clonedElement.querySelectorAll('input[type="password"]')) {
        clonedPasswordInput.value = "";
      }
      return new _PageSnapshot(this.documentElement, clonedElement, this.headSnapshot);
    }
    get lang() {
      return this.documentElement.getAttribute("lang");
    }
    get headElement() {
      return this.headSnapshot.element;
    }
    get rootLocation() {
      const root = this.getSetting("root") ?? "/";
      return expandURL(root);
    }
    get cacheControlValue() {
      return this.getSetting("cache-control");
    }
    get isPreviewable() {
      return this.cacheControlValue != "no-preview";
    }
    get isCacheable() {
      return this.cacheControlValue != "no-cache";
    }
    get isVisitable() {
      return this.getSetting("visit-control") != "reload";
    }
    get prefersViewTransitions() {
      return this.headSnapshot.getMetaValue("view-transition") === "same-origin";
    }
    get shouldMorphPage() {
      return this.getSetting("refresh-method") === "morph";
    }
    get shouldPreserveScrollPosition() {
      return this.getSetting("refresh-scroll") === "preserve";
    }
    // Private
    getSetting(name3) {
      return this.headSnapshot.getMetaValue(`turbo-${name3}`);
    }
  };
  var ViewTransitioner = class {
    #viewTransitionStarted = false;
    #lastOperation = Promise.resolve();
    renderChange(useViewTransition, render2) {
      if (useViewTransition && this.viewTransitionsAvailable && !this.#viewTransitionStarted) {
        this.#viewTransitionStarted = true;
        this.#lastOperation = this.#lastOperation.then(async () => {
          await document.startViewTransition(render2).finished;
        });
      } else {
        this.#lastOperation = this.#lastOperation.then(render2);
      }
      return this.#lastOperation;
    }
    get viewTransitionsAvailable() {
      return document.startViewTransition;
    }
  };
  var defaultOptions = {
    action: "advance",
    historyChanged: false,
    visitCachedSnapshot: () => {
    },
    willRender: true,
    updateHistory: true,
    shouldCacheSnapshot: true,
    acceptsStreamResponse: false
  };
  var TimingMetric = {
    visitStart: "visitStart",
    requestStart: "requestStart",
    requestEnd: "requestEnd",
    visitEnd: "visitEnd"
  };
  var VisitState = {
    initialized: "initialized",
    started: "started",
    canceled: "canceled",
    failed: "failed",
    completed: "completed"
  };
  var SystemStatusCode = {
    networkFailure: 0,
    timeoutFailure: -1,
    contentTypeMismatch: -2
  };
  var Direction = {
    advance: "forward",
    restore: "back",
    replace: "none"
  };
  var Visit = class {
    identifier = uuid();
    // Required by turbo-ios
    timingMetrics = {};
    followedRedirect = false;
    historyChanged = false;
    scrolled = false;
    shouldCacheSnapshot = true;
    acceptsStreamResponse = false;
    snapshotCached = false;
    state = VisitState.initialized;
    viewTransitioner = new ViewTransitioner();
    constructor(delegate, location2, restorationIdentifier, options = {}) {
      this.delegate = delegate;
      this.location = location2;
      this.restorationIdentifier = restorationIdentifier || uuid();
      const {
        action,
        historyChanged,
        referrer,
        snapshot,
        snapshotHTML,
        response: response2,
        visitCachedSnapshot,
        willRender,
        updateHistory,
        shouldCacheSnapshot,
        acceptsStreamResponse,
        direction
      } = {
        ...defaultOptions,
        ...options
      };
      this.action = action;
      this.historyChanged = historyChanged;
      this.referrer = referrer;
      this.snapshot = snapshot;
      this.snapshotHTML = snapshotHTML;
      this.response = response2;
      this.isSamePage = this.delegate.locationWithActionIsSamePage(this.location, this.action);
      this.isPageRefresh = this.view.isPageRefresh(this);
      this.visitCachedSnapshot = visitCachedSnapshot;
      this.willRender = willRender;
      this.updateHistory = updateHistory;
      this.scrolled = !willRender;
      this.shouldCacheSnapshot = shouldCacheSnapshot;
      this.acceptsStreamResponse = acceptsStreamResponse;
      this.direction = direction || Direction[action];
    }
    get adapter() {
      return this.delegate.adapter;
    }
    get view() {
      return this.delegate.view;
    }
    get history() {
      return this.delegate.history;
    }
    get restorationData() {
      return this.history.getRestorationDataForIdentifier(this.restorationIdentifier);
    }
    get silent() {
      return this.isSamePage;
    }
    start() {
      if (this.state == VisitState.initialized) {
        this.recordTimingMetric(TimingMetric.visitStart);
        this.state = VisitState.started;
        this.adapter.visitStarted(this);
        this.delegate.visitStarted(this);
      }
    }
    cancel() {
      if (this.state == VisitState.started) {
        if (this.request) {
          this.request.cancel();
        }
        this.cancelRender();
        this.state = VisitState.canceled;
      }
    }
    complete() {
      if (this.state == VisitState.started) {
        this.recordTimingMetric(TimingMetric.visitEnd);
        this.adapter.visitCompleted(this);
        this.state = VisitState.completed;
        this.followRedirect();
        if (!this.followedRedirect) {
          this.delegate.visitCompleted(this);
        }
      }
    }
    fail() {
      if (this.state == VisitState.started) {
        this.state = VisitState.failed;
        this.adapter.visitFailed(this);
        this.delegate.visitCompleted(this);
      }
    }
    changeHistory() {
      if (!this.historyChanged && this.updateHistory) {
        const actionForHistory = this.location.href === this.referrer?.href ? "replace" : this.action;
        const method = getHistoryMethodForAction(actionForHistory);
        this.history.update(method, this.location, this.restorationIdentifier);
        this.historyChanged = true;
      }
    }
    issueRequest() {
      if (this.hasPreloadedResponse()) {
        this.simulateRequest();
      } else if (this.shouldIssueRequest() && !this.request) {
        this.request = new FetchRequest(this, FetchMethod.get, this.location);
        this.request.perform();
      }
    }
    simulateRequest() {
      if (this.response) {
        this.startRequest();
        this.recordResponse();
        this.finishRequest();
      }
    }
    startRequest() {
      this.recordTimingMetric(TimingMetric.requestStart);
      this.adapter.visitRequestStarted(this);
    }
    recordResponse(response2 = this.response) {
      this.response = response2;
      if (response2) {
        const { statusCode } = response2;
        if (isSuccessful(statusCode)) {
          this.adapter.visitRequestCompleted(this);
        } else {
          this.adapter.visitRequestFailedWithStatusCode(this, statusCode);
        }
      }
    }
    finishRequest() {
      this.recordTimingMetric(TimingMetric.requestEnd);
      this.adapter.visitRequestFinished(this);
    }
    loadResponse() {
      if (this.response) {
        const { statusCode, responseHTML } = this.response;
        this.render(async () => {
          if (this.shouldCacheSnapshot) this.cacheSnapshot();
          if (this.view.renderPromise) await this.view.renderPromise;
          if (isSuccessful(statusCode) && responseHTML != null) {
            const snapshot = PageSnapshot.fromHTMLString(responseHTML);
            await this.renderPageSnapshot(snapshot, false);
            this.adapter.visitRendered(this);
            this.complete();
          } else {
            await this.view.renderError(PageSnapshot.fromHTMLString(responseHTML), this);
            this.adapter.visitRendered(this);
            this.fail();
          }
        });
      }
    }
    getCachedSnapshot() {
      const snapshot = this.view.getCachedSnapshotForLocation(this.location) || this.getPreloadedSnapshot();
      if (snapshot && (!getAnchor(this.location) || snapshot.hasAnchor(getAnchor(this.location)))) {
        if (this.action == "restore" || snapshot.isPreviewable) {
          return snapshot;
        }
      }
    }
    getPreloadedSnapshot() {
      if (this.snapshotHTML) {
        return PageSnapshot.fromHTMLString(this.snapshotHTML);
      }
    }
    hasCachedSnapshot() {
      return this.getCachedSnapshot() != null;
    }
    loadCachedSnapshot() {
      const snapshot = this.getCachedSnapshot();
      if (snapshot) {
        const isPreview = this.shouldIssueRequest();
        this.render(async () => {
          this.cacheSnapshot();
          if (this.isSamePage || this.isPageRefresh) {
            this.adapter.visitRendered(this);
          } else {
            if (this.view.renderPromise) await this.view.renderPromise;
            await this.renderPageSnapshot(snapshot, isPreview);
            this.adapter.visitRendered(this);
            if (!isPreview) {
              this.complete();
            }
          }
        });
      }
    }
    followRedirect() {
      if (this.redirectedToLocation && !this.followedRedirect && this.response?.redirected) {
        this.adapter.visitProposedToLocation(this.redirectedToLocation, {
          action: "replace",
          response: this.response,
          shouldCacheSnapshot: false,
          willRender: false
        });
        this.followedRedirect = true;
      }
    }
    goToSamePageAnchor() {
      if (this.isSamePage) {
        this.render(async () => {
          this.cacheSnapshot();
          this.performScroll();
          this.changeHistory();
          this.adapter.visitRendered(this);
        });
      }
    }
    // Fetch request delegate
    prepareRequest(request3) {
      if (this.acceptsStreamResponse) {
        request3.acceptResponseType(StreamMessage.contentType);
      }
    }
    requestStarted() {
      this.startRequest();
    }
    requestPreventedHandlingResponse(_request, _response) {
    }
    async requestSucceededWithResponse(request3, response2) {
      const responseHTML = await response2.responseHTML;
      const { redirected, statusCode } = response2;
      if (responseHTML == void 0) {
        this.recordResponse({
          statusCode: SystemStatusCode.contentTypeMismatch,
          redirected
        });
      } else {
        this.redirectedToLocation = response2.redirected ? response2.location : void 0;
        this.recordResponse({ statusCode, responseHTML, redirected });
      }
    }
    async requestFailedWithResponse(request3, response2) {
      const responseHTML = await response2.responseHTML;
      const { redirected, statusCode } = response2;
      if (responseHTML == void 0) {
        this.recordResponse({
          statusCode: SystemStatusCode.contentTypeMismatch,
          redirected
        });
      } else {
        this.recordResponse({ statusCode, responseHTML, redirected });
      }
    }
    requestErrored(_request, _error) {
      this.recordResponse({
        statusCode: SystemStatusCode.networkFailure,
        redirected: false
      });
    }
    requestFinished() {
      this.finishRequest();
    }
    // Scrolling
    performScroll() {
      if (!this.scrolled && !this.view.forceReloaded && !this.view.shouldPreserveScrollPosition(this)) {
        if (this.action == "restore") {
          this.scrollToRestoredPosition() || this.scrollToAnchor() || this.view.scrollToTop();
        } else {
          this.scrollToAnchor() || this.view.scrollToTop();
        }
        if (this.isSamePage) {
          this.delegate.visitScrolledToSamePageLocation(this.view.lastRenderedLocation, this.location);
        }
        this.scrolled = true;
      }
    }
    scrollToRestoredPosition() {
      const { scrollPosition } = this.restorationData;
      if (scrollPosition) {
        this.view.scrollToPosition(scrollPosition);
        return true;
      }
    }
    scrollToAnchor() {
      const anchor = getAnchor(this.location);
      if (anchor != null) {
        this.view.scrollToAnchor(anchor);
        return true;
      }
    }
    // Instrumentation
    recordTimingMetric(metric) {
      this.timingMetrics[metric] = (/* @__PURE__ */ new Date()).getTime();
    }
    getTimingMetrics() {
      return { ...this.timingMetrics };
    }
    // Private
    getHistoryMethodForAction(action) {
      switch (action) {
        case "replace":
          return history.replaceState;
        case "advance":
        case "restore":
          return history.pushState;
      }
    }
    hasPreloadedResponse() {
      return typeof this.response == "object";
    }
    shouldIssueRequest() {
      if (this.isSamePage) {
        return false;
      } else if (this.action == "restore") {
        return !this.hasCachedSnapshot();
      } else {
        return this.willRender;
      }
    }
    cacheSnapshot() {
      if (!this.snapshotCached) {
        this.view.cacheSnapshot(this.snapshot).then((snapshot) => snapshot && this.visitCachedSnapshot(snapshot));
        this.snapshotCached = true;
      }
    }
    async render(callback) {
      this.cancelRender();
      this.frame = await nextRepaint();
      await callback();
      delete this.frame;
    }
    async renderPageSnapshot(snapshot, isPreview) {
      await this.viewTransitioner.renderChange(this.view.shouldTransitionTo(snapshot), async () => {
        await this.view.renderPage(snapshot, isPreview, this.willRender, this);
        this.performScroll();
      });
    }
    cancelRender() {
      if (this.frame) {
        cancelAnimationFrame(this.frame);
        delete this.frame;
      }
    }
  };
  function isSuccessful(statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }
  var BrowserAdapter = class {
    progressBar = new ProgressBar();
    constructor(session2) {
      this.session = session2;
    }
    visitProposedToLocation(location2, options) {
      if (locationIsVisitable(location2, this.navigator.rootLocation)) {
        this.navigator.startVisit(location2, options?.restorationIdentifier || uuid(), options);
      } else {
        window.location.href = location2.toString();
      }
    }
    visitStarted(visit2) {
      this.location = visit2.location;
      visit2.loadCachedSnapshot();
      visit2.issueRequest();
      visit2.goToSamePageAnchor();
    }
    visitRequestStarted(visit2) {
      this.progressBar.setValue(0);
      if (visit2.hasCachedSnapshot() || visit2.action != "restore") {
        this.showVisitProgressBarAfterDelay();
      } else {
        this.showProgressBar();
      }
    }
    visitRequestCompleted(visit2) {
      visit2.loadResponse();
    }
    visitRequestFailedWithStatusCode(visit2, statusCode) {
      switch (statusCode) {
        case SystemStatusCode.networkFailure:
        case SystemStatusCode.timeoutFailure:
        case SystemStatusCode.contentTypeMismatch:
          return this.reload({
            reason: "request_failed",
            context: {
              statusCode
            }
          });
        default:
          return visit2.loadResponse();
      }
    }
    visitRequestFinished(_visit) {
    }
    visitCompleted(_visit) {
      this.progressBar.setValue(1);
      this.hideVisitProgressBar();
    }
    pageInvalidated(reason) {
      this.reload(reason);
    }
    visitFailed(_visit) {
      this.progressBar.setValue(1);
      this.hideVisitProgressBar();
    }
    visitRendered(_visit) {
    }
    // Form Submission Delegate
    formSubmissionStarted(_formSubmission) {
      this.progressBar.setValue(0);
      this.showFormProgressBarAfterDelay();
    }
    formSubmissionFinished(_formSubmission) {
      this.progressBar.setValue(1);
      this.hideFormProgressBar();
    }
    // Private
    showVisitProgressBarAfterDelay() {
      this.visitProgressBarTimeout = window.setTimeout(this.showProgressBar, this.session.progressBarDelay);
    }
    hideVisitProgressBar() {
      this.progressBar.hide();
      if (this.visitProgressBarTimeout != null) {
        window.clearTimeout(this.visitProgressBarTimeout);
        delete this.visitProgressBarTimeout;
      }
    }
    showFormProgressBarAfterDelay() {
      if (this.formProgressBarTimeout == null) {
        this.formProgressBarTimeout = window.setTimeout(this.showProgressBar, this.session.progressBarDelay);
      }
    }
    hideFormProgressBar() {
      this.progressBar.hide();
      if (this.formProgressBarTimeout != null) {
        window.clearTimeout(this.formProgressBarTimeout);
        delete this.formProgressBarTimeout;
      }
    }
    showProgressBar = () => {
      this.progressBar.show();
    };
    reload(reason) {
      dispatch("turbo:reload", { detail: reason });
      window.location.href = this.location?.toString() || window.location.href;
    }
    get navigator() {
      return this.session.navigator;
    }
  };
  var CacheObserver = class {
    selector = "[data-turbo-temporary]";
    deprecatedSelector = "[data-turbo-cache=false]";
    started = false;
    start() {
      if (!this.started) {
        this.started = true;
        addEventListener("turbo:before-cache", this.removeTemporaryElements, false);
      }
    }
    stop() {
      if (this.started) {
        this.started = false;
        removeEventListener("turbo:before-cache", this.removeTemporaryElements, false);
      }
    }
    removeTemporaryElements = (_event) => {
      for (const element of this.temporaryElements) {
        element.remove();
      }
    };
    get temporaryElements() {
      return [...document.querySelectorAll(this.selector), ...this.temporaryElementsWithDeprecation];
    }
    get temporaryElementsWithDeprecation() {
      const elements = document.querySelectorAll(this.deprecatedSelector);
      if (elements.length) {
        console.warn(
          `The ${this.deprecatedSelector} selector is deprecated and will be removed in a future version. Use ${this.selector} instead.`
        );
      }
      return [...elements];
    }
  };
  var FrameRedirector = class {
    constructor(session2, element) {
      this.session = session2;
      this.element = element;
      this.linkInterceptor = new LinkInterceptor(this, element);
      this.formSubmitObserver = new FormSubmitObserver(this, element);
    }
    start() {
      this.linkInterceptor.start();
      this.formSubmitObserver.start();
    }
    stop() {
      this.linkInterceptor.stop();
      this.formSubmitObserver.stop();
    }
    // Link interceptor delegate
    shouldInterceptLinkClick(element, _location, _event) {
      return this.#shouldRedirect(element);
    }
    linkClickIntercepted(element, url, event) {
      const frame = this.#findFrameElement(element);
      if (frame) {
        frame.delegate.linkClickIntercepted(element, url, event);
      }
    }
    // Form submit observer delegate
    willSubmitForm(element, submitter) {
      return element.closest("turbo-frame") == null && this.#shouldSubmit(element, submitter) && this.#shouldRedirect(element, submitter);
    }
    formSubmitted(element, submitter) {
      const frame = this.#findFrameElement(element, submitter);
      if (frame) {
        frame.delegate.formSubmitted(element, submitter);
      }
    }
    #shouldSubmit(form, submitter) {
      const action = getAction$1(form, submitter);
      const meta = this.element.ownerDocument.querySelector(`meta[name="turbo-root"]`);
      const rootLocation = expandURL(meta?.content ?? "/");
      return this.#shouldRedirect(form, submitter) && locationIsVisitable(action, rootLocation);
    }
    #shouldRedirect(element, submitter) {
      const isNavigatable = element instanceof HTMLFormElement ? this.session.submissionIsNavigatable(element, submitter) : this.session.elementIsNavigatable(element);
      if (isNavigatable) {
        const frame = this.#findFrameElement(element, submitter);
        return frame ? frame != element.closest("turbo-frame") : false;
      } else {
        return false;
      }
    }
    #findFrameElement(element, submitter) {
      const id = submitter?.getAttribute("data-turbo-frame") || element.getAttribute("data-turbo-frame");
      if (id && id != "_top") {
        const frame = this.element.querySelector(`#${id}:not([disabled])`);
        if (frame instanceof FrameElement) {
          return frame;
        }
      }
    }
  };
  var History = class {
    location;
    restorationIdentifier = uuid();
    restorationData = {};
    started = false;
    pageLoaded = false;
    currentIndex = 0;
    constructor(delegate) {
      this.delegate = delegate;
    }
    start() {
      if (!this.started) {
        addEventListener("popstate", this.onPopState, false);
        addEventListener("load", this.onPageLoad, false);
        this.currentIndex = history.state?.turbo?.restorationIndex || 0;
        this.started = true;
        this.replace(new URL(window.location.href));
      }
    }
    stop() {
      if (this.started) {
        removeEventListener("popstate", this.onPopState, false);
        removeEventListener("load", this.onPageLoad, false);
        this.started = false;
      }
    }
    push(location2, restorationIdentifier) {
      this.update(history.pushState, location2, restorationIdentifier);
    }
    replace(location2, restorationIdentifier) {
      this.update(history.replaceState, location2, restorationIdentifier);
    }
    update(method, location2, restorationIdentifier = uuid()) {
      if (method === history.pushState) ++this.currentIndex;
      const state = { turbo: { restorationIdentifier, restorationIndex: this.currentIndex } };
      method.call(history, state, "", location2.href);
      this.location = location2;
      this.restorationIdentifier = restorationIdentifier;
    }
    // Restoration data
    getRestorationDataForIdentifier(restorationIdentifier) {
      return this.restorationData[restorationIdentifier] || {};
    }
    updateRestorationData(additionalData) {
      const { restorationIdentifier } = this;
      const restorationData = this.restorationData[restorationIdentifier];
      this.restorationData[restorationIdentifier] = {
        ...restorationData,
        ...additionalData
      };
    }
    // Scroll restoration
    assumeControlOfScrollRestoration() {
      if (!this.previousScrollRestoration) {
        this.previousScrollRestoration = history.scrollRestoration ?? "auto";
        history.scrollRestoration = "manual";
      }
    }
    relinquishControlOfScrollRestoration() {
      if (this.previousScrollRestoration) {
        history.scrollRestoration = this.previousScrollRestoration;
        delete this.previousScrollRestoration;
      }
    }
    // Event handlers
    onPopState = (event) => {
      if (this.shouldHandlePopState()) {
        const { turbo } = event.state || {};
        if (turbo) {
          this.location = new URL(window.location.href);
          const { restorationIdentifier, restorationIndex } = turbo;
          this.restorationIdentifier = restorationIdentifier;
          const direction = restorationIndex > this.currentIndex ? "forward" : "back";
          this.delegate.historyPoppedToLocationWithRestorationIdentifierAndDirection(this.location, restorationIdentifier, direction);
          this.currentIndex = restorationIndex;
        }
      }
    };
    onPageLoad = async (_event) => {
      await nextMicrotask();
      this.pageLoaded = true;
    };
    // Private
    shouldHandlePopState() {
      return this.pageIsLoaded();
    }
    pageIsLoaded() {
      return this.pageLoaded || document.readyState == "complete";
    }
  };
  var LinkPrefetchObserver = class {
    started = false;
    #prefetchedLink = null;
    constructor(delegate, eventTarget) {
      this.delegate = delegate;
      this.eventTarget = eventTarget;
    }
    start() {
      if (this.started) return;
      if (this.eventTarget.readyState === "loading") {
        this.eventTarget.addEventListener("DOMContentLoaded", this.#enable, { once: true });
      } else {
        this.#enable();
      }
    }
    stop() {
      if (!this.started) return;
      this.eventTarget.removeEventListener("mouseenter", this.#tryToPrefetchRequest, {
        capture: true,
        passive: true
      });
      this.eventTarget.removeEventListener("mouseleave", this.#cancelRequestIfObsolete, {
        capture: true,
        passive: true
      });
      this.eventTarget.removeEventListener("turbo:before-fetch-request", this.#tryToUsePrefetchedRequest, true);
      this.started = false;
    }
    #enable = () => {
      this.eventTarget.addEventListener("mouseenter", this.#tryToPrefetchRequest, {
        capture: true,
        passive: true
      });
      this.eventTarget.addEventListener("mouseleave", this.#cancelRequestIfObsolete, {
        capture: true,
        passive: true
      });
      this.eventTarget.addEventListener("turbo:before-fetch-request", this.#tryToUsePrefetchedRequest, true);
      this.started = true;
    };
    #tryToPrefetchRequest = (event) => {
      if (getMetaContent("turbo-prefetch") === "false") return;
      const target = event.target;
      const isLink = target.matches && target.matches("a[href]:not([target^=_]):not([download])");
      if (isLink && this.#isPrefetchable(target)) {
        const link = target;
        const location2 = getLocationForLink(link);
        if (this.delegate.canPrefetchRequestToLocation(link, location2)) {
          this.#prefetchedLink = link;
          const fetchRequest = new FetchRequest(
            this,
            FetchMethod.get,
            location2,
            new URLSearchParams(),
            target
          );
          prefetchCache.setLater(location2.toString(), fetchRequest, this.#cacheTtl);
        }
      }
    };
    #cancelRequestIfObsolete = (event) => {
      if (event.target === this.#prefetchedLink) this.#cancelPrefetchRequest();
    };
    #cancelPrefetchRequest = () => {
      prefetchCache.clear();
      this.#prefetchedLink = null;
    };
    #tryToUsePrefetchedRequest = (event) => {
      if (event.target.tagName !== "FORM" && event.detail.fetchOptions.method === "get") {
        const cached = prefetchCache.get(event.detail.url.toString());
        if (cached) {
          event.detail.fetchRequest = cached;
        }
        prefetchCache.clear();
      }
    };
    prepareRequest(request3) {
      const link = request3.target;
      request3.headers["X-Sec-Purpose"] = "prefetch";
      const turboFrame = link.closest("turbo-frame");
      const turboFrameTarget = link.getAttribute("data-turbo-frame") || turboFrame?.getAttribute("target") || turboFrame?.id;
      if (turboFrameTarget && turboFrameTarget !== "_top") {
        request3.headers["Turbo-Frame"] = turboFrameTarget;
      }
    }
    // Fetch request interface
    requestSucceededWithResponse() {
    }
    requestStarted(fetchRequest) {
    }
    requestErrored(fetchRequest) {
    }
    requestFinished(fetchRequest) {
    }
    requestPreventedHandlingResponse(fetchRequest, fetchResponse) {
    }
    requestFailedWithResponse(fetchRequest, fetchResponse) {
    }
    get #cacheTtl() {
      return Number(getMetaContent("turbo-prefetch-cache-time")) || cacheTtl;
    }
    #isPrefetchable(link) {
      const href = link.getAttribute("href");
      if (!href) return false;
      if (unfetchableLink(link)) return false;
      if (linkToTheSamePage(link)) return false;
      if (linkOptsOut(link)) return false;
      if (nonSafeLink(link)) return false;
      if (eventPrevented(link)) return false;
      return true;
    }
  };
  var unfetchableLink = (link) => {
    return link.origin !== document.location.origin || !["http:", "https:"].includes(link.protocol) || link.hasAttribute("target");
  };
  var linkToTheSamePage = (link) => {
    return link.pathname + link.search === document.location.pathname + document.location.search || link.href.startsWith("#");
  };
  var linkOptsOut = (link) => {
    if (link.getAttribute("data-turbo-prefetch") === "false") return true;
    if (link.getAttribute("data-turbo") === "false") return true;
    const turboPrefetchParent = findClosestRecursively(link, "[data-turbo-prefetch]");
    if (turboPrefetchParent && turboPrefetchParent.getAttribute("data-turbo-prefetch") === "false") return true;
    return false;
  };
  var nonSafeLink = (link) => {
    const turboMethod = link.getAttribute("data-turbo-method");
    if (turboMethod && turboMethod.toLowerCase() !== "get") return true;
    if (isUJS(link)) return true;
    if (link.hasAttribute("data-turbo-confirm")) return true;
    if (link.hasAttribute("data-turbo-stream")) return true;
    return false;
  };
  var isUJS = (link) => {
    return link.hasAttribute("data-remote") || link.hasAttribute("data-behavior") || link.hasAttribute("data-confirm") || link.hasAttribute("data-method");
  };
  var eventPrevented = (link) => {
    const event = dispatch("turbo:before-prefetch", { target: link, cancelable: true });
    return event.defaultPrevented;
  };
  var Navigator = class {
    constructor(delegate) {
      this.delegate = delegate;
    }
    proposeVisit(location2, options = {}) {
      if (this.delegate.allowsVisitingLocationWithAction(location2, options.action)) {
        this.delegate.visitProposedToLocation(location2, options);
      }
    }
    startVisit(locatable, restorationIdentifier, options = {}) {
      this.stop();
      this.currentVisit = new Visit(this, expandURL(locatable), restorationIdentifier, {
        referrer: this.location,
        ...options
      });
      this.currentVisit.start();
    }
    submitForm(form, submitter) {
      this.stop();
      this.formSubmission = new FormSubmission(this, form, submitter, true);
      this.formSubmission.start();
    }
    stop() {
      if (this.formSubmission) {
        this.formSubmission.stop();
        delete this.formSubmission;
      }
      if (this.currentVisit) {
        this.currentVisit.cancel();
        delete this.currentVisit;
      }
    }
    get adapter() {
      return this.delegate.adapter;
    }
    get view() {
      return this.delegate.view;
    }
    get rootLocation() {
      return this.view.snapshot.rootLocation;
    }
    get history() {
      return this.delegate.history;
    }
    // Form submission delegate
    formSubmissionStarted(formSubmission) {
      if (typeof this.adapter.formSubmissionStarted === "function") {
        this.adapter.formSubmissionStarted(formSubmission);
      }
    }
    async formSubmissionSucceededWithResponse(formSubmission, fetchResponse) {
      if (formSubmission == this.formSubmission) {
        const responseHTML = await fetchResponse.responseHTML;
        if (responseHTML) {
          const shouldCacheSnapshot = formSubmission.isSafe;
          if (!shouldCacheSnapshot) {
            this.view.clearSnapshotCache();
          }
          const { statusCode, redirected } = fetchResponse;
          const action = this.#getActionForFormSubmission(formSubmission, fetchResponse);
          const visitOptions = {
            action,
            shouldCacheSnapshot,
            response: { statusCode, responseHTML, redirected }
          };
          this.proposeVisit(fetchResponse.location, visitOptions);
        }
      }
    }
    async formSubmissionFailedWithResponse(formSubmission, fetchResponse) {
      const responseHTML = await fetchResponse.responseHTML;
      if (responseHTML) {
        const snapshot = PageSnapshot.fromHTMLString(responseHTML);
        if (fetchResponse.serverError) {
          await this.view.renderError(snapshot, this.currentVisit);
        } else {
          await this.view.renderPage(snapshot, false, true, this.currentVisit);
        }
        if (!snapshot.shouldPreserveScrollPosition) {
          this.view.scrollToTop();
        }
        this.view.clearSnapshotCache();
      }
    }
    formSubmissionErrored(formSubmission, error3) {
      console.error(error3);
    }
    formSubmissionFinished(formSubmission) {
      if (typeof this.adapter.formSubmissionFinished === "function") {
        this.adapter.formSubmissionFinished(formSubmission);
      }
    }
    // Visit delegate
    visitStarted(visit2) {
      this.delegate.visitStarted(visit2);
    }
    visitCompleted(visit2) {
      this.delegate.visitCompleted(visit2);
    }
    locationWithActionIsSamePage(location2, action) {
      const anchor = getAnchor(location2);
      const currentAnchor = getAnchor(this.view.lastRenderedLocation);
      const isRestorationToTop = action === "restore" && typeof anchor === "undefined";
      return action !== "replace" && getRequestURL(location2) === getRequestURL(this.view.lastRenderedLocation) && (isRestorationToTop || anchor != null && anchor !== currentAnchor);
    }
    visitScrolledToSamePageLocation(oldURL, newURL) {
      this.delegate.visitScrolledToSamePageLocation(oldURL, newURL);
    }
    // Visits
    get location() {
      return this.history.location;
    }
    get restorationIdentifier() {
      return this.history.restorationIdentifier;
    }
    #getActionForFormSubmission(formSubmission, fetchResponse) {
      const { submitter, formElement } = formSubmission;
      return getVisitAction(submitter, formElement) || this.#getDefaultAction(fetchResponse);
    }
    #getDefaultAction(fetchResponse) {
      const sameLocationRedirect = fetchResponse.redirected && fetchResponse.location.href === this.location?.href;
      return sameLocationRedirect ? "replace" : "advance";
    }
  };
  var PageStage = {
    initial: 0,
    loading: 1,
    interactive: 2,
    complete: 3
  };
  var PageObserver = class {
    stage = PageStage.initial;
    started = false;
    constructor(delegate) {
      this.delegate = delegate;
    }
    start() {
      if (!this.started) {
        if (this.stage == PageStage.initial) {
          this.stage = PageStage.loading;
        }
        document.addEventListener("readystatechange", this.interpretReadyState, false);
        addEventListener("pagehide", this.pageWillUnload, false);
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        document.removeEventListener("readystatechange", this.interpretReadyState, false);
        removeEventListener("pagehide", this.pageWillUnload, false);
        this.started = false;
      }
    }
    interpretReadyState = () => {
      const { readyState } = this;
      if (readyState == "interactive") {
        this.pageIsInteractive();
      } else if (readyState == "complete") {
        this.pageIsComplete();
      }
    };
    pageIsInteractive() {
      if (this.stage == PageStage.loading) {
        this.stage = PageStage.interactive;
        this.delegate.pageBecameInteractive();
      }
    }
    pageIsComplete() {
      this.pageIsInteractive();
      if (this.stage == PageStage.interactive) {
        this.stage = PageStage.complete;
        this.delegate.pageLoaded();
      }
    }
    pageWillUnload = () => {
      this.delegate.pageWillUnload();
    };
    get readyState() {
      return document.readyState;
    }
  };
  var ScrollObserver = class {
    started = false;
    constructor(delegate) {
      this.delegate = delegate;
    }
    start() {
      if (!this.started) {
        addEventListener("scroll", this.onScroll, false);
        this.onScroll();
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        removeEventListener("scroll", this.onScroll, false);
        this.started = false;
      }
    }
    onScroll = () => {
      this.updatePosition({ x: window.pageXOffset, y: window.pageYOffset });
    };
    // Private
    updatePosition(position) {
      this.delegate.scrollPositionChanged(position);
    }
  };
  var StreamMessageRenderer = class {
    render({ fragment }) {
      Bardo.preservingPermanentElements(this, getPermanentElementMapForFragment(fragment), () => {
        withAutofocusFromFragment(fragment, () => {
          withPreservedFocus(() => {
            document.documentElement.appendChild(fragment);
          });
        });
      });
    }
    // Bardo delegate
    enteringBardo(currentPermanentElement, newPermanentElement) {
      newPermanentElement.replaceWith(currentPermanentElement.cloneNode(true));
    }
    leavingBardo() {
    }
  };
  function getPermanentElementMapForFragment(fragment) {
    const permanentElementsInDocument = queryPermanentElementsAll(document.documentElement);
    const permanentElementMap = {};
    for (const permanentElementInDocument of permanentElementsInDocument) {
      const { id } = permanentElementInDocument;
      for (const streamElement of fragment.querySelectorAll("turbo-stream")) {
        const elementInStream = getPermanentElementById(streamElement.templateElement.content, id);
        if (elementInStream) {
          permanentElementMap[id] = [permanentElementInDocument, elementInStream];
        }
      }
    }
    return permanentElementMap;
  }
  async function withAutofocusFromFragment(fragment, callback) {
    const generatedID = `turbo-stream-autofocus-${uuid()}`;
    const turboStreams = fragment.querySelectorAll("turbo-stream");
    const elementWithAutofocus = firstAutofocusableElementInStreams(turboStreams);
    let willAutofocusId = null;
    if (elementWithAutofocus) {
      if (elementWithAutofocus.id) {
        willAutofocusId = elementWithAutofocus.id;
      } else {
        willAutofocusId = generatedID;
      }
      elementWithAutofocus.id = willAutofocusId;
    }
    callback();
    await nextRepaint();
    const hasNoActiveElement = document.activeElement == null || document.activeElement == document.body;
    if (hasNoActiveElement && willAutofocusId) {
      const elementToAutofocus = document.getElementById(willAutofocusId);
      if (elementIsFocusable(elementToAutofocus)) {
        elementToAutofocus.focus();
      }
      if (elementToAutofocus && elementToAutofocus.id == generatedID) {
        elementToAutofocus.removeAttribute("id");
      }
    }
  }
  async function withPreservedFocus(callback) {
    const [activeElementBeforeRender, activeElementAfterRender] = await around(callback, () => document.activeElement);
    const restoreFocusTo = activeElementBeforeRender && activeElementBeforeRender.id;
    if (restoreFocusTo) {
      const elementToFocus = document.getElementById(restoreFocusTo);
      if (elementIsFocusable(elementToFocus) && elementToFocus != activeElementAfterRender) {
        elementToFocus.focus();
      }
    }
  }
  function firstAutofocusableElementInStreams(nodeListOfStreamElements) {
    for (const streamElement of nodeListOfStreamElements) {
      const elementWithAutofocus = queryAutofocusableElement(streamElement.templateElement.content);
      if (elementWithAutofocus) return elementWithAutofocus;
    }
    return null;
  }
  var StreamObserver = class {
    sources = /* @__PURE__ */ new Set();
    #started = false;
    constructor(delegate) {
      this.delegate = delegate;
    }
    start() {
      if (!this.#started) {
        this.#started = true;
        addEventListener("turbo:before-fetch-response", this.inspectFetchResponse, false);
      }
    }
    stop() {
      if (this.#started) {
        this.#started = false;
        removeEventListener("turbo:before-fetch-response", this.inspectFetchResponse, false);
      }
    }
    connectStreamSource(source) {
      if (!this.streamSourceIsConnected(source)) {
        this.sources.add(source);
        source.addEventListener("message", this.receiveMessageEvent, false);
      }
    }
    disconnectStreamSource(source) {
      if (this.streamSourceIsConnected(source)) {
        this.sources.delete(source);
        source.removeEventListener("message", this.receiveMessageEvent, false);
      }
    }
    streamSourceIsConnected(source) {
      return this.sources.has(source);
    }
    inspectFetchResponse = (event) => {
      const response2 = fetchResponseFromEvent(event);
      if (response2 && fetchResponseIsStream(response2)) {
        event.preventDefault();
        this.receiveMessageResponse(response2);
      }
    };
    receiveMessageEvent = (event) => {
      if (this.#started && typeof event.data == "string") {
        this.receiveMessageHTML(event.data);
      }
    };
    async receiveMessageResponse(response2) {
      const html = await response2.responseHTML;
      if (html) {
        this.receiveMessageHTML(html);
      }
    }
    receiveMessageHTML(html) {
      this.delegate.receivedMessageFromStream(StreamMessage.wrap(html));
    }
  };
  function fetchResponseFromEvent(event) {
    const fetchResponse = event.detail?.fetchResponse;
    if (fetchResponse instanceof FetchResponse) {
      return fetchResponse;
    }
  }
  function fetchResponseIsStream(response2) {
    const contentType = response2.contentType ?? "";
    return contentType.startsWith(StreamMessage.contentType);
  }
  var ErrorRenderer = class extends Renderer {
    static renderElement(currentElement, newElement) {
      const { documentElement, body } = document;
      documentElement.replaceChild(newElement, body);
    }
    async render() {
      this.replaceHeadAndBody();
      this.activateScriptElements();
    }
    replaceHeadAndBody() {
      const { documentElement, head } = document;
      documentElement.replaceChild(this.newHead, head);
      this.renderElement(this.currentElement, this.newElement);
    }
    activateScriptElements() {
      for (const replaceableElement of this.scriptElements) {
        const parentNode = replaceableElement.parentNode;
        if (parentNode) {
          const element = activateScriptElement(replaceableElement);
          parentNode.replaceChild(element, replaceableElement);
        }
      }
    }
    get newHead() {
      return this.newSnapshot.headSnapshot.element;
    }
    get scriptElements() {
      return document.documentElement.querySelectorAll("script");
    }
  };
  var Idiomorph = /* @__PURE__ */ function() {
    let EMPTY_SET = /* @__PURE__ */ new Set();
    let defaults = {
      morphStyle: "outerHTML",
      callbacks: {
        beforeNodeAdded: noOp,
        afterNodeAdded: noOp,
        beforeNodeMorphed: noOp,
        afterNodeMorphed: noOp,
        beforeNodeRemoved: noOp,
        afterNodeRemoved: noOp,
        beforeAttributeUpdated: noOp
      },
      head: {
        style: "merge",
        shouldPreserve: function(elt) {
          return elt.getAttribute("im-preserve") === "true";
        },
        shouldReAppend: function(elt) {
          return elt.getAttribute("im-re-append") === "true";
        },
        shouldRemove: noOp,
        afterHeadMorphed: noOp
      }
    };
    function morph(oldNode, newContent, config = {}) {
      if (oldNode instanceof Document) {
        oldNode = oldNode.documentElement;
      }
      if (typeof newContent === "string") {
        newContent = parseContent(newContent);
      }
      let normalizedContent = normalizeContent(newContent);
      let ctx = createMorphContext(oldNode, normalizedContent, config);
      return morphNormalizedContent(oldNode, normalizedContent, ctx);
    }
    function morphNormalizedContent(oldNode, normalizedNewContent, ctx) {
      if (ctx.head.block) {
        let oldHead = oldNode.querySelector("head");
        let newHead = normalizedNewContent.querySelector("head");
        if (oldHead && newHead) {
          let promises = handleHeadElement(newHead, oldHead, ctx);
          Promise.all(promises).then(function() {
            morphNormalizedContent(oldNode, normalizedNewContent, Object.assign(ctx, {
              head: {
                block: false,
                ignore: true
              }
            }));
          });
          return;
        }
      }
      if (ctx.morphStyle === "innerHTML") {
        morphChildren(normalizedNewContent, oldNode, ctx);
        return oldNode.children;
      } else if (ctx.morphStyle === "outerHTML" || ctx.morphStyle == null) {
        let bestMatch = findBestNodeMatch(normalizedNewContent, oldNode, ctx);
        let previousSibling = bestMatch?.previousSibling;
        let nextSibling = bestMatch?.nextSibling;
        let morphedNode = morphOldNodeTo(oldNode, bestMatch, ctx);
        if (bestMatch) {
          return insertSiblings(previousSibling, morphedNode, nextSibling);
        } else {
          return [];
        }
      } else {
        throw "Do not understand how to morph style " + ctx.morphStyle;
      }
    }
    function ignoreValueOfActiveElement(possibleActiveElement, ctx) {
      return ctx.ignoreActiveValue && possibleActiveElement === document.activeElement && possibleActiveElement !== document.body;
    }
    function morphOldNodeTo(oldNode, newContent, ctx) {
      if (ctx.ignoreActive && oldNode === document.activeElement) ;
      else if (newContent == null) {
        if (ctx.callbacks.beforeNodeRemoved(oldNode) === false) return oldNode;
        oldNode.remove();
        ctx.callbacks.afterNodeRemoved(oldNode);
        return null;
      } else if (!isSoftMatch(oldNode, newContent)) {
        if (ctx.callbacks.beforeNodeRemoved(oldNode) === false) return oldNode;
        if (ctx.callbacks.beforeNodeAdded(newContent) === false) return oldNode;
        oldNode.parentElement.replaceChild(newContent, oldNode);
        ctx.callbacks.afterNodeAdded(newContent);
        ctx.callbacks.afterNodeRemoved(oldNode);
        return newContent;
      } else {
        if (ctx.callbacks.beforeNodeMorphed(oldNode, newContent) === false) return oldNode;
        if (oldNode instanceof HTMLHeadElement && ctx.head.ignore) ;
        else if (oldNode instanceof HTMLHeadElement && ctx.head.style !== "morph") {
          handleHeadElement(newContent, oldNode, ctx);
        } else {
          syncNodeFrom(newContent, oldNode, ctx);
          if (!ignoreValueOfActiveElement(oldNode, ctx)) {
            morphChildren(newContent, oldNode, ctx);
          }
        }
        ctx.callbacks.afterNodeMorphed(oldNode, newContent);
        return oldNode;
      }
    }
    function morphChildren(newParent, oldParent, ctx) {
      let nextNewChild = newParent.firstChild;
      let insertionPoint = oldParent.firstChild;
      let newChild;
      while (nextNewChild) {
        newChild = nextNewChild;
        nextNewChild = newChild.nextSibling;
        if (insertionPoint == null) {
          if (ctx.callbacks.beforeNodeAdded(newChild) === false) return;
          oldParent.appendChild(newChild);
          ctx.callbacks.afterNodeAdded(newChild);
          removeIdsFromConsideration(ctx, newChild);
          continue;
        }
        if (isIdSetMatch(newChild, insertionPoint, ctx)) {
          morphOldNodeTo(insertionPoint, newChild, ctx);
          insertionPoint = insertionPoint.nextSibling;
          removeIdsFromConsideration(ctx, newChild);
          continue;
        }
        let idSetMatch = findIdSetMatch(newParent, oldParent, newChild, insertionPoint, ctx);
        if (idSetMatch) {
          insertionPoint = removeNodesBetween(insertionPoint, idSetMatch, ctx);
          morphOldNodeTo(idSetMatch, newChild, ctx);
          removeIdsFromConsideration(ctx, newChild);
          continue;
        }
        let softMatch = findSoftMatch(newParent, oldParent, newChild, insertionPoint, ctx);
        if (softMatch) {
          insertionPoint = removeNodesBetween(insertionPoint, softMatch, ctx);
          morphOldNodeTo(softMatch, newChild, ctx);
          removeIdsFromConsideration(ctx, newChild);
          continue;
        }
        if (ctx.callbacks.beforeNodeAdded(newChild) === false) return;
        oldParent.insertBefore(newChild, insertionPoint);
        ctx.callbacks.afterNodeAdded(newChild);
        removeIdsFromConsideration(ctx, newChild);
      }
      while (insertionPoint !== null) {
        let tempNode = insertionPoint;
        insertionPoint = insertionPoint.nextSibling;
        removeNode(tempNode, ctx);
      }
    }
    function ignoreAttribute(attr, to, updateType, ctx) {
      if (attr === "value" && ctx.ignoreActiveValue && to === document.activeElement) {
        return true;
      }
      return ctx.callbacks.beforeAttributeUpdated(attr, to, updateType) === false;
    }
    function syncNodeFrom(from, to, ctx) {
      let type = from.nodeType;
      if (type === 1) {
        const fromAttributes = from.attributes;
        const toAttributes = to.attributes;
        for (const fromAttribute of fromAttributes) {
          if (ignoreAttribute(fromAttribute.name, to, "update", ctx)) {
            continue;
          }
          if (to.getAttribute(fromAttribute.name) !== fromAttribute.value) {
            to.setAttribute(fromAttribute.name, fromAttribute.value);
          }
        }
        for (let i = toAttributes.length - 1; 0 <= i; i--) {
          const toAttribute = toAttributes[i];
          if (ignoreAttribute(toAttribute.name, to, "remove", ctx)) {
            continue;
          }
          if (!from.hasAttribute(toAttribute.name)) {
            to.removeAttribute(toAttribute.name);
          }
        }
      }
      if (type === 8 || type === 3) {
        if (to.nodeValue !== from.nodeValue) {
          to.nodeValue = from.nodeValue;
        }
      }
      if (!ignoreValueOfActiveElement(to, ctx)) {
        syncInputValue(from, to, ctx);
      }
    }
    function syncBooleanAttribute(from, to, attributeName, ctx) {
      if (from[attributeName] !== to[attributeName]) {
        let ignoreUpdate = ignoreAttribute(attributeName, to, "update", ctx);
        if (!ignoreUpdate) {
          to[attributeName] = from[attributeName];
        }
        if (from[attributeName]) {
          if (!ignoreUpdate) {
            to.setAttribute(attributeName, from[attributeName]);
          }
        } else {
          if (!ignoreAttribute(attributeName, to, "remove", ctx)) {
            to.removeAttribute(attributeName);
          }
        }
      }
    }
    function syncInputValue(from, to, ctx) {
      if (from instanceof HTMLInputElement && to instanceof HTMLInputElement && from.type !== "file") {
        let fromValue = from.value;
        let toValue = to.value;
        syncBooleanAttribute(from, to, "checked", ctx);
        syncBooleanAttribute(from, to, "disabled", ctx);
        if (!from.hasAttribute("value")) {
          if (!ignoreAttribute("value", to, "remove", ctx)) {
            to.value = "";
            to.removeAttribute("value");
          }
        } else if (fromValue !== toValue) {
          if (!ignoreAttribute("value", to, "update", ctx)) {
            to.setAttribute("value", fromValue);
            to.value = fromValue;
          }
        }
      } else if (from instanceof HTMLOptionElement) {
        syncBooleanAttribute(from, to, "selected", ctx);
      } else if (from instanceof HTMLTextAreaElement && to instanceof HTMLTextAreaElement) {
        let fromValue = from.value;
        let toValue = to.value;
        if (ignoreAttribute("value", to, "update", ctx)) {
          return;
        }
        if (fromValue !== toValue) {
          to.value = fromValue;
        }
        if (to.firstChild && to.firstChild.nodeValue !== fromValue) {
          to.firstChild.nodeValue = fromValue;
        }
      }
    }
    function handleHeadElement(newHeadTag, currentHead, ctx) {
      let added = [];
      let removed = [];
      let preserved = [];
      let nodesToAppend = [];
      let headMergeStyle = ctx.head.style;
      let srcToNewHeadNodes = /* @__PURE__ */ new Map();
      for (const newHeadChild of newHeadTag.children) {
        srcToNewHeadNodes.set(newHeadChild.outerHTML, newHeadChild);
      }
      for (const currentHeadElt of currentHead.children) {
        let inNewContent = srcToNewHeadNodes.has(currentHeadElt.outerHTML);
        let isReAppended = ctx.head.shouldReAppend(currentHeadElt);
        let isPreserved = ctx.head.shouldPreserve(currentHeadElt);
        if (inNewContent || isPreserved) {
          if (isReAppended) {
            removed.push(currentHeadElt);
          } else {
            srcToNewHeadNodes.delete(currentHeadElt.outerHTML);
            preserved.push(currentHeadElt);
          }
        } else {
          if (headMergeStyle === "append") {
            if (isReAppended) {
              removed.push(currentHeadElt);
              nodesToAppend.push(currentHeadElt);
            }
          } else {
            if (ctx.head.shouldRemove(currentHeadElt) !== false) {
              removed.push(currentHeadElt);
            }
          }
        }
      }
      nodesToAppend.push(...srcToNewHeadNodes.values());
      let promises = [];
      for (const newNode of nodesToAppend) {
        let newElt = document.createRange().createContextualFragment(newNode.outerHTML).firstChild;
        if (ctx.callbacks.beforeNodeAdded(newElt) !== false) {
          if (newElt.href || newElt.src) {
            let resolve = null;
            let promise = new Promise(function(_resolve) {
              resolve = _resolve;
            });
            newElt.addEventListener("load", function() {
              resolve();
            });
            promises.push(promise);
          }
          currentHead.appendChild(newElt);
          ctx.callbacks.afterNodeAdded(newElt);
          added.push(newElt);
        }
      }
      for (const removedElement of removed) {
        if (ctx.callbacks.beforeNodeRemoved(removedElement) !== false) {
          currentHead.removeChild(removedElement);
          ctx.callbacks.afterNodeRemoved(removedElement);
        }
      }
      ctx.head.afterHeadMorphed(currentHead, { added, kept: preserved, removed });
      return promises;
    }
    function noOp() {
    }
    function mergeDefaults(config) {
      let finalConfig = {};
      Object.assign(finalConfig, defaults);
      Object.assign(finalConfig, config);
      finalConfig.callbacks = {};
      Object.assign(finalConfig.callbacks, defaults.callbacks);
      Object.assign(finalConfig.callbacks, config.callbacks);
      finalConfig.head = {};
      Object.assign(finalConfig.head, defaults.head);
      Object.assign(finalConfig.head, config.head);
      return finalConfig;
    }
    function createMorphContext(oldNode, newContent, config) {
      config = mergeDefaults(config);
      return {
        target: oldNode,
        newContent,
        config,
        morphStyle: config.morphStyle,
        ignoreActive: config.ignoreActive,
        ignoreActiveValue: config.ignoreActiveValue,
        idMap: createIdMap(oldNode, newContent),
        deadIds: /* @__PURE__ */ new Set(),
        callbacks: config.callbacks,
        head: config.head
      };
    }
    function isIdSetMatch(node1, node2, ctx) {
      if (node1 == null || node2 == null) {
        return false;
      }
      if (node1.nodeType === node2.nodeType && node1.tagName === node2.tagName) {
        if (node1.id !== "" && node1.id === node2.id) {
          return true;
        } else {
          return getIdIntersectionCount(ctx, node1, node2) > 0;
        }
      }
      return false;
    }
    function isSoftMatch(node1, node2) {
      if (node1 == null || node2 == null) {
        return false;
      }
      return node1.nodeType === node2.nodeType && node1.tagName === node2.tagName;
    }
    function removeNodesBetween(startInclusive, endExclusive, ctx) {
      while (startInclusive !== endExclusive) {
        let tempNode = startInclusive;
        startInclusive = startInclusive.nextSibling;
        removeNode(tempNode, ctx);
      }
      removeIdsFromConsideration(ctx, endExclusive);
      return endExclusive.nextSibling;
    }
    function findIdSetMatch(newContent, oldParent, newChild, insertionPoint, ctx) {
      let newChildPotentialIdCount = getIdIntersectionCount(ctx, newChild, oldParent);
      let potentialMatch = null;
      if (newChildPotentialIdCount > 0) {
        let potentialMatch2 = insertionPoint;
        let otherMatchCount = 0;
        while (potentialMatch2 != null) {
          if (isIdSetMatch(newChild, potentialMatch2, ctx)) {
            return potentialMatch2;
          }
          otherMatchCount += getIdIntersectionCount(ctx, potentialMatch2, newContent);
          if (otherMatchCount > newChildPotentialIdCount) {
            return null;
          }
          potentialMatch2 = potentialMatch2.nextSibling;
        }
      }
      return potentialMatch;
    }
    function findSoftMatch(newContent, oldParent, newChild, insertionPoint, ctx) {
      let potentialSoftMatch = insertionPoint;
      let nextSibling = newChild.nextSibling;
      let siblingSoftMatchCount = 0;
      while (potentialSoftMatch != null) {
        if (getIdIntersectionCount(ctx, potentialSoftMatch, newContent) > 0) {
          return null;
        }
        if (isSoftMatch(newChild, potentialSoftMatch)) {
          return potentialSoftMatch;
        }
        if (isSoftMatch(nextSibling, potentialSoftMatch)) {
          siblingSoftMatchCount++;
          nextSibling = nextSibling.nextSibling;
          if (siblingSoftMatchCount >= 2) {
            return null;
          }
        }
        potentialSoftMatch = potentialSoftMatch.nextSibling;
      }
      return potentialSoftMatch;
    }
    function parseContent(newContent) {
      let parser = new DOMParser();
      let contentWithSvgsRemoved = newContent.replace(/<svg(\s[^>]*>|>)([\s\S]*?)<\/svg>/gim, "");
      if (contentWithSvgsRemoved.match(/<\/html>/) || contentWithSvgsRemoved.match(/<\/head>/) || contentWithSvgsRemoved.match(/<\/body>/)) {
        let content = parser.parseFromString(newContent, "text/html");
        if (contentWithSvgsRemoved.match(/<\/html>/)) {
          content.generatedByIdiomorph = true;
          return content;
        } else {
          let htmlElement = content.firstChild;
          if (htmlElement) {
            htmlElement.generatedByIdiomorph = true;
            return htmlElement;
          } else {
            return null;
          }
        }
      } else {
        let responseDoc = parser.parseFromString("<body><template>" + newContent + "</template></body>", "text/html");
        let content = responseDoc.body.querySelector("template").content;
        content.generatedByIdiomorph = true;
        return content;
      }
    }
    function normalizeContent(newContent) {
      if (newContent == null) {
        const dummyParent = document.createElement("div");
        return dummyParent;
      } else if (newContent.generatedByIdiomorph) {
        return newContent;
      } else if (newContent instanceof Node) {
        const dummyParent = document.createElement("div");
        dummyParent.append(newContent);
        return dummyParent;
      } else {
        const dummyParent = document.createElement("div");
        for (const elt of [...newContent]) {
          dummyParent.append(elt);
        }
        return dummyParent;
      }
    }
    function insertSiblings(previousSibling, morphedNode, nextSibling) {
      let stack = [];
      let added = [];
      while (previousSibling != null) {
        stack.push(previousSibling);
        previousSibling = previousSibling.previousSibling;
      }
      while (stack.length > 0) {
        let node = stack.pop();
        added.push(node);
        morphedNode.parentElement.insertBefore(node, morphedNode);
      }
      added.push(morphedNode);
      while (nextSibling != null) {
        stack.push(nextSibling);
        added.push(nextSibling);
        nextSibling = nextSibling.nextSibling;
      }
      while (stack.length > 0) {
        morphedNode.parentElement.insertBefore(stack.pop(), morphedNode.nextSibling);
      }
      return added;
    }
    function findBestNodeMatch(newContent, oldNode, ctx) {
      let currentElement;
      currentElement = newContent.firstChild;
      let bestElement = currentElement;
      let score = 0;
      while (currentElement) {
        let newScore = scoreElement(currentElement, oldNode, ctx);
        if (newScore > score) {
          bestElement = currentElement;
          score = newScore;
        }
        currentElement = currentElement.nextSibling;
      }
      return bestElement;
    }
    function scoreElement(node1, node2, ctx) {
      if (isSoftMatch(node1, node2)) {
        return 0.5 + getIdIntersectionCount(ctx, node1, node2);
      }
      return 0;
    }
    function removeNode(tempNode, ctx) {
      removeIdsFromConsideration(ctx, tempNode);
      if (ctx.callbacks.beforeNodeRemoved(tempNode) === false) return;
      tempNode.remove();
      ctx.callbacks.afterNodeRemoved(tempNode);
    }
    function isIdInConsideration(ctx, id) {
      return !ctx.deadIds.has(id);
    }
    function idIsWithinNode(ctx, id, targetNode) {
      let idSet = ctx.idMap.get(targetNode) || EMPTY_SET;
      return idSet.has(id);
    }
    function removeIdsFromConsideration(ctx, node) {
      let idSet = ctx.idMap.get(node) || EMPTY_SET;
      for (const id of idSet) {
        ctx.deadIds.add(id);
      }
    }
    function getIdIntersectionCount(ctx, node1, node2) {
      let sourceSet = ctx.idMap.get(node1) || EMPTY_SET;
      let matchCount = 0;
      for (const id of sourceSet) {
        if (isIdInConsideration(ctx, id) && idIsWithinNode(ctx, id, node2)) {
          ++matchCount;
        }
      }
      return matchCount;
    }
    function populateIdMapForNode(node, idMap) {
      let nodeParent = node.parentElement;
      let idElements = node.querySelectorAll("[id]");
      for (const elt of idElements) {
        let current = elt;
        while (current !== nodeParent && current != null) {
          let idSet = idMap.get(current);
          if (idSet == null) {
            idSet = /* @__PURE__ */ new Set();
            idMap.set(current, idSet);
          }
          idSet.add(elt.id);
          current = current.parentElement;
        }
      }
    }
    function createIdMap(oldContent, newContent) {
      let idMap = /* @__PURE__ */ new Map();
      populateIdMapForNode(oldContent, idMap);
      populateIdMapForNode(newContent, idMap);
      return idMap;
    }
    return {
      morph,
      defaults
    };
  }();
  var PageRenderer = class extends Renderer {
    static renderElement(currentElement, newElement) {
      if (document.body && newElement instanceof HTMLBodyElement) {
        document.body.replaceWith(newElement);
      } else {
        document.documentElement.appendChild(newElement);
      }
    }
    get shouldRender() {
      return this.newSnapshot.isVisitable && this.trackedElementsAreIdentical;
    }
    get reloadReason() {
      if (!this.newSnapshot.isVisitable) {
        return {
          reason: "turbo_visit_control_is_reload"
        };
      }
      if (!this.trackedElementsAreIdentical) {
        return {
          reason: "tracked_element_mismatch"
        };
      }
    }
    async prepareToRender() {
      this.#setLanguage();
      await this.mergeHead();
    }
    async render() {
      if (this.willRender) {
        await this.replaceBody();
      }
    }
    finishRendering() {
      super.finishRendering();
      if (!this.isPreview) {
        this.focusFirstAutofocusableElement();
      }
    }
    get currentHeadSnapshot() {
      return this.currentSnapshot.headSnapshot;
    }
    get newHeadSnapshot() {
      return this.newSnapshot.headSnapshot;
    }
    get newElement() {
      return this.newSnapshot.element;
    }
    #setLanguage() {
      const { documentElement } = this.currentSnapshot;
      const { lang } = this.newSnapshot;
      if (lang) {
        documentElement.setAttribute("lang", lang);
      } else {
        documentElement.removeAttribute("lang");
      }
    }
    async mergeHead() {
      const mergedHeadElements = this.mergeProvisionalElements();
      const newStylesheetElements = this.copyNewHeadStylesheetElements();
      this.copyNewHeadScriptElements();
      await mergedHeadElements;
      await newStylesheetElements;
      if (this.willRender) {
        this.removeUnusedDynamicStylesheetElements();
      }
    }
    async replaceBody() {
      await this.preservingPermanentElements(async () => {
        this.activateNewBody();
        await this.assignNewBody();
      });
    }
    get trackedElementsAreIdentical() {
      return this.currentHeadSnapshot.trackedElementSignature == this.newHeadSnapshot.trackedElementSignature;
    }
    async copyNewHeadStylesheetElements() {
      const loadingElements = [];
      for (const element of this.newHeadStylesheetElements) {
        loadingElements.push(waitForLoad(element));
        document.head.appendChild(element);
      }
      await Promise.all(loadingElements);
    }
    copyNewHeadScriptElements() {
      for (const element of this.newHeadScriptElements) {
        document.head.appendChild(activateScriptElement(element));
      }
    }
    removeUnusedDynamicStylesheetElements() {
      for (const element of this.unusedDynamicStylesheetElements) {
        document.head.removeChild(element);
      }
    }
    async mergeProvisionalElements() {
      const newHeadElements = [...this.newHeadProvisionalElements];
      for (const element of this.currentHeadProvisionalElements) {
        if (!this.isCurrentElementInElementList(element, newHeadElements)) {
          document.head.removeChild(element);
        }
      }
      for (const element of newHeadElements) {
        document.head.appendChild(element);
      }
    }
    isCurrentElementInElementList(element, elementList) {
      for (const [index, newElement] of elementList.entries()) {
        if (element.tagName == "TITLE") {
          if (newElement.tagName != "TITLE") {
            continue;
          }
          if (element.innerHTML == newElement.innerHTML) {
            elementList.splice(index, 1);
            return true;
          }
        }
        if (newElement.isEqualNode(element)) {
          elementList.splice(index, 1);
          return true;
        }
      }
      return false;
    }
    removeCurrentHeadProvisionalElements() {
      for (const element of this.currentHeadProvisionalElements) {
        document.head.removeChild(element);
      }
    }
    copyNewHeadProvisionalElements() {
      for (const element of this.newHeadProvisionalElements) {
        document.head.appendChild(element);
      }
    }
    activateNewBody() {
      document.adoptNode(this.newElement);
      this.activateNewBodyScriptElements();
    }
    activateNewBodyScriptElements() {
      for (const inertScriptElement of this.newBodyScriptElements) {
        const activatedScriptElement = activateScriptElement(inertScriptElement);
        inertScriptElement.replaceWith(activatedScriptElement);
      }
    }
    async assignNewBody() {
      await this.renderElement(this.currentElement, this.newElement);
    }
    get unusedDynamicStylesheetElements() {
      return this.oldHeadStylesheetElements.filter((element) => {
        return element.getAttribute("data-turbo-track") === "dynamic";
      });
    }
    get oldHeadStylesheetElements() {
      return this.currentHeadSnapshot.getStylesheetElementsNotInSnapshot(this.newHeadSnapshot);
    }
    get newHeadStylesheetElements() {
      return this.newHeadSnapshot.getStylesheetElementsNotInSnapshot(this.currentHeadSnapshot);
    }
    get newHeadScriptElements() {
      return this.newHeadSnapshot.getScriptElementsNotInSnapshot(this.currentHeadSnapshot);
    }
    get currentHeadProvisionalElements() {
      return this.currentHeadSnapshot.provisionalElements;
    }
    get newHeadProvisionalElements() {
      return this.newHeadSnapshot.provisionalElements;
    }
    get newBodyScriptElements() {
      return this.newElement.querySelectorAll("script");
    }
  };
  var MorphRenderer = class extends PageRenderer {
    async render() {
      if (this.willRender) await this.#morphBody();
    }
    get renderMethod() {
      return "morph";
    }
    // Private
    async #morphBody() {
      this.#morphElements(this.currentElement, this.newElement);
      this.#reloadRemoteFrames();
      dispatch("turbo:morph", {
        detail: {
          currentElement: this.currentElement,
          newElement: this.newElement
        }
      });
    }
    #morphElements(currentElement, newElement, morphStyle = "outerHTML") {
      this.isMorphingTurboFrame = this.#isFrameReloadedWithMorph(currentElement);
      Idiomorph.morph(currentElement, newElement, {
        morphStyle,
        callbacks: {
          beforeNodeAdded: this.#shouldAddElement,
          beforeNodeMorphed: this.#shouldMorphElement,
          beforeAttributeUpdated: this.#shouldUpdateAttribute,
          beforeNodeRemoved: this.#shouldRemoveElement,
          afterNodeMorphed: this.#didMorphElement
        }
      });
    }
    #shouldAddElement = (node) => {
      return !(node.id && node.hasAttribute("data-turbo-permanent") && document.getElementById(node.id));
    };
    #shouldMorphElement = (oldNode, newNode) => {
      if (oldNode instanceof HTMLElement) {
        if (!oldNode.hasAttribute("data-turbo-permanent") && (this.isMorphingTurboFrame || !this.#isFrameReloadedWithMorph(oldNode))) {
          const event = dispatch("turbo:before-morph-element", {
            cancelable: true,
            target: oldNode,
            detail: {
              newElement: newNode
            }
          });
          return !event.defaultPrevented;
        } else {
          return false;
        }
      }
    };
    #shouldUpdateAttribute = (attributeName, target, mutationType) => {
      const event = dispatch("turbo:before-morph-attribute", { cancelable: true, target, detail: { attributeName, mutationType } });
      return !event.defaultPrevented;
    };
    #didMorphElement = (oldNode, newNode) => {
      if (newNode instanceof HTMLElement) {
        dispatch("turbo:morph-element", {
          target: oldNode,
          detail: {
            newElement: newNode
          }
        });
      }
    };
    #shouldRemoveElement = (node) => {
      return this.#shouldMorphElement(node);
    };
    #reloadRemoteFrames() {
      this.#remoteFrames().forEach((frame) => {
        if (this.#isFrameReloadedWithMorph(frame)) {
          this.#renderFrameWithMorph(frame);
          frame.reload();
        }
      });
    }
    #renderFrameWithMorph(frame) {
      frame.addEventListener("turbo:before-frame-render", (event) => {
        event.detail.render = this.#morphFrameUpdate;
      }, { once: true });
    }
    #morphFrameUpdate = (currentElement, newElement) => {
      dispatch("turbo:before-frame-morph", {
        target: currentElement,
        detail: { currentElement, newElement }
      });
      this.#morphElements(currentElement, newElement.children, "innerHTML");
    };
    #isFrameReloadedWithMorph(element) {
      return element.src && element.refresh === "morph";
    }
    #remoteFrames() {
      return Array.from(document.querySelectorAll("turbo-frame[src]")).filter((frame) => {
        return !frame.closest("[data-turbo-permanent]");
      });
    }
  };
  var SnapshotCache = class {
    keys = [];
    snapshots = {};
    constructor(size) {
      this.size = size;
    }
    has(location2) {
      return toCacheKey(location2) in this.snapshots;
    }
    get(location2) {
      if (this.has(location2)) {
        const snapshot = this.read(location2);
        this.touch(location2);
        return snapshot;
      }
    }
    put(location2, snapshot) {
      this.write(location2, snapshot);
      this.touch(location2);
      return snapshot;
    }
    clear() {
      this.snapshots = {};
    }
    // Private
    read(location2) {
      return this.snapshots[toCacheKey(location2)];
    }
    write(location2, snapshot) {
      this.snapshots[toCacheKey(location2)] = snapshot;
    }
    touch(location2) {
      const key = toCacheKey(location2);
      const index = this.keys.indexOf(key);
      if (index > -1) this.keys.splice(index, 1);
      this.keys.unshift(key);
      this.trim();
    }
    trim() {
      for (const key of this.keys.splice(this.size)) {
        delete this.snapshots[key];
      }
    }
  };
  var PageView = class extends View {
    snapshotCache = new SnapshotCache(10);
    lastRenderedLocation = new URL(location.href);
    forceReloaded = false;
    shouldTransitionTo(newSnapshot) {
      return this.snapshot.prefersViewTransitions && newSnapshot.prefersViewTransitions;
    }
    renderPage(snapshot, isPreview = false, willRender = true, visit2) {
      const shouldMorphPage = this.isPageRefresh(visit2) && this.snapshot.shouldMorphPage;
      const rendererClass = shouldMorphPage ? MorphRenderer : PageRenderer;
      const renderer = new rendererClass(this.snapshot, snapshot, PageRenderer.renderElement, isPreview, willRender);
      if (!renderer.shouldRender) {
        this.forceReloaded = true;
      } else {
        visit2?.changeHistory();
      }
      return this.render(renderer);
    }
    renderError(snapshot, visit2) {
      visit2?.changeHistory();
      const renderer = new ErrorRenderer(this.snapshot, snapshot, ErrorRenderer.renderElement, false);
      return this.render(renderer);
    }
    clearSnapshotCache() {
      this.snapshotCache.clear();
    }
    async cacheSnapshot(snapshot = this.snapshot) {
      if (snapshot.isCacheable) {
        this.delegate.viewWillCacheSnapshot();
        const { lastRenderedLocation: location2 } = this;
        await nextEventLoopTick();
        const cachedSnapshot = snapshot.clone();
        this.snapshotCache.put(location2, cachedSnapshot);
        return cachedSnapshot;
      }
    }
    getCachedSnapshotForLocation(location2) {
      return this.snapshotCache.get(location2);
    }
    isPageRefresh(visit2) {
      return !visit2 || this.lastRenderedLocation.pathname === visit2.location.pathname && visit2.action === "replace";
    }
    shouldPreserveScrollPosition(visit2) {
      return this.isPageRefresh(visit2) && this.snapshot.shouldPreserveScrollPosition;
    }
    get snapshot() {
      return PageSnapshot.fromElement(this.element);
    }
  };
  var Preloader = class {
    selector = "a[data-turbo-preload]";
    constructor(delegate, snapshotCache) {
      this.delegate = delegate;
      this.snapshotCache = snapshotCache;
    }
    start() {
      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", this.#preloadAll);
      } else {
        this.preloadOnLoadLinksForView(document.body);
      }
    }
    stop() {
      document.removeEventListener("DOMContentLoaded", this.#preloadAll);
    }
    preloadOnLoadLinksForView(element) {
      for (const link of element.querySelectorAll(this.selector)) {
        if (this.delegate.shouldPreloadLink(link)) {
          this.preloadURL(link);
        }
      }
    }
    async preloadURL(link) {
      const location2 = new URL(link.href);
      if (this.snapshotCache.has(location2)) {
        return;
      }
      const fetchRequest = new FetchRequest(this, FetchMethod.get, location2, new URLSearchParams(), link);
      await fetchRequest.perform();
    }
    // Fetch request delegate
    prepareRequest(fetchRequest) {
      fetchRequest.headers["X-Sec-Purpose"] = "prefetch";
    }
    async requestSucceededWithResponse(fetchRequest, fetchResponse) {
      try {
        const responseHTML = await fetchResponse.responseHTML;
        const snapshot = PageSnapshot.fromHTMLString(responseHTML);
        this.snapshotCache.put(fetchRequest.url, snapshot);
      } catch (_) {
      }
    }
    requestStarted(fetchRequest) {
    }
    requestErrored(fetchRequest) {
    }
    requestFinished(fetchRequest) {
    }
    requestPreventedHandlingResponse(fetchRequest, fetchResponse) {
    }
    requestFailedWithResponse(fetchRequest, fetchResponse) {
    }
    #preloadAll = () => {
      this.preloadOnLoadLinksForView(document.body);
    };
  };
  var Cache = class {
    constructor(session2) {
      this.session = session2;
    }
    clear() {
      this.session.clearCache();
    }
    resetCacheControl() {
      this.#setCacheControl("");
    }
    exemptPageFromCache() {
      this.#setCacheControl("no-cache");
    }
    exemptPageFromPreview() {
      this.#setCacheControl("no-preview");
    }
    #setCacheControl(value) {
      setMetaContent("turbo-cache-control", value);
    }
  };
  var Session = class {
    navigator = new Navigator(this);
    history = new History(this);
    view = new PageView(this, document.documentElement);
    adapter = new BrowserAdapter(this);
    pageObserver = new PageObserver(this);
    cacheObserver = new CacheObserver();
    linkPrefetchObserver = new LinkPrefetchObserver(this, document);
    linkClickObserver = new LinkClickObserver(this, window);
    formSubmitObserver = new FormSubmitObserver(this, document);
    scrollObserver = new ScrollObserver(this);
    streamObserver = new StreamObserver(this);
    formLinkClickObserver = new FormLinkClickObserver(this, document.documentElement);
    frameRedirector = new FrameRedirector(this, document.documentElement);
    streamMessageRenderer = new StreamMessageRenderer();
    cache = new Cache(this);
    drive = true;
    enabled = true;
    progressBarDelay = 500;
    started = false;
    formMode = "on";
    #pageRefreshDebouncePeriod = 150;
    constructor(recentRequests2) {
      this.recentRequests = recentRequests2;
      this.preloader = new Preloader(this, this.view.snapshotCache);
      this.debouncedRefresh = this.refresh;
      this.pageRefreshDebouncePeriod = this.pageRefreshDebouncePeriod;
    }
    start() {
      if (!this.started) {
        this.pageObserver.start();
        this.cacheObserver.start();
        this.linkPrefetchObserver.start();
        this.formLinkClickObserver.start();
        this.linkClickObserver.start();
        this.formSubmitObserver.start();
        this.scrollObserver.start();
        this.streamObserver.start();
        this.frameRedirector.start();
        this.history.start();
        this.preloader.start();
        this.started = true;
        this.enabled = true;
      }
    }
    disable() {
      this.enabled = false;
    }
    stop() {
      if (this.started) {
        this.pageObserver.stop();
        this.cacheObserver.stop();
        this.linkPrefetchObserver.stop();
        this.formLinkClickObserver.stop();
        this.linkClickObserver.stop();
        this.formSubmitObserver.stop();
        this.scrollObserver.stop();
        this.streamObserver.stop();
        this.frameRedirector.stop();
        this.history.stop();
        this.preloader.stop();
        this.started = false;
      }
    }
    registerAdapter(adapter) {
      this.adapter = adapter;
    }
    visit(location2, options = {}) {
      const frameElement = options.frame ? document.getElementById(options.frame) : null;
      if (frameElement instanceof FrameElement) {
        const action = options.action || getVisitAction(frameElement);
        frameElement.delegate.proposeVisitIfNavigatedWithAction(frameElement, action);
        frameElement.src = location2.toString();
      } else {
        this.navigator.proposeVisit(expandURL(location2), options);
      }
    }
    refresh(url, requestId) {
      const isRecentRequest = requestId && this.recentRequests.has(requestId);
      if (!isRecentRequest) {
        this.visit(url, { action: "replace", shouldCacheSnapshot: false });
      }
    }
    connectStreamSource(source) {
      this.streamObserver.connectStreamSource(source);
    }
    disconnectStreamSource(source) {
      this.streamObserver.disconnectStreamSource(source);
    }
    renderStreamMessage(message) {
      this.streamMessageRenderer.render(StreamMessage.wrap(message));
    }
    clearCache() {
      this.view.clearSnapshotCache();
    }
    setProgressBarDelay(delay) {
      this.progressBarDelay = delay;
    }
    setFormMode(mode) {
      this.formMode = mode;
    }
    get location() {
      return this.history.location;
    }
    get restorationIdentifier() {
      return this.history.restorationIdentifier;
    }
    get pageRefreshDebouncePeriod() {
      return this.#pageRefreshDebouncePeriod;
    }
    set pageRefreshDebouncePeriod(value) {
      this.refresh = debounce(this.debouncedRefresh.bind(this), value);
      this.#pageRefreshDebouncePeriod = value;
    }
    // Preloader delegate
    shouldPreloadLink(element) {
      const isUnsafe = element.hasAttribute("data-turbo-method");
      const isStream = element.hasAttribute("data-turbo-stream");
      const frameTarget = element.getAttribute("data-turbo-frame");
      const frame = frameTarget == "_top" ? null : document.getElementById(frameTarget) || findClosestRecursively(element, "turbo-frame:not([disabled])");
      if (isUnsafe || isStream || frame instanceof FrameElement) {
        return false;
      } else {
        const location2 = new URL(element.href);
        return this.elementIsNavigatable(element) && locationIsVisitable(location2, this.snapshot.rootLocation);
      }
    }
    // History delegate
    historyPoppedToLocationWithRestorationIdentifierAndDirection(location2, restorationIdentifier, direction) {
      if (this.enabled) {
        this.navigator.startVisit(location2, restorationIdentifier, {
          action: "restore",
          historyChanged: true,
          direction
        });
      } else {
        this.adapter.pageInvalidated({
          reason: "turbo_disabled"
        });
      }
    }
    // Scroll observer delegate
    scrollPositionChanged(position) {
      this.history.updateRestorationData({ scrollPosition: position });
    }
    // Form click observer delegate
    willSubmitFormLinkToLocation(link, location2) {
      return this.elementIsNavigatable(link) && locationIsVisitable(location2, this.snapshot.rootLocation);
    }
    submittedFormLinkToLocation() {
    }
    // Link hover observer delegate
    canPrefetchRequestToLocation(link, location2) {
      return this.elementIsNavigatable(link) && locationIsVisitable(location2, this.snapshot.rootLocation);
    }
    // Link click observer delegate
    willFollowLinkToLocation(link, location2, event) {
      return this.elementIsNavigatable(link) && locationIsVisitable(location2, this.snapshot.rootLocation) && this.applicationAllowsFollowingLinkToLocation(link, location2, event);
    }
    followedLinkToLocation(link, location2) {
      const action = this.getActionForLink(link);
      const acceptsStreamResponse = link.hasAttribute("data-turbo-stream");
      this.visit(location2.href, { action, acceptsStreamResponse });
    }
    // Navigator delegate
    allowsVisitingLocationWithAction(location2, action) {
      return this.locationWithActionIsSamePage(location2, action) || this.applicationAllowsVisitingLocation(location2);
    }
    visitProposedToLocation(location2, options) {
      extendURLWithDeprecatedProperties(location2);
      this.adapter.visitProposedToLocation(location2, options);
    }
    // Visit delegate
    visitStarted(visit2) {
      if (!visit2.acceptsStreamResponse) {
        markAsBusy(document.documentElement);
        this.view.markVisitDirection(visit2.direction);
      }
      extendURLWithDeprecatedProperties(visit2.location);
      if (!visit2.silent) {
        this.notifyApplicationAfterVisitingLocation(visit2.location, visit2.action);
      }
    }
    visitCompleted(visit2) {
      this.view.unmarkVisitDirection();
      clearBusyState(document.documentElement);
      this.notifyApplicationAfterPageLoad(visit2.getTimingMetrics());
    }
    locationWithActionIsSamePage(location2, action) {
      return this.navigator.locationWithActionIsSamePage(location2, action);
    }
    visitScrolledToSamePageLocation(oldURL, newURL) {
      this.notifyApplicationAfterVisitingSamePageLocation(oldURL, newURL);
    }
    // Form submit observer delegate
    willSubmitForm(form, submitter) {
      const action = getAction$1(form, submitter);
      return this.submissionIsNavigatable(form, submitter) && locationIsVisitable(expandURL(action), this.snapshot.rootLocation);
    }
    formSubmitted(form, submitter) {
      this.navigator.submitForm(form, submitter);
    }
    // Page observer delegate
    pageBecameInteractive() {
      this.view.lastRenderedLocation = this.location;
      this.notifyApplicationAfterPageLoad();
    }
    pageLoaded() {
      this.history.assumeControlOfScrollRestoration();
    }
    pageWillUnload() {
      this.history.relinquishControlOfScrollRestoration();
    }
    // Stream observer delegate
    receivedMessageFromStream(message) {
      this.renderStreamMessage(message);
    }
    // Page view delegate
    viewWillCacheSnapshot() {
      if (!this.navigator.currentVisit?.silent) {
        this.notifyApplicationBeforeCachingSnapshot();
      }
    }
    allowsImmediateRender({ element }, options) {
      const event = this.notifyApplicationBeforeRender(element, options);
      const {
        defaultPrevented,
        detail: { render: render2 }
      } = event;
      if (this.view.renderer && render2) {
        this.view.renderer.renderElement = render2;
      }
      return !defaultPrevented;
    }
    viewRenderedSnapshot(_snapshot, _isPreview, renderMethod) {
      this.view.lastRenderedLocation = this.history.location;
      this.notifyApplicationAfterRender(renderMethod);
    }
    preloadOnLoadLinksForView(element) {
      this.preloader.preloadOnLoadLinksForView(element);
    }
    viewInvalidated(reason) {
      this.adapter.pageInvalidated(reason);
    }
    // Frame element
    frameLoaded(frame) {
      this.notifyApplicationAfterFrameLoad(frame);
    }
    frameRendered(fetchResponse, frame) {
      this.notifyApplicationAfterFrameRender(fetchResponse, frame);
    }
    // Application events
    applicationAllowsFollowingLinkToLocation(link, location2, ev) {
      const event = this.notifyApplicationAfterClickingLinkToLocation(link, location2, ev);
      return !event.defaultPrevented;
    }
    applicationAllowsVisitingLocation(location2) {
      const event = this.notifyApplicationBeforeVisitingLocation(location2);
      return !event.defaultPrevented;
    }
    notifyApplicationAfterClickingLinkToLocation(link, location2, event) {
      return dispatch("turbo:click", {
        target: link,
        detail: { url: location2.href, originalEvent: event },
        cancelable: true
      });
    }
    notifyApplicationBeforeVisitingLocation(location2) {
      return dispatch("turbo:before-visit", {
        detail: { url: location2.href },
        cancelable: true
      });
    }
    notifyApplicationAfterVisitingLocation(location2, action) {
      return dispatch("turbo:visit", { detail: { url: location2.href, action } });
    }
    notifyApplicationBeforeCachingSnapshot() {
      return dispatch("turbo:before-cache");
    }
    notifyApplicationBeforeRender(newBody, options) {
      return dispatch("turbo:before-render", {
        detail: { newBody, ...options },
        cancelable: true
      });
    }
    notifyApplicationAfterRender(renderMethod) {
      return dispatch("turbo:render", { detail: { renderMethod } });
    }
    notifyApplicationAfterPageLoad(timing = {}) {
      return dispatch("turbo:load", {
        detail: { url: this.location.href, timing }
      });
    }
    notifyApplicationAfterVisitingSamePageLocation(oldURL, newURL) {
      dispatchEvent(
        new HashChangeEvent("hashchange", {
          oldURL: oldURL.toString(),
          newURL: newURL.toString()
        })
      );
    }
    notifyApplicationAfterFrameLoad(frame) {
      return dispatch("turbo:frame-load", { target: frame });
    }
    notifyApplicationAfterFrameRender(fetchResponse, frame) {
      return dispatch("turbo:frame-render", {
        detail: { fetchResponse },
        target: frame,
        cancelable: true
      });
    }
    // Helpers
    submissionIsNavigatable(form, submitter) {
      if (this.formMode == "off") {
        return false;
      } else {
        const submitterIsNavigatable = submitter ? this.elementIsNavigatable(submitter) : true;
        if (this.formMode == "optin") {
          return submitterIsNavigatable && form.closest('[data-turbo="true"]') != null;
        } else {
          return submitterIsNavigatable && this.elementIsNavigatable(form);
        }
      }
    }
    elementIsNavigatable(element) {
      const container = findClosestRecursively(element, "[data-turbo]");
      const withinFrame = findClosestRecursively(element, "turbo-frame");
      if (this.drive || withinFrame) {
        if (container) {
          return container.getAttribute("data-turbo") != "false";
        } else {
          return true;
        }
      } else {
        if (container) {
          return container.getAttribute("data-turbo") == "true";
        } else {
          return false;
        }
      }
    }
    // Private
    getActionForLink(link) {
      return getVisitAction(link) || "advance";
    }
    get snapshot() {
      return this.view.snapshot;
    }
  };
  function extendURLWithDeprecatedProperties(url) {
    Object.defineProperties(url, deprecatedLocationPropertyDescriptors);
  }
  var deprecatedLocationPropertyDescriptors = {
    absoluteURL: {
      get() {
        return this.toString();
      }
    }
  };
  var session = new Session(recentRequests);
  var { cache, navigator: navigator$1 } = session;
  function start() {
    session.start();
  }
  function registerAdapter(adapter) {
    session.registerAdapter(adapter);
  }
  function visit(location2, options) {
    session.visit(location2, options);
  }
  function connectStreamSource(source) {
    session.connectStreamSource(source);
  }
  function disconnectStreamSource(source) {
    session.disconnectStreamSource(source);
  }
  function renderStreamMessage(message) {
    session.renderStreamMessage(message);
  }
  function clearCache() {
    console.warn(
      "Please replace `Turbo.clearCache()` with `Turbo.cache.clear()`. The top-level function is deprecated and will be removed in a future version of Turbo.`"
    );
    session.clearCache();
  }
  function setProgressBarDelay(delay) {
    session.setProgressBarDelay(delay);
  }
  function setConfirmMethod(confirmMethod) {
    FormSubmission.confirmMethod = confirmMethod;
  }
  function setFormMode(mode) {
    session.setFormMode(mode);
  }
  var Turbo = /* @__PURE__ */ Object.freeze({
    __proto__: null,
    navigator: navigator$1,
    session,
    cache,
    PageRenderer,
    PageSnapshot,
    FrameRenderer,
    fetch: fetchWithTurboHeaders,
    start,
    registerAdapter,
    visit,
    connectStreamSource,
    disconnectStreamSource,
    renderStreamMessage,
    clearCache,
    setProgressBarDelay,
    setConfirmMethod,
    setFormMode
  });
  var TurboFrameMissingError = class extends Error {
  };
  var FrameController = class {
    fetchResponseLoaded = (_fetchResponse) => Promise.resolve();
    #currentFetchRequest = null;
    #resolveVisitPromise = () => {
    };
    #connected = false;
    #hasBeenLoaded = false;
    #ignoredAttributes = /* @__PURE__ */ new Set();
    action = null;
    constructor(element) {
      this.element = element;
      this.view = new FrameView(this, this.element);
      this.appearanceObserver = new AppearanceObserver(this, this.element);
      this.formLinkClickObserver = new FormLinkClickObserver(this, this.element);
      this.linkInterceptor = new LinkInterceptor(this, this.element);
      this.restorationIdentifier = uuid();
      this.formSubmitObserver = new FormSubmitObserver(this, this.element);
    }
    // Frame delegate
    connect() {
      if (!this.#connected) {
        this.#connected = true;
        if (this.loadingStyle == FrameLoadingStyle.lazy) {
          this.appearanceObserver.start();
        } else {
          this.#loadSourceURL();
        }
        this.formLinkClickObserver.start();
        this.linkInterceptor.start();
        this.formSubmitObserver.start();
      }
    }
    disconnect() {
      if (this.#connected) {
        this.#connected = false;
        this.appearanceObserver.stop();
        this.formLinkClickObserver.stop();
        this.linkInterceptor.stop();
        this.formSubmitObserver.stop();
      }
    }
    disabledChanged() {
      if (this.loadingStyle == FrameLoadingStyle.eager) {
        this.#loadSourceURL();
      }
    }
    sourceURLChanged() {
      if (this.#isIgnoringChangesTo("src")) return;
      if (this.element.isConnected) {
        this.complete = false;
      }
      if (this.loadingStyle == FrameLoadingStyle.eager || this.#hasBeenLoaded) {
        this.#loadSourceURL();
      }
    }
    sourceURLReloaded() {
      const { src } = this.element;
      this.element.removeAttribute("complete");
      this.element.src = null;
      this.element.src = src;
      return this.element.loaded;
    }
    loadingStyleChanged() {
      if (this.loadingStyle == FrameLoadingStyle.lazy) {
        this.appearanceObserver.start();
      } else {
        this.appearanceObserver.stop();
        this.#loadSourceURL();
      }
    }
    async #loadSourceURL() {
      if (this.enabled && this.isActive && !this.complete && this.sourceURL) {
        this.element.loaded = this.#visit(expandURL(this.sourceURL));
        this.appearanceObserver.stop();
        await this.element.loaded;
        this.#hasBeenLoaded = true;
      }
    }
    async loadResponse(fetchResponse) {
      if (fetchResponse.redirected || fetchResponse.succeeded && fetchResponse.isHTML) {
        this.sourceURL = fetchResponse.response.url;
      }
      try {
        const html = await fetchResponse.responseHTML;
        if (html) {
          const document2 = parseHTMLDocument(html);
          const pageSnapshot = PageSnapshot.fromDocument(document2);
          if (pageSnapshot.isVisitable) {
            await this.#loadFrameResponse(fetchResponse, document2);
          } else {
            await this.#handleUnvisitableFrameResponse(fetchResponse);
          }
        }
      } finally {
        this.fetchResponseLoaded = () => Promise.resolve();
      }
    }
    // Appearance observer delegate
    elementAppearedInViewport(element) {
      this.proposeVisitIfNavigatedWithAction(element, getVisitAction(element));
      this.#loadSourceURL();
    }
    // Form link click observer delegate
    willSubmitFormLinkToLocation(link) {
      return this.#shouldInterceptNavigation(link);
    }
    submittedFormLinkToLocation(link, _location, form) {
      const frame = this.#findFrameElement(link);
      if (frame) form.setAttribute("data-turbo-frame", frame.id);
    }
    // Link interceptor delegate
    shouldInterceptLinkClick(element, _location, _event) {
      return this.#shouldInterceptNavigation(element);
    }
    linkClickIntercepted(element, location2) {
      this.#navigateFrame(element, location2);
    }
    // Form submit observer delegate
    willSubmitForm(element, submitter) {
      return element.closest("turbo-frame") == this.element && this.#shouldInterceptNavigation(element, submitter);
    }
    formSubmitted(element, submitter) {
      if (this.formSubmission) {
        this.formSubmission.stop();
      }
      this.formSubmission = new FormSubmission(this, element, submitter);
      const { fetchRequest } = this.formSubmission;
      this.prepareRequest(fetchRequest);
      this.formSubmission.start();
    }
    // Fetch request delegate
    prepareRequest(request3) {
      request3.headers["Turbo-Frame"] = this.id;
      if (this.currentNavigationElement?.hasAttribute("data-turbo-stream")) {
        request3.acceptResponseType(StreamMessage.contentType);
      }
    }
    requestStarted(_request) {
      markAsBusy(this.element);
    }
    requestPreventedHandlingResponse(_request, _response) {
      this.#resolveVisitPromise();
    }
    async requestSucceededWithResponse(request3, response2) {
      await this.loadResponse(response2);
      this.#resolveVisitPromise();
    }
    async requestFailedWithResponse(request3, response2) {
      await this.loadResponse(response2);
      this.#resolveVisitPromise();
    }
    requestErrored(request3, error3) {
      console.error(error3);
      this.#resolveVisitPromise();
    }
    requestFinished(_request) {
      clearBusyState(this.element);
    }
    // Form submission delegate
    formSubmissionStarted({ formElement }) {
      markAsBusy(formElement, this.#findFrameElement(formElement));
    }
    formSubmissionSucceededWithResponse(formSubmission, response2) {
      const frame = this.#findFrameElement(formSubmission.formElement, formSubmission.submitter);
      frame.delegate.proposeVisitIfNavigatedWithAction(frame, getVisitAction(formSubmission.submitter, formSubmission.formElement, frame));
      frame.delegate.loadResponse(response2);
      if (!formSubmission.isSafe) {
        session.clearCache();
      }
    }
    formSubmissionFailedWithResponse(formSubmission, fetchResponse) {
      this.element.delegate.loadResponse(fetchResponse);
      session.clearCache();
    }
    formSubmissionErrored(formSubmission, error3) {
      console.error(error3);
    }
    formSubmissionFinished({ formElement }) {
      clearBusyState(formElement, this.#findFrameElement(formElement));
    }
    // View delegate
    allowsImmediateRender({ element: newFrame }, options) {
      const event = dispatch("turbo:before-frame-render", {
        target: this.element,
        detail: { newFrame, ...options },
        cancelable: true
      });
      const {
        defaultPrevented,
        detail: { render: render2 }
      } = event;
      if (this.view.renderer && render2) {
        this.view.renderer.renderElement = render2;
      }
      return !defaultPrevented;
    }
    viewRenderedSnapshot(_snapshot, _isPreview, _renderMethod) {
    }
    preloadOnLoadLinksForView(element) {
      session.preloadOnLoadLinksForView(element);
    }
    viewInvalidated() {
    }
    // Frame renderer delegate
    willRenderFrame(currentElement, _newElement) {
      this.previousFrameElement = currentElement.cloneNode(true);
    }
    visitCachedSnapshot = ({ element }) => {
      const frame = element.querySelector("#" + this.element.id);
      if (frame && this.previousFrameElement) {
        frame.replaceChildren(...this.previousFrameElement.children);
      }
      delete this.previousFrameElement;
    };
    // Private
    async #loadFrameResponse(fetchResponse, document2) {
      const newFrameElement = await this.extractForeignFrameElement(document2.body);
      if (newFrameElement) {
        const snapshot = new Snapshot(newFrameElement);
        const renderer = new FrameRenderer(this, this.view.snapshot, snapshot, FrameRenderer.renderElement, false, false);
        if (this.view.renderPromise) await this.view.renderPromise;
        this.changeHistory();
        await this.view.render(renderer);
        this.complete = true;
        session.frameRendered(fetchResponse, this.element);
        session.frameLoaded(this.element);
        await this.fetchResponseLoaded(fetchResponse);
      } else if (this.#willHandleFrameMissingFromResponse(fetchResponse)) {
        this.#handleFrameMissingFromResponse(fetchResponse);
      }
    }
    async #visit(url) {
      const request3 = new FetchRequest(this, FetchMethod.get, url, new URLSearchParams(), this.element);
      this.#currentFetchRequest?.cancel();
      this.#currentFetchRequest = request3;
      return new Promise((resolve) => {
        this.#resolveVisitPromise = () => {
          this.#resolveVisitPromise = () => {
          };
          this.#currentFetchRequest = null;
          resolve();
        };
        request3.perform();
      });
    }
    #navigateFrame(element, url, submitter) {
      const frame = this.#findFrameElement(element, submitter);
      frame.delegate.proposeVisitIfNavigatedWithAction(frame, getVisitAction(submitter, element, frame));
      this.#withCurrentNavigationElement(element, () => {
        frame.src = url;
      });
    }
    proposeVisitIfNavigatedWithAction(frame, action = null) {
      this.action = action;
      if (this.action) {
        const pageSnapshot = PageSnapshot.fromElement(frame).clone();
        const { visitCachedSnapshot } = frame.delegate;
        frame.delegate.fetchResponseLoaded = async (fetchResponse) => {
          if (frame.src) {
            const { statusCode, redirected } = fetchResponse;
            const responseHTML = await fetchResponse.responseHTML;
            const response2 = { statusCode, redirected, responseHTML };
            const options = {
              response: response2,
              visitCachedSnapshot,
              willRender: false,
              updateHistory: false,
              restorationIdentifier: this.restorationIdentifier,
              snapshot: pageSnapshot
            };
            if (this.action) options.action = this.action;
            session.visit(frame.src, options);
          }
        };
      }
    }
    changeHistory() {
      if (this.action) {
        const method = getHistoryMethodForAction(this.action);
        session.history.update(method, expandURL(this.element.src || ""), this.restorationIdentifier);
      }
    }
    async #handleUnvisitableFrameResponse(fetchResponse) {
      console.warn(
        `The response (${fetchResponse.statusCode}) from <turbo-frame id="${this.element.id}"> is performing a full page visit due to turbo-visit-control.`
      );
      await this.#visitResponse(fetchResponse.response);
    }
    #willHandleFrameMissingFromResponse(fetchResponse) {
      this.element.setAttribute("complete", "");
      const response2 = fetchResponse.response;
      const visit2 = async (url, options) => {
        if (url instanceof Response) {
          this.#visitResponse(url);
        } else {
          session.visit(url, options);
        }
      };
      const event = dispatch("turbo:frame-missing", {
        target: this.element,
        detail: { response: response2, visit: visit2 },
        cancelable: true
      });
      return !event.defaultPrevented;
    }
    #handleFrameMissingFromResponse(fetchResponse) {
      this.view.missing();
      this.#throwFrameMissingError(fetchResponse);
    }
    #throwFrameMissingError(fetchResponse) {
      const message = `The response (${fetchResponse.statusCode}) did not contain the expected <turbo-frame id="${this.element.id}"> and will be ignored. To perform a full page visit instead, set turbo-visit-control to reload.`;
      throw new TurboFrameMissingError(message);
    }
    async #visitResponse(response2) {
      const wrapped = new FetchResponse(response2);
      const responseHTML = await wrapped.responseHTML;
      const { location: location2, redirected, statusCode } = wrapped;
      return session.visit(location2, { response: { redirected, statusCode, responseHTML } });
    }
    #findFrameElement(element, submitter) {
      const id = getAttribute("data-turbo-frame", submitter, element) || this.element.getAttribute("target");
      return getFrameElementById(id) ?? this.element;
    }
    async extractForeignFrameElement(container) {
      let element;
      const id = CSS.escape(this.id);
      try {
        element = activateElement(container.querySelector(`turbo-frame#${id}`), this.sourceURL);
        if (element) {
          return element;
        }
        element = activateElement(container.querySelector(`turbo-frame[src][recurse~=${id}]`), this.sourceURL);
        if (element) {
          await element.loaded;
          return await this.extractForeignFrameElement(element);
        }
      } catch (error3) {
        console.error(error3);
        return new FrameElement();
      }
      return null;
    }
    #formActionIsVisitable(form, submitter) {
      const action = getAction$1(form, submitter);
      return locationIsVisitable(expandURL(action), this.rootLocation);
    }
    #shouldInterceptNavigation(element, submitter) {
      const id = getAttribute("data-turbo-frame", submitter, element) || this.element.getAttribute("target");
      if (element instanceof HTMLFormElement && !this.#formActionIsVisitable(element, submitter)) {
        return false;
      }
      if (!this.enabled || id == "_top") {
        return false;
      }
      if (id) {
        const frameElement = getFrameElementById(id);
        if (frameElement) {
          return !frameElement.disabled;
        }
      }
      if (!session.elementIsNavigatable(element)) {
        return false;
      }
      if (submitter && !session.elementIsNavigatable(submitter)) {
        return false;
      }
      return true;
    }
    // Computed properties
    get id() {
      return this.element.id;
    }
    get enabled() {
      return !this.element.disabled;
    }
    get sourceURL() {
      if (this.element.src) {
        return this.element.src;
      }
    }
    set sourceURL(sourceURL) {
      this.#ignoringChangesToAttribute("src", () => {
        this.element.src = sourceURL ?? null;
      });
    }
    get loadingStyle() {
      return this.element.loading;
    }
    get isLoading() {
      return this.formSubmission !== void 0 || this.#resolveVisitPromise() !== void 0;
    }
    get complete() {
      return this.element.hasAttribute("complete");
    }
    set complete(value) {
      if (value) {
        this.element.setAttribute("complete", "");
      } else {
        this.element.removeAttribute("complete");
      }
    }
    get isActive() {
      return this.element.isActive && this.#connected;
    }
    get rootLocation() {
      const meta = this.element.ownerDocument.querySelector(`meta[name="turbo-root"]`);
      const root = meta?.content ?? "/";
      return expandURL(root);
    }
    #isIgnoringChangesTo(attributeName) {
      return this.#ignoredAttributes.has(attributeName);
    }
    #ignoringChangesToAttribute(attributeName, callback) {
      this.#ignoredAttributes.add(attributeName);
      callback();
      this.#ignoredAttributes.delete(attributeName);
    }
    #withCurrentNavigationElement(element, callback) {
      this.currentNavigationElement = element;
      callback();
      delete this.currentNavigationElement;
    }
  };
  function getFrameElementById(id) {
    if (id != null) {
      const element = document.getElementById(id);
      if (element instanceof FrameElement) {
        return element;
      }
    }
  }
  function activateElement(element, currentURL) {
    if (element) {
      const src = element.getAttribute("src");
      if (src != null && currentURL != null && urlsAreEqual(src, currentURL)) {
        throw new Error(`Matching <turbo-frame id="${element.id}"> element has a source URL which references itself`);
      }
      if (element.ownerDocument !== document) {
        element = document.importNode(element, true);
      }
      if (element instanceof FrameElement) {
        element.connectedCallback();
        element.disconnectedCallback();
        return element;
      }
    }
  }
  var StreamActions = {
    after() {
      this.targetElements.forEach((e) => e.parentElement?.insertBefore(this.templateContent, e.nextSibling));
    },
    append() {
      this.removeDuplicateTargetChildren();
      this.targetElements.forEach((e) => e.append(this.templateContent));
    },
    before() {
      this.targetElements.forEach((e) => e.parentElement?.insertBefore(this.templateContent, e));
    },
    prepend() {
      this.removeDuplicateTargetChildren();
      this.targetElements.forEach((e) => e.prepend(this.templateContent));
    },
    remove() {
      this.targetElements.forEach((e) => e.remove());
    },
    replace() {
      this.targetElements.forEach((e) => e.replaceWith(this.templateContent));
    },
    update() {
      this.targetElements.forEach((targetElement) => {
        targetElement.innerHTML = "";
        targetElement.append(this.templateContent);
      });
    },
    refresh() {
      session.refresh(this.baseURI, this.requestId);
    }
  };
  var StreamElement = class _StreamElement extends HTMLElement {
    static async renderElement(newElement) {
      await newElement.performAction();
    }
    async connectedCallback() {
      try {
        await this.render();
      } catch (error3) {
        console.error(error3);
      } finally {
        this.disconnect();
      }
    }
    async render() {
      return this.renderPromise ??= (async () => {
        const event = this.beforeRenderEvent;
        if (this.dispatchEvent(event)) {
          await nextRepaint();
          await event.detail.render(this);
        }
      })();
    }
    disconnect() {
      try {
        this.remove();
      } catch {
      }
    }
    /**
     * Removes duplicate children (by ID)
     */
    removeDuplicateTargetChildren() {
      this.duplicateChildren.forEach((c2) => c2.remove());
    }
    /**
     * Gets the list of duplicate children (i.e. those with the same ID)
     */
    get duplicateChildren() {
      const existingChildren = this.targetElements.flatMap((e) => [...e.children]).filter((c2) => !!c2.id);
      const newChildrenIds = [...this.templateContent?.children || []].filter((c2) => !!c2.id).map((c2) => c2.id);
      return existingChildren.filter((c2) => newChildrenIds.includes(c2.id));
    }
    /**
     * Gets the action function to be performed.
     */
    get performAction() {
      if (this.action) {
        const actionFunction = StreamActions[this.action];
        if (actionFunction) {
          return actionFunction;
        }
        this.#raise("unknown action");
      }
      this.#raise("action attribute is missing");
    }
    /**
     * Gets the target elements which the template will be rendered to.
     */
    get targetElements() {
      if (this.target) {
        return this.targetElementsById;
      } else if (this.targets) {
        return this.targetElementsByQuery;
      } else {
        this.#raise("target or targets attribute is missing");
      }
    }
    /**
     * Gets the contents of the main `<template>`.
     */
    get templateContent() {
      return this.templateElement.content.cloneNode(true);
    }
    /**
     * Gets the main `<template>` used for rendering
     */
    get templateElement() {
      if (this.firstElementChild === null) {
        const template2 = this.ownerDocument.createElement("template");
        this.appendChild(template2);
        return template2;
      } else if (this.firstElementChild instanceof HTMLTemplateElement) {
        return this.firstElementChild;
      }
      this.#raise("first child element must be a <template> element");
    }
    /**
     * Gets the current action.
     */
    get action() {
      return this.getAttribute("action");
    }
    /**
     * Gets the current target (an element ID) to which the result will
     * be rendered.
     */
    get target() {
      return this.getAttribute("target");
    }
    /**
     * Gets the current "targets" selector (a CSS selector)
     */
    get targets() {
      return this.getAttribute("targets");
    }
    /**
     * Reads the request-id attribute
     */
    get requestId() {
      return this.getAttribute("request-id");
    }
    #raise(message) {
      throw new Error(`${this.description}: ${message}`);
    }
    get description() {
      return (this.outerHTML.match(/<[^>]+>/) ?? [])[0] ?? "<turbo-stream>";
    }
    get beforeRenderEvent() {
      return new CustomEvent("turbo:before-stream-render", {
        bubbles: true,
        cancelable: true,
        detail: { newStream: this, render: _StreamElement.renderElement }
      });
    }
    get targetElementsById() {
      const element = this.ownerDocument?.getElementById(this.target);
      if (element !== null) {
        return [element];
      } else {
        return [];
      }
    }
    get targetElementsByQuery() {
      const elements = this.ownerDocument?.querySelectorAll(this.targets);
      if (elements.length !== 0) {
        return Array.prototype.slice.call(elements);
      } else {
        return [];
      }
    }
  };
  var StreamSourceElement = class extends HTMLElement {
    streamSource = null;
    connectedCallback() {
      this.streamSource = this.src.match(/^ws{1,2}:/) ? new WebSocket(this.src) : new EventSource(this.src);
      connectStreamSource(this.streamSource);
    }
    disconnectedCallback() {
      if (this.streamSource) {
        this.streamSource.close();
        disconnectStreamSource(this.streamSource);
      }
    }
    get src() {
      return this.getAttribute("src") || "";
    }
  };
  FrameElement.delegateConstructor = FrameController;
  if (customElements.get("turbo-frame") === void 0) {
    customElements.define("turbo-frame", FrameElement);
  }
  if (customElements.get("turbo-stream") === void 0) {
    customElements.define("turbo-stream", StreamElement);
  }
  if (customElements.get("turbo-stream-source") === void 0) {
    customElements.define("turbo-stream-source", StreamSourceElement);
  }
  (() => {
    let element = document.currentScript;
    if (!element) return;
    if (element.hasAttribute("data-turbo-suppress-warning")) return;
    element = element.parentElement;
    while (element) {
      if (element == document.body) {
        return console.warn(
          unindent`
        You are loading Turbo from a <script> element inside the <body> element. This is probably not what you meant to do!

        Load your application’s JavaScript bundle inside the <head> element instead. <script> elements in <body> are evaluated with each page change.

        For more information, see: https://turbo.hotwired.dev/handbook/building#working-with-script-elements

        ——
        Suppress this warning by adding a "data-turbo-suppress-warning" attribute to: %s
      `,
          element.outerHTML
        );
      }
      element = element.parentElement;
    }
  })();
  window.Turbo = { ...Turbo, StreamActions };
  start();

  // ../../node_modules/@hotwired/turbo-rails/app/javascript/turbo/cable.js
  var consumer;
  async function getConsumer() {
    return consumer || setConsumer(createConsumer2().then(setConsumer));
  }
  function setConsumer(newConsumer) {
    return consumer = newConsumer;
  }
  async function createConsumer2() {
    const { createConsumer: createConsumer5 } = await Promise.resolve().then(() => (init_src(), src_exports));
    return createConsumer5();
  }
  async function subscribeTo(channel, mixin) {
    const { subscriptions } = await getConsumer();
    return subscriptions.create(channel, mixin);
  }

  // ../../node_modules/@hotwired/turbo-rails/app/javascript/turbo/snakeize.js
  function walk(obj) {
    if (!obj || typeof obj !== "object") return obj;
    if (obj instanceof Date || obj instanceof RegExp) return obj;
    if (Array.isArray(obj)) return obj.map(walk);
    return Object.keys(obj).reduce(function(acc, key) {
      var camel = key[0].toLowerCase() + key.slice(1).replace(/([A-Z]+)/g, function(m2, x2) {
        return "_" + x2.toLowerCase();
      });
      acc[camel] = walk(obj[key]);
      return acc;
    }, {});
  }

  // ../../node_modules/@hotwired/turbo-rails/app/javascript/turbo/cable_stream_source_element.js
  var TurboCableStreamSourceElement = class extends HTMLElement {
    async connectedCallback() {
      connectStreamSource(this);
      this.subscription = await subscribeTo(this.channel, {
        received: this.dispatchMessageEvent.bind(this),
        connected: this.subscriptionConnected.bind(this),
        disconnected: this.subscriptionDisconnected.bind(this)
      });
    }
    disconnectedCallback() {
      disconnectStreamSource(this);
      if (this.subscription) this.subscription.unsubscribe();
    }
    dispatchMessageEvent(data) {
      const event = new MessageEvent("message", { data });
      return this.dispatchEvent(event);
    }
    subscriptionConnected() {
      this.setAttribute("connected", "");
    }
    subscriptionDisconnected() {
      this.removeAttribute("connected");
    }
    get channel() {
      const channel = this.getAttribute("channel");
      const signed_stream_name = this.getAttribute("signed-stream-name");
      return { channel, signed_stream_name, ...walk({ ...this.dataset }) };
    }
  };
  if (customElements.get("turbo-cable-stream-source") === void 0) {
    customElements.define("turbo-cable-stream-source", TurboCableStreamSourceElement);
  }

  // ../../node_modules/@hotwired/turbo-rails/app/javascript/turbo/fetch_requests.js
  function encodeMethodIntoRequestBody(event) {
    if (event.target instanceof HTMLFormElement) {
      const { target: form, detail: { fetchOptions } } = event;
      form.addEventListener("turbo:submit-start", ({ detail: { formSubmission: { submitter } } }) => {
        const body = isBodyInit(fetchOptions.body) ? fetchOptions.body : new URLSearchParams();
        const method = determineFetchMethod(submitter, body, form);
        if (!/get/i.test(method)) {
          if (/post/i.test(method)) {
            body.delete("_method");
          } else {
            body.set("_method", method);
          }
          fetchOptions.method = "post";
        }
      }, { once: true });
    }
  }
  function determineFetchMethod(submitter, body, form) {
    const formMethod = determineFormMethod(submitter);
    const overrideMethod = body.get("_method");
    const method = form.getAttribute("method") || "get";
    if (typeof formMethod == "string") {
      return formMethod;
    } else if (typeof overrideMethod == "string") {
      return overrideMethod;
    } else {
      return method;
    }
  }
  function determineFormMethod(submitter) {
    if (submitter instanceof HTMLButtonElement || submitter instanceof HTMLInputElement) {
      if (submitter.name === "_method") {
        return submitter.value;
      } else if (submitter.hasAttribute("formmethod")) {
        return submitter.formMethod;
      } else {
        return null;
      }
    } else {
      return null;
    }
  }
  function isBodyInit(body) {
    return body instanceof FormData || body instanceof URLSearchParams;
  }

  // ../../node_modules/@hotwired/turbo-rails/app/javascript/turbo/index.js
  window.Turbo = turbo_es2017_esm_exports;
  addEventListener("turbo:before-fetch-request", encodeMethodIntoRequestBody);

  // ../../node_modules/@rails/actioncable/app/assets/javascripts/actioncable.esm.js
  var adapters = {
    logger: typeof console !== "undefined" ? console : void 0,
    WebSocket: typeof WebSocket !== "undefined" ? WebSocket : void 0
  };
  var logger = {
    log(...messages) {
      if (this.enabled) {
        messages.push(Date.now());
        adapters.logger.log("[ActionCable]", ...messages);
      }
    }
  };
  var now2 = () => (/* @__PURE__ */ new Date()).getTime();
  var secondsSince2 = (time) => (now2() - time) / 1e3;
  var ConnectionMonitor2 = class {
    constructor(connection) {
      this.visibilityDidChange = this.visibilityDidChange.bind(this);
      this.connection = connection;
      this.reconnectAttempts = 0;
    }
    start() {
      if (!this.isRunning()) {
        this.startedAt = now2();
        delete this.stoppedAt;
        this.startPolling();
        addEventListener("visibilitychange", this.visibilityDidChange);
        logger.log(`ConnectionMonitor started. stale threshold = ${this.constructor.staleThreshold} s`);
      }
    }
    stop() {
      if (this.isRunning()) {
        this.stoppedAt = now2();
        this.stopPolling();
        removeEventListener("visibilitychange", this.visibilityDidChange);
        logger.log("ConnectionMonitor stopped");
      }
    }
    isRunning() {
      return this.startedAt && !this.stoppedAt;
    }
    recordMessage() {
      this.pingedAt = now2();
    }
    recordConnect() {
      this.reconnectAttempts = 0;
      delete this.disconnectedAt;
      logger.log("ConnectionMonitor recorded connect");
    }
    recordDisconnect() {
      this.disconnectedAt = now2();
      logger.log("ConnectionMonitor recorded disconnect");
    }
    startPolling() {
      this.stopPolling();
      this.poll();
    }
    stopPolling() {
      clearTimeout(this.pollTimeout);
    }
    poll() {
      this.pollTimeout = setTimeout(() => {
        this.reconnectIfStale();
        this.poll();
      }, this.getPollInterval());
    }
    getPollInterval() {
      const { staleThreshold, reconnectionBackoffRate } = this.constructor;
      const backoff = Math.pow(1 + reconnectionBackoffRate, Math.min(this.reconnectAttempts, 10));
      const jitterMax = this.reconnectAttempts === 0 ? 1 : reconnectionBackoffRate;
      const jitter = jitterMax * Math.random();
      return staleThreshold * 1e3 * backoff * (1 + jitter);
    }
    reconnectIfStale() {
      if (this.connectionIsStale()) {
        logger.log(`ConnectionMonitor detected stale connection. reconnectAttempts = ${this.reconnectAttempts}, time stale = ${secondsSince2(this.refreshedAt)} s, stale threshold = ${this.constructor.staleThreshold} s`);
        this.reconnectAttempts++;
        if (this.disconnectedRecently()) {
          logger.log(`ConnectionMonitor skipping reopening recent disconnect. time disconnected = ${secondsSince2(this.disconnectedAt)} s`);
        } else {
          logger.log("ConnectionMonitor reopening");
          this.connection.reopen();
        }
      }
    }
    get refreshedAt() {
      return this.pingedAt ? this.pingedAt : this.startedAt;
    }
    connectionIsStale() {
      return secondsSince2(this.refreshedAt) > this.constructor.staleThreshold;
    }
    disconnectedRecently() {
      return this.disconnectedAt && secondsSince2(this.disconnectedAt) < this.constructor.staleThreshold;
    }
    visibilityDidChange() {
      if (document.visibilityState === "visible") {
        setTimeout(() => {
          if (this.connectionIsStale() || !this.connection.isOpen()) {
            logger.log(`ConnectionMonitor reopening stale connection on visibilitychange. visibilityState = ${document.visibilityState}`);
            this.connection.reopen();
          }
        }, 200);
      }
    }
  };
  ConnectionMonitor2.staleThreshold = 6;
  ConnectionMonitor2.reconnectionBackoffRate = 0.15;
  var INTERNAL = {
    message_types: {
      welcome: "welcome",
      disconnect: "disconnect",
      ping: "ping",
      confirmation: "confirm_subscription",
      rejection: "reject_subscription"
    },
    disconnect_reasons: {
      unauthorized: "unauthorized",
      invalid_request: "invalid_request",
      server_restart: "server_restart",
      remote: "remote"
    },
    default_mount_path: "/cable",
    protocols: ["actioncable-v1-json", "actioncable-unsupported"]
  };
  var { message_types: message_types2, protocols: protocols2 } = INTERNAL;
  var supportedProtocols2 = protocols2.slice(0, protocols2.length - 1);
  var indexOf2 = [].indexOf;
  var Connection2 = class {
    constructor(consumer5) {
      this.open = this.open.bind(this);
      this.consumer = consumer5;
      this.subscriptions = this.consumer.subscriptions;
      this.monitor = new ConnectionMonitor2(this);
      this.disconnected = true;
    }
    send(data) {
      if (this.isOpen()) {
        this.webSocket.send(JSON.stringify(data));
        return true;
      } else {
        return false;
      }
    }
    open() {
      if (this.isActive()) {
        logger.log(`Attempted to open WebSocket, but existing socket is ${this.getState()}`);
        return false;
      } else {
        const socketProtocols = [...protocols2, ...this.consumer.subprotocols || []];
        logger.log(`Opening WebSocket, current state is ${this.getState()}, subprotocols: ${socketProtocols}`);
        if (this.webSocket) {
          this.uninstallEventHandlers();
        }
        this.webSocket = new adapters.WebSocket(this.consumer.url, socketProtocols);
        this.installEventHandlers();
        this.monitor.start();
        return true;
      }
    }
    close({ allowReconnect } = {
      allowReconnect: true
    }) {
      if (!allowReconnect) {
        this.monitor.stop();
      }
      if (this.isOpen()) {
        return this.webSocket.close();
      }
    }
    reopen() {
      logger.log(`Reopening WebSocket, current state is ${this.getState()}`);
      if (this.isActive()) {
        try {
          return this.close();
        } catch (error3) {
          logger.log("Failed to reopen WebSocket", error3);
        } finally {
          logger.log(`Reopening WebSocket in ${this.constructor.reopenDelay}ms`);
          setTimeout(this.open, this.constructor.reopenDelay);
        }
      } else {
        return this.open();
      }
    }
    getProtocol() {
      if (this.webSocket) {
        return this.webSocket.protocol;
      }
    }
    isOpen() {
      return this.isState("open");
    }
    isActive() {
      return this.isState("open", "connecting");
    }
    triedToReconnect() {
      return this.monitor.reconnectAttempts > 0;
    }
    isProtocolSupported() {
      return indexOf2.call(supportedProtocols2, this.getProtocol()) >= 0;
    }
    isState(...states) {
      return indexOf2.call(states, this.getState()) >= 0;
    }
    getState() {
      if (this.webSocket) {
        for (let state in adapters.WebSocket) {
          if (adapters.WebSocket[state] === this.webSocket.readyState) {
            return state.toLowerCase();
          }
        }
      }
      return null;
    }
    installEventHandlers() {
      for (let eventName in this.events) {
        const handler = this.events[eventName].bind(this);
        this.webSocket[`on${eventName}`] = handler;
      }
    }
    uninstallEventHandlers() {
      for (let eventName in this.events) {
        this.webSocket[`on${eventName}`] = function() {
        };
      }
    }
  };
  Connection2.reopenDelay = 500;
  Connection2.prototype.events = {
    message(event) {
      if (!this.isProtocolSupported()) {
        return;
      }
      const { identifier, message, reason, reconnect, type } = JSON.parse(event.data);
      this.monitor.recordMessage();
      switch (type) {
        case message_types2.welcome:
          if (this.triedToReconnect()) {
            this.reconnectAttempted = true;
          }
          this.monitor.recordConnect();
          return this.subscriptions.reload();
        case message_types2.disconnect:
          logger.log(`Disconnecting. Reason: ${reason}`);
          return this.close({
            allowReconnect: reconnect
          });
        case message_types2.ping:
          return null;
        case message_types2.confirmation:
          this.subscriptions.confirmSubscription(identifier);
          if (this.reconnectAttempted) {
            this.reconnectAttempted = false;
            return this.subscriptions.notify(identifier, "connected", {
              reconnected: true
            });
          } else {
            return this.subscriptions.notify(identifier, "connected", {
              reconnected: false
            });
          }
        case message_types2.rejection:
          return this.subscriptions.reject(identifier);
        default:
          return this.subscriptions.notify(identifier, "received", message);
      }
    },
    open() {
      logger.log(`WebSocket onopen event, using '${this.getProtocol()}' subprotocol`);
      this.disconnected = false;
      if (!this.isProtocolSupported()) {
        logger.log("Protocol is unsupported. Stopping monitor and disconnecting.");
        return this.close({
          allowReconnect: false
        });
      }
    },
    close(event) {
      logger.log("WebSocket onclose event");
      if (this.disconnected) {
        return;
      }
      this.disconnected = true;
      this.monitor.recordDisconnect();
      return this.subscriptions.notifyAll("disconnected", {
        willAttemptReconnect: this.monitor.isRunning()
      });
    },
    error() {
      logger.log("WebSocket onerror event");
    }
  };
  var extend2 = function(object, properties) {
    if (properties != null) {
      for (let key in properties) {
        const value = properties[key];
        object[key] = value;
      }
    }
    return object;
  };
  var Subscription2 = class {
    constructor(consumer5, params2 = {}, mixin) {
      this.consumer = consumer5;
      this.identifier = JSON.stringify(params2);
      extend2(this, mixin);
    }
    perform(action, data = {}) {
      data.action = action;
      return this.send(data);
    }
    send(data) {
      return this.consumer.send({
        command: "message",
        identifier: this.identifier,
        data: JSON.stringify(data)
      });
    }
    unsubscribe() {
      return this.consumer.subscriptions.remove(this);
    }
  };
  var SubscriptionGuarantor2 = class {
    constructor(subscriptions) {
      this.subscriptions = subscriptions;
      this.pendingSubscriptions = [];
    }
    guarantee(subscription2) {
      if (this.pendingSubscriptions.indexOf(subscription2) == -1) {
        logger.log(`SubscriptionGuarantor guaranteeing ${subscription2.identifier}`);
        this.pendingSubscriptions.push(subscription2);
      } else {
        logger.log(`SubscriptionGuarantor already guaranteeing ${subscription2.identifier}`);
      }
      this.startGuaranteeing();
    }
    forget(subscription2) {
      logger.log(`SubscriptionGuarantor forgetting ${subscription2.identifier}`);
      this.pendingSubscriptions = this.pendingSubscriptions.filter((s2) => s2 !== subscription2);
    }
    startGuaranteeing() {
      this.stopGuaranteeing();
      this.retrySubscribing();
    }
    stopGuaranteeing() {
      clearTimeout(this.retryTimeout);
    }
    retrySubscribing() {
      this.retryTimeout = setTimeout(() => {
        if (this.subscriptions && typeof this.subscriptions.subscribe === "function") {
          this.pendingSubscriptions.map((subscription2) => {
            logger.log(`SubscriptionGuarantor resubscribing ${subscription2.identifier}`);
            this.subscriptions.subscribe(subscription2);
          });
        }
      }, 500);
    }
  };
  var Subscriptions2 = class {
    constructor(consumer5) {
      this.consumer = consumer5;
      this.guarantor = new SubscriptionGuarantor2(this);
      this.subscriptions = [];
    }
    create(channelName, mixin) {
      const channel = channelName;
      const params2 = typeof channel === "object" ? channel : {
        channel
      };
      const subscription2 = new Subscription2(this.consumer, params2, mixin);
      return this.add(subscription2);
    }
    add(subscription2) {
      this.subscriptions.push(subscription2);
      this.consumer.ensureActiveConnection();
      this.notify(subscription2, "initialized");
      this.subscribe(subscription2);
      return subscription2;
    }
    remove(subscription2) {
      this.forget(subscription2);
      if (!this.findAll(subscription2.identifier).length) {
        this.sendCommand(subscription2, "unsubscribe");
      }
      return subscription2;
    }
    reject(identifier) {
      return this.findAll(identifier).map((subscription2) => {
        this.forget(subscription2);
        this.notify(subscription2, "rejected");
        return subscription2;
      });
    }
    forget(subscription2) {
      this.guarantor.forget(subscription2);
      this.subscriptions = this.subscriptions.filter((s2) => s2 !== subscription2);
      return subscription2;
    }
    findAll(identifier) {
      return this.subscriptions.filter((s2) => s2.identifier === identifier);
    }
    reload() {
      return this.subscriptions.map((subscription2) => this.subscribe(subscription2));
    }
    notifyAll(callbackName, ...args) {
      return this.subscriptions.map((subscription2) => this.notify(subscription2, callbackName, ...args));
    }
    notify(subscription2, callbackName, ...args) {
      let subscriptions;
      if (typeof subscription2 === "string") {
        subscriptions = this.findAll(subscription2);
      } else {
        subscriptions = [subscription2];
      }
      return subscriptions.map((subscription3) => typeof subscription3[callbackName] === "function" ? subscription3[callbackName](...args) : void 0);
    }
    subscribe(subscription2) {
      if (this.sendCommand(subscription2, "subscribe")) {
        this.guarantor.guarantee(subscription2);
      }
    }
    confirmSubscription(identifier) {
      logger.log(`Subscription confirmed ${identifier}`);
      this.findAll(identifier).map((subscription2) => this.guarantor.forget(subscription2));
    }
    sendCommand(subscription2, command) {
      const { identifier } = subscription2;
      return this.consumer.send({
        command,
        identifier
      });
    }
  };
  var Consumer2 = class {
    constructor(url) {
      this._url = url;
      this.subscriptions = new Subscriptions2(this);
      this.connection = new Connection2(this);
      this.subprotocols = [];
    }
    get url() {
      return createWebSocketURL2(this._url);
    }
    send(data) {
      return this.connection.send(data);
    }
    connect() {
      return this.connection.open();
    }
    disconnect() {
      return this.connection.close({
        allowReconnect: false
      });
    }
    ensureActiveConnection() {
      if (!this.connection.isActive()) {
        return this.connection.open();
      }
    }
    addSubProtocol(subprotocol) {
      this.subprotocols = [...this.subprotocols, subprotocol];
    }
  };
  function createWebSocketURL2(url) {
    if (typeof url === "function") {
      url = url();
    }
    if (url && !/^wss?:/i.test(url)) {
      const a = document.createElement("a");
      a.href = url;
      a.href = a.href;
      a.protocol = a.protocol.replace("http", "ws");
      return a.href;
    } else {
      return url;
    }
  }
  function createConsumer3(url = getConfig2("url") || INTERNAL.default_mount_path) {
    return new Consumer2(url);
  }
  function getConfig2(name3) {
    const element = document.head.querySelector(`meta[name='action-cable-${name3}']`);
    if (element) {
      return element.getAttribute("content");
    }
  }

  // channels/consumer.js
  console.log("Initializing ActionCable consumer...");
  var consumer2 = createConsumer3();
  console.log("ActionCable consumer initialized");
  var consumer_default = consumer2;

  // ../../node_modules/morphdom/dist/morphdom-esm.js
  var DOCUMENT_FRAGMENT_NODE = 11;
  function morphAttrs(fromNode, toNode) {
    var toNodeAttrs = toNode.attributes;
    var attr;
    var attrName;
    var attrNamespaceURI;
    var attrValue;
    var fromValue;
    if (toNode.nodeType === DOCUMENT_FRAGMENT_NODE || fromNode.nodeType === DOCUMENT_FRAGMENT_NODE) {
      return;
    }
    for (var i = toNodeAttrs.length - 1; i >= 0; i--) {
      attr = toNodeAttrs[i];
      attrName = attr.name;
      attrNamespaceURI = attr.namespaceURI;
      attrValue = attr.value;
      if (attrNamespaceURI) {
        attrName = attr.localName || attrName;
        fromValue = fromNode.getAttributeNS(attrNamespaceURI, attrName);
        if (fromValue !== attrValue) {
          if (attr.prefix === "xmlns") {
            attrName = attr.name;
          }
          fromNode.setAttributeNS(attrNamespaceURI, attrName, attrValue);
        }
      } else {
        fromValue = fromNode.getAttribute(attrName);
        if (fromValue !== attrValue) {
          fromNode.setAttribute(attrName, attrValue);
        }
      }
    }
    var fromNodeAttrs = fromNode.attributes;
    for (var d2 = fromNodeAttrs.length - 1; d2 >= 0; d2--) {
      attr = fromNodeAttrs[d2];
      attrName = attr.name;
      attrNamespaceURI = attr.namespaceURI;
      if (attrNamespaceURI) {
        attrName = attr.localName || attrName;
        if (!toNode.hasAttributeNS(attrNamespaceURI, attrName)) {
          fromNode.removeAttributeNS(attrNamespaceURI, attrName);
        }
      } else {
        if (!toNode.hasAttribute(attrName)) {
          fromNode.removeAttribute(attrName);
        }
      }
    }
  }
  var range;
  var NS_XHTML = "http://www.w3.org/1999/xhtml";
  var doc = typeof document === "undefined" ? void 0 : document;
  var HAS_TEMPLATE_SUPPORT = !!doc && "content" in doc.createElement("template");
  var HAS_RANGE_SUPPORT = !!doc && doc.createRange && "createContextualFragment" in doc.createRange();
  function createFragmentFromTemplate(str) {
    var template2 = doc.createElement("template");
    template2.innerHTML = str;
    return template2.content.childNodes[0];
  }
  function createFragmentFromRange(str) {
    if (!range) {
      range = doc.createRange();
      range.selectNode(doc.body);
    }
    var fragment = range.createContextualFragment(str);
    return fragment.childNodes[0];
  }
  function createFragmentFromWrap(str) {
    var fragment = doc.createElement("body");
    fragment.innerHTML = str;
    return fragment.childNodes[0];
  }
  function toElement(str) {
    str = str.trim();
    if (HAS_TEMPLATE_SUPPORT) {
      return createFragmentFromTemplate(str);
    } else if (HAS_RANGE_SUPPORT) {
      return createFragmentFromRange(str);
    }
    return createFragmentFromWrap(str);
  }
  function compareNodeNames(fromEl, toEl) {
    var fromNodeName = fromEl.nodeName;
    var toNodeName = toEl.nodeName;
    var fromCodeStart, toCodeStart;
    if (fromNodeName === toNodeName) {
      return true;
    }
    fromCodeStart = fromNodeName.charCodeAt(0);
    toCodeStart = toNodeName.charCodeAt(0);
    if (fromCodeStart <= 90 && toCodeStart >= 97) {
      return fromNodeName === toNodeName.toUpperCase();
    } else if (toCodeStart <= 90 && fromCodeStart >= 97) {
      return toNodeName === fromNodeName.toUpperCase();
    } else {
      return false;
    }
  }
  function createElementNS(name3, namespaceURI) {
    return !namespaceURI || namespaceURI === NS_XHTML ? doc.createElement(name3) : doc.createElementNS(namespaceURI, name3);
  }
  function moveChildren(fromEl, toEl) {
    var curChild = fromEl.firstChild;
    while (curChild) {
      var nextChild = curChild.nextSibling;
      toEl.appendChild(curChild);
      curChild = nextChild;
    }
    return toEl;
  }
  function syncBooleanAttrProp(fromEl, toEl, name3) {
    if (fromEl[name3] !== toEl[name3]) {
      fromEl[name3] = toEl[name3];
      if (fromEl[name3]) {
        fromEl.setAttribute(name3, "");
      } else {
        fromEl.removeAttribute(name3);
      }
    }
  }
  var specialElHandlers = {
    OPTION: function(fromEl, toEl) {
      var parentNode = fromEl.parentNode;
      if (parentNode) {
        var parentName = parentNode.nodeName.toUpperCase();
        if (parentName === "OPTGROUP") {
          parentNode = parentNode.parentNode;
          parentName = parentNode && parentNode.nodeName.toUpperCase();
        }
        if (parentName === "SELECT" && !parentNode.hasAttribute("multiple")) {
          if (fromEl.hasAttribute("selected") && !toEl.selected) {
            fromEl.setAttribute("selected", "selected");
            fromEl.removeAttribute("selected");
          }
          parentNode.selectedIndex = -1;
        }
      }
      syncBooleanAttrProp(fromEl, toEl, "selected");
    },
    /**
     * The "value" attribute is special for the <input> element since it sets
     * the initial value. Changing the "value" attribute without changing the
     * "value" property will have no effect since it is only used to the set the
     * initial value.  Similar for the "checked" attribute, and "disabled".
     */
    INPUT: function(fromEl, toEl) {
      syncBooleanAttrProp(fromEl, toEl, "checked");
      syncBooleanAttrProp(fromEl, toEl, "disabled");
      if (fromEl.value !== toEl.value) {
        fromEl.value = toEl.value;
      }
      if (!toEl.hasAttribute("value")) {
        fromEl.removeAttribute("value");
      }
    },
    TEXTAREA: function(fromEl, toEl) {
      var newValue = toEl.value;
      if (fromEl.value !== newValue) {
        fromEl.value = newValue;
      }
      var firstChild = fromEl.firstChild;
      if (firstChild) {
        var oldValue = firstChild.nodeValue;
        if (oldValue == newValue || !newValue && oldValue == fromEl.placeholder) {
          return;
        }
        firstChild.nodeValue = newValue;
      }
    },
    SELECT: function(fromEl, toEl) {
      if (!toEl.hasAttribute("multiple")) {
        var selectedIndex = -1;
        var i = 0;
        var curChild = fromEl.firstChild;
        var optgroup;
        var nodeName;
        while (curChild) {
          nodeName = curChild.nodeName && curChild.nodeName.toUpperCase();
          if (nodeName === "OPTGROUP") {
            optgroup = curChild;
            curChild = optgroup.firstChild;
          } else {
            if (nodeName === "OPTION") {
              if (curChild.hasAttribute("selected")) {
                selectedIndex = i;
                break;
              }
              i++;
            }
            curChild = curChild.nextSibling;
            if (!curChild && optgroup) {
              curChild = optgroup.nextSibling;
              optgroup = null;
            }
          }
        }
        fromEl.selectedIndex = selectedIndex;
      }
    }
  };
  var ELEMENT_NODE = 1;
  var DOCUMENT_FRAGMENT_NODE$1 = 11;
  var TEXT_NODE = 3;
  var COMMENT_NODE = 8;
  function noop() {
  }
  function defaultGetNodeKey(node) {
    if (node) {
      return node.getAttribute && node.getAttribute("id") || node.id;
    }
  }
  function morphdomFactory(morphAttrs2) {
    return function morphdom2(fromNode, toNode, options) {
      if (!options) {
        options = {};
      }
      if (typeof toNode === "string") {
        if (fromNode.nodeName === "#document" || fromNode.nodeName === "HTML" || fromNode.nodeName === "BODY") {
          var toNodeHtml = toNode;
          toNode = doc.createElement("html");
          toNode.innerHTML = toNodeHtml;
        } else {
          toNode = toElement(toNode);
        }
      }
      var getNodeKey = options.getNodeKey || defaultGetNodeKey;
      var onBeforeNodeAdded = options.onBeforeNodeAdded || noop;
      var onNodeAdded = options.onNodeAdded || noop;
      var onBeforeElUpdated = options.onBeforeElUpdated || noop;
      var onElUpdated = options.onElUpdated || noop;
      var onBeforeNodeDiscarded = options.onBeforeNodeDiscarded || noop;
      var onNodeDiscarded = options.onNodeDiscarded || noop;
      var onBeforeElChildrenUpdated = options.onBeforeElChildrenUpdated || noop;
      var childrenOnly = options.childrenOnly === true;
      var fromNodesLookup = /* @__PURE__ */ Object.create(null);
      var keyedRemovalList = [];
      function addKeyedRemoval(key) {
        keyedRemovalList.push(key);
      }
      function walkDiscardedChildNodes(node, skipKeyedNodes) {
        if (node.nodeType === ELEMENT_NODE) {
          var curChild = node.firstChild;
          while (curChild) {
            var key = void 0;
            if (skipKeyedNodes && (key = getNodeKey(curChild))) {
              addKeyedRemoval(key);
            } else {
              onNodeDiscarded(curChild);
              if (curChild.firstChild) {
                walkDiscardedChildNodes(curChild, skipKeyedNodes);
              }
            }
            curChild = curChild.nextSibling;
          }
        }
      }
      function removeNode(node, parentNode, skipKeyedNodes) {
        if (onBeforeNodeDiscarded(node) === false) {
          return;
        }
        if (parentNode) {
          parentNode.removeChild(node);
        }
        onNodeDiscarded(node);
        walkDiscardedChildNodes(node, skipKeyedNodes);
      }
      function indexTree(node) {
        if (node.nodeType === ELEMENT_NODE || node.nodeType === DOCUMENT_FRAGMENT_NODE$1) {
          var curChild = node.firstChild;
          while (curChild) {
            var key = getNodeKey(curChild);
            if (key) {
              fromNodesLookup[key] = curChild;
            }
            indexTree(curChild);
            curChild = curChild.nextSibling;
          }
        }
      }
      indexTree(fromNode);
      function handleNodeAdded(el) {
        onNodeAdded(el);
        var curChild = el.firstChild;
        while (curChild) {
          var nextSibling = curChild.nextSibling;
          var key = getNodeKey(curChild);
          if (key) {
            var unmatchedFromEl = fromNodesLookup[key];
            if (unmatchedFromEl && compareNodeNames(curChild, unmatchedFromEl)) {
              curChild.parentNode.replaceChild(unmatchedFromEl, curChild);
              morphEl(unmatchedFromEl, curChild);
            } else {
              handleNodeAdded(curChild);
            }
          } else {
            handleNodeAdded(curChild);
          }
          curChild = nextSibling;
        }
      }
      function cleanupFromEl(fromEl, curFromNodeChild, curFromNodeKey) {
        while (curFromNodeChild) {
          var fromNextSibling = curFromNodeChild.nextSibling;
          if (curFromNodeKey = getNodeKey(curFromNodeChild)) {
            addKeyedRemoval(curFromNodeKey);
          } else {
            removeNode(
              curFromNodeChild,
              fromEl,
              true
              /* skip keyed nodes */
            );
          }
          curFromNodeChild = fromNextSibling;
        }
      }
      function morphEl(fromEl, toEl, childrenOnly2) {
        var toElKey = getNodeKey(toEl);
        if (toElKey) {
          delete fromNodesLookup[toElKey];
        }
        if (!childrenOnly2) {
          if (onBeforeElUpdated(fromEl, toEl) === false) {
            return;
          }
          morphAttrs2(fromEl, toEl);
          onElUpdated(fromEl);
          if (onBeforeElChildrenUpdated(fromEl, toEl) === false) {
            return;
          }
        }
        if (fromEl.nodeName !== "TEXTAREA") {
          morphChildren(fromEl, toEl);
        } else {
          specialElHandlers.TEXTAREA(fromEl, toEl);
        }
      }
      function morphChildren(fromEl, toEl) {
        var curToNodeChild = toEl.firstChild;
        var curFromNodeChild = fromEl.firstChild;
        var curToNodeKey;
        var curFromNodeKey;
        var fromNextSibling;
        var toNextSibling;
        var matchingFromEl;
        outer: while (curToNodeChild) {
          toNextSibling = curToNodeChild.nextSibling;
          curToNodeKey = getNodeKey(curToNodeChild);
          while (curFromNodeChild) {
            fromNextSibling = curFromNodeChild.nextSibling;
            if (curToNodeChild.isSameNode && curToNodeChild.isSameNode(curFromNodeChild)) {
              curToNodeChild = toNextSibling;
              curFromNodeChild = fromNextSibling;
              continue outer;
            }
            curFromNodeKey = getNodeKey(curFromNodeChild);
            var curFromNodeType = curFromNodeChild.nodeType;
            var isCompatible = void 0;
            if (curFromNodeType === curToNodeChild.nodeType) {
              if (curFromNodeType === ELEMENT_NODE) {
                if (curToNodeKey) {
                  if (curToNodeKey !== curFromNodeKey) {
                    if (matchingFromEl = fromNodesLookup[curToNodeKey]) {
                      if (fromNextSibling === matchingFromEl) {
                        isCompatible = false;
                      } else {
                        fromEl.insertBefore(matchingFromEl, curFromNodeChild);
                        if (curFromNodeKey) {
                          addKeyedRemoval(curFromNodeKey);
                        } else {
                          removeNode(
                            curFromNodeChild,
                            fromEl,
                            true
                            /* skip keyed nodes */
                          );
                        }
                        curFromNodeChild = matchingFromEl;
                      }
                    } else {
                      isCompatible = false;
                    }
                  }
                } else if (curFromNodeKey) {
                  isCompatible = false;
                }
                isCompatible = isCompatible !== false && compareNodeNames(curFromNodeChild, curToNodeChild);
                if (isCompatible) {
                  morphEl(curFromNodeChild, curToNodeChild);
                }
              } else if (curFromNodeType === TEXT_NODE || curFromNodeType == COMMENT_NODE) {
                isCompatible = true;
                if (curFromNodeChild.nodeValue !== curToNodeChild.nodeValue) {
                  curFromNodeChild.nodeValue = curToNodeChild.nodeValue;
                }
              }
            }
            if (isCompatible) {
              curToNodeChild = toNextSibling;
              curFromNodeChild = fromNextSibling;
              continue outer;
            }
            if (curFromNodeKey) {
              addKeyedRemoval(curFromNodeKey);
            } else {
              removeNode(
                curFromNodeChild,
                fromEl,
                true
                /* skip keyed nodes */
              );
            }
            curFromNodeChild = fromNextSibling;
          }
          if (curToNodeKey && (matchingFromEl = fromNodesLookup[curToNodeKey]) && compareNodeNames(matchingFromEl, curToNodeChild)) {
            fromEl.appendChild(matchingFromEl);
            morphEl(matchingFromEl, curToNodeChild);
          } else {
            var onBeforeNodeAddedResult = onBeforeNodeAdded(curToNodeChild);
            if (onBeforeNodeAddedResult !== false) {
              if (onBeforeNodeAddedResult) {
                curToNodeChild = onBeforeNodeAddedResult;
              }
              if (curToNodeChild.actualize) {
                curToNodeChild = curToNodeChild.actualize(fromEl.ownerDocument || doc);
              }
              fromEl.appendChild(curToNodeChild);
              handleNodeAdded(curToNodeChild);
            }
          }
          curToNodeChild = toNextSibling;
          curFromNodeChild = fromNextSibling;
        }
        cleanupFromEl(fromEl, curFromNodeChild, curFromNodeKey);
        var specialElHandler = specialElHandlers[fromEl.nodeName];
        if (specialElHandler) {
          specialElHandler(fromEl, toEl);
        }
      }
      var morphedNode = fromNode;
      var morphedNodeType = morphedNode.nodeType;
      var toNodeType = toNode.nodeType;
      if (!childrenOnly) {
        if (morphedNodeType === ELEMENT_NODE) {
          if (toNodeType === ELEMENT_NODE) {
            if (!compareNodeNames(fromNode, toNode)) {
              onNodeDiscarded(fromNode);
              morphedNode = moveChildren(fromNode, createElementNS(toNode.nodeName, toNode.namespaceURI));
            }
          } else {
            morphedNode = toNode;
          }
        } else if (morphedNodeType === TEXT_NODE || morphedNodeType === COMMENT_NODE) {
          if (toNodeType === morphedNodeType) {
            if (morphedNode.nodeValue !== toNode.nodeValue) {
              morphedNode.nodeValue = toNode.nodeValue;
            }
            return morphedNode;
          } else {
            morphedNode = toNode;
          }
        }
      }
      if (morphedNode === toNode) {
        onNodeDiscarded(fromNode);
      } else {
        if (toNode.isSameNode && toNode.isSameNode(morphedNode)) {
          return;
        }
        morphEl(morphedNode, toNode, childrenOnly);
        if (keyedRemovalList) {
          for (var i = 0, len = keyedRemovalList.length; i < len; i++) {
            var elToRemove = fromNodesLookup[keyedRemovalList[i]];
            if (elToRemove) {
              removeNode(elToRemove, elToRemove.parentNode, false);
            }
          }
        }
      }
      if (!childrenOnly && morphedNode !== fromNode && fromNode.parentNode) {
        if (morphedNode.actualize) {
          morphedNode = morphedNode.actualize(fromNode.ownerDocument || doc);
        }
        fromNode.parentNode.replaceChild(morphedNode, fromNode);
      }
      return morphedNode;
    };
  }
  var morphdom = morphdomFactory(morphAttrs);
  var morphdom_esm_default = morphdom;

  // ../../node_modules/cable_ready/dist/cable_ready.js
  var name = "cable_ready";
  var version = "5.0.6";
  var description = "CableReady helps you create great real-time user experiences by making it simple to trigger client-side DOM changes from server-side Ruby.";
  var keywords = ["ruby", "rails", "websockets", "actioncable", "cable", "ssr", "stimulus_reflex", "client-side", "dom"];
  var homepage = "https://cableready.stimulusreflex.com";
  var bugs = "https://github.com/stimulusreflex/cable_ready/issues";
  var repository = "https://github.com/stimulusreflex/cable_ready";
  var license = "MIT";
  var author = "Nathan Hopkins <natehop@gmail.com>";
  var contributors = ["Andrew Mason <andrewmcodes@protonmail.com>", "Julian Rubisch <julian@julianrubisch.at>", "Marco Roth <marco.roth@intergga.ch>", "Nathan Hopkins <natehop@gmail.com>"];
  var main = "./dist/cable_ready.js";
  var module = "./dist/cable_ready.js";
  var browser = "./dist/cable_ready.js";
  var unpkg = "./dist/cable_ready.umd.js";
  var umd = "./dist/cable_ready.umd.js";
  var files = ["dist/*", "javascript/*"];
  var scripts = {
    lint: "yarn run format --check",
    format: "yarn run prettier-standard ./javascript/**/*.js rollup.config.mjs",
    build: "yarn rollup -c",
    watch: "yarn rollup -wc",
    test: "web-test-runner javascript/test/**/*.test.js",
    "docs:dev": "vitepress dev docs",
    "docs:build": "vitepress build docs && cp ./docs/_redirects ./docs/.vitepress/dist",
    "docs:preview": "vitepress preview docs"
  };
  var dependencies = {
    morphdom: "2.6.1"
  };
  var devDependencies = {
    "@open-wc/testing": "^4.0.0",
    "@rollup/plugin-json": "^6.1.0",
    "@rollup/plugin-node-resolve": "^15.3.0",
    "@rollup/plugin-terser": "^0.4.4",
    "@web/dev-server-esbuild": "^1.0.3",
    "@web/dev-server-rollup": "^0.6.4",
    "@web/test-runner": "^0.19.0",
    "prettier-standard": "^16.4.1",
    rollup: "^4.25.0",
    sinon: "^19.0.2",
    vite: "^5.4.10",
    vitepress: "^1.5.0",
    "vitepress-plugin-search": "^1.0.4-alpha.22"
  };
  var packageInfo = {
    name,
    version,
    description,
    keywords,
    homepage,
    bugs,
    repository,
    license,
    author,
    contributors,
    main,
    module,
    browser,
    import: "./dist/cable_ready.js",
    unpkg,
    umd,
    files,
    scripts,
    dependencies,
    devDependencies
  };
  var inputTags = {
    INPUT: true,
    TEXTAREA: true,
    SELECT: true
  };
  var mutableTags = {
    INPUT: true,
    TEXTAREA: true,
    OPTION: true
  };
  var textInputTypes = {
    "datetime-local": true,
    "select-multiple": true,
    "select-one": true,
    color: true,
    date: true,
    datetime: true,
    email: true,
    month: true,
    number: true,
    password: true,
    range: true,
    search: true,
    tel: true,
    text: true,
    textarea: true,
    time: true,
    url: true,
    week: true
  };
  var activeElement;
  var ActiveElement = {
    get element() {
      return activeElement;
    },
    set(element) {
      activeElement = element;
    }
  };
  var isTextInput = (element) => inputTags[element.tagName] && textInputTypes[element.type];
  var assignFocus = (selector) => {
    const element = selector && selector.nodeType === Node.ELEMENT_NODE ? selector : document.querySelector(selector);
    const focusElement = element || ActiveElement.element;
    if (focusElement && focusElement.focus) focusElement.focus();
  };
  var dispatch2 = (element, name3, detail = {}) => {
    const init = {
      bubbles: true,
      cancelable: true,
      detail
    };
    const event = new CustomEvent(name3, init);
    element.dispatchEvent(event);
    if (window.jQuery) window.jQuery(element).trigger(name3, detail);
  };
  var xpathToElement = (xpath) => document.evaluate(xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
  var xpathToElementArray = (xpath, reverse = false) => {
    const snapshotList = document.evaluate(xpath, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
    const snapshots = [];
    for (let i = 0; i < snapshotList.snapshotLength; i++) {
      snapshots.push(snapshotList.snapshotItem(i));
    }
    return reverse ? snapshots.reverse() : snapshots;
  };
  var getClassNames = (names) => Array.from(names).flat();
  var processElements = (operation, callback) => {
    Array.from(operation.selectAll ? operation.element : [operation.element]).forEach(callback);
  };
  var kebabize = createCompounder(function(result, word, index) {
    return result + (index ? "-" : "") + word.toLowerCase();
  });
  function createCompounder(callback) {
    return function(str) {
      return words(str).reduce(callback, "");
    };
  }
  var words = (str) => {
    str = str == null ? "" : str;
    return str.match(/([A-Z]{2,}|[0-9]+|[A-Z]?[a-z]+|[A-Z])/g) || [];
  };
  var operate = (operation, callback) => {
    if (!operation.cancel) {
      operation.delay ? setTimeout(callback, operation.delay) : callback();
      return true;
    }
    return false;
  };
  var before = (target, operation) => dispatch2(target, `cable-ready:before-${kebabize(operation.operation)}`, operation);
  var after = (target, operation) => dispatch2(target, `cable-ready:after-${kebabize(operation.operation)}`, operation);
  function debounce2(fn2, delay = 250) {
    let timer;
    return (...args) => {
      const callback = () => fn2.apply(this, args);
      if (timer) clearTimeout(timer);
      timer = setTimeout(callback, delay);
    };
  }
  function handleErrors(response2) {
    if (!response2.ok) throw Error(response2.statusText);
    return response2;
  }
  function safeScalar(val) {
    if (val !== void 0 && !["string", "number", "boolean"].includes(typeof val)) console.warn(`Operation expects a string, number or boolean, but got ${val} (${typeof val})`);
    return val != null ? val : "";
  }
  function safeString(str) {
    if (str !== void 0 && typeof str !== "string") console.warn(`Operation expects a string, but got ${str} (${typeof str})`);
    return str != null ? String(str) : "";
  }
  function safeArray(arr) {
    if (arr !== void 0 && !Array.isArray(arr)) console.warn(`Operation expects an array, but got ${arr} (${typeof arr})`);
    return arr != null ? Array.from(arr) : [];
  }
  function safeObject(obj) {
    if (obj !== void 0 && typeof obj !== "object") console.warn(`Operation expects an object, but got ${obj} (${typeof obj})`);
    return obj != null ? Object(obj) : {};
  }
  function safeStringOrArray(elem) {
    if (elem !== void 0 && !Array.isArray(elem) && typeof elem !== "string") console.warn(`Operation expects an Array or a String, but got ${elem} (${typeof elem})`);
    return elem == null ? "" : Array.isArray(elem) ? Array.from(elem) : String(elem);
  }
  function fragmentToString(fragment) {
    return new XMLSerializer().serializeToString(fragment);
  }
  async function graciouslyFetch(url, additionalHeaders) {
    try {
      const response2 = await fetch(url, {
        headers: {
          "X-REQUESTED-WITH": "XmlHttpRequest",
          ...additionalHeaders
        }
      });
      if (response2 == void 0) return;
      handleErrors(response2);
      return response2;
    } catch (e) {
      console.error(`Could not fetch ${url}`);
    }
  }
  var BoundedQueue = class {
    constructor(maxSize) {
      this.maxSize = maxSize;
      this.queue = [];
    }
    push(item) {
      if (this.isFull()) {
        this.shift();
      }
      this.queue.push(item);
    }
    shift() {
      return this.queue.shift();
    }
    isFull() {
      return this.queue.length === this.maxSize;
    }
  };
  var utils = Object.freeze({
    __proto__: null,
    BoundedQueue,
    after,
    assignFocus,
    before,
    debounce: debounce2,
    dispatch: dispatch2,
    fragmentToString,
    getClassNames,
    graciouslyFetch,
    handleErrors,
    isTextInput,
    kebabize,
    operate,
    processElements,
    safeArray,
    safeObject,
    safeScalar,
    safeString,
    safeStringOrArray,
    xpathToElement,
    xpathToElementArray
  });
  var shouldMorph = (operation) => (fromEl, toEl) => !shouldMorphCallbacks.map((callback) => typeof callback === "function" ? callback(operation, fromEl, toEl) : true).includes(false);
  var didMorph = (operation) => (el) => {
    didMorphCallbacks.forEach((callback) => {
      if (typeof callback === "function") callback(operation, el);
    });
  };
  var verifyNotMutable = (detail, fromEl, toEl) => {
    if (!mutableTags[fromEl.tagName] && fromEl.isEqualNode(toEl)) return false;
    return true;
  };
  var verifyNotContentEditable = (detail, fromEl, toEl) => {
    if (fromEl === ActiveElement.element && fromEl.isContentEditable) return false;
    return true;
  };
  var verifyNotPermanent = (detail, fromEl, toEl) => {
    const { permanentAttributeName } = detail;
    if (!permanentAttributeName) return true;
    const permanent = fromEl.closest(`[${permanentAttributeName}]`);
    if (!permanent && fromEl === ActiveElement.element && isTextInput(fromEl)) {
      const ignore = {
        value: true
      };
      Array.from(toEl.attributes).forEach((attribute) => {
        if (!ignore[attribute.name]) fromEl.setAttribute(attribute.name, attribute.value);
      });
      return false;
    }
    return !permanent;
  };
  var shouldMorphCallbacks = [verifyNotMutable, verifyNotPermanent, verifyNotContentEditable];
  var didMorphCallbacks = [];
  var morph_callbacks = Object.freeze({
    __proto__: null,
    didMorph,
    didMorphCallbacks,
    shouldMorph,
    shouldMorphCallbacks,
    verifyNotContentEditable,
    verifyNotMutable,
    verifyNotPermanent
  });
  var Operations = {
    // DOM Mutations
    append: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { html, focusSelector } = operation;
          element.insertAdjacentHTML("beforeend", safeScalar(html));
          assignFocus(focusSelector);
        });
        after(element, operation);
      });
    },
    graft: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { parent, focusSelector } = operation;
          const parentElement = document.querySelector(parent);
          if (parentElement) {
            parentElement.appendChild(element);
            assignFocus(focusSelector);
          }
        });
        after(element, operation);
      });
    },
    innerHtml: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { html, focusSelector } = operation;
          element.innerHTML = safeScalar(html);
          assignFocus(focusSelector);
        });
        after(element, operation);
      });
    },
    insertAdjacentHtml: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { html, position, focusSelector } = operation;
          element.insertAdjacentHTML(position || "beforeend", safeScalar(html));
          assignFocus(focusSelector);
        });
        after(element, operation);
      });
    },
    insertAdjacentText: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { text, position, focusSelector } = operation;
          element.insertAdjacentText(position || "beforeend", safeScalar(text));
          assignFocus(focusSelector);
        });
        after(element, operation);
      });
    },
    outerHtml: (operation) => {
      processElements(operation, (element) => {
        const parent = element.parentElement;
        const idx = parent && Array.from(parent.children).indexOf(element);
        before(element, operation);
        operate(operation, () => {
          const { html, focusSelector } = operation;
          element.outerHTML = safeScalar(html);
          assignFocus(focusSelector);
        });
        after(parent ? parent.children[idx] : document.documentElement, operation);
      });
    },
    prepend: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { html, focusSelector } = operation;
          element.insertAdjacentHTML("afterbegin", safeScalar(html));
          assignFocus(focusSelector);
        });
        after(element, operation);
      });
    },
    remove: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { focusSelector } = operation;
          element.remove();
          assignFocus(focusSelector);
        });
        after(document, operation);
      });
    },
    replace: (operation) => {
      processElements(operation, (element) => {
        const parent = element.parentElement;
        const idx = parent && Array.from(parent.children).indexOf(element);
        before(element, operation);
        operate(operation, () => {
          const { html, focusSelector } = operation;
          element.outerHTML = safeScalar(html);
          assignFocus(focusSelector);
        });
        after(parent ? parent.children[idx] : document.documentElement, operation);
      });
    },
    textContent: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { text, focusSelector } = operation;
          element.textContent = safeScalar(text);
          assignFocus(focusSelector);
        });
        after(element, operation);
      });
    },
    // Element Property Mutations
    addCssClass: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { name: name3 } = operation;
          element.classList.add(...getClassNames([safeStringOrArray(name3)]));
        });
        after(element, operation);
      });
    },
    removeAttribute: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { name: name3 } = operation;
          element.removeAttribute(safeString(name3));
        });
        after(element, operation);
      });
    },
    removeCssClass: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { name: name3 } = operation;
          element.classList.remove(...getClassNames([safeStringOrArray(name3)]));
          if (element.classList.length === 0) element.removeAttribute("class");
        });
        after(element, operation);
      });
    },
    setAttribute: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { name: name3, value } = operation;
          element.setAttribute(safeString(name3), safeScalar(value));
        });
        after(element, operation);
      });
    },
    setDatasetProperty: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { name: name3, value } = operation;
          element.dataset[safeString(name3)] = safeScalar(value);
        });
        after(element, operation);
      });
    },
    setProperty: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { name: name3, value } = operation;
          if (name3 in element) element[safeString(name3)] = safeScalar(value);
        });
        after(element, operation);
      });
    },
    setStyle: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { name: name3, value } = operation;
          element.style[safeString(name3)] = safeScalar(value);
        });
        after(element, operation);
      });
    },
    setStyles: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { styles } = operation;
          for (let [name3, value] of Object.entries(styles)) element.style[safeString(name3)] = safeScalar(value);
        });
        after(element, operation);
      });
    },
    setValue: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { value } = operation;
          element.value = safeScalar(value);
        });
        after(element, operation);
      });
    },
    // DOM Events and Meta-Operations
    dispatchEvent: (operation) => {
      processElements(operation, (element) => {
        before(element, operation);
        operate(operation, () => {
          const { name: name3, detail } = operation;
          dispatch2(element, safeString(name3), safeObject(detail));
        });
        after(element, operation);
      });
    },
    setMeta: (operation) => {
      before(document, operation);
      operate(operation, () => {
        const { name: name3, content } = operation;
        let meta = document.head.querySelector(`meta[name='${name3}']`);
        if (!meta) {
          meta = document.createElement("meta");
          meta.name = safeString(name3);
          document.head.appendChild(meta);
        }
        meta.content = safeScalar(content);
      });
      after(document, operation);
    },
    setTitle: (operation) => {
      before(document, operation);
      operate(operation, () => {
        const { title } = operation;
        document.title = safeScalar(title);
      });
      after(document, operation);
    },
    // Browser Manipulations
    clearStorage: (operation) => {
      before(document, operation);
      operate(operation, () => {
        const { type } = operation;
        const storage = type === "session" ? sessionStorage : localStorage;
        storage.clear();
      });
      after(document, operation);
    },
    go: (operation) => {
      before(window, operation);
      operate(operation, () => {
        const { delta } = operation;
        history.go(delta);
      });
      after(window, operation);
    },
    pushState: (operation) => {
      before(window, operation);
      operate(operation, () => {
        const { state, title, url } = operation;
        history.pushState(safeObject(state), safeString(title), safeString(url));
      });
      after(window, operation);
    },
    redirectTo: (operation) => {
      before(window, operation);
      operate(operation, () => {
        let { url, action, turbo } = operation;
        action = action || "advance";
        url = safeString(url);
        if (turbo === void 0) turbo = true;
        if (turbo) {
          if (window.Turbo) window.Turbo.visit(url, {
            action
          });
          if (window.Turbolinks) window.Turbolinks.visit(url, {
            action
          });
          if (!window.Turbo && !window.Turbolinks) window.location.href = url;
        } else {
          window.location.href = url;
        }
      });
      after(window, operation);
    },
    reload: (operation) => {
      before(window, operation);
      operate(operation, () => {
        window.location.reload();
      });
      after(window, operation);
    },
    removeStorageItem: (operation) => {
      before(document, operation);
      operate(operation, () => {
        const { key, type } = operation;
        const storage = type === "session" ? sessionStorage : localStorage;
        storage.removeItem(safeString(key));
      });
      after(document, operation);
    },
    replaceState: (operation) => {
      before(window, operation);
      operate(operation, () => {
        const { state, title, url } = operation;
        history.replaceState(safeObject(state), safeString(title), safeString(url));
      });
      after(window, operation);
    },
    scrollIntoView: (operation) => {
      const { element } = operation;
      before(element, operation);
      operate(operation, () => {
        element.scrollIntoView(operation);
      });
      after(element, operation);
    },
    setCookie: (operation) => {
      before(document, operation);
      operate(operation, () => {
        const { cookie } = operation;
        document.cookie = safeScalar(cookie);
      });
      after(document, operation);
    },
    setFocus: (operation) => {
      const { element } = operation;
      before(element, operation);
      operate(operation, () => {
        assignFocus(element);
      });
      after(element, operation);
    },
    setStorageItem: (operation) => {
      before(document, operation);
      operate(operation, () => {
        const { key, value, type } = operation;
        const storage = type === "session" ? sessionStorage : localStorage;
        storage.setItem(safeString(key), safeScalar(value));
      });
      after(document, operation);
    },
    // Notifications
    consoleLog: (operation) => {
      before(document, operation);
      operate(operation, () => {
        const { message, level } = operation;
        level && ["warn", "info", "error"].includes(level) ? console[level](message) : console.log(message);
      });
      after(document, operation);
    },
    consoleTable: (operation) => {
      before(document, operation);
      operate(operation, () => {
        const { data, columns } = operation;
        console.table(data, safeArray(columns));
      });
      after(document, operation);
    },
    notification: (operation) => {
      before(document, operation);
      operate(operation, () => {
        const { title, options } = operation;
        Notification.requestPermission().then((result) => {
          operation.permission = result;
          if (result === "granted") new Notification(safeString(title), safeObject(options));
        });
      });
      after(document, operation);
    },
    // Morph operations
    morph: (operation) => {
      processElements(operation, (element) => {
        const { html } = operation;
        const template2 = document.createElement("template");
        template2.innerHTML = String(safeScalar(html)).trim();
        operation.content = template2.content;
        const parent = element.parentElement;
        const idx = parent && Array.from(parent.children).indexOf(element);
        before(element, operation);
        operate(operation, () => {
          const { childrenOnly, focusSelector } = operation;
          morphdom_esm_default(element, childrenOnly ? template2.content : template2.innerHTML, {
            childrenOnly: !!childrenOnly,
            onBeforeElUpdated: shouldMorph(operation),
            onElUpdated: didMorph(operation)
          });
          assignFocus(focusSelector);
        });
        after(parent ? parent.children[idx] : document.documentElement, operation);
      });
    }
  };
  var operations = Operations;
  var add = (newOperations) => {
    operations = {
      ...operations,
      ...newOperations
    };
  };
  var addOperations = (operations2) => {
    add(operations2);
  };
  var addOperation = (name3, operation) => {
    const operations2 = {};
    operations2[name3] = operation;
    add(operations2);
  };
  var OperationStore = {
    get all() {
      return operations;
    }
  };
  var missingElement = "warn";
  var MissingElement = {
    get behavior() {
      return missingElement;
    },
    set(value) {
      if (["warn", "ignore", "event", "exception"].includes(value)) missingElement = value;
      else console.warn("Invalid 'onMissingElement' option. Defaulting to 'warn'.");
    }
  };
  var perform = (operations2, options = {
    onMissingElement: MissingElement.behavior
  }) => {
    const batches = {};
    operations2.forEach((operation) => {
      if (!!operation.batch) batches[operation.batch] = batches[operation.batch] ? ++batches[operation.batch] : 1;
    });
    operations2.forEach((operation) => {
      const name3 = operation.operation;
      try {
        if (operation.selector) {
          if (operation.xpath) {
            operation.element = operation.selectAll ? xpathToElementArray(operation.selector) : xpathToElement(operation.selector);
          } else {
            operation.element = operation.selectAll ? document.querySelectorAll(operation.selector) : document.querySelector(operation.selector);
          }
        } else {
          operation.element = document;
        }
        if (operation.element || options.onMissingElement !== "ignore") {
          ActiveElement.set(document.activeElement);
          const cableReadyOperation = OperationStore.all[name3];
          if (cableReadyOperation) {
            cableReadyOperation(operation);
            if (!!operation.batch && --batches[operation.batch] === 0) dispatch2(document, "cable-ready:batch-complete", {
              batch: operation.batch
            });
          } else {
            console.error(`CableReady couldn't find the "${name3}" operation. Make sure you use the camelized form when calling an operation method.`);
          }
        }
      } catch (e) {
        if (operation.element) {
          console.error(`CableReady detected an error in ${name3 || "operation"}: ${e.message}. If you need to support older browsers make sure you've included the corresponding polyfills. https://docs.stimulusreflex.com/setup#polyfills-for-ie11.`);
          console.error(e);
        } else {
          const warning = `CableReady ${name3 || ""} operation failed due to missing DOM element for selector: '${operation.selector}'`;
          switch (options.onMissingElement) {
            case "ignore":
              break;
            case "event":
              dispatch2(document, "cable-ready:missing-element", {
                warning,
                operation
              });
              break;
            case "exception":
              throw warning;
            default:
              console.warn(warning);
          }
        }
      }
    });
  };
  var performAsync = (operations2, options = {
    onMissingElement: MissingElement.behavior
  }) => new Promise((resolve, reject) => {
    try {
      resolve(perform(operations2, options));
    } catch (err) {
      reject(err);
    }
  });
  var SubscribingElement = class extends HTMLElement {
    static get tagName() {
      throw new Error("Implement the tagName() getter in the inheriting class");
    }
    static define() {
      if (!customElements.get(this.tagName)) {
        customElements.define(this.tagName, this);
      }
    }
    disconnectedCallback() {
      if (this.channel) this.channel.unsubscribe();
    }
    createSubscription(consumer5, channel, receivedCallback) {
      this.channel = consumer5.subscriptions.create({
        channel,
        identifier: this.identifier
      }, {
        received: receivedCallback
      });
    }
    get preview() {
      return document.documentElement.hasAttribute("data-turbolinks-preview") || document.documentElement.hasAttribute("data-turbo-preview");
    }
    get identifier() {
      return this.getAttribute("identifier");
    }
  };
  var consumer3;
  var BACKOFF = [25, 50, 75, 100, 200, 250, 500, 800, 1e3, 2e3];
  var wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  var getConsumerWithRetry = async (retry = 0) => {
    if (consumer3) return consumer3;
    if (retry >= BACKOFF.length) {
      throw new Error("Couldn't obtain a Action Cable consumer within 5s");
    }
    await wait(BACKOFF[retry]);
    return await getConsumerWithRetry(retry + 1);
  };
  var CableConsumer = {
    setConsumer(value) {
      consumer3 = value;
    },
    get consumer() {
      return consumer3;
    },
    async getConsumer() {
      return await getConsumerWithRetry();
    }
  };
  var StreamFromElement = class extends SubscribingElement {
    static get tagName() {
      return "cable-ready-stream-from";
    }
    async connectedCallback() {
      if (this.preview) return;
      const consumer5 = await CableConsumer.getConsumer();
      if (consumer5) {
        this.createSubscription(consumer5, "CableReady::Stream", this.performOperations.bind(this));
      } else {
        console.error("The `cable_ready_stream_from` helper cannot connect. You must initialize CableReady with an Action Cable consumer.");
      }
    }
    performOperations(data) {
      if (data.cableReady) perform(data.operations, {
        onMissingElement: this.onMissingElement
      });
    }
    get onMissingElement() {
      const value = this.getAttribute("missing") || MissingElement.behavior;
      if (["warn", "ignore", "event"].includes(value)) return value;
      else {
        console.warn("Invalid 'missing' attribute. Defaulting to 'warn'.");
        return "warn";
      }
    }
  };
  var debugging = false;
  var Debug2 = {
    get enabled() {
      return debugging;
    },
    get disabled() {
      return !debugging;
    },
    get value() {
      return debugging;
    },
    set(value) {
      debugging = !!value;
    },
    set debug(value) {
      debugging = !!value;
    }
  };
  var request = (data, blocks) => {
    if (Debug2.disabled) return;
    const message = `\u2191 Updatable request affecting ${blocks.length} element(s): `;
    console.log(message, {
      elements: blocks.map((b2) => b2.element),
      identifiers: blocks.map((b2) => b2.element.getAttribute("identifier")),
      data
    });
    return message;
  };
  var cancel = (timestamp, reason) => {
    if (Debug2.disabled) return;
    const duration2 = /* @__PURE__ */ new Date() - timestamp;
    const message = `\u274C Updatable request canceled after ${duration2}ms: ${reason}`;
    console.log(message);
    return message;
  };
  var response = (timestamp, element, urls) => {
    if (Debug2.disabled) return;
    const duration2 = /* @__PURE__ */ new Date() - timestamp;
    const message = `\u2193 Updatable response: All URLs fetched in ${duration2}ms`;
    console.log(message, {
      element,
      urls
    });
    return message;
  };
  var morphStart = (timestamp, element) => {
    if (Debug2.disabled) return;
    const duration2 = /* @__PURE__ */ new Date() - timestamp;
    const message = `\u21BB Updatable morph: starting after ${duration2}ms`;
    console.log(message, {
      element
    });
    return message;
  };
  var morphEnd = (timestamp, element) => {
    if (Debug2.disabled) return;
    const duration2 = /* @__PURE__ */ new Date() - timestamp;
    const message = `\u21BA Updatable morph: completed after ${duration2}ms`;
    console.log(message, {
      element
    });
    return message;
  };
  var Log = {
    request,
    cancel,
    response,
    morphStart,
    morphEnd
  };
  var AppearanceObserver2 = class {
    constructor(delegate, element = null) {
      this.delegate = delegate;
      this.element = element || delegate;
      this.started = false;
      this.intersecting = false;
      this.intersectionObserver = new IntersectionObserver(this.intersect);
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.intersectionObserver.observe(this.element);
        this.observeVisibility();
      }
    }
    stop() {
      if (this.started) {
        this.started = false;
        this.intersectionObserver.unobserve(this.element);
        this.unobserveVisibility();
      }
    }
    observeVisibility = () => {
      document.addEventListener("visibilitychange", this.handleVisibilityChange);
    };
    unobserveVisibility = () => {
      document.removeEventListener("visibilitychange", this.handleVisibilityChange);
    };
    intersect = (entries) => {
      entries.forEach((entry) => {
        if (entry.target === this.element) {
          if (entry.isIntersecting && document.visibilityState === "visible") {
            this.intersecting = true;
            this.delegate.appearedInViewport();
          } else {
            this.intersecting = false;
            this.delegate.disappearedFromViewport();
          }
        }
      });
    };
    handleVisibilityChange = (event) => {
      if (document.visibilityState === "visible" && this.intersecting) {
        this.delegate.appearedInViewport();
      } else {
        this.delegate.disappearedFromViewport();
      }
    };
  };
  var template = `
<style>
  :host {
    display: block;
  }
</style>
<slot></slot>
`;
  var UpdatesForElement = class extends SubscribingElement {
    static get tagName() {
      return "cable-ready-updates-for";
    }
    constructor() {
      super();
      const shadowRoot = this.attachShadow({
        mode: "open"
      });
      shadowRoot.innerHTML = template;
      this.triggerElementLog = new BoundedQueue(10);
      this.targetElementLog = new BoundedQueue(10);
      this.appearanceObserver = new AppearanceObserver2(this);
      this.visible = false;
      this.didTransitionToVisible = false;
    }
    async connectedCallback() {
      if (this.preview) return;
      this.update = debounce2(this.update.bind(this), this.debounce);
      const consumer5 = await CableConsumer.getConsumer();
      if (consumer5) {
        this.createSubscription(consumer5, "CableReady::Stream", this.update);
      } else {
        console.error("The `cable_ready_updates_for` helper cannot connect. You must initialize CableReady with an Action Cable consumer.");
      }
      if (this.observeAppearance) {
        this.appearanceObserver.start();
      }
    }
    disconnectedCallback() {
      super.disconnectedCallback();
      if (this.observeAppearance) {
        this.appearanceObserver.stop();
      }
    }
    async update(data) {
      this.lastUpdateTimestamp = /* @__PURE__ */ new Date();
      const blocks = Array.from(document.querySelectorAll(this.query), (element) => new Block(element)).filter((block) => block.shouldUpdate(data));
      this.triggerElementLog.push(`${(/* @__PURE__ */ new Date()).toLocaleString()}: ${Log.request(data, blocks)}`);
      if (blocks.length === 0) {
        this.triggerElementLog.push(`${(/* @__PURE__ */ new Date()).toLocaleString()}: ${Log.cancel(this.lastUpdateTimestamp, "All elements filtered out")}`);
        return;
      }
      if (blocks[0].element !== this && !this.didTransitionToVisible) {
        this.triggerElementLog.push(`${(/* @__PURE__ */ new Date()).toLocaleString()}: ${Log.cancel(this.lastUpdateTimestamp, "Update already requested")}`);
        return;
      }
      ActiveElement.set(document.activeElement);
      this.html = {};
      const uniqueUrls = [...new Set(blocks.map((block) => block.url))];
      await Promise.all(uniqueUrls.map(async (url) => {
        if (!this.html.hasOwnProperty(url)) {
          const response2 = await graciouslyFetch(url, {
            "X-Cable-Ready": "update"
          });
          this.html[url] = await response2.text();
        }
      }));
      this.triggerElementLog.push(`${(/* @__PURE__ */ new Date()).toLocaleString()}: ${Log.response(this.lastUpdateTimestamp, this, uniqueUrls)}`);
      this.index = {};
      blocks.forEach((block) => {
        this.index.hasOwnProperty(block.url) ? this.index[block.url]++ : this.index[block.url] = 0;
        block.process(data, this.html, this.index, this.lastUpdateTimestamp);
      });
    }
    appearedInViewport() {
      if (!this.visible) {
        this.didTransitionToVisible = true;
        this.update({});
      }
      this.visible = true;
    }
    disappearedFromViewport() {
      this.visible = false;
    }
    get query() {
      return `${this.tagName}[identifier="${this.identifier}"]`;
    }
    get identifier() {
      return this.getAttribute("identifier");
    }
    get debounce() {
      return this.hasAttribute("debounce") ? parseInt(this.getAttribute("debounce")) : 20;
    }
    get observeAppearance() {
      return this.hasAttribute("observe-appearance");
    }
  };
  var Block = class {
    constructor(element) {
      this.element = element;
    }
    async process(data, html, fragmentsIndex, startTimestamp) {
      const blockIndex = fragmentsIndex[this.url];
      const template2 = document.createElement("template");
      this.element.setAttribute("updating", "updating");
      template2.innerHTML = String(html[this.url]).trim();
      await this.resolveTurboFrames(template2.content);
      const fragments = template2.content.querySelectorAll(this.query);
      if (fragments.length <= blockIndex) {
        console.warn(`Update aborted due to insufficient number of elements. The offending url is ${this.url}, the offending element is:`, this.element);
        return;
      }
      const operation = {
        element: this.element,
        html: fragments[blockIndex],
        permanentAttributeName: "data-ignore-updates"
      };
      dispatch2(this.element, "cable-ready:before-update", operation);
      this.element.targetElementLog.push(`${(/* @__PURE__ */ new Date()).toLocaleString()}: ${Log.morphStart(startTimestamp, this.element)}`);
      morphdom_esm_default(this.element, fragments[blockIndex], {
        childrenOnly: true,
        onBeforeElUpdated: shouldMorph(operation),
        onElUpdated: (_) => {
          this.element.removeAttribute("updating");
          this.element.didTransitionToVisible = false;
          dispatch2(this.element, "cable-ready:after-update", operation);
          assignFocus(operation.focusSelector);
        }
      });
      this.element.targetElementLog.push(`${(/* @__PURE__ */ new Date()).toLocaleString()}: ${Log.morphEnd(startTimestamp, this.element)}`);
    }
    async resolveTurboFrames(documentFragment) {
      const reloadingTurboFrames = [...documentFragment.querySelectorAll('turbo-frame[src]:not([loading="lazy"])')];
      return Promise.all(reloadingTurboFrames.map((frame) => new Promise(async (resolve) => {
        const frameResponse = await graciouslyFetch(frame.getAttribute("src"), {
          "Turbo-Frame": frame.id,
          "X-Cable-Ready": "update"
        });
        const frameTemplate = document.createElement("template");
        frameTemplate.innerHTML = await frameResponse.text();
        await this.resolveTurboFrames(frameTemplate.content);
        const selector = `turbo-frame#${frame.id}`;
        const frameContent = frameTemplate.content.querySelector(selector);
        const content = frameContent ? frameContent.innerHTML.trim() : "";
        documentFragment.querySelector(selector).innerHTML = content;
        resolve();
      })));
    }
    shouldUpdate(data) {
      return !this.ignoresInnerUpdates && this.hasChangesSelectedForUpdate(data) && (!this.observeAppearance || this.visible);
    }
    hasChangesSelectedForUpdate(data) {
      const only = this.element.getAttribute("only");
      return !(only && data.changed && !only.split(" ").some((attribute) => data.changed.includes(attribute)));
    }
    get ignoresInnerUpdates() {
      return this.element.hasAttribute("ignore-inner-updates") && this.element.hasAttribute("performing-inner-update");
    }
    get url() {
      return this.element.hasAttribute("url") ? this.element.getAttribute("url") : location.href;
    }
    get identifier() {
      return this.element.identifier;
    }
    get query() {
      return this.element.query;
    }
    get visible() {
      return this.element.visible;
    }
    get observeAppearance() {
      return this.element.observeAppearance;
    }
  };
  var registerInnerUpdates = () => {
    document.addEventListener("stimulus-reflex:before", (event) => {
      recursiveMarkUpdatesForElements(event.detail.element);
    });
    document.addEventListener("stimulus-reflex:after", (event) => {
      setTimeout(() => {
        recursiveUnmarkUpdatesForElements(event.detail.element);
      });
    });
    document.addEventListener("turbo:submit-start", (event) => {
      recursiveMarkUpdatesForElements(event.target);
    });
    document.addEventListener("turbo:submit-end", (event) => {
      setTimeout(() => {
        recursiveUnmarkUpdatesForElements(event.target);
      });
    });
    document.addEventListener("turbo-boost:command:start", (event) => {
      recursiveMarkUpdatesForElements(event.target);
    });
    document.addEventListener("turbo-boost:command:finish", (event) => {
      setTimeout(() => {
        recursiveUnmarkUpdatesForElements(event.target);
      });
    });
    document.addEventListener("turbo-boost:command:error", (event) => {
      setTimeout(() => {
        recursiveUnmarkUpdatesForElements(event.target);
      });
    });
  };
  var recursiveMarkUpdatesForElements = (leaf) => {
    const closestUpdatesFor = leaf && leaf.parentElement && leaf.parentElement.closest("cable-ready-updates-for");
    if (closestUpdatesFor) {
      closestUpdatesFor.setAttribute("performing-inner-update", "");
      recursiveMarkUpdatesForElements(closestUpdatesFor);
    }
  };
  var recursiveUnmarkUpdatesForElements = (leaf) => {
    const closestUpdatesFor = leaf && leaf.parentElement && leaf.parentElement.closest("cable-ready-updates-for");
    if (closestUpdatesFor) {
      closestUpdatesFor.removeAttribute("performing-inner-update");
      recursiveUnmarkUpdatesForElements(closestUpdatesFor);
    }
  };
  var defineElements = () => {
    registerInnerUpdates();
    StreamFromElement.define();
    UpdatesForElement.define();
  };
  var initialize = (initializeOptions = {}) => {
    const { consumer: consumer5, onMissingElement, debug } = initializeOptions;
    Debug2.set(!!debug);
    if (consumer5) {
      CableConsumer.setConsumer(consumer5);
    } else {
      console.error("CableReady requires a reference to your Action Cable `consumer` for its helpers to function.\nEnsure that you have imported the `CableReady` package as well as `consumer` from your `channels` folder, then call `CableReady.initialize({ consumer })`.");
    }
    if (onMissingElement) {
      MissingElement.set(onMissingElement);
    }
    defineElements();
  };
  var global2 = {
    perform,
    performAsync,
    shouldMorphCallbacks,
    didMorphCallbacks,
    initialize,
    addOperation,
    addOperations,
    version: packageInfo.version,
    cable: CableConsumer,
    get DOMOperations() {
      console.warn("DEPRECATED: Please use `CableReady.operations` instead of `CableReady.DOMOperations`");
      return OperationStore.all;
    },
    get operations() {
      return OperationStore.all;
    },
    get consumer() {
      return CableConsumer.consumer;
    }
  };
  window.CableReady = global2;

  // channels/location_channel.js
  consumer_default.subscriptions.create("LocationChannel", {
    initialized() {
      console.log("Location Channel initialized");
    },
    connected() {
      console.log("Location Channel connected");
    },
    disconnected() {
      console.log("Location Channel disconnected");
    },
    received(data) {
      if (data.cableReady) global2.perform(data.operations);
    }
  });

  // channels/table_monitor_channel.js
  consumer_default.subscriptions.create("TableMonitorChannel", {
    // Called once when the subscription is created.
    initialized() {
      console.log("TableMonitor Channel initialized");
    },
    connected() {
      console.log("TableMonitor Channel connected");
    },
    disconnected() {
      console.log("TableMonitor Channel disconnected");
    },
    received(data) {
      if (data.cableReady) global2.perform(data.operations);
    }
  });

  // channels/test_channel.js
  consumer_default.subscriptions.create("TestChannel", {
    connected() {
      this.send({ message: "********* Test Client is live *******" });
    },
    received(data) {
      console.log(data);
    }
  });

  // channels/tournament_channel.js
  consumer_default.subscriptions.create("TournamentChannel", {
    initialized() {
      console.log("Tournament Channel initialized");
    },
    connected() {
      console.log("Tournament Channel connected");
    },
    disconnected() {
      console.log("Tournament Channel disconnected");
    },
    received(data) {
      if (data.cableReady) global2.perform(data.operations);
    }
  });

  // channels/tournament_monitor_channel.js
  consumer_default.subscriptions.create("TournamentMonitorChannel", {
    connected() {
    },
    disconnected() {
    },
    received(data) {
      if (data.cableReady) global2.perform(data.operations);
    }
  });

  // ../../node_modules/@hotwired/stimulus/dist/stimulus.js
  var EventListener = class {
    constructor(eventTarget, eventName, eventOptions) {
      this.eventTarget = eventTarget;
      this.eventName = eventName;
      this.eventOptions = eventOptions;
      this.unorderedBindings = /* @__PURE__ */ new Set();
    }
    connect() {
      this.eventTarget.addEventListener(this.eventName, this, this.eventOptions);
    }
    disconnect() {
      this.eventTarget.removeEventListener(this.eventName, this, this.eventOptions);
    }
    bindingConnected(binding) {
      this.unorderedBindings.add(binding);
    }
    bindingDisconnected(binding) {
      this.unorderedBindings.delete(binding);
    }
    handleEvent(event) {
      const extendedEvent = extendEvent(event);
      for (const binding of this.bindings) {
        if (extendedEvent.immediatePropagationStopped) {
          break;
        } else {
          binding.handleEvent(extendedEvent);
        }
      }
    }
    hasBindings() {
      return this.unorderedBindings.size > 0;
    }
    get bindings() {
      return Array.from(this.unorderedBindings).sort((left2, right2) => {
        const leftIndex = left2.index, rightIndex = right2.index;
        return leftIndex < rightIndex ? -1 : leftIndex > rightIndex ? 1 : 0;
      });
    }
  };
  function extendEvent(event) {
    if ("immediatePropagationStopped" in event) {
      return event;
    } else {
      const { stopImmediatePropagation } = event;
      return Object.assign(event, {
        immediatePropagationStopped: false,
        stopImmediatePropagation() {
          this.immediatePropagationStopped = true;
          stopImmediatePropagation.call(this);
        }
      });
    }
  }
  var Dispatcher = class {
    constructor(application2) {
      this.application = application2;
      this.eventListenerMaps = /* @__PURE__ */ new Map();
      this.started = false;
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.eventListeners.forEach((eventListener) => eventListener.connect());
      }
    }
    stop() {
      if (this.started) {
        this.started = false;
        this.eventListeners.forEach((eventListener) => eventListener.disconnect());
      }
    }
    get eventListeners() {
      return Array.from(this.eventListenerMaps.values()).reduce((listeners, map) => listeners.concat(Array.from(map.values())), []);
    }
    bindingConnected(binding) {
      this.fetchEventListenerForBinding(binding).bindingConnected(binding);
    }
    bindingDisconnected(binding, clearEventListeners = false) {
      this.fetchEventListenerForBinding(binding).bindingDisconnected(binding);
      if (clearEventListeners)
        this.clearEventListenersForBinding(binding);
    }
    handleError(error3, message, detail = {}) {
      this.application.handleError(error3, `Error ${message}`, detail);
    }
    clearEventListenersForBinding(binding) {
      const eventListener = this.fetchEventListenerForBinding(binding);
      if (!eventListener.hasBindings()) {
        eventListener.disconnect();
        this.removeMappedEventListenerFor(binding);
      }
    }
    removeMappedEventListenerFor(binding) {
      const { eventTarget, eventName, eventOptions } = binding;
      const eventListenerMap = this.fetchEventListenerMapForEventTarget(eventTarget);
      const cacheKey = this.cacheKey(eventName, eventOptions);
      eventListenerMap.delete(cacheKey);
      if (eventListenerMap.size == 0)
        this.eventListenerMaps.delete(eventTarget);
    }
    fetchEventListenerForBinding(binding) {
      const { eventTarget, eventName, eventOptions } = binding;
      return this.fetchEventListener(eventTarget, eventName, eventOptions);
    }
    fetchEventListener(eventTarget, eventName, eventOptions) {
      const eventListenerMap = this.fetchEventListenerMapForEventTarget(eventTarget);
      const cacheKey = this.cacheKey(eventName, eventOptions);
      let eventListener = eventListenerMap.get(cacheKey);
      if (!eventListener) {
        eventListener = this.createEventListener(eventTarget, eventName, eventOptions);
        eventListenerMap.set(cacheKey, eventListener);
      }
      return eventListener;
    }
    createEventListener(eventTarget, eventName, eventOptions) {
      const eventListener = new EventListener(eventTarget, eventName, eventOptions);
      if (this.started) {
        eventListener.connect();
      }
      return eventListener;
    }
    fetchEventListenerMapForEventTarget(eventTarget) {
      let eventListenerMap = this.eventListenerMaps.get(eventTarget);
      if (!eventListenerMap) {
        eventListenerMap = /* @__PURE__ */ new Map();
        this.eventListenerMaps.set(eventTarget, eventListenerMap);
      }
      return eventListenerMap;
    }
    cacheKey(eventName, eventOptions) {
      const parts = [eventName];
      Object.keys(eventOptions).sort().forEach((key) => {
        parts.push(`${eventOptions[key] ? "" : "!"}${key}`);
      });
      return parts.join(":");
    }
  };
  var defaultActionDescriptorFilters = {
    stop({ event, value }) {
      if (value)
        event.stopPropagation();
      return true;
    },
    prevent({ event, value }) {
      if (value)
        event.preventDefault();
      return true;
    },
    self({ event, value, element }) {
      if (value) {
        return element === event.target;
      } else {
        return true;
      }
    }
  };
  var descriptorPattern = /^(?:(?:([^.]+?)\+)?(.+?)(?:\.(.+?))?(?:@(window|document))?->)?(.+?)(?:#([^:]+?))(?::(.+))?$/;
  function parseActionDescriptorString(descriptorString) {
    const source = descriptorString.trim();
    const matches = source.match(descriptorPattern) || [];
    let eventName = matches[2];
    let keyFilter = matches[3];
    if (keyFilter && !["keydown", "keyup", "keypress"].includes(eventName)) {
      eventName += `.${keyFilter}`;
      keyFilter = "";
    }
    return {
      eventTarget: parseEventTarget(matches[4]),
      eventName,
      eventOptions: matches[7] ? parseEventOptions(matches[7]) : {},
      identifier: matches[5],
      methodName: matches[6],
      keyFilter: matches[1] || keyFilter
    };
  }
  function parseEventTarget(eventTargetName) {
    if (eventTargetName == "window") {
      return window;
    } else if (eventTargetName == "document") {
      return document;
    }
  }
  function parseEventOptions(eventOptions) {
    return eventOptions.split(":").reduce((options, token) => Object.assign(options, { [token.replace(/^!/, "")]: !/^!/.test(token) }), {});
  }
  function stringifyEventTarget(eventTarget) {
    if (eventTarget == window) {
      return "window";
    } else if (eventTarget == document) {
      return "document";
    }
  }
  function camelize(value) {
    return value.replace(/(?:[_-])([a-z0-9])/g, (_, char) => char.toUpperCase());
  }
  function namespaceCamelize(value) {
    return camelize(value.replace(/--/g, "-").replace(/__/g, "_"));
  }
  function capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1);
  }
  function dasherize(value) {
    return value.replace(/([A-Z])/g, (_, char) => `-${char.toLowerCase()}`);
  }
  function tokenize(value) {
    return value.match(/[^\s]+/g) || [];
  }
  function isSomething(object) {
    return object !== null && object !== void 0;
  }
  function hasProperty(object, property) {
    return Object.prototype.hasOwnProperty.call(object, property);
  }
  var allModifiers = ["meta", "ctrl", "alt", "shift"];
  var Action = class {
    constructor(element, index, descriptor, schema2) {
      this.element = element;
      this.index = index;
      this.eventTarget = descriptor.eventTarget || element;
      this.eventName = descriptor.eventName || getDefaultEventNameForElement(element) || error("missing event name");
      this.eventOptions = descriptor.eventOptions || {};
      this.identifier = descriptor.identifier || error("missing identifier");
      this.methodName = descriptor.methodName || error("missing method name");
      this.keyFilter = descriptor.keyFilter || "";
      this.schema = schema2;
    }
    static forToken(token, schema2) {
      return new this(token.element, token.index, parseActionDescriptorString(token.content), schema2);
    }
    toString() {
      const eventFilter = this.keyFilter ? `.${this.keyFilter}` : "";
      const eventTarget = this.eventTargetName ? `@${this.eventTargetName}` : "";
      return `${this.eventName}${eventFilter}${eventTarget}->${this.identifier}#${this.methodName}`;
    }
    shouldIgnoreKeyboardEvent(event) {
      if (!this.keyFilter) {
        return false;
      }
      const filters = this.keyFilter.split("+");
      if (this.keyFilterDissatisfied(event, filters)) {
        return true;
      }
      const standardFilter = filters.filter((key) => !allModifiers.includes(key))[0];
      if (!standardFilter) {
        return false;
      }
      if (!hasProperty(this.keyMappings, standardFilter)) {
        error(`contains unknown key filter: ${this.keyFilter}`);
      }
      return this.keyMappings[standardFilter].toLowerCase() !== event.key.toLowerCase();
    }
    shouldIgnoreMouseEvent(event) {
      if (!this.keyFilter) {
        return false;
      }
      const filters = [this.keyFilter];
      if (this.keyFilterDissatisfied(event, filters)) {
        return true;
      }
      return false;
    }
    get params() {
      const params2 = {};
      const pattern = new RegExp(`^data-${this.identifier}-(.+)-param$`, "i");
      for (const { name: name3, value } of Array.from(this.element.attributes)) {
        const match = name3.match(pattern);
        const key = match && match[1];
        if (key) {
          params2[camelize(key)] = typecast(value);
        }
      }
      return params2;
    }
    get eventTargetName() {
      return stringifyEventTarget(this.eventTarget);
    }
    get keyMappings() {
      return this.schema.keyMappings;
    }
    keyFilterDissatisfied(event, filters) {
      const [meta, ctrl, alt, shift] = allModifiers.map((modifier) => filters.includes(modifier));
      return event.metaKey !== meta || event.ctrlKey !== ctrl || event.altKey !== alt || event.shiftKey !== shift;
    }
  };
  var defaultEventNames = {
    a: () => "click",
    button: () => "click",
    form: () => "submit",
    details: () => "toggle",
    input: (e) => e.getAttribute("type") == "submit" ? "click" : "input",
    select: () => "change",
    textarea: () => "input"
  };
  function getDefaultEventNameForElement(element) {
    const tagName = element.tagName.toLowerCase();
    if (tagName in defaultEventNames) {
      return defaultEventNames[tagName](element);
    }
  }
  function error(message) {
    throw new Error(message);
  }
  function typecast(value) {
    try {
      return JSON.parse(value);
    } catch (o_O) {
      return value;
    }
  }
  var Binding = class {
    constructor(context, action) {
      this.context = context;
      this.action = action;
    }
    get index() {
      return this.action.index;
    }
    get eventTarget() {
      return this.action.eventTarget;
    }
    get eventOptions() {
      return this.action.eventOptions;
    }
    get identifier() {
      return this.context.identifier;
    }
    handleEvent(event) {
      const actionEvent = this.prepareActionEvent(event);
      if (this.willBeInvokedByEvent(event) && this.applyEventModifiers(actionEvent)) {
        this.invokeWithEvent(actionEvent);
      }
    }
    get eventName() {
      return this.action.eventName;
    }
    get method() {
      const method = this.controller[this.methodName];
      if (typeof method == "function") {
        return method;
      }
      throw new Error(`Action "${this.action}" references undefined method "${this.methodName}"`);
    }
    applyEventModifiers(event) {
      const { element } = this.action;
      const { actionDescriptorFilters } = this.context.application;
      const { controller } = this.context;
      let passes = true;
      for (const [name3, value] of Object.entries(this.eventOptions)) {
        if (name3 in actionDescriptorFilters) {
          const filter = actionDescriptorFilters[name3];
          passes = passes && filter({ name: name3, value, event, element, controller });
        } else {
          continue;
        }
      }
      return passes;
    }
    prepareActionEvent(event) {
      return Object.assign(event, { params: this.action.params });
    }
    invokeWithEvent(event) {
      const { target, currentTarget } = event;
      try {
        this.method.call(this.controller, event);
        this.context.logDebugActivity(this.methodName, { event, target, currentTarget, action: this.methodName });
      } catch (error3) {
        const { identifier, controller, element, index } = this;
        const detail = { identifier, controller, element, index, event };
        this.context.handleError(error3, `invoking action "${this.action}"`, detail);
      }
    }
    willBeInvokedByEvent(event) {
      const eventTarget = event.target;
      if (event instanceof KeyboardEvent && this.action.shouldIgnoreKeyboardEvent(event)) {
        return false;
      }
      if (event instanceof MouseEvent && this.action.shouldIgnoreMouseEvent(event)) {
        return false;
      }
      if (this.element === eventTarget) {
        return true;
      } else if (eventTarget instanceof Element && this.element.contains(eventTarget)) {
        return this.scope.containsElement(eventTarget);
      } else {
        return this.scope.containsElement(this.action.element);
      }
    }
    get controller() {
      return this.context.controller;
    }
    get methodName() {
      return this.action.methodName;
    }
    get element() {
      return this.scope.element;
    }
    get scope() {
      return this.context.scope;
    }
  };
  var ElementObserver = class {
    constructor(element, delegate) {
      this.mutationObserverInit = { attributes: true, childList: true, subtree: true };
      this.element = element;
      this.started = false;
      this.delegate = delegate;
      this.elements = /* @__PURE__ */ new Set();
      this.mutationObserver = new MutationObserver((mutations) => this.processMutations(mutations));
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.mutationObserver.observe(this.element, this.mutationObserverInit);
        this.refresh();
      }
    }
    pause(callback) {
      if (this.started) {
        this.mutationObserver.disconnect();
        this.started = false;
      }
      callback();
      if (!this.started) {
        this.mutationObserver.observe(this.element, this.mutationObserverInit);
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        this.mutationObserver.takeRecords();
        this.mutationObserver.disconnect();
        this.started = false;
      }
    }
    refresh() {
      if (this.started) {
        const matches = new Set(this.matchElementsInTree());
        for (const element of Array.from(this.elements)) {
          if (!matches.has(element)) {
            this.removeElement(element);
          }
        }
        for (const element of Array.from(matches)) {
          this.addElement(element);
        }
      }
    }
    processMutations(mutations) {
      if (this.started) {
        for (const mutation of mutations) {
          this.processMutation(mutation);
        }
      }
    }
    processMutation(mutation) {
      if (mutation.type == "attributes") {
        this.processAttributeChange(mutation.target, mutation.attributeName);
      } else if (mutation.type == "childList") {
        this.processRemovedNodes(mutation.removedNodes);
        this.processAddedNodes(mutation.addedNodes);
      }
    }
    processAttributeChange(element, attributeName) {
      if (this.elements.has(element)) {
        if (this.delegate.elementAttributeChanged && this.matchElement(element)) {
          this.delegate.elementAttributeChanged(element, attributeName);
        } else {
          this.removeElement(element);
        }
      } else if (this.matchElement(element)) {
        this.addElement(element);
      }
    }
    processRemovedNodes(nodes) {
      for (const node of Array.from(nodes)) {
        const element = this.elementFromNode(node);
        if (element) {
          this.processTree(element, this.removeElement);
        }
      }
    }
    processAddedNodes(nodes) {
      for (const node of Array.from(nodes)) {
        const element = this.elementFromNode(node);
        if (element && this.elementIsActive(element)) {
          this.processTree(element, this.addElement);
        }
      }
    }
    matchElement(element) {
      return this.delegate.matchElement(element);
    }
    matchElementsInTree(tree = this.element) {
      return this.delegate.matchElementsInTree(tree);
    }
    processTree(tree, processor) {
      for (const element of this.matchElementsInTree(tree)) {
        processor.call(this, element);
      }
    }
    elementFromNode(node) {
      if (node.nodeType == Node.ELEMENT_NODE) {
        return node;
      }
    }
    elementIsActive(element) {
      if (element.isConnected != this.element.isConnected) {
        return false;
      } else {
        return this.element.contains(element);
      }
    }
    addElement(element) {
      if (!this.elements.has(element)) {
        if (this.elementIsActive(element)) {
          this.elements.add(element);
          if (this.delegate.elementMatched) {
            this.delegate.elementMatched(element);
          }
        }
      }
    }
    removeElement(element) {
      if (this.elements.has(element)) {
        this.elements.delete(element);
        if (this.delegate.elementUnmatched) {
          this.delegate.elementUnmatched(element);
        }
      }
    }
  };
  var AttributeObserver = class {
    constructor(element, attributeName, delegate) {
      this.attributeName = attributeName;
      this.delegate = delegate;
      this.elementObserver = new ElementObserver(element, this);
    }
    get element() {
      return this.elementObserver.element;
    }
    get selector() {
      return `[${this.attributeName}]`;
    }
    start() {
      this.elementObserver.start();
    }
    pause(callback) {
      this.elementObserver.pause(callback);
    }
    stop() {
      this.elementObserver.stop();
    }
    refresh() {
      this.elementObserver.refresh();
    }
    get started() {
      return this.elementObserver.started;
    }
    matchElement(element) {
      return element.hasAttribute(this.attributeName);
    }
    matchElementsInTree(tree) {
      const match = this.matchElement(tree) ? [tree] : [];
      const matches = Array.from(tree.querySelectorAll(this.selector));
      return match.concat(matches);
    }
    elementMatched(element) {
      if (this.delegate.elementMatchedAttribute) {
        this.delegate.elementMatchedAttribute(element, this.attributeName);
      }
    }
    elementUnmatched(element) {
      if (this.delegate.elementUnmatchedAttribute) {
        this.delegate.elementUnmatchedAttribute(element, this.attributeName);
      }
    }
    elementAttributeChanged(element, attributeName) {
      if (this.delegate.elementAttributeValueChanged && this.attributeName == attributeName) {
        this.delegate.elementAttributeValueChanged(element, attributeName);
      }
    }
  };
  function add2(map, key, value) {
    fetch2(map, key).add(value);
  }
  function del(map, key, value) {
    fetch2(map, key).delete(value);
    prune(map, key);
  }
  function fetch2(map, key) {
    let values = map.get(key);
    if (!values) {
      values = /* @__PURE__ */ new Set();
      map.set(key, values);
    }
    return values;
  }
  function prune(map, key) {
    const values = map.get(key);
    if (values != null && values.size == 0) {
      map.delete(key);
    }
  }
  var Multimap = class {
    constructor() {
      this.valuesByKey = /* @__PURE__ */ new Map();
    }
    get keys() {
      return Array.from(this.valuesByKey.keys());
    }
    get values() {
      const sets = Array.from(this.valuesByKey.values());
      return sets.reduce((values, set) => values.concat(Array.from(set)), []);
    }
    get size() {
      const sets = Array.from(this.valuesByKey.values());
      return sets.reduce((size, set) => size + set.size, 0);
    }
    add(key, value) {
      add2(this.valuesByKey, key, value);
    }
    delete(key, value) {
      del(this.valuesByKey, key, value);
    }
    has(key, value) {
      const values = this.valuesByKey.get(key);
      return values != null && values.has(value);
    }
    hasKey(key) {
      return this.valuesByKey.has(key);
    }
    hasValue(value) {
      const sets = Array.from(this.valuesByKey.values());
      return sets.some((set) => set.has(value));
    }
    getValuesForKey(key) {
      const values = this.valuesByKey.get(key);
      return values ? Array.from(values) : [];
    }
    getKeysForValue(value) {
      return Array.from(this.valuesByKey).filter(([_key, values]) => values.has(value)).map(([key, _values]) => key);
    }
  };
  var SelectorObserver = class {
    constructor(element, selector, delegate, details) {
      this._selector = selector;
      this.details = details;
      this.elementObserver = new ElementObserver(element, this);
      this.delegate = delegate;
      this.matchesByElement = new Multimap();
    }
    get started() {
      return this.elementObserver.started;
    }
    get selector() {
      return this._selector;
    }
    set selector(selector) {
      this._selector = selector;
      this.refresh();
    }
    start() {
      this.elementObserver.start();
    }
    pause(callback) {
      this.elementObserver.pause(callback);
    }
    stop() {
      this.elementObserver.stop();
    }
    refresh() {
      this.elementObserver.refresh();
    }
    get element() {
      return this.elementObserver.element;
    }
    matchElement(element) {
      const { selector } = this;
      if (selector) {
        const matches = element.matches(selector);
        if (this.delegate.selectorMatchElement) {
          return matches && this.delegate.selectorMatchElement(element, this.details);
        }
        return matches;
      } else {
        return false;
      }
    }
    matchElementsInTree(tree) {
      const { selector } = this;
      if (selector) {
        const match = this.matchElement(tree) ? [tree] : [];
        const matches = Array.from(tree.querySelectorAll(selector)).filter((match2) => this.matchElement(match2));
        return match.concat(matches);
      } else {
        return [];
      }
    }
    elementMatched(element) {
      const { selector } = this;
      if (selector) {
        this.selectorMatched(element, selector);
      }
    }
    elementUnmatched(element) {
      const selectors = this.matchesByElement.getKeysForValue(element);
      for (const selector of selectors) {
        this.selectorUnmatched(element, selector);
      }
    }
    elementAttributeChanged(element, _attributeName) {
      const { selector } = this;
      if (selector) {
        const matches = this.matchElement(element);
        const matchedBefore = this.matchesByElement.has(selector, element);
        if (matches && !matchedBefore) {
          this.selectorMatched(element, selector);
        } else if (!matches && matchedBefore) {
          this.selectorUnmatched(element, selector);
        }
      }
    }
    selectorMatched(element, selector) {
      this.delegate.selectorMatched(element, selector, this.details);
      this.matchesByElement.add(selector, element);
    }
    selectorUnmatched(element, selector) {
      this.delegate.selectorUnmatched(element, selector, this.details);
      this.matchesByElement.delete(selector, element);
    }
  };
  var StringMapObserver = class {
    constructor(element, delegate) {
      this.element = element;
      this.delegate = delegate;
      this.started = false;
      this.stringMap = /* @__PURE__ */ new Map();
      this.mutationObserver = new MutationObserver((mutations) => this.processMutations(mutations));
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.mutationObserver.observe(this.element, { attributes: true, attributeOldValue: true });
        this.refresh();
      }
    }
    stop() {
      if (this.started) {
        this.mutationObserver.takeRecords();
        this.mutationObserver.disconnect();
        this.started = false;
      }
    }
    refresh() {
      if (this.started) {
        for (const attributeName of this.knownAttributeNames) {
          this.refreshAttribute(attributeName, null);
        }
      }
    }
    processMutations(mutations) {
      if (this.started) {
        for (const mutation of mutations) {
          this.processMutation(mutation);
        }
      }
    }
    processMutation(mutation) {
      const attributeName = mutation.attributeName;
      if (attributeName) {
        this.refreshAttribute(attributeName, mutation.oldValue);
      }
    }
    refreshAttribute(attributeName, oldValue) {
      const key = this.delegate.getStringMapKeyForAttribute(attributeName);
      if (key != null) {
        if (!this.stringMap.has(attributeName)) {
          this.stringMapKeyAdded(key, attributeName);
        }
        const value = this.element.getAttribute(attributeName);
        if (this.stringMap.get(attributeName) != value) {
          this.stringMapValueChanged(value, key, oldValue);
        }
        if (value == null) {
          const oldValue2 = this.stringMap.get(attributeName);
          this.stringMap.delete(attributeName);
          if (oldValue2)
            this.stringMapKeyRemoved(key, attributeName, oldValue2);
        } else {
          this.stringMap.set(attributeName, value);
        }
      }
    }
    stringMapKeyAdded(key, attributeName) {
      if (this.delegate.stringMapKeyAdded) {
        this.delegate.stringMapKeyAdded(key, attributeName);
      }
    }
    stringMapValueChanged(value, key, oldValue) {
      if (this.delegate.stringMapValueChanged) {
        this.delegate.stringMapValueChanged(value, key, oldValue);
      }
    }
    stringMapKeyRemoved(key, attributeName, oldValue) {
      if (this.delegate.stringMapKeyRemoved) {
        this.delegate.stringMapKeyRemoved(key, attributeName, oldValue);
      }
    }
    get knownAttributeNames() {
      return Array.from(new Set(this.currentAttributeNames.concat(this.recordedAttributeNames)));
    }
    get currentAttributeNames() {
      return Array.from(this.element.attributes).map((attribute) => attribute.name);
    }
    get recordedAttributeNames() {
      return Array.from(this.stringMap.keys());
    }
  };
  var TokenListObserver = class {
    constructor(element, attributeName, delegate) {
      this.attributeObserver = new AttributeObserver(element, attributeName, this);
      this.delegate = delegate;
      this.tokensByElement = new Multimap();
    }
    get started() {
      return this.attributeObserver.started;
    }
    start() {
      this.attributeObserver.start();
    }
    pause(callback) {
      this.attributeObserver.pause(callback);
    }
    stop() {
      this.attributeObserver.stop();
    }
    refresh() {
      this.attributeObserver.refresh();
    }
    get element() {
      return this.attributeObserver.element;
    }
    get attributeName() {
      return this.attributeObserver.attributeName;
    }
    elementMatchedAttribute(element) {
      this.tokensMatched(this.readTokensForElement(element));
    }
    elementAttributeValueChanged(element) {
      const [unmatchedTokens, matchedTokens] = this.refreshTokensForElement(element);
      this.tokensUnmatched(unmatchedTokens);
      this.tokensMatched(matchedTokens);
    }
    elementUnmatchedAttribute(element) {
      this.tokensUnmatched(this.tokensByElement.getValuesForKey(element));
    }
    tokensMatched(tokens) {
      tokens.forEach((token) => this.tokenMatched(token));
    }
    tokensUnmatched(tokens) {
      tokens.forEach((token) => this.tokenUnmatched(token));
    }
    tokenMatched(token) {
      this.delegate.tokenMatched(token);
      this.tokensByElement.add(token.element, token);
    }
    tokenUnmatched(token) {
      this.delegate.tokenUnmatched(token);
      this.tokensByElement.delete(token.element, token);
    }
    refreshTokensForElement(element) {
      const previousTokens = this.tokensByElement.getValuesForKey(element);
      const currentTokens = this.readTokensForElement(element);
      const firstDifferingIndex = zip(previousTokens, currentTokens).findIndex(([previousToken, currentToken]) => !tokensAreEqual(previousToken, currentToken));
      if (firstDifferingIndex == -1) {
        return [[], []];
      } else {
        return [previousTokens.slice(firstDifferingIndex), currentTokens.slice(firstDifferingIndex)];
      }
    }
    readTokensForElement(element) {
      const attributeName = this.attributeName;
      const tokenString = element.getAttribute(attributeName) || "";
      return parseTokenString(tokenString, element, attributeName);
    }
  };
  function parseTokenString(tokenString, element, attributeName) {
    return tokenString.trim().split(/\s+/).filter((content) => content.length).map((content, index) => ({ element, attributeName, content, index }));
  }
  function zip(left2, right2) {
    const length = Math.max(left2.length, right2.length);
    return Array.from({ length }, (_, index) => [left2[index], right2[index]]);
  }
  function tokensAreEqual(left2, right2) {
    return left2 && right2 && left2.index == right2.index && left2.content == right2.content;
  }
  var ValueListObserver = class {
    constructor(element, attributeName, delegate) {
      this.tokenListObserver = new TokenListObserver(element, attributeName, this);
      this.delegate = delegate;
      this.parseResultsByToken = /* @__PURE__ */ new WeakMap();
      this.valuesByTokenByElement = /* @__PURE__ */ new WeakMap();
    }
    get started() {
      return this.tokenListObserver.started;
    }
    start() {
      this.tokenListObserver.start();
    }
    stop() {
      this.tokenListObserver.stop();
    }
    refresh() {
      this.tokenListObserver.refresh();
    }
    get element() {
      return this.tokenListObserver.element;
    }
    get attributeName() {
      return this.tokenListObserver.attributeName;
    }
    tokenMatched(token) {
      const { element } = token;
      const { value } = this.fetchParseResultForToken(token);
      if (value) {
        this.fetchValuesByTokenForElement(element).set(token, value);
        this.delegate.elementMatchedValue(element, value);
      }
    }
    tokenUnmatched(token) {
      const { element } = token;
      const { value } = this.fetchParseResultForToken(token);
      if (value) {
        this.fetchValuesByTokenForElement(element).delete(token);
        this.delegate.elementUnmatchedValue(element, value);
      }
    }
    fetchParseResultForToken(token) {
      let parseResult = this.parseResultsByToken.get(token);
      if (!parseResult) {
        parseResult = this.parseToken(token);
        this.parseResultsByToken.set(token, parseResult);
      }
      return parseResult;
    }
    fetchValuesByTokenForElement(element) {
      let valuesByToken = this.valuesByTokenByElement.get(element);
      if (!valuesByToken) {
        valuesByToken = /* @__PURE__ */ new Map();
        this.valuesByTokenByElement.set(element, valuesByToken);
      }
      return valuesByToken;
    }
    parseToken(token) {
      try {
        const value = this.delegate.parseValueForToken(token);
        return { value };
      } catch (error3) {
        return { error: error3 };
      }
    }
  };
  var BindingObserver = class {
    constructor(context, delegate) {
      this.context = context;
      this.delegate = delegate;
      this.bindingsByAction = /* @__PURE__ */ new Map();
    }
    start() {
      if (!this.valueListObserver) {
        this.valueListObserver = new ValueListObserver(this.element, this.actionAttribute, this);
        this.valueListObserver.start();
      }
    }
    stop() {
      if (this.valueListObserver) {
        this.valueListObserver.stop();
        delete this.valueListObserver;
        this.disconnectAllActions();
      }
    }
    get element() {
      return this.context.element;
    }
    get identifier() {
      return this.context.identifier;
    }
    get actionAttribute() {
      return this.schema.actionAttribute;
    }
    get schema() {
      return this.context.schema;
    }
    get bindings() {
      return Array.from(this.bindingsByAction.values());
    }
    connectAction(action) {
      const binding = new Binding(this.context, action);
      this.bindingsByAction.set(action, binding);
      this.delegate.bindingConnected(binding);
    }
    disconnectAction(action) {
      const binding = this.bindingsByAction.get(action);
      if (binding) {
        this.bindingsByAction.delete(action);
        this.delegate.bindingDisconnected(binding);
      }
    }
    disconnectAllActions() {
      this.bindings.forEach((binding) => this.delegate.bindingDisconnected(binding, true));
      this.bindingsByAction.clear();
    }
    parseValueForToken(token) {
      const action = Action.forToken(token, this.schema);
      if (action.identifier == this.identifier) {
        return action;
      }
    }
    elementMatchedValue(element, action) {
      this.connectAction(action);
    }
    elementUnmatchedValue(element, action) {
      this.disconnectAction(action);
    }
  };
  var ValueObserver = class {
    constructor(context, receiver) {
      this.context = context;
      this.receiver = receiver;
      this.stringMapObserver = new StringMapObserver(this.element, this);
      this.valueDescriptorMap = this.controller.valueDescriptorMap;
    }
    start() {
      this.stringMapObserver.start();
      this.invokeChangedCallbacksForDefaultValues();
    }
    stop() {
      this.stringMapObserver.stop();
    }
    get element() {
      return this.context.element;
    }
    get controller() {
      return this.context.controller;
    }
    getStringMapKeyForAttribute(attributeName) {
      if (attributeName in this.valueDescriptorMap) {
        return this.valueDescriptorMap[attributeName].name;
      }
    }
    stringMapKeyAdded(key, attributeName) {
      const descriptor = this.valueDescriptorMap[attributeName];
      if (!this.hasValue(key)) {
        this.invokeChangedCallback(key, descriptor.writer(this.receiver[key]), descriptor.writer(descriptor.defaultValue));
      }
    }
    stringMapValueChanged(value, name3, oldValue) {
      const descriptor = this.valueDescriptorNameMap[name3];
      if (value === null)
        return;
      if (oldValue === null) {
        oldValue = descriptor.writer(descriptor.defaultValue);
      }
      this.invokeChangedCallback(name3, value, oldValue);
    }
    stringMapKeyRemoved(key, attributeName, oldValue) {
      const descriptor = this.valueDescriptorNameMap[key];
      if (this.hasValue(key)) {
        this.invokeChangedCallback(key, descriptor.writer(this.receiver[key]), oldValue);
      } else {
        this.invokeChangedCallback(key, descriptor.writer(descriptor.defaultValue), oldValue);
      }
    }
    invokeChangedCallbacksForDefaultValues() {
      for (const { key, name: name3, defaultValue, writer } of this.valueDescriptors) {
        if (defaultValue != void 0 && !this.controller.data.has(key)) {
          this.invokeChangedCallback(name3, writer(defaultValue), void 0);
        }
      }
    }
    invokeChangedCallback(name3, rawValue, rawOldValue) {
      const changedMethodName = `${name3}Changed`;
      const changedMethod = this.receiver[changedMethodName];
      if (typeof changedMethod == "function") {
        const descriptor = this.valueDescriptorNameMap[name3];
        try {
          const value = descriptor.reader(rawValue);
          let oldValue = rawOldValue;
          if (rawOldValue) {
            oldValue = descriptor.reader(rawOldValue);
          }
          changedMethod.call(this.receiver, value, oldValue);
        } catch (error3) {
          if (error3 instanceof TypeError) {
            error3.message = `Stimulus Value "${this.context.identifier}.${descriptor.name}" - ${error3.message}`;
          }
          throw error3;
        }
      }
    }
    get valueDescriptors() {
      const { valueDescriptorMap } = this;
      return Object.keys(valueDescriptorMap).map((key) => valueDescriptorMap[key]);
    }
    get valueDescriptorNameMap() {
      const descriptors = {};
      Object.keys(this.valueDescriptorMap).forEach((key) => {
        const descriptor = this.valueDescriptorMap[key];
        descriptors[descriptor.name] = descriptor;
      });
      return descriptors;
    }
    hasValue(attributeName) {
      const descriptor = this.valueDescriptorNameMap[attributeName];
      const hasMethodName = `has${capitalize(descriptor.name)}`;
      return this.receiver[hasMethodName];
    }
  };
  var TargetObserver = class {
    constructor(context, delegate) {
      this.context = context;
      this.delegate = delegate;
      this.targetsByName = new Multimap();
    }
    start() {
      if (!this.tokenListObserver) {
        this.tokenListObserver = new TokenListObserver(this.element, this.attributeName, this);
        this.tokenListObserver.start();
      }
    }
    stop() {
      if (this.tokenListObserver) {
        this.disconnectAllTargets();
        this.tokenListObserver.stop();
        delete this.tokenListObserver;
      }
    }
    tokenMatched({ element, content: name3 }) {
      if (this.scope.containsElement(element)) {
        this.connectTarget(element, name3);
      }
    }
    tokenUnmatched({ element, content: name3 }) {
      this.disconnectTarget(element, name3);
    }
    connectTarget(element, name3) {
      var _a;
      if (!this.targetsByName.has(name3, element)) {
        this.targetsByName.add(name3, element);
        (_a = this.tokenListObserver) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.targetConnected(element, name3));
      }
    }
    disconnectTarget(element, name3) {
      var _a;
      if (this.targetsByName.has(name3, element)) {
        this.targetsByName.delete(name3, element);
        (_a = this.tokenListObserver) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.targetDisconnected(element, name3));
      }
    }
    disconnectAllTargets() {
      for (const name3 of this.targetsByName.keys) {
        for (const element of this.targetsByName.getValuesForKey(name3)) {
          this.disconnectTarget(element, name3);
        }
      }
    }
    get attributeName() {
      return `data-${this.context.identifier}-target`;
    }
    get element() {
      return this.context.element;
    }
    get scope() {
      return this.context.scope;
    }
  };
  function readInheritableStaticArrayValues(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor(constructor);
    return Array.from(ancestors.reduce((values, constructor2) => {
      getOwnStaticArrayValues(constructor2, propertyName).forEach((name3) => values.add(name3));
      return values;
    }, /* @__PURE__ */ new Set()));
  }
  function readInheritableStaticObjectPairs(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor(constructor);
    return ancestors.reduce((pairs, constructor2) => {
      pairs.push(...getOwnStaticObjectPairs(constructor2, propertyName));
      return pairs;
    }, []);
  }
  function getAncestorsForConstructor(constructor) {
    const ancestors = [];
    while (constructor) {
      ancestors.push(constructor);
      constructor = Object.getPrototypeOf(constructor);
    }
    return ancestors.reverse();
  }
  function getOwnStaticArrayValues(constructor, propertyName) {
    const definition = constructor[propertyName];
    return Array.isArray(definition) ? definition : [];
  }
  function getOwnStaticObjectPairs(constructor, propertyName) {
    const definition = constructor[propertyName];
    return definition ? Object.keys(definition).map((key) => [key, definition[key]]) : [];
  }
  var OutletObserver = class {
    constructor(context, delegate) {
      this.started = false;
      this.context = context;
      this.delegate = delegate;
      this.outletsByName = new Multimap();
      this.outletElementsByName = new Multimap();
      this.selectorObserverMap = /* @__PURE__ */ new Map();
      this.attributeObserverMap = /* @__PURE__ */ new Map();
    }
    start() {
      if (!this.started) {
        this.outletDefinitions.forEach((outletName) => {
          this.setupSelectorObserverForOutlet(outletName);
          this.setupAttributeObserverForOutlet(outletName);
        });
        this.started = true;
        this.dependentContexts.forEach((context) => context.refresh());
      }
    }
    refresh() {
      this.selectorObserverMap.forEach((observer) => observer.refresh());
      this.attributeObserverMap.forEach((observer) => observer.refresh());
    }
    stop() {
      if (this.started) {
        this.started = false;
        this.disconnectAllOutlets();
        this.stopSelectorObservers();
        this.stopAttributeObservers();
      }
    }
    stopSelectorObservers() {
      if (this.selectorObserverMap.size > 0) {
        this.selectorObserverMap.forEach((observer) => observer.stop());
        this.selectorObserverMap.clear();
      }
    }
    stopAttributeObservers() {
      if (this.attributeObserverMap.size > 0) {
        this.attributeObserverMap.forEach((observer) => observer.stop());
        this.attributeObserverMap.clear();
      }
    }
    selectorMatched(element, _selector, { outletName }) {
      const outlet = this.getOutlet(element, outletName);
      if (outlet) {
        this.connectOutlet(outlet, element, outletName);
      }
    }
    selectorUnmatched(element, _selector, { outletName }) {
      const outlet = this.getOutletFromMap(element, outletName);
      if (outlet) {
        this.disconnectOutlet(outlet, element, outletName);
      }
    }
    selectorMatchElement(element, { outletName }) {
      const selector = this.selector(outletName);
      const hasOutlet = this.hasOutlet(element, outletName);
      const hasOutletController = element.matches(`[${this.schema.controllerAttribute}~=${outletName}]`);
      if (selector) {
        return hasOutlet && hasOutletController && element.matches(selector);
      } else {
        return false;
      }
    }
    elementMatchedAttribute(_element, attributeName) {
      const outletName = this.getOutletNameFromOutletAttributeName(attributeName);
      if (outletName) {
        this.updateSelectorObserverForOutlet(outletName);
      }
    }
    elementAttributeValueChanged(_element, attributeName) {
      const outletName = this.getOutletNameFromOutletAttributeName(attributeName);
      if (outletName) {
        this.updateSelectorObserverForOutlet(outletName);
      }
    }
    elementUnmatchedAttribute(_element, attributeName) {
      const outletName = this.getOutletNameFromOutletAttributeName(attributeName);
      if (outletName) {
        this.updateSelectorObserverForOutlet(outletName);
      }
    }
    connectOutlet(outlet, element, outletName) {
      var _a;
      if (!this.outletElementsByName.has(outletName, element)) {
        this.outletsByName.add(outletName, outlet);
        this.outletElementsByName.add(outletName, element);
        (_a = this.selectorObserverMap.get(outletName)) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.outletConnected(outlet, element, outletName));
      }
    }
    disconnectOutlet(outlet, element, outletName) {
      var _a;
      if (this.outletElementsByName.has(outletName, element)) {
        this.outletsByName.delete(outletName, outlet);
        this.outletElementsByName.delete(outletName, element);
        (_a = this.selectorObserverMap.get(outletName)) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.outletDisconnected(outlet, element, outletName));
      }
    }
    disconnectAllOutlets() {
      for (const outletName of this.outletElementsByName.keys) {
        for (const element of this.outletElementsByName.getValuesForKey(outletName)) {
          for (const outlet of this.outletsByName.getValuesForKey(outletName)) {
            this.disconnectOutlet(outlet, element, outletName);
          }
        }
      }
    }
    updateSelectorObserverForOutlet(outletName) {
      const observer = this.selectorObserverMap.get(outletName);
      if (observer) {
        observer.selector = this.selector(outletName);
      }
    }
    setupSelectorObserverForOutlet(outletName) {
      const selector = this.selector(outletName);
      const selectorObserver = new SelectorObserver(document.body, selector, this, { outletName });
      this.selectorObserverMap.set(outletName, selectorObserver);
      selectorObserver.start();
    }
    setupAttributeObserverForOutlet(outletName) {
      const attributeName = this.attributeNameForOutletName(outletName);
      const attributeObserver = new AttributeObserver(this.scope.element, attributeName, this);
      this.attributeObserverMap.set(outletName, attributeObserver);
      attributeObserver.start();
    }
    selector(outletName) {
      return this.scope.outlets.getSelectorForOutletName(outletName);
    }
    attributeNameForOutletName(outletName) {
      return this.scope.schema.outletAttributeForScope(this.identifier, outletName);
    }
    getOutletNameFromOutletAttributeName(attributeName) {
      return this.outletDefinitions.find((outletName) => this.attributeNameForOutletName(outletName) === attributeName);
    }
    get outletDependencies() {
      const dependencies3 = new Multimap();
      this.router.modules.forEach((module3) => {
        const constructor = module3.definition.controllerConstructor;
        const outlets = readInheritableStaticArrayValues(constructor, "outlets");
        outlets.forEach((outlet) => dependencies3.add(outlet, module3.identifier));
      });
      return dependencies3;
    }
    get outletDefinitions() {
      return this.outletDependencies.getKeysForValue(this.identifier);
    }
    get dependentControllerIdentifiers() {
      return this.outletDependencies.getValuesForKey(this.identifier);
    }
    get dependentContexts() {
      const identifiers = this.dependentControllerIdentifiers;
      return this.router.contexts.filter((context) => identifiers.includes(context.identifier));
    }
    hasOutlet(element, outletName) {
      return !!this.getOutlet(element, outletName) || !!this.getOutletFromMap(element, outletName);
    }
    getOutlet(element, outletName) {
      return this.application.getControllerForElementAndIdentifier(element, outletName);
    }
    getOutletFromMap(element, outletName) {
      return this.outletsByName.getValuesForKey(outletName).find((outlet) => outlet.element === element);
    }
    get scope() {
      return this.context.scope;
    }
    get schema() {
      return this.context.schema;
    }
    get identifier() {
      return this.context.identifier;
    }
    get application() {
      return this.context.application;
    }
    get router() {
      return this.application.router;
    }
  };
  var Context = class {
    constructor(module3, scope) {
      this.logDebugActivity = (functionName, detail = {}) => {
        const { identifier, controller, element } = this;
        detail = Object.assign({ identifier, controller, element }, detail);
        this.application.logDebugActivity(this.identifier, functionName, detail);
      };
      this.module = module3;
      this.scope = scope;
      this.controller = new module3.controllerConstructor(this);
      this.bindingObserver = new BindingObserver(this, this.dispatcher);
      this.valueObserver = new ValueObserver(this, this.controller);
      this.targetObserver = new TargetObserver(this, this);
      this.outletObserver = new OutletObserver(this, this);
      try {
        this.controller.initialize();
        this.logDebugActivity("initialize");
      } catch (error3) {
        this.handleError(error3, "initializing controller");
      }
    }
    connect() {
      this.bindingObserver.start();
      this.valueObserver.start();
      this.targetObserver.start();
      this.outletObserver.start();
      try {
        this.controller.connect();
        this.logDebugActivity("connect");
      } catch (error3) {
        this.handleError(error3, "connecting controller");
      }
    }
    refresh() {
      this.outletObserver.refresh();
    }
    disconnect() {
      try {
        this.controller.disconnect();
        this.logDebugActivity("disconnect");
      } catch (error3) {
        this.handleError(error3, "disconnecting controller");
      }
      this.outletObserver.stop();
      this.targetObserver.stop();
      this.valueObserver.stop();
      this.bindingObserver.stop();
    }
    get application() {
      return this.module.application;
    }
    get identifier() {
      return this.module.identifier;
    }
    get schema() {
      return this.application.schema;
    }
    get dispatcher() {
      return this.application.dispatcher;
    }
    get element() {
      return this.scope.element;
    }
    get parentElement() {
      return this.element.parentElement;
    }
    handleError(error3, message, detail = {}) {
      const { identifier, controller, element } = this;
      detail = Object.assign({ identifier, controller, element }, detail);
      this.application.handleError(error3, `Error ${message}`, detail);
    }
    targetConnected(element, name3) {
      this.invokeControllerMethod(`${name3}TargetConnected`, element);
    }
    targetDisconnected(element, name3) {
      this.invokeControllerMethod(`${name3}TargetDisconnected`, element);
    }
    outletConnected(outlet, element, name3) {
      this.invokeControllerMethod(`${namespaceCamelize(name3)}OutletConnected`, outlet, element);
    }
    outletDisconnected(outlet, element, name3) {
      this.invokeControllerMethod(`${namespaceCamelize(name3)}OutletDisconnected`, outlet, element);
    }
    invokeControllerMethod(methodName, ...args) {
      const controller = this.controller;
      if (typeof controller[methodName] == "function") {
        controller[methodName](...args);
      }
    }
  };
  function bless(constructor) {
    return shadow(constructor, getBlessedProperties(constructor));
  }
  function shadow(constructor, properties) {
    const shadowConstructor = extend3(constructor);
    const shadowProperties = getShadowProperties(constructor.prototype, properties);
    Object.defineProperties(shadowConstructor.prototype, shadowProperties);
    return shadowConstructor;
  }
  function getBlessedProperties(constructor) {
    const blessings = readInheritableStaticArrayValues(constructor, "blessings");
    return blessings.reduce((blessedProperties, blessing) => {
      const properties = blessing(constructor);
      for (const key in properties) {
        const descriptor = blessedProperties[key] || {};
        blessedProperties[key] = Object.assign(descriptor, properties[key]);
      }
      return blessedProperties;
    }, {});
  }
  function getShadowProperties(prototype, properties) {
    return getOwnKeys(properties).reduce((shadowProperties, key) => {
      const descriptor = getShadowedDescriptor(prototype, properties, key);
      if (descriptor) {
        Object.assign(shadowProperties, { [key]: descriptor });
      }
      return shadowProperties;
    }, {});
  }
  function getShadowedDescriptor(prototype, properties, key) {
    const shadowingDescriptor = Object.getOwnPropertyDescriptor(prototype, key);
    const shadowedByValue = shadowingDescriptor && "value" in shadowingDescriptor;
    if (!shadowedByValue) {
      const descriptor = Object.getOwnPropertyDescriptor(properties, key).value;
      if (shadowingDescriptor) {
        descriptor.get = shadowingDescriptor.get || descriptor.get;
        descriptor.set = shadowingDescriptor.set || descriptor.set;
      }
      return descriptor;
    }
  }
  var getOwnKeys = (() => {
    if (typeof Object.getOwnPropertySymbols == "function") {
      return (object) => [...Object.getOwnPropertyNames(object), ...Object.getOwnPropertySymbols(object)];
    } else {
      return Object.getOwnPropertyNames;
    }
  })();
  var extend3 = (() => {
    function extendWithReflect(constructor) {
      function extended() {
        return Reflect.construct(constructor, arguments, new.target);
      }
      extended.prototype = Object.create(constructor.prototype, {
        constructor: { value: extended }
      });
      Reflect.setPrototypeOf(extended, constructor);
      return extended;
    }
    function testReflectExtension() {
      const a = function() {
        this.a.call(this);
      };
      const b2 = extendWithReflect(a);
      b2.prototype.a = function() {
      };
      return new b2();
    }
    try {
      testReflectExtension();
      return extendWithReflect;
    } catch (error3) {
      return (constructor) => class extended extends constructor {
      };
    }
  })();
  function blessDefinition(definition) {
    return {
      identifier: definition.identifier,
      controllerConstructor: bless(definition.controllerConstructor)
    };
  }
  var Module = class {
    constructor(application2, definition) {
      this.application = application2;
      this.definition = blessDefinition(definition);
      this.contextsByScope = /* @__PURE__ */ new WeakMap();
      this.connectedContexts = /* @__PURE__ */ new Set();
    }
    get identifier() {
      return this.definition.identifier;
    }
    get controllerConstructor() {
      return this.definition.controllerConstructor;
    }
    get contexts() {
      return Array.from(this.connectedContexts);
    }
    connectContextForScope(scope) {
      const context = this.fetchContextForScope(scope);
      this.connectedContexts.add(context);
      context.connect();
    }
    disconnectContextForScope(scope) {
      const context = this.contextsByScope.get(scope);
      if (context) {
        this.connectedContexts.delete(context);
        context.disconnect();
      }
    }
    fetchContextForScope(scope) {
      let context = this.contextsByScope.get(scope);
      if (!context) {
        context = new Context(this, scope);
        this.contextsByScope.set(scope, context);
      }
      return context;
    }
  };
  var ClassMap = class {
    constructor(scope) {
      this.scope = scope;
    }
    has(name3) {
      return this.data.has(this.getDataKey(name3));
    }
    get(name3) {
      return this.getAll(name3)[0];
    }
    getAll(name3) {
      const tokenString = this.data.get(this.getDataKey(name3)) || "";
      return tokenize(tokenString);
    }
    getAttributeName(name3) {
      return this.data.getAttributeNameForKey(this.getDataKey(name3));
    }
    getDataKey(name3) {
      return `${name3}-class`;
    }
    get data() {
      return this.scope.data;
    }
  };
  var DataMap = class {
    constructor(scope) {
      this.scope = scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get(key) {
      const name3 = this.getAttributeNameForKey(key);
      return this.element.getAttribute(name3);
    }
    set(key, value) {
      const name3 = this.getAttributeNameForKey(key);
      this.element.setAttribute(name3, value);
      return this.get(key);
    }
    has(key) {
      const name3 = this.getAttributeNameForKey(key);
      return this.element.hasAttribute(name3);
    }
    delete(key) {
      if (this.has(key)) {
        const name3 = this.getAttributeNameForKey(key);
        this.element.removeAttribute(name3);
        return true;
      } else {
        return false;
      }
    }
    getAttributeNameForKey(key) {
      return `data-${this.identifier}-${dasherize(key)}`;
    }
  };
  var Guide = class {
    constructor(logger3) {
      this.warnedKeysByObject = /* @__PURE__ */ new WeakMap();
      this.logger = logger3;
    }
    warn(object, key, message) {
      let warnedKeys = this.warnedKeysByObject.get(object);
      if (!warnedKeys) {
        warnedKeys = /* @__PURE__ */ new Set();
        this.warnedKeysByObject.set(object, warnedKeys);
      }
      if (!warnedKeys.has(key)) {
        warnedKeys.add(key);
        this.logger.warn(message, object);
      }
    }
  };
  function attributeValueContainsToken(attributeName, token) {
    return `[${attributeName}~="${token}"]`;
  }
  var TargetSet = class {
    constructor(scope) {
      this.scope = scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get schema() {
      return this.scope.schema;
    }
    has(targetName) {
      return this.find(targetName) != null;
    }
    find(...targetNames) {
      return targetNames.reduce((target, targetName) => target || this.findTarget(targetName) || this.findLegacyTarget(targetName), void 0);
    }
    findAll(...targetNames) {
      return targetNames.reduce((targets, targetName) => [
        ...targets,
        ...this.findAllTargets(targetName),
        ...this.findAllLegacyTargets(targetName)
      ], []);
    }
    findTarget(targetName) {
      const selector = this.getSelectorForTargetName(targetName);
      return this.scope.findElement(selector);
    }
    findAllTargets(targetName) {
      const selector = this.getSelectorForTargetName(targetName);
      return this.scope.findAllElements(selector);
    }
    getSelectorForTargetName(targetName) {
      const attributeName = this.schema.targetAttributeForScope(this.identifier);
      return attributeValueContainsToken(attributeName, targetName);
    }
    findLegacyTarget(targetName) {
      const selector = this.getLegacySelectorForTargetName(targetName);
      return this.deprecate(this.scope.findElement(selector), targetName);
    }
    findAllLegacyTargets(targetName) {
      const selector = this.getLegacySelectorForTargetName(targetName);
      return this.scope.findAllElements(selector).map((element) => this.deprecate(element, targetName));
    }
    getLegacySelectorForTargetName(targetName) {
      const targetDescriptor = `${this.identifier}.${targetName}`;
      return attributeValueContainsToken(this.schema.targetAttribute, targetDescriptor);
    }
    deprecate(element, targetName) {
      if (element) {
        const { identifier } = this;
        const attributeName = this.schema.targetAttribute;
        const revisedAttributeName = this.schema.targetAttributeForScope(identifier);
        this.guide.warn(element, `target:${targetName}`, `Please replace ${attributeName}="${identifier}.${targetName}" with ${revisedAttributeName}="${targetName}". The ${attributeName} attribute is deprecated and will be removed in a future version of Stimulus.`);
      }
      return element;
    }
    get guide() {
      return this.scope.guide;
    }
  };
  var OutletSet = class {
    constructor(scope, controllerElement) {
      this.scope = scope;
      this.controllerElement = controllerElement;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get schema() {
      return this.scope.schema;
    }
    has(outletName) {
      return this.find(outletName) != null;
    }
    find(...outletNames) {
      return outletNames.reduce((outlet, outletName) => outlet || this.findOutlet(outletName), void 0);
    }
    findAll(...outletNames) {
      return outletNames.reduce((outlets, outletName) => [...outlets, ...this.findAllOutlets(outletName)], []);
    }
    getSelectorForOutletName(outletName) {
      const attributeName = this.schema.outletAttributeForScope(this.identifier, outletName);
      return this.controllerElement.getAttribute(attributeName);
    }
    findOutlet(outletName) {
      const selector = this.getSelectorForOutletName(outletName);
      if (selector)
        return this.findElement(selector, outletName);
    }
    findAllOutlets(outletName) {
      const selector = this.getSelectorForOutletName(outletName);
      return selector ? this.findAllElements(selector, outletName) : [];
    }
    findElement(selector, outletName) {
      const elements = this.scope.queryElements(selector);
      return elements.filter((element) => this.matchesElement(element, selector, outletName))[0];
    }
    findAllElements(selector, outletName) {
      const elements = this.scope.queryElements(selector);
      return elements.filter((element) => this.matchesElement(element, selector, outletName));
    }
    matchesElement(element, selector, outletName) {
      const controllerAttribute = element.getAttribute(this.scope.schema.controllerAttribute) || "";
      return element.matches(selector) && controllerAttribute.split(" ").includes(outletName);
    }
  };
  var Scope = class _Scope {
    constructor(schema2, element, identifier, logger3) {
      this.targets = new TargetSet(this);
      this.classes = new ClassMap(this);
      this.data = new DataMap(this);
      this.containsElement = (element2) => {
        return element2.closest(this.controllerSelector) === this.element;
      };
      this.schema = schema2;
      this.element = element;
      this.identifier = identifier;
      this.guide = new Guide(logger3);
      this.outlets = new OutletSet(this.documentScope, element);
    }
    findElement(selector) {
      return this.element.matches(selector) ? this.element : this.queryElements(selector).find(this.containsElement);
    }
    findAllElements(selector) {
      return [
        ...this.element.matches(selector) ? [this.element] : [],
        ...this.queryElements(selector).filter(this.containsElement)
      ];
    }
    queryElements(selector) {
      return Array.from(this.element.querySelectorAll(selector));
    }
    get controllerSelector() {
      return attributeValueContainsToken(this.schema.controllerAttribute, this.identifier);
    }
    get isDocumentScope() {
      return this.element === document.documentElement;
    }
    get documentScope() {
      return this.isDocumentScope ? this : new _Scope(this.schema, document.documentElement, this.identifier, this.guide.logger);
    }
  };
  var ScopeObserver = class {
    constructor(element, schema2, delegate) {
      this.element = element;
      this.schema = schema2;
      this.delegate = delegate;
      this.valueListObserver = new ValueListObserver(this.element, this.controllerAttribute, this);
      this.scopesByIdentifierByElement = /* @__PURE__ */ new WeakMap();
      this.scopeReferenceCounts = /* @__PURE__ */ new WeakMap();
    }
    start() {
      this.valueListObserver.start();
    }
    stop() {
      this.valueListObserver.stop();
    }
    get controllerAttribute() {
      return this.schema.controllerAttribute;
    }
    parseValueForToken(token) {
      const { element, content: identifier } = token;
      return this.parseValueForElementAndIdentifier(element, identifier);
    }
    parseValueForElementAndIdentifier(element, identifier) {
      const scopesByIdentifier = this.fetchScopesByIdentifierForElement(element);
      let scope = scopesByIdentifier.get(identifier);
      if (!scope) {
        scope = this.delegate.createScopeForElementAndIdentifier(element, identifier);
        scopesByIdentifier.set(identifier, scope);
      }
      return scope;
    }
    elementMatchedValue(element, value) {
      const referenceCount = (this.scopeReferenceCounts.get(value) || 0) + 1;
      this.scopeReferenceCounts.set(value, referenceCount);
      if (referenceCount == 1) {
        this.delegate.scopeConnected(value);
      }
    }
    elementUnmatchedValue(element, value) {
      const referenceCount = this.scopeReferenceCounts.get(value);
      if (referenceCount) {
        this.scopeReferenceCounts.set(value, referenceCount - 1);
        if (referenceCount == 1) {
          this.delegate.scopeDisconnected(value);
        }
      }
    }
    fetchScopesByIdentifierForElement(element) {
      let scopesByIdentifier = this.scopesByIdentifierByElement.get(element);
      if (!scopesByIdentifier) {
        scopesByIdentifier = /* @__PURE__ */ new Map();
        this.scopesByIdentifierByElement.set(element, scopesByIdentifier);
      }
      return scopesByIdentifier;
    }
  };
  var Router = class {
    constructor(application2) {
      this.application = application2;
      this.scopeObserver = new ScopeObserver(this.element, this.schema, this);
      this.scopesByIdentifier = new Multimap();
      this.modulesByIdentifier = /* @__PURE__ */ new Map();
    }
    get element() {
      return this.application.element;
    }
    get schema() {
      return this.application.schema;
    }
    get logger() {
      return this.application.logger;
    }
    get controllerAttribute() {
      return this.schema.controllerAttribute;
    }
    get modules() {
      return Array.from(this.modulesByIdentifier.values());
    }
    get contexts() {
      return this.modules.reduce((contexts, module3) => contexts.concat(module3.contexts), []);
    }
    start() {
      this.scopeObserver.start();
    }
    stop() {
      this.scopeObserver.stop();
    }
    loadDefinition(definition) {
      this.unloadIdentifier(definition.identifier);
      const module3 = new Module(this.application, definition);
      this.connectModule(module3);
      const afterLoad = definition.controllerConstructor.afterLoad;
      if (afterLoad) {
        afterLoad.call(definition.controllerConstructor, definition.identifier, this.application);
      }
    }
    unloadIdentifier(identifier) {
      const module3 = this.modulesByIdentifier.get(identifier);
      if (module3) {
        this.disconnectModule(module3);
      }
    }
    getContextForElementAndIdentifier(element, identifier) {
      const module3 = this.modulesByIdentifier.get(identifier);
      if (module3) {
        return module3.contexts.find((context) => context.element == element);
      }
    }
    proposeToConnectScopeForElementAndIdentifier(element, identifier) {
      const scope = this.scopeObserver.parseValueForElementAndIdentifier(element, identifier);
      if (scope) {
        this.scopeObserver.elementMatchedValue(scope.element, scope);
      } else {
        console.error(`Couldn't find or create scope for identifier: "${identifier}" and element:`, element);
      }
    }
    handleError(error3, message, detail) {
      this.application.handleError(error3, message, detail);
    }
    createScopeForElementAndIdentifier(element, identifier) {
      return new Scope(this.schema, element, identifier, this.logger);
    }
    scopeConnected(scope) {
      this.scopesByIdentifier.add(scope.identifier, scope);
      const module3 = this.modulesByIdentifier.get(scope.identifier);
      if (module3) {
        module3.connectContextForScope(scope);
      }
    }
    scopeDisconnected(scope) {
      this.scopesByIdentifier.delete(scope.identifier, scope);
      const module3 = this.modulesByIdentifier.get(scope.identifier);
      if (module3) {
        module3.disconnectContextForScope(scope);
      }
    }
    connectModule(module3) {
      this.modulesByIdentifier.set(module3.identifier, module3);
      const scopes = this.scopesByIdentifier.getValuesForKey(module3.identifier);
      scopes.forEach((scope) => module3.connectContextForScope(scope));
    }
    disconnectModule(module3) {
      this.modulesByIdentifier.delete(module3.identifier);
      const scopes = this.scopesByIdentifier.getValuesForKey(module3.identifier);
      scopes.forEach((scope) => module3.disconnectContextForScope(scope));
    }
  };
  var defaultSchema = {
    controllerAttribute: "data-controller",
    actionAttribute: "data-action",
    targetAttribute: "data-target",
    targetAttributeForScope: (identifier) => `data-${identifier}-target`,
    outletAttributeForScope: (identifier, outlet) => `data-${identifier}-${outlet}-outlet`,
    keyMappings: Object.assign(Object.assign({ enter: "Enter", tab: "Tab", esc: "Escape", space: " ", up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight", home: "Home", end: "End", page_up: "PageUp", page_down: "PageDown" }, objectFromEntries("abcdefghijklmnopqrstuvwxyz".split("").map((c2) => [c2, c2]))), objectFromEntries("0123456789".split("").map((n2) => [n2, n2])))
  };
  function objectFromEntries(array) {
    return array.reduce((memo, [k, v2]) => Object.assign(Object.assign({}, memo), { [k]: v2 }), {});
  }
  var Application = class {
    constructor(element = document.documentElement, schema2 = defaultSchema) {
      this.logger = console;
      this.debug = false;
      this.logDebugActivity = (identifier, functionName, detail = {}) => {
        if (this.debug) {
          this.logFormattedMessage(identifier, functionName, detail);
        }
      };
      this.element = element;
      this.schema = schema2;
      this.dispatcher = new Dispatcher(this);
      this.router = new Router(this);
      this.actionDescriptorFilters = Object.assign({}, defaultActionDescriptorFilters);
    }
    static start(element, schema2) {
      const application2 = new this(element, schema2);
      application2.start();
      return application2;
    }
    async start() {
      await domReady();
      this.logDebugActivity("application", "starting");
      this.dispatcher.start();
      this.router.start();
      this.logDebugActivity("application", "start");
    }
    stop() {
      this.logDebugActivity("application", "stopping");
      this.dispatcher.stop();
      this.router.stop();
      this.logDebugActivity("application", "stop");
    }
    register(identifier, controllerConstructor) {
      this.load({ identifier, controllerConstructor });
    }
    registerActionOption(name3, filter) {
      this.actionDescriptorFilters[name3] = filter;
    }
    load(head, ...rest) {
      const definitions = Array.isArray(head) ? head : [head, ...rest];
      definitions.forEach((definition) => {
        if (definition.controllerConstructor.shouldLoad) {
          this.router.loadDefinition(definition);
        }
      });
    }
    unload(head, ...rest) {
      const identifiers = Array.isArray(head) ? head : [head, ...rest];
      identifiers.forEach((identifier) => this.router.unloadIdentifier(identifier));
    }
    get controllers() {
      return this.router.contexts.map((context) => context.controller);
    }
    getControllerForElementAndIdentifier(element, identifier) {
      const context = this.router.getContextForElementAndIdentifier(element, identifier);
      return context ? context.controller : null;
    }
    handleError(error3, message, detail) {
      var _a;
      this.logger.error(`%s

%o

%o`, message, error3, detail);
      (_a = window.onerror) === null || _a === void 0 ? void 0 : _a.call(window, message, "", 0, 0, error3);
    }
    logFormattedMessage(identifier, functionName, detail = {}) {
      detail = Object.assign({ application: this }, detail);
      this.logger.groupCollapsed(`${identifier} #${functionName}`);
      this.logger.log("details:", Object.assign({}, detail));
      this.logger.groupEnd();
    }
  };
  function domReady() {
    return new Promise((resolve) => {
      if (document.readyState == "loading") {
        document.addEventListener("DOMContentLoaded", () => resolve());
      } else {
        resolve();
      }
    });
  }
  function ClassPropertiesBlessing(constructor) {
    const classes = readInheritableStaticArrayValues(constructor, "classes");
    return classes.reduce((properties, classDefinition) => {
      return Object.assign(properties, propertiesForClassDefinition(classDefinition));
    }, {});
  }
  function propertiesForClassDefinition(key) {
    return {
      [`${key}Class`]: {
        get() {
          const { classes } = this;
          if (classes.has(key)) {
            return classes.get(key);
          } else {
            const attribute = classes.getAttributeName(key);
            throw new Error(`Missing attribute "${attribute}"`);
          }
        }
      },
      [`${key}Classes`]: {
        get() {
          return this.classes.getAll(key);
        }
      },
      [`has${capitalize(key)}Class`]: {
        get() {
          return this.classes.has(key);
        }
      }
    };
  }
  function OutletPropertiesBlessing(constructor) {
    const outlets = readInheritableStaticArrayValues(constructor, "outlets");
    return outlets.reduce((properties, outletDefinition) => {
      return Object.assign(properties, propertiesForOutletDefinition(outletDefinition));
    }, {});
  }
  function getOutletController(controller, element, identifier) {
    return controller.application.getControllerForElementAndIdentifier(element, identifier);
  }
  function getControllerAndEnsureConnectedScope(controller, element, outletName) {
    let outletController = getOutletController(controller, element, outletName);
    if (outletController)
      return outletController;
    controller.application.router.proposeToConnectScopeForElementAndIdentifier(element, outletName);
    outletController = getOutletController(controller, element, outletName);
    if (outletController)
      return outletController;
  }
  function propertiesForOutletDefinition(name3) {
    const camelizedName = namespaceCamelize(name3);
    return {
      [`${camelizedName}Outlet`]: {
        get() {
          const outletElement = this.outlets.find(name3);
          const selector = this.outlets.getSelectorForOutletName(name3);
          if (outletElement) {
            const outletController = getControllerAndEnsureConnectedScope(this, outletElement, name3);
            if (outletController)
              return outletController;
            throw new Error(`The provided outlet element is missing an outlet controller "${name3}" instance for host controller "${this.identifier}"`);
          }
          throw new Error(`Missing outlet element "${name3}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
        }
      },
      [`${camelizedName}Outlets`]: {
        get() {
          const outlets = this.outlets.findAll(name3);
          if (outlets.length > 0) {
            return outlets.map((outletElement) => {
              const outletController = getControllerAndEnsureConnectedScope(this, outletElement, name3);
              if (outletController)
                return outletController;
              console.warn(`The provided outlet element is missing an outlet controller "${name3}" instance for host controller "${this.identifier}"`, outletElement);
            }).filter((controller) => controller);
          }
          return [];
        }
      },
      [`${camelizedName}OutletElement`]: {
        get() {
          const outletElement = this.outlets.find(name3);
          const selector = this.outlets.getSelectorForOutletName(name3);
          if (outletElement) {
            return outletElement;
          } else {
            throw new Error(`Missing outlet element "${name3}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
          }
        }
      },
      [`${camelizedName}OutletElements`]: {
        get() {
          return this.outlets.findAll(name3);
        }
      },
      [`has${capitalize(camelizedName)}Outlet`]: {
        get() {
          return this.outlets.has(name3);
        }
      }
    };
  }
  function TargetPropertiesBlessing(constructor) {
    const targets = readInheritableStaticArrayValues(constructor, "targets");
    return targets.reduce((properties, targetDefinition) => {
      return Object.assign(properties, propertiesForTargetDefinition(targetDefinition));
    }, {});
  }
  function propertiesForTargetDefinition(name3) {
    return {
      [`${name3}Target`]: {
        get() {
          const target = this.targets.find(name3);
          if (target) {
            return target;
          } else {
            throw new Error(`Missing target element "${name3}" for "${this.identifier}" controller`);
          }
        }
      },
      [`${name3}Targets`]: {
        get() {
          return this.targets.findAll(name3);
        }
      },
      [`has${capitalize(name3)}Target`]: {
        get() {
          return this.targets.has(name3);
        }
      }
    };
  }
  function ValuePropertiesBlessing(constructor) {
    const valueDefinitionPairs = readInheritableStaticObjectPairs(constructor, "values");
    const propertyDescriptorMap = {
      valueDescriptorMap: {
        get() {
          return valueDefinitionPairs.reduce((result, valueDefinitionPair) => {
            const valueDescriptor = parseValueDefinitionPair(valueDefinitionPair, this.identifier);
            const attributeName = this.data.getAttributeNameForKey(valueDescriptor.key);
            return Object.assign(result, { [attributeName]: valueDescriptor });
          }, {});
        }
      }
    };
    return valueDefinitionPairs.reduce((properties, valueDefinitionPair) => {
      return Object.assign(properties, propertiesForValueDefinitionPair(valueDefinitionPair));
    }, propertyDescriptorMap);
  }
  function propertiesForValueDefinitionPair(valueDefinitionPair, controller) {
    const definition = parseValueDefinitionPair(valueDefinitionPair, controller);
    const { key, name: name3, reader: read2, writer: write2 } = definition;
    return {
      [name3]: {
        get() {
          const value = this.data.get(key);
          if (value !== null) {
            return read2(value);
          } else {
            return definition.defaultValue;
          }
        },
        set(value) {
          if (value === void 0) {
            this.data.delete(key);
          } else {
            this.data.set(key, write2(value));
          }
        }
      },
      [`has${capitalize(name3)}`]: {
        get() {
          return this.data.has(key) || definition.hasCustomDefaultValue;
        }
      }
    };
  }
  function parseValueDefinitionPair([token, typeDefinition], controller) {
    return valueDescriptorForTokenAndTypeDefinition({
      controller,
      token,
      typeDefinition
    });
  }
  function parseValueTypeConstant(constant) {
    switch (constant) {
      case Array:
        return "array";
      case Boolean:
        return "boolean";
      case Number:
        return "number";
      case Object:
        return "object";
      case String:
        return "string";
    }
  }
  function parseValueTypeDefault(defaultValue) {
    switch (typeof defaultValue) {
      case "boolean":
        return "boolean";
      case "number":
        return "number";
      case "string":
        return "string";
    }
    if (Array.isArray(defaultValue))
      return "array";
    if (Object.prototype.toString.call(defaultValue) === "[object Object]")
      return "object";
  }
  function parseValueTypeObject(payload) {
    const { controller, token, typeObject } = payload;
    const hasType = isSomething(typeObject.type);
    const hasDefault = isSomething(typeObject.default);
    const fullObject = hasType && hasDefault;
    const onlyType = hasType && !hasDefault;
    const onlyDefault = !hasType && hasDefault;
    const typeFromObject = parseValueTypeConstant(typeObject.type);
    const typeFromDefaultValue = parseValueTypeDefault(payload.typeObject.default);
    if (onlyType)
      return typeFromObject;
    if (onlyDefault)
      return typeFromDefaultValue;
    if (typeFromObject !== typeFromDefaultValue) {
      const propertyPath = controller ? `${controller}.${token}` : token;
      throw new Error(`The specified default value for the Stimulus Value "${propertyPath}" must match the defined type "${typeFromObject}". The provided default value of "${typeObject.default}" is of type "${typeFromDefaultValue}".`);
    }
    if (fullObject)
      return typeFromObject;
  }
  function parseValueTypeDefinition(payload) {
    const { controller, token, typeDefinition } = payload;
    const typeObject = { controller, token, typeObject: typeDefinition };
    const typeFromObject = parseValueTypeObject(typeObject);
    const typeFromDefaultValue = parseValueTypeDefault(typeDefinition);
    const typeFromConstant = parseValueTypeConstant(typeDefinition);
    const type = typeFromObject || typeFromDefaultValue || typeFromConstant;
    if (type)
      return type;
    const propertyPath = controller ? `${controller}.${typeDefinition}` : token;
    throw new Error(`Unknown value type "${propertyPath}" for "${token}" value`);
  }
  function defaultValueForDefinition(typeDefinition) {
    const constant = parseValueTypeConstant(typeDefinition);
    if (constant)
      return defaultValuesByType[constant];
    const hasDefault = hasProperty(typeDefinition, "default");
    const hasType = hasProperty(typeDefinition, "type");
    const typeObject = typeDefinition;
    if (hasDefault)
      return typeObject.default;
    if (hasType) {
      const { type } = typeObject;
      const constantFromType = parseValueTypeConstant(type);
      if (constantFromType)
        return defaultValuesByType[constantFromType];
    }
    return typeDefinition;
  }
  function valueDescriptorForTokenAndTypeDefinition(payload) {
    const { token, typeDefinition } = payload;
    const key = `${dasherize(token)}-value`;
    const type = parseValueTypeDefinition(payload);
    return {
      type,
      key,
      name: camelize(key),
      get defaultValue() {
        return defaultValueForDefinition(typeDefinition);
      },
      get hasCustomDefaultValue() {
        return parseValueTypeDefault(typeDefinition) !== void 0;
      },
      reader: readers[type],
      writer: writers[type] || writers.default
    };
  }
  var defaultValuesByType = {
    get array() {
      return [];
    },
    boolean: false,
    number: 0,
    get object() {
      return {};
    },
    string: ""
  };
  var readers = {
    array(value) {
      const array = JSON.parse(value);
      if (!Array.isArray(array)) {
        throw new TypeError(`expected value of type "array" but instead got value "${value}" of type "${parseValueTypeDefault(array)}"`);
      }
      return array;
    },
    boolean(value) {
      return !(value == "0" || String(value).toLowerCase() == "false");
    },
    number(value) {
      return Number(value.replace(/_/g, ""));
    },
    object(value) {
      const object = JSON.parse(value);
      if (object === null || typeof object != "object" || Array.isArray(object)) {
        throw new TypeError(`expected value of type "object" but instead got value "${value}" of type "${parseValueTypeDefault(object)}"`);
      }
      return object;
    },
    string(value) {
      return value;
    }
  };
  var writers = {
    default: writeString,
    array: writeJSON,
    object: writeJSON
  };
  function writeJSON(value) {
    return JSON.stringify(value);
  }
  function writeString(value) {
    return `${value}`;
  }
  var Controller = class {
    constructor(context) {
      this.context = context;
    }
    static get shouldLoad() {
      return true;
    }
    static afterLoad(_identifier, _application) {
      return;
    }
    get application() {
      return this.context.application;
    }
    get scope() {
      return this.context.scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get targets() {
      return this.scope.targets;
    }
    get outlets() {
      return this.scope.outlets;
    }
    get classes() {
      return this.scope.classes;
    }
    get data() {
      return this.scope.data;
    }
    initialize() {
    }
    connect() {
    }
    disconnect() {
    }
    dispatch(eventName, { target = this.element, detail = {}, prefix = this.identifier, bubbles = true, cancelable = true } = {}) {
      const type = prefix ? `${prefix}:${eventName}` : eventName;
      const event = new CustomEvent(type, { detail, bubbles, cancelable });
      target.dispatchEvent(event);
      return event;
    }
  };
  Controller.blessings = [
    ClassPropertiesBlessing,
    TargetPropertiesBlessing,
    ValuePropertiesBlessing,
    OutletPropertiesBlessing
  ];
  Controller.targets = [];
  Controller.outlets = [];
  Controller.values = {};

  // controllers/application.js
  var application = Application.start();
  application.debug = false;
  window.Stimulus = application;

  // controllers/application_controller.js
  var application_controller_exports = {};
  __export(application_controller_exports, {
    default: () => application_controller_default
  });

  // ../../node_modules/stimulus_reflex/node_modules/@rails/actioncable/app/assets/javascripts/actioncable.esm.js
  var adapters2 = {
    logger: typeof console !== "undefined" ? console : void 0,
    WebSocket: typeof WebSocket !== "undefined" ? WebSocket : void 0
  };
  var logger2 = {
    log(...messages) {
      if (this.enabled) {
        messages.push(Date.now());
        adapters2.logger.log("[ActionCable]", ...messages);
      }
    }
  };
  var now3 = () => (/* @__PURE__ */ new Date()).getTime();
  var secondsSince3 = (time) => (now3() - time) / 1e3;
  var ConnectionMonitor3 = class {
    constructor(connection) {
      this.visibilityDidChange = this.visibilityDidChange.bind(this);
      this.connection = connection;
      this.reconnectAttempts = 0;
    }
    start() {
      if (!this.isRunning()) {
        this.startedAt = now3();
        delete this.stoppedAt;
        this.startPolling();
        addEventListener("visibilitychange", this.visibilityDidChange);
        logger2.log(`ConnectionMonitor started. stale threshold = ${this.constructor.staleThreshold} s`);
      }
    }
    stop() {
      if (this.isRunning()) {
        this.stoppedAt = now3();
        this.stopPolling();
        removeEventListener("visibilitychange", this.visibilityDidChange);
        logger2.log("ConnectionMonitor stopped");
      }
    }
    isRunning() {
      return this.startedAt && !this.stoppedAt;
    }
    recordPing() {
      this.pingedAt = now3();
    }
    recordConnect() {
      this.reconnectAttempts = 0;
      this.recordPing();
      delete this.disconnectedAt;
      logger2.log("ConnectionMonitor recorded connect");
    }
    recordDisconnect() {
      this.disconnectedAt = now3();
      logger2.log("ConnectionMonitor recorded disconnect");
    }
    startPolling() {
      this.stopPolling();
      this.poll();
    }
    stopPolling() {
      clearTimeout(this.pollTimeout);
    }
    poll() {
      this.pollTimeout = setTimeout(() => {
        this.reconnectIfStale();
        this.poll();
      }, this.getPollInterval());
    }
    getPollInterval() {
      const { staleThreshold, reconnectionBackoffRate } = this.constructor;
      const backoff = Math.pow(1 + reconnectionBackoffRate, Math.min(this.reconnectAttempts, 10));
      const jitterMax = this.reconnectAttempts === 0 ? 1 : reconnectionBackoffRate;
      const jitter = jitterMax * Math.random();
      return staleThreshold * 1e3 * backoff * (1 + jitter);
    }
    reconnectIfStale() {
      if (this.connectionIsStale()) {
        logger2.log(`ConnectionMonitor detected stale connection. reconnectAttempts = ${this.reconnectAttempts}, time stale = ${secondsSince3(this.refreshedAt)} s, stale threshold = ${this.constructor.staleThreshold} s`);
        this.reconnectAttempts++;
        if (this.disconnectedRecently()) {
          logger2.log(`ConnectionMonitor skipping reopening recent disconnect. time disconnected = ${secondsSince3(this.disconnectedAt)} s`);
        } else {
          logger2.log("ConnectionMonitor reopening");
          this.connection.reopen();
        }
      }
    }
    get refreshedAt() {
      return this.pingedAt ? this.pingedAt : this.startedAt;
    }
    connectionIsStale() {
      return secondsSince3(this.refreshedAt) > this.constructor.staleThreshold;
    }
    disconnectedRecently() {
      return this.disconnectedAt && secondsSince3(this.disconnectedAt) < this.constructor.staleThreshold;
    }
    visibilityDidChange() {
      if (document.visibilityState === "visible") {
        setTimeout(() => {
          if (this.connectionIsStale() || !this.connection.isOpen()) {
            logger2.log(`ConnectionMonitor reopening stale connection on visibilitychange. visibilityState = ${document.visibilityState}`);
            this.connection.reopen();
          }
        }, 200);
      }
    }
  };
  ConnectionMonitor3.staleThreshold = 6;
  ConnectionMonitor3.reconnectionBackoffRate = 0.15;
  var INTERNAL2 = {
    message_types: {
      welcome: "welcome",
      disconnect: "disconnect",
      ping: "ping",
      confirmation: "confirm_subscription",
      rejection: "reject_subscription"
    },
    disconnect_reasons: {
      unauthorized: "unauthorized",
      invalid_request: "invalid_request",
      server_restart: "server_restart",
      remote: "remote"
    },
    default_mount_path: "/cable",
    protocols: ["actioncable-v1-json", "actioncable-unsupported"]
  };
  var { message_types: message_types3, protocols: protocols3 } = INTERNAL2;
  var supportedProtocols3 = protocols3.slice(0, protocols3.length - 1);
  var indexOf3 = [].indexOf;
  var Connection3 = class {
    constructor(consumer5) {
      this.open = this.open.bind(this);
      this.consumer = consumer5;
      this.subscriptions = this.consumer.subscriptions;
      this.monitor = new ConnectionMonitor3(this);
      this.disconnected = true;
    }
    send(data) {
      if (this.isOpen()) {
        this.webSocket.send(JSON.stringify(data));
        return true;
      } else {
        return false;
      }
    }
    open() {
      if (this.isActive()) {
        logger2.log(`Attempted to open WebSocket, but existing socket is ${this.getState()}`);
        return false;
      } else {
        const socketProtocols = [...protocols3, ...this.consumer.subprotocols || []];
        logger2.log(`Opening WebSocket, current state is ${this.getState()}, subprotocols: ${socketProtocols}`);
        if (this.webSocket) {
          this.uninstallEventHandlers();
        }
        this.webSocket = new adapters2.WebSocket(this.consumer.url, socketProtocols);
        this.installEventHandlers();
        this.monitor.start();
        return true;
      }
    }
    close({ allowReconnect } = {
      allowReconnect: true
    }) {
      if (!allowReconnect) {
        this.monitor.stop();
      }
      if (this.isOpen()) {
        return this.webSocket.close();
      }
    }
    reopen() {
      logger2.log(`Reopening WebSocket, current state is ${this.getState()}`);
      if (this.isActive()) {
        try {
          return this.close();
        } catch (error3) {
          logger2.log("Failed to reopen WebSocket", error3);
        } finally {
          logger2.log(`Reopening WebSocket in ${this.constructor.reopenDelay}ms`);
          setTimeout(this.open, this.constructor.reopenDelay);
        }
      } else {
        return this.open();
      }
    }
    getProtocol() {
      if (this.webSocket) {
        return this.webSocket.protocol;
      }
    }
    isOpen() {
      return this.isState("open");
    }
    isActive() {
      return this.isState("open", "connecting");
    }
    triedToReconnect() {
      return this.monitor.reconnectAttempts > 0;
    }
    isProtocolSupported() {
      return indexOf3.call(supportedProtocols3, this.getProtocol()) >= 0;
    }
    isState(...states) {
      return indexOf3.call(states, this.getState()) >= 0;
    }
    getState() {
      if (this.webSocket) {
        for (let state in adapters2.WebSocket) {
          if (adapters2.WebSocket[state] === this.webSocket.readyState) {
            return state.toLowerCase();
          }
        }
      }
      return null;
    }
    installEventHandlers() {
      for (let eventName in this.events) {
        const handler = this.events[eventName].bind(this);
        this.webSocket[`on${eventName}`] = handler;
      }
    }
    uninstallEventHandlers() {
      for (let eventName in this.events) {
        this.webSocket[`on${eventName}`] = function() {
        };
      }
    }
  };
  Connection3.reopenDelay = 500;
  Connection3.prototype.events = {
    message(event) {
      if (!this.isProtocolSupported()) {
        return;
      }
      const { identifier, message, reason, reconnect, type } = JSON.parse(event.data);
      switch (type) {
        case message_types3.welcome:
          if (this.triedToReconnect()) {
            this.reconnectAttempted = true;
          }
          this.monitor.recordConnect();
          return this.subscriptions.reload();
        case message_types3.disconnect:
          logger2.log(`Disconnecting. Reason: ${reason}`);
          return this.close({
            allowReconnect: reconnect
          });
        case message_types3.ping:
          return this.monitor.recordPing();
        case message_types3.confirmation:
          this.subscriptions.confirmSubscription(identifier);
          if (this.reconnectAttempted) {
            this.reconnectAttempted = false;
            return this.subscriptions.notify(identifier, "connected", {
              reconnected: true
            });
          } else {
            return this.subscriptions.notify(identifier, "connected", {
              reconnected: false
            });
          }
        case message_types3.rejection:
          return this.subscriptions.reject(identifier);
        default:
          return this.subscriptions.notify(identifier, "received", message);
      }
    },
    open() {
      logger2.log(`WebSocket onopen event, using '${this.getProtocol()}' subprotocol`);
      this.disconnected = false;
      if (!this.isProtocolSupported()) {
        logger2.log("Protocol is unsupported. Stopping monitor and disconnecting.");
        return this.close({
          allowReconnect: false
        });
      }
    },
    close(event) {
      logger2.log("WebSocket onclose event");
      if (this.disconnected) {
        return;
      }
      this.disconnected = true;
      this.monitor.recordDisconnect();
      return this.subscriptions.notifyAll("disconnected", {
        willAttemptReconnect: this.monitor.isRunning()
      });
    },
    error() {
      logger2.log("WebSocket onerror event");
    }
  };
  var extend4 = function(object, properties) {
    if (properties != null) {
      for (let key in properties) {
        const value = properties[key];
        object[key] = value;
      }
    }
    return object;
  };
  var Subscription3 = class {
    constructor(consumer5, params2 = {}, mixin) {
      this.consumer = consumer5;
      this.identifier = JSON.stringify(params2);
      extend4(this, mixin);
    }
    perform(action, data = {}) {
      data.action = action;
      return this.send(data);
    }
    send(data) {
      return this.consumer.send({
        command: "message",
        identifier: this.identifier,
        data: JSON.stringify(data)
      });
    }
    unsubscribe() {
      return this.consumer.subscriptions.remove(this);
    }
  };
  var SubscriptionGuarantor3 = class {
    constructor(subscriptions) {
      this.subscriptions = subscriptions;
      this.pendingSubscriptions = [];
    }
    guarantee(subscription2) {
      if (this.pendingSubscriptions.indexOf(subscription2) == -1) {
        logger2.log(`SubscriptionGuarantor guaranteeing ${subscription2.identifier}`);
        this.pendingSubscriptions.push(subscription2);
      } else {
        logger2.log(`SubscriptionGuarantor already guaranteeing ${subscription2.identifier}`);
      }
      this.startGuaranteeing();
    }
    forget(subscription2) {
      logger2.log(`SubscriptionGuarantor forgetting ${subscription2.identifier}`);
      this.pendingSubscriptions = this.pendingSubscriptions.filter((s2) => s2 !== subscription2);
    }
    startGuaranteeing() {
      this.stopGuaranteeing();
      this.retrySubscribing();
    }
    stopGuaranteeing() {
      clearTimeout(this.retryTimeout);
    }
    retrySubscribing() {
      this.retryTimeout = setTimeout(() => {
        if (this.subscriptions && typeof this.subscriptions.subscribe === "function") {
          this.pendingSubscriptions.map((subscription2) => {
            logger2.log(`SubscriptionGuarantor resubscribing ${subscription2.identifier}`);
            this.subscriptions.subscribe(subscription2);
          });
        }
      }, 500);
    }
  };
  var Subscriptions3 = class {
    constructor(consumer5) {
      this.consumer = consumer5;
      this.guarantor = new SubscriptionGuarantor3(this);
      this.subscriptions = [];
    }
    create(channelName, mixin) {
      const channel = channelName;
      const params2 = typeof channel === "object" ? channel : {
        channel
      };
      const subscription2 = new Subscription3(this.consumer, params2, mixin);
      return this.add(subscription2);
    }
    add(subscription2) {
      this.subscriptions.push(subscription2);
      this.consumer.ensureActiveConnection();
      this.notify(subscription2, "initialized");
      this.subscribe(subscription2);
      return subscription2;
    }
    remove(subscription2) {
      this.forget(subscription2);
      if (!this.findAll(subscription2.identifier).length) {
        this.sendCommand(subscription2, "unsubscribe");
      }
      return subscription2;
    }
    reject(identifier) {
      return this.findAll(identifier).map((subscription2) => {
        this.forget(subscription2);
        this.notify(subscription2, "rejected");
        return subscription2;
      });
    }
    forget(subscription2) {
      this.guarantor.forget(subscription2);
      this.subscriptions = this.subscriptions.filter((s2) => s2 !== subscription2);
      return subscription2;
    }
    findAll(identifier) {
      return this.subscriptions.filter((s2) => s2.identifier === identifier);
    }
    reload() {
      return this.subscriptions.map((subscription2) => this.subscribe(subscription2));
    }
    notifyAll(callbackName, ...args) {
      return this.subscriptions.map((subscription2) => this.notify(subscription2, callbackName, ...args));
    }
    notify(subscription2, callbackName, ...args) {
      let subscriptions;
      if (typeof subscription2 === "string") {
        subscriptions = this.findAll(subscription2);
      } else {
        subscriptions = [subscription2];
      }
      return subscriptions.map((subscription3) => typeof subscription3[callbackName] === "function" ? subscription3[callbackName](...args) : void 0);
    }
    subscribe(subscription2) {
      if (this.sendCommand(subscription2, "subscribe")) {
        this.guarantor.guarantee(subscription2);
      }
    }
    confirmSubscription(identifier) {
      logger2.log(`Subscription confirmed ${identifier}`);
      this.findAll(identifier).map((subscription2) => this.guarantor.forget(subscription2));
    }
    sendCommand(subscription2, command) {
      const { identifier } = subscription2;
      return this.consumer.send({
        command,
        identifier
      });
    }
  };
  var Consumer3 = class {
    constructor(url) {
      this._url = url;
      this.subscriptions = new Subscriptions3(this);
      this.connection = new Connection3(this);
      this.subprotocols = [];
    }
    get url() {
      return createWebSocketURL3(this._url);
    }
    send(data) {
      return this.connection.send(data);
    }
    connect() {
      return this.connection.open();
    }
    disconnect() {
      return this.connection.close({
        allowReconnect: false
      });
    }
    ensureActiveConnection() {
      if (!this.connection.isActive()) {
        return this.connection.open();
      }
    }
    addSubProtocol(subprotocol) {
      this.subprotocols = [...this.subprotocols, subprotocol];
    }
  };
  function createWebSocketURL3(url) {
    if (typeof url === "function") {
      url = url();
    }
    if (url && !/^wss?:/i.test(url)) {
      const a = document.createElement("a");
      a.href = url;
      a.href = a.href;
      a.protocol = a.protocol.replace("http", "ws");
      return a.href;
    } else {
      return url;
    }
  }
  function createConsumer4(url = getConfig3("url") || INTERNAL2.default_mount_path) {
    return new Consumer3(url);
  }
  function getConfig3(name3) {
    const element = document.head.querySelector(`meta[name='action-cable-${name3}']`);
    if (element) {
      return element.getAttribute("content");
    }
  }

  // ../../node_modules/stimulus_reflex/dist/stimulus_reflex.js
  var Toastify = class {
    defaults = {
      oldestFirst: true,
      text: "Toastify is awesome!",
      node: void 0,
      duration: 3e3,
      selector: void 0,
      callback: function() {
      },
      destination: void 0,
      newWindow: false,
      close: false,
      gravity: "toastify-top",
      positionLeft: false,
      position: "",
      backgroundColor: "",
      avatar: "",
      className: "",
      stopOnFocus: true,
      onClick: function() {
      },
      offset: {
        x: 0,
        y: 0
      },
      escapeMarkup: true,
      ariaLive: "polite",
      style: {
        background: ""
      }
    };
    constructor(options) {
      this.version = "1.12.0";
      this.options = {};
      this.toastElement = null;
      this._rootElement = document.body;
      this._init(options);
    }
    showToast() {
      this.toastElement = this._buildToast();
      if (typeof this.options.selector === "string") {
        this._rootElement = document.getElementById(this.options.selector);
      } else if (this.options.selector instanceof HTMLElement || this.options.selector instanceof ShadowRoot) {
        this._rootElement = this.options.selector;
      } else {
        this._rootElement = document.body;
      }
      if (!this._rootElement) {
        throw "Root element is not defined";
      }
      this._rootElement.insertBefore(this.toastElement, this._rootElement.firstChild);
      this._reposition();
      if (this.options.duration > 0) {
        this.toastElement.timeOutValue = window.setTimeout(() => {
          this._removeElement(this.toastElement);
        }, this.options.duration);
      }
      return this;
    }
    hideToast() {
      if (this.toastElement.timeOutValue) {
        clearTimeout(this.toastElement.timeOutValue);
      }
      this._removeElement(this.toastElement);
    }
    _init(options) {
      this.options = Object.assign(this.defaults, options);
      if (this.options.backgroundColor) {
        console.warn('DEPRECATION NOTICE: "backgroundColor" is being deprecated. Please use the "style.background" property.');
      }
      this.toastElement = null;
      this.options.gravity = options.gravity === "bottom" ? "toastify-bottom" : "toastify-top";
      this.options.stopOnFocus = options.stopOnFocus === void 0 ? true : options.stopOnFocus;
      if (options.backgroundColor) {
        this.options.style.background = options.backgroundColor;
      }
    }
    _buildToast() {
      if (!this.options) {
        throw "Toastify is not initialized";
      }
      let divElement = document.createElement("div");
      divElement.className = `toastify on ${this.options.className}`;
      divElement.className += ` toastify-${this.options.position}`;
      divElement.className += ` ${this.options.gravity}`;
      for (const property in this.options.style) {
        divElement.style[property] = this.options.style[property];
      }
      if (this.options.ariaLive) {
        divElement.setAttribute("aria-live", this.options.ariaLive);
      }
      if (this.options.node && this.options.node.nodeType === Node.ELEMENT_NODE) {
        divElement.appendChild(this.options.node);
      } else {
        if (this.options.escapeMarkup) {
          divElement.innerText = this.options.text;
        } else {
          divElement.innerHTML = this.options.text;
        }
        if (this.options.avatar !== "") {
          let avatarElement = document.createElement("img");
          avatarElement.src = this.options.avatar;
          avatarElement.className = "toastify-avatar";
          if (this.options.position == "left") {
            divElement.appendChild(avatarElement);
          } else {
            divElement.insertAdjacentElement("afterbegin", avatarElement);
          }
        }
      }
      if (this.options.close === true) {
        let closeElement = document.createElement("button");
        closeElement.type = "button";
        closeElement.setAttribute("aria-label", "Close");
        closeElement.className = "toast-close";
        closeElement.innerHTML = "&#10006;";
        closeElement.addEventListener("click", (event) => {
          event.stopPropagation();
          this._removeElement(this.toastElement);
          window.clearTimeout(this.toastElement.timeOutValue);
        });
        const width = window.innerWidth > 0 ? window.innerWidth : screen.width;
        if (this.options.position == "left" && width > 360) {
          divElement.insertAdjacentElement("afterbegin", closeElement);
        } else {
          divElement.appendChild(closeElement);
        }
      }
      if (this.options.stopOnFocus && this.options.duration > 0) {
        divElement.addEventListener("mouseover", (event) => {
          window.clearTimeout(divElement.timeOutValue);
        });
        divElement.addEventListener("mouseleave", () => {
          divElement.timeOutValue = window.setTimeout(() => {
            this._removeElement(divElement);
          }, this.options.duration);
        });
      }
      if (typeof this.options.destination !== "undefined") {
        divElement.addEventListener("click", (event) => {
          event.stopPropagation();
          if (this.options.newWindow === true) {
            window.open(this.options.destination, "_blank");
          } else {
            window.location = this.options.destination;
          }
        });
      }
      if (typeof this.options.onClick === "function" && typeof this.options.destination === "undefined") {
        divElement.addEventListener("click", (event) => {
          event.stopPropagation();
          this.options.onClick();
        });
      }
      if (typeof this.options.offset === "object") {
        const x2 = this._getAxisOffsetAValue("x", this.options);
        const y = this._getAxisOffsetAValue("y", this.options);
        const xOffset = this.options.position == "left" ? x2 : `-${x2}`;
        const yOffset = this.options.gravity == "toastify-top" ? y : `-${y}`;
        divElement.style.transform = `translate(${xOffset},${yOffset})`;
      }
      return divElement;
    }
    _removeElement(toastElement) {
      toastElement.className = toastElement.className.replace(" on", "");
      window.setTimeout(() => {
        if (this.options.node && this.options.node.parentNode) {
          this.options.node.parentNode.removeChild(this.options.node);
        }
        if (toastElement.parentNode) {
          toastElement.parentNode.removeChild(toastElement);
        }
        this.options.callback.call(toastElement);
        this._reposition();
      }, 400);
    }
    _reposition() {
      let topLeftOffsetSize = {
        top: 15,
        bottom: 15
      };
      let topRightOffsetSize = {
        top: 15,
        bottom: 15
      };
      let offsetSize = {
        top: 15,
        bottom: 15
      };
      let allToasts = this._rootElement.querySelectorAll(".toastify");
      let classUsed;
      for (let i = 0; i < allToasts.length; i++) {
        if (allToasts[i].classList.contains("toastify-top") === true) {
          classUsed = "toastify-top";
        } else {
          classUsed = "toastify-bottom";
        }
        let height = allToasts[i].offsetHeight;
        classUsed = classUsed.substr(9, classUsed.length - 1);
        let offset2 = 15;
        let width = window.innerWidth > 0 ? window.innerWidth : screen.width;
        if (width <= 360) {
          allToasts[i].style[classUsed] = `${offsetSize[classUsed]}px`;
          offsetSize[classUsed] += height + offset2;
        } else {
          if (allToasts[i].classList.contains("toastify-left") === true) {
            allToasts[i].style[classUsed] = `${topLeftOffsetSize[classUsed]}px`;
            topLeftOffsetSize[classUsed] += height + offset2;
          } else {
            allToasts[i].style[classUsed] = `${topRightOffsetSize[classUsed]}px`;
            topRightOffsetSize[classUsed] += height + offset2;
          }
        }
      }
    }
    _getAxisOffsetAValue(axis, options) {
      if (options.offset[axis]) {
        if (isNaN(options.offset[axis])) {
          return options.offset[axis];
        } else {
          return `${options.offset[axis]}px`;
        }
      }
      return "0px";
    }
  };
  function StartToastifyInstance(options) {
    return new Toastify(options);
  }
  global2.operations.stimulusReflexVersionMismatch = (operation) => {
    const levels = {
      info: {},
      success: {
        background: "#198754",
        color: "white"
      },
      warn: {
        background: "#ffc107",
        color: "black"
      },
      error: {
        background: "#dc3545",
        color: "white"
      }
    };
    const defaults = {
      selector: setupToastify(),
      close: true,
      duration: 30 * 1e3,
      gravity: "bottom",
      position: "right",
      newWindow: true,
      style: levels[operation.level || "info"]
    };
    StartToastifyInstance({
      ...defaults,
      ...operation
    }).showToast();
  };
  function setupToastify() {
    const id = "stimulus-reflex-toast-element";
    let element = document.querySelector(`#${id}`);
    if (!element) {
      element = document.createElement("div");
      element.id = id;
      document.documentElement.appendChild(element);
      const styles = document.createElement("style");
      styles.innerHTML = `
      #${id} .toastify {
         padding: 12px 20px;
         color: #ffffff;
         display: inline-block;
         background: -webkit-linear-gradient(315deg, #73a5ff, #5477f5);
         background: linear-gradient(135deg, #73a5ff, #5477f5);
         position: fixed;
         opacity: 0;
         transition: all 0.4s cubic-bezier(0.215, 0.61, 0.355, 1);
         border-radius: 2px;
         cursor: pointer;
         text-decoration: none;
         max-width: calc(50% - 20px);
         z-index: 2147483647;
         bottom: -150px;
         right: 15px;
      }

      #${id} .toastify.on {
        opacity: 1;
      }

      #${id} .toast-close {
        background: transparent;
        border: 0;
        color: white;
        cursor: pointer;
        font-family: inherit;
        font-size: 1em;
        opacity: 0.4;
        padding: 0 5px;
      }
    `;
      document.head.appendChild(styles);
    }
    return element;
  }
  var deprecationWarnings = true;
  var Deprecate = {
    get enabled() {
      return deprecationWarnings;
    },
    get disabled() {
      return !deprecationWarnings;
    },
    get value() {
      return deprecationWarnings;
    },
    set(value) {
      deprecationWarnings = !!value;
    },
    set deprecate(value) {
      deprecationWarnings = !!value;
    }
  };
  var debugging2 = false;
  var Debug$1 = {
    get enabled() {
      return debugging2;
    },
    get disabled() {
      return !debugging2;
    },
    get value() {
      return debugging2;
    },
    set(value) {
      debugging2 = !!value;
    },
    set debug(value) {
      debugging2 = !!value;
    }
  };
  var defaultSchema2 = {
    reflexAttribute: "data-reflex",
    reflexPermanentAttribute: "data-reflex-permanent",
    reflexRootAttribute: "data-reflex-root",
    reflexSuppressLoggingAttribute: "data-reflex-suppress-logging",
    reflexDatasetAttribute: "data-reflex-dataset",
    reflexDatasetAllAttribute: "data-reflex-dataset-all",
    reflexSerializeFormAttribute: "data-reflex-serialize-form",
    reflexFormSelectorAttribute: "data-reflex-form-selector",
    reflexIncludeInnerHtmlAttribute: "data-reflex-include-inner-html",
    reflexIncludeTextContentAttribute: "data-reflex-include-text-content"
  };
  var schema = {};
  var Schema = {
    set(application2) {
      schema = {
        ...defaultSchema2,
        ...application2.schema
      };
      for (const attribute in schema) {
        const attributeName = attribute.slice(0, -9);
        Object.defineProperty(this, attributeName, {
          get: () => schema[attribute],
          configurable: true
        });
      }
    }
  };
  var { debounce: debounce3, dispatch: dispatch3, xpathToElement: xpathToElement2, xpathToElementArray: xpathToElementArray2 } = utils;
  var uuidv4 = () => {
    const crypto = window.crypto || window.msCrypto;
    return ("10000000-1000-4000-8000" + -1e11).replace(/[018]/g, (c2) => (c2 ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c2 / 4).toString(16));
  };
  var serializeForm = (form, options = {}) => {
    if (!form) return "";
    const w = options.w || window;
    const { element } = options;
    const formData = new w.FormData(form);
    const data = Array.from(formData, (e) => e.map(encodeURIComponent).join("="));
    const submitButton = form.querySelector("input[type=submit]");
    if (element && element.name && element.nodeName === "INPUT" && element.type === "submit") {
      data.push(`${encodeURIComponent(element.name)}=${encodeURIComponent(element.value)}`);
    } else if (submitButton && submitButton.name) {
      data.push(`${encodeURIComponent(submitButton.name)}=${encodeURIComponent(submitButton.value)}`);
    }
    return Array.from(data).join("&");
  };
  var camelize2 = (value, uppercaseFirstLetter = true) => {
    if (typeof value !== "string") return "";
    value = value.replace(/[\s_](.)/g, ($1) => $1.toUpperCase()).replace(/[\s_]/g, "").replace(/^(.)/, ($1) => $1.toLowerCase());
    if (uppercaseFirstLetter) value = value.substr(0, 1).toUpperCase() + value.substr(1);
    return value;
  };
  var XPathToElement = xpathToElement2;
  var XPathToArray = xpathToElementArray2;
  var emitEvent = (name3, detail = {}) => dispatch3(document, name3, detail);
  var extractReflexName = (reflexString) => {
    const match = reflexString.match(/(?:.*->)?(.*?)(?:Reflex)?#/);
    return match ? match[1] : "";
  };
  var elementToXPath = (element) => {
    if (element.id !== "") return "//*[@id='" + element.id + "']";
    if (element === document.body) return "/html/body";
    if (element.nodeName === "HTML") return "/html";
    let ix = 0;
    const siblings = element && element.parentNode ? element.parentNode.childNodes : [];
    for (var i = 0; i < siblings.length; i++) {
      const sibling = siblings[i];
      if (sibling === element) {
        const computedPath = elementToXPath(element.parentNode);
        const tagName = element.tagName.toLowerCase();
        const ixInc = ix + 1;
        return `${computedPath}/${tagName}[${ixInc}]`;
      }
      if (sibling.nodeType === 1 && sibling.tagName === element.tagName) {
        ix++;
      }
    }
  };
  var elementInvalid = (element) => element.type === "number" && element.validity && element.validity.badInput;
  var getReflexElement = (args, element) => args[0] && args[0].nodeType === Node.ELEMENT_NODE ? args.shift() : element;
  var getReflexOptions = (args) => {
    const options = {};
    if (args[0] && typeof args[0] === "object" && Object.keys(args[0]).filter((key) => ["id", "attrs", "selectors", "reflexId", "resolveLate", "serializeForm", "suppressLogging", "includeInnerHTML", "includeTextContent"].includes(key)).length) {
      const opts = args.shift();
      Object.keys(opts).forEach((o) => {
        if (o === "reflexId") {
          if (Deprecate.enabled) console.warn("reflexId option will be removed in v4. Use id instead.");
          options["id"] = opts["reflexId"];
        } else options[o] = opts[o];
      });
    }
    return options;
  };
  var getReflexRoots = (element) => {
    let list = [];
    while (list.length === 0 && element) {
      let reflexRoot = element.getAttribute(Schema.reflexRoot);
      if (reflexRoot) {
        if (reflexRoot.length === 0 && element.id) reflexRoot = `#${element.id}`;
        const selectors = reflexRoot.split(",").filter((s2) => s2.trim().length);
        if (Debug$1.enabled && selectors.length === 0) {
          console.error(`No value found for ${Schema.reflexRoot}. Add an #id to the element or provide a value for ${Schema.reflexRoot}.`, element);
        }
        list = list.concat(selectors.filter((s2) => document.querySelector(s2)));
      }
      element = element.parentElement ? element.parentElement.closest(`[${Schema.reflexRoot}]`) : null;
    }
    return list;
  };
  var reflexNameToControllerIdentifier = (reflexName) => reflexName.replace(/([a-z0–9])([A-Z])/g, "$1-$2").replace(/(::)/g, "--").replace(/-reflex$/gi, "").toLowerCase();
  var stages = ["created", "before", "delivered", "queued", "after", "finalized", "success", "error", "halted", "forbidden"];
  var lastReflex;
  var reflexes = new Proxy({}, {
    get: function(target, prop) {
      if (stages.includes(prop)) return Object.fromEntries(Object.entries(target).filter(([_, reflex]) => reflex.stage === prop));
      else if (prop === "last") return lastReflex;
      else if (prop === "all") return target;
      return Reflect.get(...arguments);
    },
    set: function(target, prop, value) {
      target[prop] = value;
      lastReflex = value;
      return true;
    }
  });
  var invokeLifecycleMethod = (reflex, stage) => {
    const specificLifecycleMethod = reflex.controller[["before", "after", "finalize"].includes(stage) ? `${stage}${camelize2(reflex.action)}` : `${camelize2(reflex.action, false)}${camelize2(stage)}`];
    const genericLifecycleMethod = reflex.controller[["before", "after", "finalize"].includes(stage) ? `${stage}Reflex` : `reflex${camelize2(stage)}`];
    if (typeof specificLifecycleMethod === "function") {
      specificLifecycleMethod.call(reflex.controller, reflex.element, reflex.target, reflex.error, reflex.id, reflex.payload);
    }
    if (typeof genericLifecycleMethod === "function") {
      genericLifecycleMethod.call(reflex.controller, reflex.element, reflex.target, reflex.error, reflex.id, reflex.payload);
    }
  };
  var dispatchLifecycleEvent = (reflex, stage) => {
    if (!reflex.controller.element.parentElement) {
      if (Debug$1.enabled && !reflex.warned) {
        console.warn(`StimulusReflex was not able execute callbacks or emit events for "${stage}" or later life-cycle stages for this Reflex. The StimulusReflex Controller Element is no longer present in the DOM. Could you move the StimulusReflex Controller to an element higher in your DOM?`);
        reflex.warned = true;
      }
      return;
    }
    reflex.stage = stage;
    reflex.lifecycle.push(stage);
    const event = `stimulus-reflex:${stage}`;
    const action = `${event}:${reflex.action}`;
    const detail = {
      reflex: reflex.target,
      controller: reflex.controller,
      id: reflex.id,
      element: reflex.element,
      payload: reflex.payload
    };
    const options = {
      bubbles: true,
      cancelable: false,
      detail
    };
    reflex.controller.element.dispatchEvent(new CustomEvent(event, options));
    reflex.controller.element.dispatchEvent(new CustomEvent(action, options));
    if (window.jQuery) {
      window.jQuery(reflex.controller.element).trigger(event, detail);
      window.jQuery(reflex.controller.element).trigger(action, detail);
    }
  };
  document.addEventListener("stimulus-reflex:before", (event) => invokeLifecycleMethod(reflexes[event.detail.id], "before"), true);
  document.addEventListener("stimulus-reflex:queued", (event) => invokeLifecycleMethod(reflexes[event.detail.id], "queued"), true);
  document.addEventListener("stimulus-reflex:delivered", (event) => invokeLifecycleMethod(reflexes[event.detail.id], "delivered"), true);
  document.addEventListener("stimulus-reflex:success", (event) => {
    const reflex = reflexes[event.detail.id];
    invokeLifecycleMethod(reflex, "success");
    dispatchLifecycleEvent(reflex, "after");
  }, true);
  document.addEventListener("stimulus-reflex:nothing", (event) => dispatchLifecycleEvent(reflexes[event.detail.id], "success"), true);
  document.addEventListener("stimulus-reflex:error", (event) => {
    const reflex = reflexes[event.detail.id];
    invokeLifecycleMethod(reflex, "error");
    dispatchLifecycleEvent(reflex, "after");
  }, true);
  document.addEventListener("stimulus-reflex:halted", (event) => invokeLifecycleMethod(reflexes[event.detail.id], "halted"), true);
  document.addEventListener("stimulus-reflex:forbidden", (event) => invokeLifecycleMethod(reflexes[event.detail.id], "forbidden"), true);
  document.addEventListener("stimulus-reflex:after", (event) => invokeLifecycleMethod(reflexes[event.detail.id], "after"), true);
  document.addEventListener("stimulus-reflex:finalize", (event) => invokeLifecycleMethod(reflexes[event.detail.id], "finalize"), true);
  var app = {};
  var App = {
    get app() {
      return app;
    },
    set(application2) {
      app = application2;
    }
  };
  var isolationMode = false;
  var IsolationMode = {
    get disabled() {
      return !isolationMode;
    },
    set(value) {
      isolationMode = value;
      if (Deprecate.enabled && !isolationMode) {
        document.addEventListener("DOMContentLoaded", () => console.warn("Deprecation warning: the next version of StimulusReflex will standardize isolation mode, and the isolate option will be removed.\nPlease update your applications to assume that every tab will be isolated. Use CableReady operations to broadcast updates to other tabs and users."), {
          once: true
        });
      }
    }
  };
  var Reflex = class {
    constructor(data, controller) {
      this.data = data.valueOf();
      this.controller = controller;
      this.element = data.reflexElement;
      this.id = data.id;
      this.error = null;
      this.payload = null;
      this.stage = "created";
      this.lifecycle = ["created"];
      this.warned = false;
      this.target = data.target;
      this.action = data.target.split("#")[1];
      this.selector = null;
      this.morph = null;
      this.operation = null;
      this.timestamp = /* @__PURE__ */ new Date();
      this.cloned = false;
    }
    get getPromise() {
      const promise = new Promise((resolve, reject) => {
        this.promise = {
          resolve,
          reject,
          data: this.data
        };
      });
      promise.id = this.id;
      Object.defineProperty(promise, "reflexId", {
        get() {
          if (Deprecate.enabled) console.warn("reflexId is deprecated and will be removed from v4. Use id instead.");
          return this.id;
        }
      });
      promise.reflex = this;
      if (Debug$1.enabled) promise.catch(() => {
      });
      return promise;
    }
  };
  var received = (data) => {
    if (!data.cableReady) return;
    if (data.version.replace(".pre", "-pre").replace(".rc", "-rc") !== global2.version) {
      const mismatch = `CableReady failed to execute your reflex action due to a version mismatch between your gem and JavaScript version. Package versions must match exactly.

cable_ready gem: ${data.version}
cable_ready npm: ${global2.version}`;
      console.error(mismatch);
      if (Debug$1.enabled) {
        global2.operations.stimulusReflexVersionMismatch({
          text: mismatch,
          level: "error"
        });
      }
      return;
    }
    let reflexOperations = [];
    for (let i = data.operations.length - 1; i >= 0; i--) {
      if (data.operations[i].stimulusReflex) {
        reflexOperations.push(data.operations[i]);
        data.operations.splice(i, 1);
      }
    }
    if (reflexOperations.some((operation) => operation.stimulusReflex.url !== location.href)) {
      if (Debug$1.enabled) {
        console.error("Reflex failed due to mismatched URL.");
        return;
      }
    }
    let reflexData;
    if (reflexOperations.length) {
      reflexData = reflexOperations[0].stimulusReflex;
      reflexData.payload = reflexOperations[0].payload;
    }
    if (reflexData) {
      const { id, payload } = reflexData;
      let reflex;
      if (!reflexes[id] && IsolationMode.disabled) {
        const controllerElement = XPathToElement(reflexData.xpathController);
        const reflexElement = XPathToElement(reflexData.xpathElement);
        controllerElement.reflexController = controllerElement.reflexController || {};
        controllerElement.reflexData = controllerElement.reflexData || {};
        controllerElement.reflexError = controllerElement.reflexError || {};
        const controller = App.app.getControllerForElementAndIdentifier(controllerElement, reflexData.reflexController);
        controllerElement.reflexController[id] = controller;
        controllerElement.reflexData[id] = reflexData;
        reflex = new Reflex(reflexData, controller);
        reflexes[id] = reflex;
        reflex.cloned = true;
        reflex.element = reflexElement;
        controller.lastReflex = reflex;
        dispatchLifecycleEvent(reflex, "before");
        reflex.getPromise;
      } else {
        reflex = reflexes[id];
      }
      if (reflex) {
        reflex.payload = payload;
        reflex.totalOperations = reflexOperations.length;
        reflex.pendingOperations = reflexOperations.length;
        reflex.completedOperations = 0;
        reflex.piggybackOperations = data.operations;
        global2.perform(reflexOperations);
      }
    } else {
      if (data.operations.length && reflexes[data.operations[0].reflexId]) {
        global2.perform(data.operations);
      }
    }
  };
  var consumer4;
  var params;
  var subscription;
  var active;
  var initialize$1 = (consumerValue, paramsValue) => {
    consumer4 = consumerValue;
    params = paramsValue;
    document.addEventListener("DOMContentLoaded", () => {
      active = false;
      connectionStatusClass();
      if (Deprecate.enabled && consumerValue) console.warn("Deprecation warning: the next version of StimulusReflex will obtain a reference to consumer via the Stimulus application object.\nPlease add 'application.consumer = consumer' to your index.js after your Stimulus application has been established, and remove the consumer key from your StimulusReflex initialize() options object.");
    });
    document.addEventListener("turbolinks:load", connectionStatusClass);
    document.addEventListener("turbo:load", connectionStatusClass);
  };
  var subscribe = (controller) => {
    if (subscription) return;
    consumer4 = consumer4 || controller.application.consumer || createConsumer4();
    const { channel } = controller.StimulusReflex;
    const request3 = {
      channel,
      ...params
    };
    const identifier = JSON.stringify(request3);
    subscription = consumer4.subscriptions.findAll(identifier)[0] || consumer4.subscriptions.create(request3, {
      received,
      connected,
      rejected,
      disconnected
    });
  };
  var connected = () => {
    active = true;
    connectionStatusClass();
    emitEvent("stimulus-reflex:connected");
    Object.values(reflexes.queued).forEach((reflex) => {
      subscription.send(reflex.data);
      dispatchLifecycleEvent(reflex, "delivered");
    });
  };
  var rejected = () => {
    active = false;
    connectionStatusClass();
    emitEvent("stimulus-reflex:rejected");
    if (Debug.enabled) console.warn("Channel subscription was rejected.");
  };
  var disconnected = (willAttemptReconnect) => {
    active = false;
    connectionStatusClass();
    emitEvent("stimulus-reflex:disconnected", willAttemptReconnect);
  };
  var deliver = (reflex) => {
    if (active) {
      subscription.send(reflex.data);
      dispatchLifecycleEvent(reflex, "delivered");
    } else dispatchLifecycleEvent(reflex, "queued");
  };
  var connectionStatusClass = () => {
    const list = document.body.classList;
    if (!(list.contains("stimulus-reflex-connected") || list.contains("stimulus-reflex-disconnected"))) {
      list.add(active ? "stimulus-reflex-connected" : "stimulus-reflex-disconnected");
      return;
    }
    if (active) {
      list.replace("stimulus-reflex-disconnected", "stimulus-reflex-connected");
    } else {
      list.replace("stimulus-reflex-connected", "stimulus-reflex-disconnected");
    }
  };
  var ActionCableTransport = {
    subscribe,
    deliver,
    initialize: initialize$1
  };
  var request2 = (reflex) => {
    if (Debug$1.disabled || reflex.data.suppressLogging) return;
    console.log(`\u2191 stimulus \u2191 ${reflex.target}`, {
      id: reflex.id,
      args: reflex.data.args,
      controller: reflex.controller.identifier,
      element: reflex.element,
      controllerElement: reflex.controller.element
    });
  };
  var success = (reflex) => {
    if (Debug$1.disabled || reflex.data.suppressLogging) return;
    const output = {
      id: reflex.id,
      morph: reflex.morph,
      payload: reflex.payload
    };
    if (reflex.operation !== "dispatch_event") output.operation = reflex.operation;
    console.log(`\u2193 reflex \u2193 ${reflex.target} \u2192 ${reflex.selector || "\u221E"}${progress(reflex)} ${duration(reflex)}`, output);
  };
  var halted$1 = (reflex) => {
    if (Debug$1.disabled || reflex.data.suppressLogging) return;
    console.log(`\u2193 reflex \u2193 ${reflex.target} ${duration(reflex)} %cHALTED`, "color: #ffa500;", {
      id: reflex.id,
      payload: reflex.payload
    });
  };
  var forbidden$1 = (reflex) => {
    if (Debug$1.disabled || reflex.data.suppressLogging) return;
    console.log(`\u2193 reflex \u2193 ${reflex.target} ${duration(reflex)} %cFORBIDDEN`, "color: #BF40BF;", {
      id: reflex.id,
      payload: reflex.payload
    });
  };
  var error$1 = (reflex) => {
    if (Debug$1.disabled || reflex.data.suppressLogging) return;
    console.log(`\u2193 reflex \u2193 ${reflex.target} ${duration(reflex)} %cERROR: ${reflex.error}`, "color: #f00;", {
      id: reflex.id,
      payload: reflex.payload
    });
  };
  var duration = (reflex) => !reflex.cloned ? `in ${/* @__PURE__ */ new Date() - reflex.timestamp}ms` : "CLONED";
  var progress = (reflex) => reflex.totalOperations > 1 ? ` ${reflex.completedOperations}/${reflex.totalOperations}` : "";
  var Log2 = {
    request: request2,
    success,
    halted: halted$1,
    forbidden: forbidden$1,
    error: error$1
  };
  var multipleInstances = (element) => {
    if (["checkbox", "radio"].includes(element.type)) {
      return document.querySelectorAll(`input[type="${element.type}"][name="${element.name}"]`).length > 1;
    }
    return false;
  };
  var collectCheckedOptions = (element) => Array.from(element.querySelectorAll("option:checked")).concat(Array.from(document.querySelectorAll(`input[type="${element.type}"][name="${element.name}"]`)).filter((elem) => elem.checked)).map((o) => o.value);
  var attributeValue = (values = []) => {
    const value = Array.from(new Set(values.filter((v2) => v2 && String(v2).length).map((v2) => v2.trim()))).join(" ").trim();
    return value.length > 0 ? value : null;
  };
  var attributeValues = (value) => {
    if (!value) return [];
    if (!value.length) return [];
    return value.split(" ").filter((v2) => v2.trim().length);
  };
  var extractElementAttributes = (element) => {
    let attrs = Array.from(element.attributes).reduce((memo, attr) => {
      memo[attr.name] = attr.value;
      return memo;
    }, {});
    attrs.checked = !!element.checked;
    attrs.selected = !!element.selected;
    attrs.tag_name = element.tagName;
    if (element.tagName.match(/select/i) || multipleInstances(element)) {
      const collectedOptions = collectCheckedOptions(element);
      attrs.values = collectedOptions;
      attrs.value = collectedOptions.join(",");
    } else {
      attrs.value = element.value;
    }
    return attrs;
  };
  var getElementsFromTokens = (element, tokens) => {
    if (!tokens || tokens.length === 0) return [];
    let elements = [element];
    const xPath = elementToXPath(element);
    tokens.forEach((token) => {
      try {
        switch (token) {
          case "combined":
            if (Deprecate.enabled) console.warn("In the next version of StimulusReflex, the 'combined' option to data-reflex-dataset will become 'ancestors'.");
            elements = [...elements, ...XPathToArray(`${xPath}/ancestor::*`, true)];
            break;
          case "ancestors":
            elements = [...elements, ...XPathToArray(`${xPath}/ancestor::*`, true)];
            break;
          case "parent":
            elements = [...elements, ...XPathToArray(`${xPath}/parent::*`)];
            break;
          case "siblings":
            elements = [...elements, ...XPathToArray(`${xPath}/preceding-sibling::*|${xPath}/following-sibling::*`)];
            break;
          case "children":
            elements = [...elements, ...XPathToArray(`${xPath}/child::*`)];
            break;
          case "descendants":
            elements = [...elements, ...XPathToArray(`${xPath}/descendant::*`)];
            break;
          default:
            elements = [...elements, ...document.querySelectorAll(token)];
        }
      } catch (error3) {
        if (Debug$1.enabled) console.error(error3);
      }
    });
    return elements;
  };
  var extractElementDataset = (element) => {
    const dataset = element.attributes[Schema.reflexDataset];
    const allDataset = element.attributes[Schema.reflexDatasetAll];
    const tokens = dataset && dataset.value.split(" ") || [];
    const allTokens = allDataset && allDataset.value.split(" ") || [];
    const datasetElements = getElementsFromTokens(element, tokens);
    const datasetAllElements = getElementsFromTokens(element, allTokens);
    const datasetAttributes = datasetElements.reduce((acc, ele) => ({
      ...extractDataAttributes(ele),
      ...acc
    }), {});
    const reflexElementAttributes = extractDataAttributes(element);
    const elementDataset = {
      dataset: {
        ...reflexElementAttributes,
        ...datasetAttributes
      },
      datasetAll: {}
    };
    datasetAllElements.forEach((element2) => {
      const elementAttributes = extractDataAttributes(element2);
      Object.keys(elementAttributes).forEach((key) => {
        const value = elementAttributes[key];
        if (elementDataset.datasetAll[key] && Array.isArray(elementDataset.datasetAll[key])) {
          elementDataset.datasetAll[key].push(value);
        } else {
          elementDataset.datasetAll[key] = [value];
        }
      });
    });
    return elementDataset;
  };
  var extractDataAttributes = (element) => {
    let attrs = {};
    if (element && element.attributes) {
      Array.from(element.attributes).forEach((attr) => {
        if (attr.name.startsWith("data-")) {
          attrs[attr.name] = attr.value;
        }
      });
    }
    return attrs;
  };
  var name2 = "stimulus_reflex";
  var version2 = "3.5.3";
  var description2 = "Build reactive applications with the Rails tooling you already know and love.";
  var keywords2 = ["ruby", "rails", "websockets", "actioncable", "turbolinks", "reactive", "cable", "ujs", "ssr", "stimulus", "reflex", "stimulus_reflex", "dom", "morphdom"];
  var homepage2 = "https://docs.stimulusreflex.com";
  var bugs2 = "https://github.com/stimulusreflex/stimulus_reflex/issues";
  var repository2 = "https://github.com/stimulusreflex/stimulus_reflex";
  var license2 = "MIT";
  var author2 = "Nathan Hopkins <natehop@gmail.com>";
  var contributors2 = ["Andrew Mason <andrewmcodes@protonmail.com>", "Julian Rubisch <julian@julianrubisch.at>", "Marco Roth <marco.roth@intergga.ch>", "Nathan Hopkins <natehop@gmail.com>"];
  var main2 = "./dist/stimulus_reflex.js";
  var module2 = "./dist/stimulus_reflex.js";
  var browser2 = "./dist/stimulus_reflex.js";
  var unpkg2 = "./dist/stimulus_reflex.umd.js";
  var umd2 = "./dist/stimulus_reflex.umd.js";
  var files2 = ["dist/*", "javascript/*"];
  var scripts2 = {
    lint: "yarn run format --check",
    format: "yarn run prettier-standard ./javascript/**/*.js rollup.config.mjs",
    build: "yarn rollup -c",
    "build:watch": "yarn rollup -wc",
    watch: "yarn build:watch",
    test: "web-test-runner javascript/test/**/*.test.js",
    "test:watch": "yarn test --watch",
    "docs:dev": "vitepress dev docs",
    "docs:build": "vitepress build docs && cp docs/_redirects docs/.vitepress/dist",
    "docs:preview": "vitepress preview docs"
  };
  var peerDependencies = {
    "@hotwired/stimulus": ">= 3.0"
  };
  var dependencies2 = {
    "@hotwired/stimulus": "^3",
    "@rails/actioncable": "^6 || ^7",
    cable_ready: "^5.0.6"
  };
  var devDependencies2 = {
    "@open-wc/testing": "^4.0.0",
    "@rollup/plugin-json": "^6.1.0",
    "@rollup/plugin-node-resolve": "^15.3.0",
    "@rollup/plugin-terser": "^0.4.4",
    "@web/dev-server-esbuild": "^1.0.2",
    "@web/dev-server-rollup": "^0.6.4",
    "@web/test-runner": "^0.19.0",
    "prettier-standard": "^16.4.1",
    rollup: "^4.22.4",
    "toastify-js": "^1.12.0",
    vitepress: "^1.0.0-beta.1"
  };
  var packageInfo2 = {
    name: name2,
    version: version2,
    description: description2,
    keywords: keywords2,
    homepage: homepage2,
    bugs: bugs2,
    repository: repository2,
    license: license2,
    author: author2,
    contributors: contributors2,
    main: main2,
    module: module2,
    browser: browser2,
    import: "./dist/stimulus_reflex.js",
    unpkg: unpkg2,
    umd: umd2,
    files: files2,
    scripts: scripts2,
    peerDependencies,
    dependencies: dependencies2,
    devDependencies: devDependencies2
  };
  var ReflexData = class {
    constructor(options, reflexElement, controllerElement, reflexController, permanentAttributeName, target, args, url, tabId2) {
      this.options = options;
      this.reflexElement = reflexElement;
      this.controllerElement = controllerElement;
      this.reflexController = reflexController;
      this.permanentAttributeName = permanentAttributeName;
      this.target = target;
      this.args = args;
      this.url = url;
      this.tabId = tabId2;
    }
    get attrs() {
      this._attrs = this._attrs || this.options["attrs"] || extractElementAttributes(this.reflexElement);
      return this._attrs;
    }
    get id() {
      this._id = this._id || this.options["id"] || uuidv4();
      return this._id;
    }
    get selectors() {
      this._selectors = this._selectors || this.options["selectors"] || getReflexRoots(this.reflexElement);
      return typeof this._selectors === "string" ? [this._selectors] : this._selectors;
    }
    get resolveLate() {
      return this.options["resolveLate"] || false;
    }
    get dataset() {
      this._dataset = this._dataset || extractElementDataset(this.reflexElement);
      return this._dataset;
    }
    get innerHTML() {
      return this.includeInnerHtml ? this.reflexElement.innerHTML : "";
    }
    get textContent() {
      return this.includeTextContent ? this.reflexElement.textContent : "";
    }
    get xpathController() {
      return elementToXPath(this.controllerElement);
    }
    get xpathElement() {
      return elementToXPath(this.reflexElement);
    }
    get formSelector() {
      const attr = this.reflexElement.attributes[Schema.reflexFormSelector] ? this.reflexElement.attributes[Schema.reflexFormSelector].value : void 0;
      return this.options["formSelector"] || attr;
    }
    get includeInnerHtml() {
      const attr = this.reflexElement.attributes[Schema.reflexIncludeInnerHtml] || false;
      return this.options["includeInnerHTML"] || attr ? attr.value !== "false" : false;
    }
    get includeTextContent() {
      const attr = this.reflexElement.attributes[Schema.reflexIncludeTextContent] || false;
      return this.options["includeTextContent"] || attr ? attr.value !== "false" : false;
    }
    get suppressLogging() {
      return this.options["suppressLogging"] || this.reflexElement.attributes[Schema.reflexSuppressLogging] || false;
    }
    valueOf() {
      return {
        attrs: this.attrs,
        dataset: this.dataset,
        selectors: this.selectors,
        id: this.id,
        resolveLate: this.resolveLate,
        suppressLogging: this.suppressLogging,
        xpathController: this.xpathController,
        xpathElement: this.xpathElement,
        inner_html: this.innerHTML,
        text_content: this.textContent,
        formSelector: this.formSelector,
        reflexController: this.reflexController,
        permanentAttributeName: this.permanentAttributeName,
        target: this.target,
        args: this.args,
        url: this.url,
        tabId: this.tabId,
        version: packageInfo2.version
      };
    }
  };
  var transport = {};
  var Transport = {
    get plugin() {
      return transport;
    },
    set(newTransport) {
      transport = newTransport;
    }
  };
  var beforeDOMUpdate = (event) => {
    const { stimulusReflex } = event.detail || {};
    if (!stimulusReflex) return;
    const reflex = reflexes[stimulusReflex.id];
    reflex.pendingOperations--;
    if (reflex.pendingOperations > 0) return;
    if (!stimulusReflex.resolveLate) setTimeout(() => reflex.promise.resolve({
      element: reflex.element,
      event,
      data: reflex.data,
      payload: reflex.payload,
      id: reflex.id,
      toString: () => ""
    }));
    setTimeout(() => dispatchLifecycleEvent(reflex, "success"));
  };
  var afterDOMUpdate = (event) => {
    const { stimulusReflex } = event.detail || {};
    if (!stimulusReflex) return;
    const reflex = reflexes[stimulusReflex.id];
    reflex.completedOperations++;
    reflex.selector = event.detail.selector;
    reflex.morph = event.detail.stimulusReflex.morph;
    reflex.operation = event.type.split(":")[1].split("-").slice(1).join("_");
    Log2.success(reflex);
    if (reflex.completedOperations < reflex.totalOperations) return;
    if (stimulusReflex.resolveLate) setTimeout(() => reflex.promise.resolve({
      element: reflex.element,
      event,
      data: reflex.data,
      payload: reflex.payload,
      id: reflex.id,
      toString: () => ""
    }));
    setTimeout(() => dispatchLifecycleEvent(reflex, "finalize"));
    if (reflex.piggybackOperations.length) global2.perform(reflex.piggybackOperations);
  };
  var routeReflexEvent = (event) => {
    const { stimulusReflex, name: name3 } = event.detail || {};
    const eventType = name3.split("-")[2];
    const eventTypes = {
      nothing,
      halted,
      forbidden,
      error: error2
    };
    if (!stimulusReflex || !Object.keys(eventTypes).includes(eventType)) return;
    const reflex = reflexes[stimulusReflex.id];
    reflex.completedOperations++;
    reflex.pendingOperations--;
    reflex.selector = event.detail.selector;
    reflex.morph = event.detail.stimulusReflex.morph;
    reflex.operation = event.type.split(":")[1].split("-").slice(1).join("_");
    if (eventType === "error") reflex.error = event.detail.error;
    eventTypes[eventType](reflex, event);
    setTimeout(() => dispatchLifecycleEvent(reflex, eventType));
    if (reflex.piggybackOperations.length) global2.perform(reflex.piggybackOperations);
  };
  var nothing = (reflex, event) => {
    Log2.success(reflex);
    setTimeout(() => reflex.promise.resolve({
      data: reflex.data,
      element: reflex.element,
      event,
      payload: reflex.payload,
      id: reflex.id,
      toString: () => ""
    }));
  };
  var halted = (reflex, event) => {
    Log2.halted(reflex, event);
    setTimeout(() => reflex.promise.resolve({
      data: reflex.data,
      element: reflex.element,
      event,
      payload: reflex.payload,
      id: reflex.id,
      toString: () => ""
    }));
  };
  var forbidden = (reflex, event) => {
    Log2.forbidden(reflex, event);
    setTimeout(() => reflex.promise.resolve({
      data: reflex.data,
      element: reflex.element,
      event,
      payload: reflex.payload,
      id: reflex.id,
      toString: () => ""
    }));
  };
  var error2 = (reflex, event) => {
    Log2.error(reflex, event);
    setTimeout(() => reflex.promise.reject({
      data: reflex.data,
      element: reflex.element,
      event,
      payload: reflex.payload,
      id: reflex.id,
      error: reflex.error,
      toString: () => reflex.error
    }));
  };
  var localReflexControllers = (element) => {
    const potentialIdentifiers = attributeValues(element.getAttribute(Schema.controller));
    const potentialControllers = potentialIdentifiers.map((identifier) => App.app.getControllerForElementAndIdentifier(element, identifier));
    return potentialControllers.filter((controller) => controller && controller.StimulusReflex);
  };
  var allReflexControllers = (element) => {
    let controllers = [];
    while (element) {
      controllers = controllers.concat(localReflexControllers(element));
      element = element.parentElement;
    }
    return controllers;
  };
  var findControllerByReflexName = (reflexName, controllers) => {
    const controller = controllers.find((controller2) => {
      if (!controller2 || !controller2.identifier) return;
      const identifier = reflexNameToControllerIdentifier(extractReflexName(reflexName));
      return identifier === controller2.identifier;
    });
    return controller;
  };
  var scanForReflexes = debounce3(() => {
    const reflexElements = document.querySelectorAll(`[${Schema.reflex}]`);
    reflexElements.forEach((element) => scanForReflexesOnElement(element));
  }, 20);
  var scanForReflexesOnElement = (element, controller = null) => {
    const controllerAttribute = element.getAttribute(Schema.controller);
    const controllers = attributeValues(controllerAttribute).filter((controller2) => controller2 !== "stimulus-reflex");
    const reflexAttribute = element.getAttribute(Schema.reflex);
    const reflexAttributeNames = attributeValues(reflexAttribute);
    const actionAttribute = element.getAttribute(Schema.action);
    const actions = attributeValues(actionAttribute).filter((action) => !action.includes("#__perform"));
    reflexAttributeNames.forEach((reflexName) => {
      const potentialControllers = [controller].concat(allReflexControllers(element));
      controller = findControllerByReflexName(reflexName, potentialControllers);
      const controllerName = controller ? controller.identifier : "stimulus-reflex";
      actions.push(`${reflexName.split("->")[0]}->${controllerName}#__perform`);
      const parentControllerElement = element.closest(`[data-controller~=${controllerName}]`);
      const elementPreviouslyHadStimulusReflexController = element === parentControllerElement && controllerName === "stimulus-reflex";
      if (!parentControllerElement || elementPreviouslyHadStimulusReflexController) {
        controllers.push(controllerName);
      }
    });
    const controllerValue = attributeValue(controllers);
    const actionValue = attributeValue(actions);
    let emitReadyEvent = false;
    if (controllerValue && element.getAttribute(Schema.controller) != controllerValue) {
      element.setAttribute(Schema.controller, controllerValue);
      emitReadyEvent = true;
    }
    if (actionValue && element.getAttribute(Schema.action) != actionValue) {
      element.setAttribute(Schema.action, actionValue);
      emitReadyEvent = true;
    }
    if (emitReadyEvent) {
      dispatch3(element, "stimulus-reflex:ready", {
        reflex: reflexAttribute,
        controller: controllerValue,
        action: actionValue,
        element
      });
    }
  };
  var StimulusReflexController = class extends Controller {
    constructor(...args) {
      super(...args);
      register(this);
    }
  };
  var tabId = uuidv4();
  var initialize2 = (application2, { controller, consumer: consumer5, debug, params: params2, isolate, deprecate, transport: transport2 } = {}) => {
    Transport.set(transport2 || ActionCableTransport);
    Transport.plugin.initialize(consumer5, params2);
    IsolationMode.set(!!isolate);
    App.set(application2);
    Schema.set(application2);
    App.app.register("stimulus-reflex", controller || StimulusReflexController);
    Debug$1.set(!!debug);
    if (typeof deprecate !== "undefined") Deprecate.set(deprecate);
    const observer = new MutationObserver(scanForReflexes);
    observer.observe(document.documentElement, {
      attributeFilter: [Schema.reflex, Schema.action],
      childList: true,
      subtree: true
    });
    emitEvent("stimulus-reflex:initialized");
  };
  var register = (controller, options = {}) => {
    const channel = "StimulusReflex::Channel";
    controller.StimulusReflex = {
      ...options,
      channel
    };
    Transport.plugin.subscribe(controller);
    Object.assign(controller, {
      stimulate() {
        const url = location.href;
        const controllerElement = this.element;
        const args = Array.from(arguments);
        const target = args.shift() || "StimulusReflex::Reflex#default_reflex";
        const reflexElement = getReflexElement(args, controllerElement);
        if (elementInvalid(reflexElement)) {
          if (Debug$1.enabled) console.warn("Reflex aborted: invalid numeric input");
          return;
        }
        const options2 = getReflexOptions(args);
        const reflexData = new ReflexData(options2, reflexElement, controllerElement, this.identifier, Schema.reflexPermanent, target, args, url, tabId);
        const id = reflexData.id;
        controllerElement.reflexController = controllerElement.reflexController || {};
        controllerElement.reflexData = controllerElement.reflexData || {};
        controllerElement.reflexError = controllerElement.reflexError || {};
        controllerElement.reflexController[id] = this;
        controllerElement.reflexData[id] = reflexData.valueOf();
        const reflex = new Reflex(reflexData, this);
        reflexes[id] = reflex;
        this.lastReflex = reflex;
        dispatchLifecycleEvent(reflex, "before");
        setTimeout(() => {
          const { params: params2 } = controllerElement.reflexData[id] || {};
          const check = reflexElement.attributes[Schema.reflexSerializeForm];
          if (check) {
            options2["serializeForm"] = check.value !== "false";
          }
          const form = reflexElement.closest(reflexData.formSelector) || document.querySelector(reflexData.formSelector) || reflexElement.closest("form");
          if (Deprecate.enabled && options2["serializeForm"] === void 0 && form) console.warn(`Deprecation warning: the next version of StimulusReflex will not serialize forms by default.
Please set ${Schema.reflexSerializeForm}="true" on your Reflex Controller Element or pass { serializeForm: true } as an option to stimulate.`);
          const formData = options2["serializeForm"] === false ? "" : serializeForm(form, {
            element: reflexElement
          });
          reflex.data = {
            ...reflexData.valueOf(),
            params: params2,
            formData
          };
          controllerElement.reflexData[id] = reflex.data;
          Transport.plugin.deliver(reflex);
        });
        Log2.request(reflex);
        return reflex.getPromise;
      },
      __perform(event) {
        let element = event.target;
        let reflex;
        while (element && !reflex) {
          reflex = element.getAttribute(Schema.reflex);
          if (!reflex || !reflex.trim().length) element = element.parentElement;
        }
        const match = attributeValues(reflex).find((reflex2) => reflex2.split("->")[0] === event.type);
        if (match) {
          event.preventDefault();
          event.stopPropagation();
          this.stimulate(match.split("->")[1], element);
        }
      }
    });
    if (!controller.reflexes) Object.defineProperty(controller, "reflexes", {
      get() {
        return new Proxy(reflexes, {
          get: function(target, prop) {
            if (prop === "last") return this.lastReflex;
            return Object.fromEntries(Object.entries(target[prop]).filter(([_, reflex]) => reflex.controller === this));
          }.bind(this)
        });
      }
    });
    scanForReflexesOnElement(controller.element, controller);
    emitEvent("stimulus-reflex:controller-registered", {
      detail: {
        controller
      }
    });
  };
  var useReflex = (controller, options = {}) => {
    register(controller, options);
  };
  document.addEventListener("cable-ready:after-dispatch-event", routeReflexEvent);
  document.addEventListener("cable-ready:before-inner-html", beforeDOMUpdate);
  document.addEventListener("cable-ready:before-morph", beforeDOMUpdate);
  document.addEventListener("cable-ready:after-inner-html", afterDOMUpdate);
  document.addEventListener("cable-ready:after-morph", afterDOMUpdate);
  document.addEventListener("readystatechange", () => {
    if (document.readyState === "complete") {
      scanForReflexes();
    }
  });
  var StimulusReflex2 = Object.freeze({
    __proto__: null,
    StimulusReflexController,
    initialize: initialize2,
    reflexes,
    register,
    scanForReflexes,
    scanForReflexesOnElement,
    useReflex
  });
  var global3 = {
    version: packageInfo2.version,
    ...StimulusReflex2,
    get debug() {
      return Debug$1.value;
    },
    set debug(value) {
      Debug$1.set(!!value);
    },
    get deprecate() {
      return Deprecate.value;
    },
    set deprecate(value) {
      Deprecate.set(!!value);
    }
  };
  window.StimulusReflex = global3;

  // controllers/application_controller.js
  var application_controller_default = class extends Controller {
    connect() {
      global3.register(this);
    }
    /* Application-wide lifecycle methods
     *
     * Use these methods to handle lifecycle concerns for the entire application.
     * Using the lifecycle is optional, so feel free to delete these stubs if you don't need them.
     *
     * Arguments:
     *
     *   element - the element that triggered the reflex
     *             may be different than the Stimulus controller's this.element
     *
     *   reflex - the name of the reflex e.g. "Example#demo"
     *
     *   error/noop - the error message (for reflexError), otherwise null
     *
     *   id - a UUID4 or developer-provided unique identifier for each Reflex
     */
    beforeReflex(element, reflex, noop2, id) {
    }
    reflexQueued(element, reflex, noop2, id) {
    }
    reflexDelivered(element, reflex, noop2, id) {
    }
    reflexSuccess(element, reflex, noop2, id) {
    }
    reflexError(element, reflex, error3, id) {
    }
    reflexForbidden(element, reflex, noop2, id) {
    }
    reflexHalted(element, reflex, noop2, id) {
    }
    afterReflex(element, reflex, noop2, id) {
    }
    finalizeReflex(element, reflex, noop2, id) {
    }
  };

  // controllers/clipboard_controller.js
  var clipboard_controller_exports = {};
  __export(clipboard_controller_exports, {
    default: () => clipboard_controller_default
  });
  var import_clipboard = __toESM(require_clipboard());
  var clipboard_controller_default = class extends Controller {
    connect() {
      this.clipboard = new import_clipboard.default(this.element);
      this.clipboard.on("success", (e) => {
        const originalText = e.trigger.textContent;
        const successContent = this.element.dataset.clipboardSuccessContent || "Copied!";
        e.trigger.textContent = successContent;
        setTimeout(() => {
          e.trigger.textContent = originalText;
        }, 2e3);
        e.clearSelection();
      });
      this.clipboard.on("error", (e) => {
        console.error("Clipboard error:", e.action);
      });
    }
    disconnect() {
      if (this.clipboard) {
        this.clipboard.destroy();
      }
    }
  };

  // controllers/counter_controller.js
  var counter_controller_exports = {};
  __export(counter_controller_exports, {
    default: () => counter_controller_default
  });
  var counter_controller_default = class extends Controller {
    static targets = ["output"];
    connect() {
      this.count = 0;
    }
    increment() {
      this.count += 1;
      this.outputTarget.textContent = `You have clicked ${this.count} times.`;
    }
  };

  // controllers/dark_mode_controller.js
  var dark_mode_controller_exports = {};
  __export(dark_mode_controller_exports, {
    default: () => dark_mode_controller_default
  });
  var dark_mode_controller_default = class extends Controller {
    toggle() {
      document.documentElement.classList.toggle("dark");
    }
  };

  // controllers/dropdown_controller.js
  var dropdown_controller_exports = {};
  __export(dropdown_controller_exports, {
    default: () => dropdown_controller_default
  });
  var dropdown_controller_default = class extends Controller {
    static targets = ["menu", "button"];
    connect() {
      document.addEventListener("click", this.handleClickOutside.bind(this));
    }
    disconnect() {
      document.removeEventListener("click", this.handleClickOutside.bind(this));
    }
    toggle(event) {
      event.stopPropagation();
      this.menuTarget.classList.toggle("hidden");
    }
    handleClickOutside(event) {
      if (!this.element.contains(event.target)) {
        this.menuTarget.classList.add("hidden");
      }
    }
  };

  // controllers/example_controller.js
  var example_controller_exports = {};
  __export(example_controller_exports, {
    default: () => example_controller_default
  });
  var example_controller_default = class extends application_controller_default {
    pageup(event) {
      event.preventDefault();
      this.stimulate("TableMonitor#key_a");
      console.log(this.event);
      event.stopPropagation();
    }
    pagedown() {
      this.stimulate("TableMonitor#key_b");
    }
    b() {
      this.stimulate("TableMonitor#key_c");
    }
    esc() {
      this.stimulate("TableMonitor#key_d");
    }
  };

  // controllers/filter_popup_controller.js
  var filter_popup_controller_exports = {};
  __export(filter_popup_controller_exports, {
    default: () => filter_popup_controller_default
  });
  var filter_popup_controller_default = class extends application_controller_default {
    static targets = ["popup", "searchInput", "filterForm"];
    connect() {
      console.log("\u{1F527} FilterPopupController connected - DEBUG VERSION");
      console.log("Targets:", {
        popup: this.hasPopupTarget,
        searchInput: this.hasSearchInputTarget,
        filterForm: this.hasFilterFormTarget
      });
      if (!this.hasPopupTarget) {
        console.error("Missing popup target");
      }
      if (!this.hasSearchInputTarget) {
        console.error("Missing searchInput target");
      }
      if (!this.hasFilterFormTarget) {
        console.error("Missing filterForm target");
      }
      document.addEventListener("click", this.handleClickOutside.bind(this));
      this.loadRecentSelections();
    }
    disconnect() {
      console.log("FilterPopupController disconnected");
      document.removeEventListener("click", this.handleClickOutside.bind(this));
    }
    toggle() {
      console.log("\u{1F3AF} Toggle method called - DEBUG");
      const wasHidden = this.popupTarget.classList.contains("hidden");
      this.popupTarget.classList.toggle("hidden");
      if (!this.popupTarget.classList.contains("hidden")) {
        console.log("\u{1F3AF} Popup is now visible, loading recent selections...");
        this.loadRecentSelections();
        console.log("\u{1F3AF} About to call restoreCurrentSearchState...");
        this.restoreCurrentSearchState();
      }
    }
    close() {
      try {
        this.popupTarget.classList.add("hidden");
      } catch (error3) {
        console.error("Error in close method:", error3);
      }
    }
    handleClickOutside(event) {
      if (!this.element.contains(event.target)) {
        this.close();
      }
    }
    clearFilters(event) {
      event.preventDefault();
      console.log("Clearing filters");
      this.filterFormTarget.reset();
      this.searchInputTarget.value = "";
      this.updateSearchAndRefresh("");
    }
    applyFilters(event) {
      event.preventDefault();
      console.log("Applying filters");
      const formData = new FormData(this.filterFormTarget);
      const searchParts = [];
      const globalSearch = formData.get("global");
      if (globalSearch) {
        searchParts.push(globalSearch);
      }
      for (const [name3, value] of formData.entries()) {
        if (name3 !== "global" && !name3.endsWith("_operator") && value) {
          const operator = formData.get(`${name3}_operator`) || "";
          const isReferenceField = ["region_shortname", "season_shortname", "club_shortname", "league_shortname", "party_shortname"].includes(name3);
          console.log(`Debug: Field ${name3}, isReferenceField: ${isReferenceField}`);
          if (isReferenceField) {
            const selectElement = this.filterFormTarget.querySelector(`[name="${name3}"]`);
            console.log(`Debug: Found select element for ${name3}:`, selectElement);
            if (selectElement) {
              const selectedOption = selectElement.options[selectElement.selectedIndex];
              const dataId = selectedOption.dataset.id || selectedOption.value;
              console.log(`Debug: Field ${name3}, selected value: ${selectedOption.value}, data-id: ${dataId}`);
              if (dataId && dataId !== "") {
                let idFieldName;
                if (name3 === "region_shortname") {
                  idFieldName = "region_id";
                } else if (name3 === "club_shortname") {
                  idFieldName = "club_id";
                } else if (name3 === "season_shortname") {
                  idFieldName = "season_id";
                } else if (name3 === "league_shortname") {
                  idFieldName = "league_id";
                } else if (name3 === "party_shortname") {
                  idFieldName = "party_id";
                } else {
                  idFieldName = name3;
                }
                const searchPart = `${idFieldName}:${dataId}`;
                console.log(`Debug: Adding search part: ${searchPart}`);
                searchParts.push(searchPart);
              } else {
                console.log(`Debug: No data-id found for ${name3}, falling back to text search`);
                if (operator && operator !== "contains") {
                  searchParts.push(`${name3}:${operator}${value}`);
                } else {
                  searchParts.push(`${name3}:${value}`);
                }
              }
            }
          } else {
            if (operator && operator !== "contains") {
              searchParts.push(`${name3}:${operator}${value}`);
            } else {
              searchParts.push(`${name3}:${value}`);
            }
          }
        }
      }
      const searchString = searchParts.join(" ");
      this.updateSearchAndRefresh(searchString);
      this.close();
    }
    updateSearchAndRefresh(searchString) {
      this.searchInputTarget.value = searchString;
      const url = new URL(window.location.href);
      if (searchString) {
        url.searchParams.set("sSearch", searchString);
      } else {
        url.searchParams.delete("sSearch");
      }
      window.history.replaceState({}, "", url.toString());
      setTimeout(() => {
        const event = new Event("input", {
          bubbles: true,
          cancelable: true
        });
        this.searchInputTarget.dispatchEvent(event);
      }, 100);
    }
    // Recent selections functionality
    saveRecentSelection(event) {
      const fieldKey = event.target.dataset.fieldKey;
      const value = event.target.value;
      if (value && fieldKey) {
        this.addToRecentSelections(fieldKey, value);
      }
    }
    addToRecentSelections(fieldKey, value) {
      const storageKey = `filter_recent_${fieldKey}`;
      let recent = JSON.parse(localStorage.getItem(storageKey) || "[]");
      recent = recent.filter((item) => item !== value);
      recent.unshift(value);
      recent = recent.slice(0, 5);
      localStorage.setItem(storageKey, JSON.stringify(recent));
    }
    loadRecentSelections() {
      const fieldElements = this.element.querySelectorAll("[data-field-key]");
      fieldElements.forEach((fieldElement) => {
        const fieldKey = fieldElement.dataset.fieldKey;
        const recentContainer = fieldElement.querySelector(".recent-selections");
        if (recentContainer) {
          const storageKey = `filter_recent_${fieldKey}`;
          const recent = JSON.parse(localStorage.getItem(storageKey) || "[]");
          if (recent.length > 0) {
            const recentList = recentContainer.querySelector(".flex");
            recentList.innerHTML = "";
            recent.forEach((value) => {
              const chip = document.createElement("span");
              chip.className = "inline-flex items-center px-2 py-1 rounded-full text-xs bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200 cursor-pointer hover:bg-blue-200 dark:hover:bg-blue-800";
              chip.textContent = value;
              chip.dataset.value = value;
              chip.dataset.fieldKey = fieldKey;
              chip.addEventListener("click", (e) => this.selectRecentValue(e));
              recentList.appendChild(chip);
            });
            recentContainer.style.display = "block";
          } else {
            recentContainer.style.display = "none";
          }
        }
      });
    }
    selectRecentValue(event) {
      const value = event.target.dataset.value;
      const fieldKey = event.target.dataset.fieldKey;
      const input = this.element.querySelector(`[name="${fieldKey}"]`);
      if (input) {
        input.value = value;
        input.dispatchEvent(new Event("change", { bubbles: true }));
      }
    }
    // Autocomplete functionality
    async handleAutocomplete(event) {
      const input = event.target;
      const endpoint = input.dataset.endpoint;
      const query = input.value;
      if (!endpoint || query.length < 2) return;
      try {
        const response2 = await fetch(`${endpoint}?q=${encodeURIComponent(query)}`);
        const data = await response2.json();
        this.showAutocompleteDropdown(input, data);
      } catch (error3) {
        console.error("Autocomplete error:", error3);
      }
    }
    showAutocompleteDropdown(input, suggestions) {
      const existingDropdown = this.element.querySelector(".autocomplete-dropdown");
      if (existingDropdown) {
        existingDropdown.remove();
      }
      if (suggestions.length === 0) return;
      const dropdown = document.createElement("div");
      dropdown.className = "autocomplete-dropdown absolute z-50 w-full bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-md shadow-lg max-h-48 overflow-y-auto";
      suggestions.forEach((suggestion) => {
        const item = document.createElement("div");
        item.className = "px-3 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer";
        item.textContent = suggestion.label || suggestion;
        item.addEventListener("click", () => {
          input.value = suggestion.value || suggestion;
          input.dispatchEvent(new Event("change", { bubbles: true }));
          dropdown.remove();
        });
        dropdown.appendChild(item);
      });
      const rect = input.getBoundingClientRect();
      dropdown.style.top = `${rect.bottom}px`;
      dropdown.style.left = `${rect.left}px`;
      dropdown.style.width = `${rect.width}px`;
      input.parentNode.appendChild(dropdown);
      document.addEventListener("click", (e) => {
        if (!dropdown.contains(e.target) && !input.contains(e.target)) {
          dropdown.remove();
        }
      }, { once: true });
    }
    restoreCurrentSearchState() {
      console.log("\u{1F50D} restoreCurrentSearchState method called");
      const currentSearch = this.searchInputTarget.value || this.getSearchFromURL();
      console.log("Current search input value:", currentSearch);
      if (!currentSearch || currentSearch.trim() === "") {
        console.log("No current search, returning early");
        return;
      }
      console.log("Restoring search state from:", currentSearch);
      const searchParts = currentSearch.split(" ");
      let regionId = null;
      let seasonId = null;
      let clubId = null;
      let leagueId = null;
      let partyId = null;
      searchParts.forEach((part) => {
        if (part.startsWith("region_id:")) {
          regionId = part.split(":")[1];
        } else if (part.startsWith("season_id:")) {
          seasonId = part.split(":")[1];
        } else if (part.startsWith("club_id:")) {
          clubId = part.split(":")[1];
        } else if (part.startsWith("league_id:")) {
          leagueId = part.split(":")[1];
        } else if (part.startsWith("party_id:")) {
          partyId = part.split(":")[1];
        }
      });
      console.log("Found regionId:", regionId, "seasonId:", seasonId, "clubId:", clubId, "leagueId:", leagueId, "partyId:", partyId);
      if (regionId) {
        console.log("Found region select, temporarily disabling StimulusReflex");
        const regionSelect = this.filterFormTarget.querySelector('select[name="region_shortname"]');
        if (regionSelect) {
          regionSelect.removeAttribute("data-reflex");
          regionSelect.removeAttribute("data-action");
        }
        this.restoreSelectValue("region_shortname", regionId, "region_id");
        setTimeout(() => {
          if (regionSelect) {
            const currentPath = window.location.pathname;
            let reflexName = "change->FilterPopupReflex#filter_clubs_by_region_for_players";
            if (currentPath.includes("/party_games")) {
              reflexName = "change->FilterPopupReflex#filter_seasons_by_region_for_party_games";
            } else if (currentPath.includes("/locations")) {
              reflexName = "change->FilterPopupReflex#filter_clubs_by_region_for_locations";
            } else if (currentPath.includes("/clubs")) {
              reflexName = "change->FilterPopupReflex#filter_clubs_by_region_for_clubs";
            }
            regionSelect.setAttribute("data-reflex", reflexName);
            regionSelect.setAttribute("data-action", "change->filter-popup#saveRecentSelection change->stimulus-reflex#__perform");
            regionSelect.dispatchEvent(new Event("change", { bubbles: true }));
          }
          setTimeout(() => {
            if (clubId) {
              console.log("Restoring club selection");
              this.restoreSelectValue("club_shortname", clubId, "club_id");
            }
            if (seasonId) {
              console.log("Restoring season selection");
              this.restoreSelectValue("season_shortname", seasonId, "season_id");
            }
            if (leagueId) {
              console.log("Restoring league selection");
              this.restoreSelectValue("league_shortname", leagueId, "league_id");
            }
            if (partyId) {
              console.log("Restoring party selection");
              this.restoreSelectValue("party_shortname", partyId, "party_id");
            }
          }, 300);
        }, 100);
      } else if (clubId) {
        this.restoreSelectValue("club_shortname", clubId, "club_id");
      }
    }
    restoreSelectValue(selectName, targetId, idFieldName) {
      console.log(`Looking for select element: [name="${selectName}"]`);
      console.log(`Looking for id field: [name="${idFieldName}"]`);
      const selectElement = this.filterFormTarget.querySelector(`[name="${selectName}"]`);
      const idField = this.filterFormTarget.querySelector(`[name="${idFieldName}"]`);
      console.log("Found select element:", selectElement);
      console.log("Found id field:", idField);
      if (!selectElement) {
        console.error(`\u274C Could not find select element for ${selectName} or id field for ${idFieldName}`);
        const allElements = this.filterFormTarget.querySelectorAll("*");
        console.log("All form elements:", allElements.length);
        allElements.forEach((el, index) => {
          if (el.name) {
            console.log(`Element ${index}: name="${el.name}", tag="${el.tagName}"`);
          }
        });
        const allSelects = this.filterFormTarget.querySelectorAll("select");
        console.log("All select elements:", allSelects.length);
        allSelects.forEach((select, index) => {
          console.log(`Select ${index}: name="${select.name}", id="${select.id}"`);
        });
        return;
      }
      console.log(`Attempting to restore ${selectName} with data-id: ${targetId}`);
      console.log("Available options:", selectElement.options.length);
      for (let i = 0; i < selectElement.options.length; i++) {
        const option = selectElement.options[i];
        const dataId = option.dataset.id || option.value;
        console.log(`Option ${i}: value="${option.value}", data-id="${dataId}"`);
        if (dataId == targetId) {
          console.log(`\u2705 Found matching option for ${selectName}: ${option.value}`);
          selectElement.selectedIndex = i;
          selectElement.dispatchEvent(new Event("change", { bubbles: true }));
          return;
        }
      }
      console.log(`\u274C No matching option found for ${selectName} with data-id: ${targetId}`);
    }
    getSearchFromURL() {
      const urlParams = new URLSearchParams(window.location.search);
      return urlParams.get("sSearch") || "";
    }
  };

  // controllers/hello_controller.js
  var hello_controller_exports = {};
  __export(hello_controller_exports, {
    default: () => hello_controller_default
  });
  var hello_controller_default = class extends Controller {
    static targets = ["name"];
    greet() {
      const element = this.nameTarget;
      const name3 = element.value;
      console.log(`hello, ${name3}!`);
    }
  };

  // controllers/markdown_editor_controller.js
  var markdown_editor_controller_exports = {};
  __export(markdown_editor_controller_exports, {
    default: () => markdown_editor_controller_default
  });
  var markdown_editor_controller_default = class extends Controller {
    static targets = ["editor", "preview", "previewButton", "editButton"];
    connect() {
      console.log("Markdown editor controller connected");
    }
    showPreview() {
      const markdownContent = this.editorTarget.value;
      fetch("/pages/preview", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ content: markdownContent })
      }).then((response2) => response2.json()).then((data) => {
        this.previewTarget.innerHTML = data.html;
        this.previewTarget.classList.remove("hidden");
        this.editorTarget.classList.add("hidden");
        this.previewButtonTarget.classList.add("hidden");
        this.editButtonTarget.classList.remove("hidden");
      });
    }
    showEditor() {
      this.previewTarget.classList.add("hidden");
      this.editorTarget.classList.remove("hidden");
      this.previewButtonTarget.classList.remove("hidden");
      this.editButtonTarget.classList.add("hidden");
    }
  };

  // controllers/pagy_url_controller.js
  var pagy_url_controller_exports = {};
  __export(pagy_url_controller_exports, {
    default: () => pagy_url_controller_default
  });
  var pagy_url_controller_default = class extends Controller {
    connect() {
      console.log("PagyUrlController connected");
      document.addEventListener("stimulus-reflex:after", this.updateUrl);
      document.addEventListener("turbo:frame-load", this.updateUrl);
      this.element.addEventListener("click", this.handlePaginationClick);
      this.setupMutationObserver();
    }
    disconnect() {
      document.removeEventListener("stimulus-reflex:after", this.updateUrl);
      document.removeEventListener("turbo:frame-load", this.updateUrl);
      this.element.removeEventListener("click", this.handlePaginationClick);
      if (this.mutationObserver) {
        this.mutationObserver.disconnect();
      }
    }
    setupMutationObserver() {
      this.mutationObserver = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.type === "childList" && mutation.addedNodes.length > 0) {
            const hasPaginationLinks = Array.from(mutation.addedNodes).some(
              (node) => node.nodeType === Node.ELEMENT_NODE && (node.classList?.contains("pagy") || node.querySelector?.("nav.pagy"))
            );
            if (hasPaginationLinks) {
              console.log("Pagination links detected, updating URL");
              this.updateUrl();
            }
          }
        });
      });
      this.mutationObserver.observe(this.element, {
        childList: true,
        subtree: true
      });
    }
    handlePaginationClick = (event) => {
      console.log("Click detected:", event.target);
      const paginationLink = event.target.closest("nav.pagy a");
      if (paginationLink) {
        console.log("Pagination link clicked:", paginationLink.href);
        const url = new URL(paginationLink.href);
        console.log("Updating URL on click to:", url.toString());
        window.history.pushState({}, "", url.toString());
      }
    };
    updateUrl = (event) => {
      console.log("Updating URL after frame/reflex update");
      setTimeout(() => {
        console.log("Looking for pagination elements...");
        const pagyElements = this.element.querySelectorAll("nav.pagy");
        console.log("Found pagy elements:", pagyElements.length);
        const currentPage = this.element.querySelector("nav.pagy .current");
        if (currentPage && currentPage.textContent) {
          const pageNumber = currentPage.textContent.trim();
          const currentUrl = new URL(window.location);
          currentUrl.searchParams.set("page", pageNumber);
          console.log("Method 1 - Updating URL to:", currentUrl.toString());
          window.history.pushState({}, "", currentUrl.toString());
          return;
        }
        const activeLink = this.element.querySelector("nav.pagy a[aria-current='page']");
        if (activeLink) {
          console.log("Method 2 - Updating URL to:", activeLink.href);
          window.history.pushState({}, "", activeLink.href);
          return;
        }
        const firstLink = this.element.querySelector("nav.pagy a");
        if (firstLink) {
          const url = new URL(firstLink.href);
          url.searchParams.delete("page");
          console.log("Method 3 - Updating URL to:", url.toString());
          window.history.pushState({}, "", url.toString());
        }
        console.log("No pagination elements found for URL update");
      }, 100);
    };
  };

  // controllers/party_controller.js
  var party_controller_exports = {};
  __export(party_controller_exports, {
    default: () => party_controller_default
  });
  var party_controller_default = class extends application_controller_default {
    /*
     * Regular Stimulus lifecycle methods
     * Learn more at: https://stimulusjs.org/reference/lifecycle-callbacks
     *
     * If you intend to use this controller as a regular stimulus controller as well,
     * make sure any Stimulus lifecycle methods overridden in ApplicationController call super.
     *
     * Important:
     * By default, StimulusReflex overrides the -connect- method so make sure you
     * call super if you intend to do anything else when this controller connects.
    */
    connect() {
      super.connect();
    }
    /* Reflex specific lifecycle methods.
     *
     * For every method defined in your Reflex class, a matching set of lifecycle methods become available
     * in this javascript controller. These are optional, so feel free to delete these stubs if you don't
     * need them.
     *
     * Important:
     * Make sure to add data-controller="example" to your markup alongside
     * data-reflex="Example#dance" for the lifecycle methods to fire properly.
     *
     * Example:
     *
     *   <a href="#" data-reflex="click->Example#dance" data-controller="example">Dance!</a>
     *
     * Arguments:
     *
     *   element - the element that triggered the reflex
     *             may be different than the Stimulus controller's this.element
     *
     *   reflex - the name of the reflex e.g. "Example#dance"
     *
     *   error/noop - the error message (for reflexError), otherwise null
     *
     *   reflexId - a UUID4 or developer-provided unique identifier for each Reflex
     */
    // Assuming you create a "Example#dance" action in your Reflex class
    // you'll be able to use the following lifecycle methods:
    // beforeDance(element, reflex, noop, reflexId) {
    //  element.innerText = 'Putting dance shoes on...'
    // }
    // danceSuccess(element, reflex, noop, reflexId) {
    //   element.innerText = 'Danced like no one was watching! Was someone watching?'
    // }
    // danceError(element, reflex, error, reflexId) {
    //   console.error('danceError', error);
    //   element.innerText = "Couldn't dance!"
    // }
  };

  // rails:/Volumes/EXT2TB/gullrich/DEV/projects/carambus_api/app/javascript/controllers/**/*_controller.js
  var module11 = __toESM(require_scoreboard_controller());

  // controllers/search_parser_controller.js
  var search_parser_controller_exports = {};
  __export(search_parser_controller_exports, {
    default: () => search_parser_controller_default
  });
  var search_parser_controller_default = class extends Controller {
    static targets = ["field"];
    connect() {
      if (this.hasFieldTargets) {
        this.parseInitialSearch();
      }
    }
    parseInitialSearch() {
      const searchInput = this.element.value;
      if (!searchInput) return;
      const components = {};
      const regex = /(\w+):(\S+)|(\S+)/g;
      let match;
      while ((match = regex.exec(searchInput)) !== null) {
        const [, field, value, plainText] = match;
        if (field && value) {
          const fieldInput = this.fieldTargets.find(
            (target) => target.dataset.fieldName === field.toLowerCase()
          );
          if (fieldInput) {
            fieldInput.value = value;
          }
        } else if (plainText) {
          const generalInput = this.fieldTargets.find(
            (target) => target.dataset.fieldName === "general"
          );
          if (generalInput) {
            generalInput.value = plainText;
          }
        }
      }
    }
    parseInput(event) {
    }
  };

  // controllers/sidebar_controller.js
  var sidebar_controller_exports = {};
  __export(sidebar_controller_exports, {
    default: () => sidebar_controller_default
  });
  var sidebar_controller_default = class extends Controller {
    static targets = ["nav", "submenu", "icon", "content", "showButton"];
    connect() {
      const isSidebarCollapsed = localStorage.getItem("sidebarCollapsed") === "true";
      const isMobile = window.innerWidth < 768;
      if (isMobile || isSidebarCollapsed) {
        document.documentElement.classList.add("sidebar-collapsed");
      } else {
        document.documentElement.classList.remove("sidebar-collapsed");
      }
    }
    toggle(event) {
      const submenu = event.currentTarget.nextElementSibling;
      submenu.classList.toggle("hidden");
      event.currentTarget.querySelector("svg").classList.toggle("rotate-180");
    }
    collapse(event) {
      void this.navTarget.offsetHeight;
      requestAnimationFrame(() => {
        document.documentElement.classList.toggle("sidebar-collapsed");
        const isCollapsed = document.documentElement.classList.contains("sidebar-collapsed");
        localStorage.setItem("sidebarCollapsed", isCollapsed.toString());
      });
    }
    emptyState() {
      return `
      <div class="text-center py-8 px-4">
        <svg class="mx-auto h-12 w-12 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 0 0 2.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 0 0 .75-.75 2.25 2.25 0 0 0-.1-.664m-5.8 0A2.251 2.251 0 0 1 13.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V19.5a2.25 2.25 0 0 0 2.25 2.25h.75m0-3.75h3.75" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No items found</h3>
        <p class="mt-1 text-sm text-gray-500">Get started by creating a new item.</p>
      </div>
    `;
    }
  };

  // controllers/table_monitor_controller.js
  var table_monitor_controller_exports = {};
  __export(table_monitor_controller_exports, {
    default: () => table_monitor_controller_default
  });
  var table_monitor_controller_default = class extends application_controller_default {
    /*
     * Regular Stimulus lifecycle methods
     * Learn more at: https://stimulusjs.org/reference/lifecycle-callbacks
     *
     * If you intend to use this controller as a regular stimulus controller as well,
     * make sure any Stimulus lifecycle methods overridden in ApplicationController call super.
     *
     * Important:
     * By default, StimulusReflex overrides the -connect- method so make sure you
     * call super if you intend to do anything else when this controller connects.
    */
    connect() {
      super.connect();
    }
    /* Reflex specific lifecycle methods.
     *
     * For every method defined in your Reflex class, a matching set of lifecycle methods become available
     * in this javascript controller. These are optional, so feel free to delete these stubs if you don't
     * need them.
     *
     * Important:
     * Make sure to add data-controller="example" to your markup alongside
     * data-reflex="Example#dance" for the lifecycle methods to fire properly.
     *
     * Example:
     *
     *   <a href="#" data-reflex="click->Example#dance" data-controller="example">Dance!</a>
     *
     * Arguments:
     *
     *   element - the element that triggered the reflex
     *             may be different than the Stimulus controller's this.element
     *
     *   reflex - the name of the reflex e.g. "Example#dance"
     *
     *   error/noop - the error message (for reflexError), otherwise null
     *
     *   reflexId - a UUID4 or developer-provided unique identifier for each Reflex
     */
    key_a() {
      console.log("KEY_A");
      this.stimulate("TableMonitor#key_a");
    }
    key_b() {
      console.log("KEY_B");
      this.stimulate("TableMonitor#key_b");
    }
    key_c() {
      console.log("KEY_C");
      this.stimulate("TableMonitor#key_c");
    }
    key_d() {
      console.log("KEY_D");
      this.stimulate("TableMonitor#key_d");
    }
    back() {
      window.history.back();
    }
    home() {
      this.stimulate("TableMonitor#home");
    }
    // Assuming you create a "Example#dance" action in your Reflex class
    // you'll be able to use the following lifecycle methods:
    // beforeDance(element, reflex, noop, reflexId) {
    //  element.innerText = 'Putting dance shoes on...'
    // }
    // danceSuccess(element, reflex, noop, reflexId) {
    //   element.innerText = 'Danced like no one was watching! Was someone watching?'
    // }
    // danceError(element, reflex, error, reflexId) {
    //   console.error('danceError', error);
    //   element.innerText = "Couldn't dance!"
    // }
  };

  // controllers/tabmon_controller.js
  var tabmon_controller_exports = {};
  __export(tabmon_controller_exports, {
    default: () => tabmon_controller_default
  });

  // ../../node_modules/stimulus/dist/stimulus.js
  function camelize3(value) {
    return value.replace(/(?:[_-])([a-z0-9])/g, (_, char) => char.toUpperCase());
  }
  function namespaceCamelize2(value) {
    return camelize3(value.replace(/--/g, "-").replace(/__/g, "_"));
  }
  function capitalize2(value) {
    return value.charAt(0).toUpperCase() + value.slice(1);
  }
  function dasherize2(value) {
    return value.replace(/([A-Z])/g, (_, char) => `-${char.toLowerCase()}`);
  }
  function isSomething2(object) {
    return object !== null && object !== void 0;
  }
  function hasProperty2(object, property) {
    return Object.prototype.hasOwnProperty.call(object, property);
  }
  function readInheritableStaticArrayValues2(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor2(constructor);
    return Array.from(ancestors.reduce((values, constructor2) => {
      getOwnStaticArrayValues2(constructor2, propertyName).forEach((name3) => values.add(name3));
      return values;
    }, /* @__PURE__ */ new Set()));
  }
  function readInheritableStaticObjectPairs2(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor2(constructor);
    return ancestors.reduce((pairs, constructor2) => {
      pairs.push(...getOwnStaticObjectPairs2(constructor2, propertyName));
      return pairs;
    }, []);
  }
  function getAncestorsForConstructor2(constructor) {
    const ancestors = [];
    while (constructor) {
      ancestors.push(constructor);
      constructor = Object.getPrototypeOf(constructor);
    }
    return ancestors.reverse();
  }
  function getOwnStaticArrayValues2(constructor, propertyName) {
    const definition = constructor[propertyName];
    return Array.isArray(definition) ? definition : [];
  }
  function getOwnStaticObjectPairs2(constructor, propertyName) {
    const definition = constructor[propertyName];
    return definition ? Object.keys(definition).map((key) => [key, definition[key]]) : [];
  }
  var getOwnKeys2 = (() => {
    if (typeof Object.getOwnPropertySymbols == "function") {
      return (object) => [...Object.getOwnPropertyNames(object), ...Object.getOwnPropertySymbols(object)];
    } else {
      return Object.getOwnPropertyNames;
    }
  })();
  var extend5 = (() => {
    function extendWithReflect(constructor) {
      function extended() {
        return Reflect.construct(constructor, arguments, new.target);
      }
      extended.prototype = Object.create(constructor.prototype, {
        constructor: { value: extended }
      });
      Reflect.setPrototypeOf(extended, constructor);
      return extended;
    }
    function testReflectExtension() {
      const a = function() {
        this.a.call(this);
      };
      const b2 = extendWithReflect(a);
      b2.prototype.a = function() {
      };
      return new b2();
    }
    try {
      testReflectExtension();
      return extendWithReflect;
    } catch (error3) {
      return (constructor) => class extended extends constructor {
      };
    }
  })();
  var defaultSchema3 = {
    controllerAttribute: "data-controller",
    actionAttribute: "data-action",
    targetAttribute: "data-target",
    targetAttributeForScope: (identifier) => `data-${identifier}-target`,
    outletAttributeForScope: (identifier, outlet) => `data-${identifier}-${outlet}-outlet`,
    keyMappings: Object.assign(Object.assign({ enter: "Enter", tab: "Tab", esc: "Escape", space: " ", up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight", home: "Home", end: "End", page_up: "PageUp", page_down: "PageDown" }, objectFromEntries2("abcdefghijklmnopqrstuvwxyz".split("").map((c2) => [c2, c2]))), objectFromEntries2("0123456789".split("").map((n2) => [n2, n2])))
  };
  function objectFromEntries2(array) {
    return array.reduce((memo, [k, v2]) => Object.assign(Object.assign({}, memo), { [k]: v2 }), {});
  }
  function ClassPropertiesBlessing2(constructor) {
    const classes = readInheritableStaticArrayValues2(constructor, "classes");
    return classes.reduce((properties, classDefinition) => {
      return Object.assign(properties, propertiesForClassDefinition2(classDefinition));
    }, {});
  }
  function propertiesForClassDefinition2(key) {
    return {
      [`${key}Class`]: {
        get() {
          const { classes } = this;
          if (classes.has(key)) {
            return classes.get(key);
          } else {
            const attribute = classes.getAttributeName(key);
            throw new Error(`Missing attribute "${attribute}"`);
          }
        }
      },
      [`${key}Classes`]: {
        get() {
          return this.classes.getAll(key);
        }
      },
      [`has${capitalize2(key)}Class`]: {
        get() {
          return this.classes.has(key);
        }
      }
    };
  }
  function OutletPropertiesBlessing2(constructor) {
    const outlets = readInheritableStaticArrayValues2(constructor, "outlets");
    return outlets.reduce((properties, outletDefinition) => {
      return Object.assign(properties, propertiesForOutletDefinition2(outletDefinition));
    }, {});
  }
  function getOutletController2(controller, element, identifier) {
    return controller.application.getControllerForElementAndIdentifier(element, identifier);
  }
  function getControllerAndEnsureConnectedScope2(controller, element, outletName) {
    let outletController = getOutletController2(controller, element, outletName);
    if (outletController)
      return outletController;
    controller.application.router.proposeToConnectScopeForElementAndIdentifier(element, outletName);
    outletController = getOutletController2(controller, element, outletName);
    if (outletController)
      return outletController;
  }
  function propertiesForOutletDefinition2(name3) {
    const camelizedName = namespaceCamelize2(name3);
    return {
      [`${camelizedName}Outlet`]: {
        get() {
          const outletElement = this.outlets.find(name3);
          const selector = this.outlets.getSelectorForOutletName(name3);
          if (outletElement) {
            const outletController = getControllerAndEnsureConnectedScope2(this, outletElement, name3);
            if (outletController)
              return outletController;
            throw new Error(`The provided outlet element is missing an outlet controller "${name3}" instance for host controller "${this.identifier}"`);
          }
          throw new Error(`Missing outlet element "${name3}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
        }
      },
      [`${camelizedName}Outlets`]: {
        get() {
          const outlets = this.outlets.findAll(name3);
          if (outlets.length > 0) {
            return outlets.map((outletElement) => {
              const outletController = getControllerAndEnsureConnectedScope2(this, outletElement, name3);
              if (outletController)
                return outletController;
              console.warn(`The provided outlet element is missing an outlet controller "${name3}" instance for host controller "${this.identifier}"`, outletElement);
            }).filter((controller) => controller);
          }
          return [];
        }
      },
      [`${camelizedName}OutletElement`]: {
        get() {
          const outletElement = this.outlets.find(name3);
          const selector = this.outlets.getSelectorForOutletName(name3);
          if (outletElement) {
            return outletElement;
          } else {
            throw new Error(`Missing outlet element "${name3}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
          }
        }
      },
      [`${camelizedName}OutletElements`]: {
        get() {
          return this.outlets.findAll(name3);
        }
      },
      [`has${capitalize2(camelizedName)}Outlet`]: {
        get() {
          return this.outlets.has(name3);
        }
      }
    };
  }
  function TargetPropertiesBlessing2(constructor) {
    const targets = readInheritableStaticArrayValues2(constructor, "targets");
    return targets.reduce((properties, targetDefinition) => {
      return Object.assign(properties, propertiesForTargetDefinition2(targetDefinition));
    }, {});
  }
  function propertiesForTargetDefinition2(name3) {
    return {
      [`${name3}Target`]: {
        get() {
          const target = this.targets.find(name3);
          if (target) {
            return target;
          } else {
            throw new Error(`Missing target element "${name3}" for "${this.identifier}" controller`);
          }
        }
      },
      [`${name3}Targets`]: {
        get() {
          return this.targets.findAll(name3);
        }
      },
      [`has${capitalize2(name3)}Target`]: {
        get() {
          return this.targets.has(name3);
        }
      }
    };
  }
  function ValuePropertiesBlessing2(constructor) {
    const valueDefinitionPairs = readInheritableStaticObjectPairs2(constructor, "values");
    const propertyDescriptorMap = {
      valueDescriptorMap: {
        get() {
          return valueDefinitionPairs.reduce((result, valueDefinitionPair) => {
            const valueDescriptor = parseValueDefinitionPair2(valueDefinitionPair, this.identifier);
            const attributeName = this.data.getAttributeNameForKey(valueDescriptor.key);
            return Object.assign(result, { [attributeName]: valueDescriptor });
          }, {});
        }
      }
    };
    return valueDefinitionPairs.reduce((properties, valueDefinitionPair) => {
      return Object.assign(properties, propertiesForValueDefinitionPair2(valueDefinitionPair));
    }, propertyDescriptorMap);
  }
  function propertiesForValueDefinitionPair2(valueDefinitionPair, controller) {
    const definition = parseValueDefinitionPair2(valueDefinitionPair, controller);
    const { key, name: name3, reader: read2, writer: write2 } = definition;
    return {
      [name3]: {
        get() {
          const value = this.data.get(key);
          if (value !== null) {
            return read2(value);
          } else {
            return definition.defaultValue;
          }
        },
        set(value) {
          if (value === void 0) {
            this.data.delete(key);
          } else {
            this.data.set(key, write2(value));
          }
        }
      },
      [`has${capitalize2(name3)}`]: {
        get() {
          return this.data.has(key) || definition.hasCustomDefaultValue;
        }
      }
    };
  }
  function parseValueDefinitionPair2([token, typeDefinition], controller) {
    return valueDescriptorForTokenAndTypeDefinition2({
      controller,
      token,
      typeDefinition
    });
  }
  function parseValueTypeConstant2(constant) {
    switch (constant) {
      case Array:
        return "array";
      case Boolean:
        return "boolean";
      case Number:
        return "number";
      case Object:
        return "object";
      case String:
        return "string";
    }
  }
  function parseValueTypeDefault2(defaultValue) {
    switch (typeof defaultValue) {
      case "boolean":
        return "boolean";
      case "number":
        return "number";
      case "string":
        return "string";
    }
    if (Array.isArray(defaultValue))
      return "array";
    if (Object.prototype.toString.call(defaultValue) === "[object Object]")
      return "object";
  }
  function parseValueTypeObject2(payload) {
    const { controller, token, typeObject } = payload;
    const hasType = isSomething2(typeObject.type);
    const hasDefault = isSomething2(typeObject.default);
    const fullObject = hasType && hasDefault;
    const onlyType = hasType && !hasDefault;
    const onlyDefault = !hasType && hasDefault;
    const typeFromObject = parseValueTypeConstant2(typeObject.type);
    const typeFromDefaultValue = parseValueTypeDefault2(payload.typeObject.default);
    if (onlyType)
      return typeFromObject;
    if (onlyDefault)
      return typeFromDefaultValue;
    if (typeFromObject !== typeFromDefaultValue) {
      const propertyPath = controller ? `${controller}.${token}` : token;
      throw new Error(`The specified default value for the Stimulus Value "${propertyPath}" must match the defined type "${typeFromObject}". The provided default value of "${typeObject.default}" is of type "${typeFromDefaultValue}".`);
    }
    if (fullObject)
      return typeFromObject;
  }
  function parseValueTypeDefinition2(payload) {
    const { controller, token, typeDefinition } = payload;
    const typeObject = { controller, token, typeObject: typeDefinition };
    const typeFromObject = parseValueTypeObject2(typeObject);
    const typeFromDefaultValue = parseValueTypeDefault2(typeDefinition);
    const typeFromConstant = parseValueTypeConstant2(typeDefinition);
    const type = typeFromObject || typeFromDefaultValue || typeFromConstant;
    if (type)
      return type;
    const propertyPath = controller ? `${controller}.${typeDefinition}` : token;
    throw new Error(`Unknown value type "${propertyPath}" for "${token}" value`);
  }
  function defaultValueForDefinition2(typeDefinition) {
    const constant = parseValueTypeConstant2(typeDefinition);
    if (constant)
      return defaultValuesByType2[constant];
    const hasDefault = hasProperty2(typeDefinition, "default");
    const hasType = hasProperty2(typeDefinition, "type");
    const typeObject = typeDefinition;
    if (hasDefault)
      return typeObject.default;
    if (hasType) {
      const { type } = typeObject;
      const constantFromType = parseValueTypeConstant2(type);
      if (constantFromType)
        return defaultValuesByType2[constantFromType];
    }
    return typeDefinition;
  }
  function valueDescriptorForTokenAndTypeDefinition2(payload) {
    const { token, typeDefinition } = payload;
    const key = `${dasherize2(token)}-value`;
    const type = parseValueTypeDefinition2(payload);
    return {
      type,
      key,
      name: camelize3(key),
      get defaultValue() {
        return defaultValueForDefinition2(typeDefinition);
      },
      get hasCustomDefaultValue() {
        return parseValueTypeDefault2(typeDefinition) !== void 0;
      },
      reader: readers2[type],
      writer: writers2[type] || writers2.default
    };
  }
  var defaultValuesByType2 = {
    get array() {
      return [];
    },
    boolean: false,
    number: 0,
    get object() {
      return {};
    },
    string: ""
  };
  var readers2 = {
    array(value) {
      const array = JSON.parse(value);
      if (!Array.isArray(array)) {
        throw new TypeError(`expected value of type "array" but instead got value "${value}" of type "${parseValueTypeDefault2(array)}"`);
      }
      return array;
    },
    boolean(value) {
      return !(value == "0" || String(value).toLowerCase() == "false");
    },
    number(value) {
      return Number(value.replace(/_/g, ""));
    },
    object(value) {
      const object = JSON.parse(value);
      if (object === null || typeof object != "object" || Array.isArray(object)) {
        throw new TypeError(`expected value of type "object" but instead got value "${value}" of type "${parseValueTypeDefault2(object)}"`);
      }
      return object;
    },
    string(value) {
      return value;
    }
  };
  var writers2 = {
    default: writeString2,
    array: writeJSON2,
    object: writeJSON2
  };
  function writeJSON2(value) {
    return JSON.stringify(value);
  }
  function writeString2(value) {
    return `${value}`;
  }
  var Controller2 = class {
    constructor(context) {
      this.context = context;
    }
    static get shouldLoad() {
      return true;
    }
    static afterLoad(_identifier, _application) {
      return;
    }
    get application() {
      return this.context.application;
    }
    get scope() {
      return this.context.scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get targets() {
      return this.scope.targets;
    }
    get outlets() {
      return this.scope.outlets;
    }
    get classes() {
      return this.scope.classes;
    }
    get data() {
      return this.scope.data;
    }
    initialize() {
    }
    connect() {
    }
    disconnect() {
    }
    dispatch(eventName, { target = this.element, detail = {}, prefix = this.identifier, bubbles = true, cancelable = true } = {}) {
      const type = prefix ? `${prefix}:${eventName}` : eventName;
      const event = new CustomEvent(type, { detail, bubbles, cancelable });
      target.dispatchEvent(event);
      return event;
    }
  };
  Controller2.blessings = [
    ClassPropertiesBlessing2,
    TargetPropertiesBlessing2,
    ValuePropertiesBlessing2,
    OutletPropertiesBlessing2
  ];
  Controller2.targets = [];
  Controller2.outlets = [];
  Controller2.values = {};

  // controllers/tabmon_controller.js
  var tabmon_controller_default = class extends Controller2 {
    connect() {
      global3.register(this);
    }
    key_a(event) {
      this.stimulate("TableMonitor#key_a", event.currentTarget);
      console.log("keyA was triggered!");
    }
    force_next_state(event) {
      this.stimulate("TableMonitor#force_next_state", event.currentTarget);
      console.log("force_next_state was triggered!");
    }
    stop(event) {
      this.stimulate("TableMonitor#stop", event.currentTarget);
      console.log("stop was triggered!");
    }
    timeout(event) {
      this.stimulate("TableMonitor#timeout", event.currentTarget);
      console.log("timeout was triggered!");
    }
    pause(event) {
      this.stimulate("TableMonitor#pause", event.currentTarget);
      console.log("pause was triggered!");
    }
    play(event) {
      this.stimulate("TableMonitor#play", event.currentTarget);
      console.log("play was triggered!");
    }
    key_b(event) {
      this.stimulate("TableMonitor#key_b", event.currentTarget);
      console.log("key_b was triggered!");
    }
    undo(event) {
      this.stimulate("TableMonitor#undo", event.currentTarget);
      console.log("undo was triggered!");
    }
    add_n(event) {
      this.stimulate("TableMonitor#add_n", event.currentTarget);
      console.log("add_n was triggered!");
    }
    minus_n(event) {
      this.stimulate("TableMonitor#minus_n", event.currentTarget);
      console.log("minus_n was triggered!");
    }
    next_step(event) {
      this.stimulate("TableMonitor#next_step", event.currentTarget);
      console.log("next_step was triggered!");
    }
    numbers(event) {
      this.stimulate("TableMonitor#numbers", event.currentTarget);
      console.log("numbers was triggered!");
    }
  };

  // controllers/tippy_controller.js
  var tippy_controller_exports = {};
  __export(tippy_controller_exports, {
    default: () => tippy_controller_default
  });

  // ../../node_modules/@popperjs/core/lib/enums.js
  var top = "top";
  var bottom = "bottom";
  var right = "right";
  var left = "left";
  var auto = "auto";
  var basePlacements = [top, bottom, right, left];
  var start2 = "start";
  var end = "end";
  var clippingParents = "clippingParents";
  var viewport = "viewport";
  var popper = "popper";
  var reference = "reference";
  var variationPlacements = /* @__PURE__ */ basePlacements.reduce(function(acc, placement) {
    return acc.concat([placement + "-" + start2, placement + "-" + end]);
  }, []);
  var placements = /* @__PURE__ */ [].concat(basePlacements, [auto]).reduce(function(acc, placement) {
    return acc.concat([placement, placement + "-" + start2, placement + "-" + end]);
  }, []);
  var beforeRead = "beforeRead";
  var read = "read";
  var afterRead = "afterRead";
  var beforeMain = "beforeMain";
  var main3 = "main";
  var afterMain = "afterMain";
  var beforeWrite = "beforeWrite";
  var write = "write";
  var afterWrite = "afterWrite";
  var modifierPhases = [beforeRead, read, afterRead, beforeMain, main3, afterMain, beforeWrite, write, afterWrite];

  // ../../node_modules/@popperjs/core/lib/dom-utils/getNodeName.js
  function getNodeName(element) {
    return element ? (element.nodeName || "").toLowerCase() : null;
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getWindow.js
  function getWindow(node) {
    if (node == null) {
      return window;
    }
    if (node.toString() !== "[object Window]") {
      var ownerDocument = node.ownerDocument;
      return ownerDocument ? ownerDocument.defaultView || window : window;
    }
    return node;
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/instanceOf.js
  function isElement(node) {
    var OwnElement = getWindow(node).Element;
    return node instanceof OwnElement || node instanceof Element;
  }
  function isHTMLElement(node) {
    var OwnElement = getWindow(node).HTMLElement;
    return node instanceof OwnElement || node instanceof HTMLElement;
  }
  function isShadowRoot(node) {
    if (typeof ShadowRoot === "undefined") {
      return false;
    }
    var OwnElement = getWindow(node).ShadowRoot;
    return node instanceof OwnElement || node instanceof ShadowRoot;
  }

  // ../../node_modules/@popperjs/core/lib/modifiers/applyStyles.js
  function applyStyles(_ref) {
    var state = _ref.state;
    Object.keys(state.elements).forEach(function(name3) {
      var style = state.styles[name3] || {};
      var attributes = state.attributes[name3] || {};
      var element = state.elements[name3];
      if (!isHTMLElement(element) || !getNodeName(element)) {
        return;
      }
      Object.assign(element.style, style);
      Object.keys(attributes).forEach(function(name4) {
        var value = attributes[name4];
        if (value === false) {
          element.removeAttribute(name4);
        } else {
          element.setAttribute(name4, value === true ? "" : value);
        }
      });
    });
  }
  function effect(_ref2) {
    var state = _ref2.state;
    var initialStyles = {
      popper: {
        position: state.options.strategy,
        left: "0",
        top: "0",
        margin: "0"
      },
      arrow: {
        position: "absolute"
      },
      reference: {}
    };
    Object.assign(state.elements.popper.style, initialStyles.popper);
    state.styles = initialStyles;
    if (state.elements.arrow) {
      Object.assign(state.elements.arrow.style, initialStyles.arrow);
    }
    return function() {
      Object.keys(state.elements).forEach(function(name3) {
        var element = state.elements[name3];
        var attributes = state.attributes[name3] || {};
        var styleProperties = Object.keys(state.styles.hasOwnProperty(name3) ? state.styles[name3] : initialStyles[name3]);
        var style = styleProperties.reduce(function(style2, property) {
          style2[property] = "";
          return style2;
        }, {});
        if (!isHTMLElement(element) || !getNodeName(element)) {
          return;
        }
        Object.assign(element.style, style);
        Object.keys(attributes).forEach(function(attribute) {
          element.removeAttribute(attribute);
        });
      });
    };
  }
  var applyStyles_default = {
    name: "applyStyles",
    enabled: true,
    phase: "write",
    fn: applyStyles,
    effect,
    requires: ["computeStyles"]
  };

  // ../../node_modules/@popperjs/core/lib/utils/getBasePlacement.js
  function getBasePlacement(placement) {
    return placement.split("-")[0];
  }

  // ../../node_modules/@popperjs/core/lib/utils/math.js
  var max = Math.max;
  var min = Math.min;
  var round = Math.round;

  // ../../node_modules/@popperjs/core/lib/utils/userAgent.js
  function getUAString() {
    var uaData = navigator.userAgentData;
    if (uaData != null && uaData.brands && Array.isArray(uaData.brands)) {
      return uaData.brands.map(function(item) {
        return item.brand + "/" + item.version;
      }).join(" ");
    }
    return navigator.userAgent;
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/isLayoutViewport.js
  function isLayoutViewport() {
    return !/^((?!chrome|android).)*safari/i.test(getUAString());
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getBoundingClientRect.js
  function getBoundingClientRect(element, includeScale, isFixedStrategy) {
    if (includeScale === void 0) {
      includeScale = false;
    }
    if (isFixedStrategy === void 0) {
      isFixedStrategy = false;
    }
    var clientRect = element.getBoundingClientRect();
    var scaleX = 1;
    var scaleY = 1;
    if (includeScale && isHTMLElement(element)) {
      scaleX = element.offsetWidth > 0 ? round(clientRect.width) / element.offsetWidth || 1 : 1;
      scaleY = element.offsetHeight > 0 ? round(clientRect.height) / element.offsetHeight || 1 : 1;
    }
    var _ref = isElement(element) ? getWindow(element) : window, visualViewport = _ref.visualViewport;
    var addVisualOffsets = !isLayoutViewport() && isFixedStrategy;
    var x2 = (clientRect.left + (addVisualOffsets && visualViewport ? visualViewport.offsetLeft : 0)) / scaleX;
    var y = (clientRect.top + (addVisualOffsets && visualViewport ? visualViewport.offsetTop : 0)) / scaleY;
    var width = clientRect.width / scaleX;
    var height = clientRect.height / scaleY;
    return {
      width,
      height,
      top: y,
      right: x2 + width,
      bottom: y + height,
      left: x2,
      x: x2,
      y
    };
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getLayoutRect.js
  function getLayoutRect(element) {
    var clientRect = getBoundingClientRect(element);
    var width = element.offsetWidth;
    var height = element.offsetHeight;
    if (Math.abs(clientRect.width - width) <= 1) {
      width = clientRect.width;
    }
    if (Math.abs(clientRect.height - height) <= 1) {
      height = clientRect.height;
    }
    return {
      x: element.offsetLeft,
      y: element.offsetTop,
      width,
      height
    };
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/contains.js
  function contains(parent, child) {
    var rootNode = child.getRootNode && child.getRootNode();
    if (parent.contains(child)) {
      return true;
    } else if (rootNode && isShadowRoot(rootNode)) {
      var next = child;
      do {
        if (next && parent.isSameNode(next)) {
          return true;
        }
        next = next.parentNode || next.host;
      } while (next);
    }
    return false;
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getComputedStyle.js
  function getComputedStyle(element) {
    return getWindow(element).getComputedStyle(element);
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/isTableElement.js
  function isTableElement(element) {
    return ["table", "td", "th"].indexOf(getNodeName(element)) >= 0;
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getDocumentElement.js
  function getDocumentElement(element) {
    return ((isElement(element) ? element.ownerDocument : (
      // $FlowFixMe[prop-missing]
      element.document
    )) || window.document).documentElement;
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getParentNode.js
  function getParentNode(element) {
    if (getNodeName(element) === "html") {
      return element;
    }
    return (
      // this is a quicker (but less type safe) way to save quite some bytes from the bundle
      // $FlowFixMe[incompatible-return]
      // $FlowFixMe[prop-missing]
      element.assignedSlot || // step into the shadow DOM of the parent of a slotted node
      element.parentNode || // DOM Element detected
      (isShadowRoot(element) ? element.host : null) || // ShadowRoot detected
      // $FlowFixMe[incompatible-call]: HTMLElement is a Node
      getDocumentElement(element)
    );
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getOffsetParent.js
  function getTrueOffsetParent(element) {
    if (!isHTMLElement(element) || // https://github.com/popperjs/popper-core/issues/837
    getComputedStyle(element).position === "fixed") {
      return null;
    }
    return element.offsetParent;
  }
  function getContainingBlock(element) {
    var isFirefox = /firefox/i.test(getUAString());
    var isIE = /Trident/i.test(getUAString());
    if (isIE && isHTMLElement(element)) {
      var elementCss = getComputedStyle(element);
      if (elementCss.position === "fixed") {
        return null;
      }
    }
    var currentNode = getParentNode(element);
    if (isShadowRoot(currentNode)) {
      currentNode = currentNode.host;
    }
    while (isHTMLElement(currentNode) && ["html", "body"].indexOf(getNodeName(currentNode)) < 0) {
      var css = getComputedStyle(currentNode);
      if (css.transform !== "none" || css.perspective !== "none" || css.contain === "paint" || ["transform", "perspective"].indexOf(css.willChange) !== -1 || isFirefox && css.willChange === "filter" || isFirefox && css.filter && css.filter !== "none") {
        return currentNode;
      } else {
        currentNode = currentNode.parentNode;
      }
    }
    return null;
  }
  function getOffsetParent(element) {
    var window2 = getWindow(element);
    var offsetParent = getTrueOffsetParent(element);
    while (offsetParent && isTableElement(offsetParent) && getComputedStyle(offsetParent).position === "static") {
      offsetParent = getTrueOffsetParent(offsetParent);
    }
    if (offsetParent && (getNodeName(offsetParent) === "html" || getNodeName(offsetParent) === "body" && getComputedStyle(offsetParent).position === "static")) {
      return window2;
    }
    return offsetParent || getContainingBlock(element) || window2;
  }

  // ../../node_modules/@popperjs/core/lib/utils/getMainAxisFromPlacement.js
  function getMainAxisFromPlacement(placement) {
    return ["top", "bottom"].indexOf(placement) >= 0 ? "x" : "y";
  }

  // ../../node_modules/@popperjs/core/lib/utils/within.js
  function within(min2, value, max2) {
    return max(min2, min(value, max2));
  }
  function withinMaxClamp(min2, value, max2) {
    var v2 = within(min2, value, max2);
    return v2 > max2 ? max2 : v2;
  }

  // ../../node_modules/@popperjs/core/lib/utils/getFreshSideObject.js
  function getFreshSideObject() {
    return {
      top: 0,
      right: 0,
      bottom: 0,
      left: 0
    };
  }

  // ../../node_modules/@popperjs/core/lib/utils/mergePaddingObject.js
  function mergePaddingObject(paddingObject) {
    return Object.assign({}, getFreshSideObject(), paddingObject);
  }

  // ../../node_modules/@popperjs/core/lib/utils/expandToHashMap.js
  function expandToHashMap(value, keys) {
    return keys.reduce(function(hashMap, key) {
      hashMap[key] = value;
      return hashMap;
    }, {});
  }

  // ../../node_modules/@popperjs/core/lib/modifiers/arrow.js
  var toPaddingObject = function toPaddingObject2(padding, state) {
    padding = typeof padding === "function" ? padding(Object.assign({}, state.rects, {
      placement: state.placement
    })) : padding;
    return mergePaddingObject(typeof padding !== "number" ? padding : expandToHashMap(padding, basePlacements));
  };
  function arrow(_ref) {
    var _state$modifiersData$;
    var state = _ref.state, name3 = _ref.name, options = _ref.options;
    var arrowElement = state.elements.arrow;
    var popperOffsets2 = state.modifiersData.popperOffsets;
    var basePlacement = getBasePlacement(state.placement);
    var axis = getMainAxisFromPlacement(basePlacement);
    var isVertical = [left, right].indexOf(basePlacement) >= 0;
    var len = isVertical ? "height" : "width";
    if (!arrowElement || !popperOffsets2) {
      return;
    }
    var paddingObject = toPaddingObject(options.padding, state);
    var arrowRect = getLayoutRect(arrowElement);
    var minProp = axis === "y" ? top : left;
    var maxProp = axis === "y" ? bottom : right;
    var endDiff = state.rects.reference[len] + state.rects.reference[axis] - popperOffsets2[axis] - state.rects.popper[len];
    var startDiff = popperOffsets2[axis] - state.rects.reference[axis];
    var arrowOffsetParent = getOffsetParent(arrowElement);
    var clientSize = arrowOffsetParent ? axis === "y" ? arrowOffsetParent.clientHeight || 0 : arrowOffsetParent.clientWidth || 0 : 0;
    var centerToReference = endDiff / 2 - startDiff / 2;
    var min2 = paddingObject[minProp];
    var max2 = clientSize - arrowRect[len] - paddingObject[maxProp];
    var center = clientSize / 2 - arrowRect[len] / 2 + centerToReference;
    var offset2 = within(min2, center, max2);
    var axisProp = axis;
    state.modifiersData[name3] = (_state$modifiersData$ = {}, _state$modifiersData$[axisProp] = offset2, _state$modifiersData$.centerOffset = offset2 - center, _state$modifiersData$);
  }
  function effect2(_ref2) {
    var state = _ref2.state, options = _ref2.options;
    var _options$element = options.element, arrowElement = _options$element === void 0 ? "[data-popper-arrow]" : _options$element;
    if (arrowElement == null) {
      return;
    }
    if (typeof arrowElement === "string") {
      arrowElement = state.elements.popper.querySelector(arrowElement);
      if (!arrowElement) {
        return;
      }
    }
    if (!contains(state.elements.popper, arrowElement)) {
      return;
    }
    state.elements.arrow = arrowElement;
  }
  var arrow_default = {
    name: "arrow",
    enabled: true,
    phase: "main",
    fn: arrow,
    effect: effect2,
    requires: ["popperOffsets"],
    requiresIfExists: ["preventOverflow"]
  };

  // ../../node_modules/@popperjs/core/lib/utils/getVariation.js
  function getVariation(placement) {
    return placement.split("-")[1];
  }

  // ../../node_modules/@popperjs/core/lib/modifiers/computeStyles.js
  var unsetSides = {
    top: "auto",
    right: "auto",
    bottom: "auto",
    left: "auto"
  };
  function roundOffsetsByDPR(_ref, win) {
    var x2 = _ref.x, y = _ref.y;
    var dpr = win.devicePixelRatio || 1;
    return {
      x: round(x2 * dpr) / dpr || 0,
      y: round(y * dpr) / dpr || 0
    };
  }
  function mapToStyles(_ref2) {
    var _Object$assign2;
    var popper2 = _ref2.popper, popperRect = _ref2.popperRect, placement = _ref2.placement, variation = _ref2.variation, offsets = _ref2.offsets, position = _ref2.position, gpuAcceleration = _ref2.gpuAcceleration, adaptive = _ref2.adaptive, roundOffsets = _ref2.roundOffsets, isFixed = _ref2.isFixed;
    var _offsets$x = offsets.x, x2 = _offsets$x === void 0 ? 0 : _offsets$x, _offsets$y = offsets.y, y = _offsets$y === void 0 ? 0 : _offsets$y;
    var _ref3 = typeof roundOffsets === "function" ? roundOffsets({
      x: x2,
      y
    }) : {
      x: x2,
      y
    };
    x2 = _ref3.x;
    y = _ref3.y;
    var hasX = offsets.hasOwnProperty("x");
    var hasY = offsets.hasOwnProperty("y");
    var sideX = left;
    var sideY = top;
    var win = window;
    if (adaptive) {
      var offsetParent = getOffsetParent(popper2);
      var heightProp = "clientHeight";
      var widthProp = "clientWidth";
      if (offsetParent === getWindow(popper2)) {
        offsetParent = getDocumentElement(popper2);
        if (getComputedStyle(offsetParent).position !== "static" && position === "absolute") {
          heightProp = "scrollHeight";
          widthProp = "scrollWidth";
        }
      }
      offsetParent = offsetParent;
      if (placement === top || (placement === left || placement === right) && variation === end) {
        sideY = bottom;
        var offsetY = isFixed && offsetParent === win && win.visualViewport ? win.visualViewport.height : (
          // $FlowFixMe[prop-missing]
          offsetParent[heightProp]
        );
        y -= offsetY - popperRect.height;
        y *= gpuAcceleration ? 1 : -1;
      }
      if (placement === left || (placement === top || placement === bottom) && variation === end) {
        sideX = right;
        var offsetX = isFixed && offsetParent === win && win.visualViewport ? win.visualViewport.width : (
          // $FlowFixMe[prop-missing]
          offsetParent[widthProp]
        );
        x2 -= offsetX - popperRect.width;
        x2 *= gpuAcceleration ? 1 : -1;
      }
    }
    var commonStyles = Object.assign({
      position
    }, adaptive && unsetSides);
    var _ref4 = roundOffsets === true ? roundOffsetsByDPR({
      x: x2,
      y
    }, getWindow(popper2)) : {
      x: x2,
      y
    };
    x2 = _ref4.x;
    y = _ref4.y;
    if (gpuAcceleration) {
      var _Object$assign;
      return Object.assign({}, commonStyles, (_Object$assign = {}, _Object$assign[sideY] = hasY ? "0" : "", _Object$assign[sideX] = hasX ? "0" : "", _Object$assign.transform = (win.devicePixelRatio || 1) <= 1 ? "translate(" + x2 + "px, " + y + "px)" : "translate3d(" + x2 + "px, " + y + "px, 0)", _Object$assign));
    }
    return Object.assign({}, commonStyles, (_Object$assign2 = {}, _Object$assign2[sideY] = hasY ? y + "px" : "", _Object$assign2[sideX] = hasX ? x2 + "px" : "", _Object$assign2.transform = "", _Object$assign2));
  }
  function computeStyles(_ref5) {
    var state = _ref5.state, options = _ref5.options;
    var _options$gpuAccelerat = options.gpuAcceleration, gpuAcceleration = _options$gpuAccelerat === void 0 ? true : _options$gpuAccelerat, _options$adaptive = options.adaptive, adaptive = _options$adaptive === void 0 ? true : _options$adaptive, _options$roundOffsets = options.roundOffsets, roundOffsets = _options$roundOffsets === void 0 ? true : _options$roundOffsets;
    var commonStyles = {
      placement: getBasePlacement(state.placement),
      variation: getVariation(state.placement),
      popper: state.elements.popper,
      popperRect: state.rects.popper,
      gpuAcceleration,
      isFixed: state.options.strategy === "fixed"
    };
    if (state.modifiersData.popperOffsets != null) {
      state.styles.popper = Object.assign({}, state.styles.popper, mapToStyles(Object.assign({}, commonStyles, {
        offsets: state.modifiersData.popperOffsets,
        position: state.options.strategy,
        adaptive,
        roundOffsets
      })));
    }
    if (state.modifiersData.arrow != null) {
      state.styles.arrow = Object.assign({}, state.styles.arrow, mapToStyles(Object.assign({}, commonStyles, {
        offsets: state.modifiersData.arrow,
        position: "absolute",
        adaptive: false,
        roundOffsets
      })));
    }
    state.attributes.popper = Object.assign({}, state.attributes.popper, {
      "data-popper-placement": state.placement
    });
  }
  var computeStyles_default = {
    name: "computeStyles",
    enabled: true,
    phase: "beforeWrite",
    fn: computeStyles,
    data: {}
  };

  // ../../node_modules/@popperjs/core/lib/modifiers/eventListeners.js
  var passive = {
    passive: true
  };
  function effect3(_ref) {
    var state = _ref.state, instance = _ref.instance, options = _ref.options;
    var _options$scroll = options.scroll, scroll = _options$scroll === void 0 ? true : _options$scroll, _options$resize = options.resize, resize = _options$resize === void 0 ? true : _options$resize;
    var window2 = getWindow(state.elements.popper);
    var scrollParents = [].concat(state.scrollParents.reference, state.scrollParents.popper);
    if (scroll) {
      scrollParents.forEach(function(scrollParent) {
        scrollParent.addEventListener("scroll", instance.update, passive);
      });
    }
    if (resize) {
      window2.addEventListener("resize", instance.update, passive);
    }
    return function() {
      if (scroll) {
        scrollParents.forEach(function(scrollParent) {
          scrollParent.removeEventListener("scroll", instance.update, passive);
        });
      }
      if (resize) {
        window2.removeEventListener("resize", instance.update, passive);
      }
    };
  }
  var eventListeners_default = {
    name: "eventListeners",
    enabled: true,
    phase: "write",
    fn: function fn() {
    },
    effect: effect3,
    data: {}
  };

  // ../../node_modules/@popperjs/core/lib/utils/getOppositePlacement.js
  var hash = {
    left: "right",
    right: "left",
    bottom: "top",
    top: "bottom"
  };
  function getOppositePlacement(placement) {
    return placement.replace(/left|right|bottom|top/g, function(matched) {
      return hash[matched];
    });
  }

  // ../../node_modules/@popperjs/core/lib/utils/getOppositeVariationPlacement.js
  var hash2 = {
    start: "end",
    end: "start"
  };
  function getOppositeVariationPlacement(placement) {
    return placement.replace(/start|end/g, function(matched) {
      return hash2[matched];
    });
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getWindowScroll.js
  function getWindowScroll(node) {
    var win = getWindow(node);
    var scrollLeft = win.pageXOffset;
    var scrollTop = win.pageYOffset;
    return {
      scrollLeft,
      scrollTop
    };
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getWindowScrollBarX.js
  function getWindowScrollBarX(element) {
    return getBoundingClientRect(getDocumentElement(element)).left + getWindowScroll(element).scrollLeft;
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getViewportRect.js
  function getViewportRect(element, strategy) {
    var win = getWindow(element);
    var html = getDocumentElement(element);
    var visualViewport = win.visualViewport;
    var width = html.clientWidth;
    var height = html.clientHeight;
    var x2 = 0;
    var y = 0;
    if (visualViewport) {
      width = visualViewport.width;
      height = visualViewport.height;
      var layoutViewport = isLayoutViewport();
      if (layoutViewport || !layoutViewport && strategy === "fixed") {
        x2 = visualViewport.offsetLeft;
        y = visualViewport.offsetTop;
      }
    }
    return {
      width,
      height,
      x: x2 + getWindowScrollBarX(element),
      y
    };
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getDocumentRect.js
  function getDocumentRect(element) {
    var _element$ownerDocumen;
    var html = getDocumentElement(element);
    var winScroll = getWindowScroll(element);
    var body = (_element$ownerDocumen = element.ownerDocument) == null ? void 0 : _element$ownerDocumen.body;
    var width = max(html.scrollWidth, html.clientWidth, body ? body.scrollWidth : 0, body ? body.clientWidth : 0);
    var height = max(html.scrollHeight, html.clientHeight, body ? body.scrollHeight : 0, body ? body.clientHeight : 0);
    var x2 = -winScroll.scrollLeft + getWindowScrollBarX(element);
    var y = -winScroll.scrollTop;
    if (getComputedStyle(body || html).direction === "rtl") {
      x2 += max(html.clientWidth, body ? body.clientWidth : 0) - width;
    }
    return {
      width,
      height,
      x: x2,
      y
    };
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/isScrollParent.js
  function isScrollParent(element) {
    var _getComputedStyle = getComputedStyle(element), overflow = _getComputedStyle.overflow, overflowX = _getComputedStyle.overflowX, overflowY = _getComputedStyle.overflowY;
    return /auto|scroll|overlay|hidden/.test(overflow + overflowY + overflowX);
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getScrollParent.js
  function getScrollParent(node) {
    if (["html", "body", "#document"].indexOf(getNodeName(node)) >= 0) {
      return node.ownerDocument.body;
    }
    if (isHTMLElement(node) && isScrollParent(node)) {
      return node;
    }
    return getScrollParent(getParentNode(node));
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/listScrollParents.js
  function listScrollParents(element, list) {
    var _element$ownerDocumen;
    if (list === void 0) {
      list = [];
    }
    var scrollParent = getScrollParent(element);
    var isBody = scrollParent === ((_element$ownerDocumen = element.ownerDocument) == null ? void 0 : _element$ownerDocumen.body);
    var win = getWindow(scrollParent);
    var target = isBody ? [win].concat(win.visualViewport || [], isScrollParent(scrollParent) ? scrollParent : []) : scrollParent;
    var updatedList = list.concat(target);
    return isBody ? updatedList : (
      // $FlowFixMe[incompatible-call]: isBody tells us target will be an HTMLElement here
      updatedList.concat(listScrollParents(getParentNode(target)))
    );
  }

  // ../../node_modules/@popperjs/core/lib/utils/rectToClientRect.js
  function rectToClientRect(rect) {
    return Object.assign({}, rect, {
      left: rect.x,
      top: rect.y,
      right: rect.x + rect.width,
      bottom: rect.y + rect.height
    });
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getClippingRect.js
  function getInnerBoundingClientRect(element, strategy) {
    var rect = getBoundingClientRect(element, false, strategy === "fixed");
    rect.top = rect.top + element.clientTop;
    rect.left = rect.left + element.clientLeft;
    rect.bottom = rect.top + element.clientHeight;
    rect.right = rect.left + element.clientWidth;
    rect.width = element.clientWidth;
    rect.height = element.clientHeight;
    rect.x = rect.left;
    rect.y = rect.top;
    return rect;
  }
  function getClientRectFromMixedType(element, clippingParent, strategy) {
    return clippingParent === viewport ? rectToClientRect(getViewportRect(element, strategy)) : isElement(clippingParent) ? getInnerBoundingClientRect(clippingParent, strategy) : rectToClientRect(getDocumentRect(getDocumentElement(element)));
  }
  function getClippingParents(element) {
    var clippingParents2 = listScrollParents(getParentNode(element));
    var canEscapeClipping = ["absolute", "fixed"].indexOf(getComputedStyle(element).position) >= 0;
    var clipperElement = canEscapeClipping && isHTMLElement(element) ? getOffsetParent(element) : element;
    if (!isElement(clipperElement)) {
      return [];
    }
    return clippingParents2.filter(function(clippingParent) {
      return isElement(clippingParent) && contains(clippingParent, clipperElement) && getNodeName(clippingParent) !== "body";
    });
  }
  function getClippingRect(element, boundary, rootBoundary, strategy) {
    var mainClippingParents = boundary === "clippingParents" ? getClippingParents(element) : [].concat(boundary);
    var clippingParents2 = [].concat(mainClippingParents, [rootBoundary]);
    var firstClippingParent = clippingParents2[0];
    var clippingRect = clippingParents2.reduce(function(accRect, clippingParent) {
      var rect = getClientRectFromMixedType(element, clippingParent, strategy);
      accRect.top = max(rect.top, accRect.top);
      accRect.right = min(rect.right, accRect.right);
      accRect.bottom = min(rect.bottom, accRect.bottom);
      accRect.left = max(rect.left, accRect.left);
      return accRect;
    }, getClientRectFromMixedType(element, firstClippingParent, strategy));
    clippingRect.width = clippingRect.right - clippingRect.left;
    clippingRect.height = clippingRect.bottom - clippingRect.top;
    clippingRect.x = clippingRect.left;
    clippingRect.y = clippingRect.top;
    return clippingRect;
  }

  // ../../node_modules/@popperjs/core/lib/utils/computeOffsets.js
  function computeOffsets(_ref) {
    var reference2 = _ref.reference, element = _ref.element, placement = _ref.placement;
    var basePlacement = placement ? getBasePlacement(placement) : null;
    var variation = placement ? getVariation(placement) : null;
    var commonX = reference2.x + reference2.width / 2 - element.width / 2;
    var commonY = reference2.y + reference2.height / 2 - element.height / 2;
    var offsets;
    switch (basePlacement) {
      case top:
        offsets = {
          x: commonX,
          y: reference2.y - element.height
        };
        break;
      case bottom:
        offsets = {
          x: commonX,
          y: reference2.y + reference2.height
        };
        break;
      case right:
        offsets = {
          x: reference2.x + reference2.width,
          y: commonY
        };
        break;
      case left:
        offsets = {
          x: reference2.x - element.width,
          y: commonY
        };
        break;
      default:
        offsets = {
          x: reference2.x,
          y: reference2.y
        };
    }
    var mainAxis = basePlacement ? getMainAxisFromPlacement(basePlacement) : null;
    if (mainAxis != null) {
      var len = mainAxis === "y" ? "height" : "width";
      switch (variation) {
        case start2:
          offsets[mainAxis] = offsets[mainAxis] - (reference2[len] / 2 - element[len] / 2);
          break;
        case end:
          offsets[mainAxis] = offsets[mainAxis] + (reference2[len] / 2 - element[len] / 2);
          break;
        default:
      }
    }
    return offsets;
  }

  // ../../node_modules/@popperjs/core/lib/utils/detectOverflow.js
  function detectOverflow(state, options) {
    if (options === void 0) {
      options = {};
    }
    var _options = options, _options$placement = _options.placement, placement = _options$placement === void 0 ? state.placement : _options$placement, _options$strategy = _options.strategy, strategy = _options$strategy === void 0 ? state.strategy : _options$strategy, _options$boundary = _options.boundary, boundary = _options$boundary === void 0 ? clippingParents : _options$boundary, _options$rootBoundary = _options.rootBoundary, rootBoundary = _options$rootBoundary === void 0 ? viewport : _options$rootBoundary, _options$elementConte = _options.elementContext, elementContext = _options$elementConte === void 0 ? popper : _options$elementConte, _options$altBoundary = _options.altBoundary, altBoundary = _options$altBoundary === void 0 ? false : _options$altBoundary, _options$padding = _options.padding, padding = _options$padding === void 0 ? 0 : _options$padding;
    var paddingObject = mergePaddingObject(typeof padding !== "number" ? padding : expandToHashMap(padding, basePlacements));
    var altContext = elementContext === popper ? reference : popper;
    var popperRect = state.rects.popper;
    var element = state.elements[altBoundary ? altContext : elementContext];
    var clippingClientRect = getClippingRect(isElement(element) ? element : element.contextElement || getDocumentElement(state.elements.popper), boundary, rootBoundary, strategy);
    var referenceClientRect = getBoundingClientRect(state.elements.reference);
    var popperOffsets2 = computeOffsets({
      reference: referenceClientRect,
      element: popperRect,
      strategy: "absolute",
      placement
    });
    var popperClientRect = rectToClientRect(Object.assign({}, popperRect, popperOffsets2));
    var elementClientRect = elementContext === popper ? popperClientRect : referenceClientRect;
    var overflowOffsets = {
      top: clippingClientRect.top - elementClientRect.top + paddingObject.top,
      bottom: elementClientRect.bottom - clippingClientRect.bottom + paddingObject.bottom,
      left: clippingClientRect.left - elementClientRect.left + paddingObject.left,
      right: elementClientRect.right - clippingClientRect.right + paddingObject.right
    };
    var offsetData = state.modifiersData.offset;
    if (elementContext === popper && offsetData) {
      var offset2 = offsetData[placement];
      Object.keys(overflowOffsets).forEach(function(key) {
        var multiply = [right, bottom].indexOf(key) >= 0 ? 1 : -1;
        var axis = [top, bottom].indexOf(key) >= 0 ? "y" : "x";
        overflowOffsets[key] += offset2[axis] * multiply;
      });
    }
    return overflowOffsets;
  }

  // ../../node_modules/@popperjs/core/lib/utils/computeAutoPlacement.js
  function computeAutoPlacement(state, options) {
    if (options === void 0) {
      options = {};
    }
    var _options = options, placement = _options.placement, boundary = _options.boundary, rootBoundary = _options.rootBoundary, padding = _options.padding, flipVariations = _options.flipVariations, _options$allowedAutoP = _options.allowedAutoPlacements, allowedAutoPlacements = _options$allowedAutoP === void 0 ? placements : _options$allowedAutoP;
    var variation = getVariation(placement);
    var placements2 = variation ? flipVariations ? variationPlacements : variationPlacements.filter(function(placement2) {
      return getVariation(placement2) === variation;
    }) : basePlacements;
    var allowedPlacements = placements2.filter(function(placement2) {
      return allowedAutoPlacements.indexOf(placement2) >= 0;
    });
    if (allowedPlacements.length === 0) {
      allowedPlacements = placements2;
    }
    var overflows = allowedPlacements.reduce(function(acc, placement2) {
      acc[placement2] = detectOverflow(state, {
        placement: placement2,
        boundary,
        rootBoundary,
        padding
      })[getBasePlacement(placement2)];
      return acc;
    }, {});
    return Object.keys(overflows).sort(function(a, b2) {
      return overflows[a] - overflows[b2];
    });
  }

  // ../../node_modules/@popperjs/core/lib/modifiers/flip.js
  function getExpandedFallbackPlacements(placement) {
    if (getBasePlacement(placement) === auto) {
      return [];
    }
    var oppositePlacement = getOppositePlacement(placement);
    return [getOppositeVariationPlacement(placement), oppositePlacement, getOppositeVariationPlacement(oppositePlacement)];
  }
  function flip(_ref) {
    var state = _ref.state, options = _ref.options, name3 = _ref.name;
    if (state.modifiersData[name3]._skip) {
      return;
    }
    var _options$mainAxis = options.mainAxis, checkMainAxis = _options$mainAxis === void 0 ? true : _options$mainAxis, _options$altAxis = options.altAxis, checkAltAxis = _options$altAxis === void 0 ? true : _options$altAxis, specifiedFallbackPlacements = options.fallbackPlacements, padding = options.padding, boundary = options.boundary, rootBoundary = options.rootBoundary, altBoundary = options.altBoundary, _options$flipVariatio = options.flipVariations, flipVariations = _options$flipVariatio === void 0 ? true : _options$flipVariatio, allowedAutoPlacements = options.allowedAutoPlacements;
    var preferredPlacement = state.options.placement;
    var basePlacement = getBasePlacement(preferredPlacement);
    var isBasePlacement = basePlacement === preferredPlacement;
    var fallbackPlacements = specifiedFallbackPlacements || (isBasePlacement || !flipVariations ? [getOppositePlacement(preferredPlacement)] : getExpandedFallbackPlacements(preferredPlacement));
    var placements2 = [preferredPlacement].concat(fallbackPlacements).reduce(function(acc, placement2) {
      return acc.concat(getBasePlacement(placement2) === auto ? computeAutoPlacement(state, {
        placement: placement2,
        boundary,
        rootBoundary,
        padding,
        flipVariations,
        allowedAutoPlacements
      }) : placement2);
    }, []);
    var referenceRect = state.rects.reference;
    var popperRect = state.rects.popper;
    var checksMap = /* @__PURE__ */ new Map();
    var makeFallbackChecks = true;
    var firstFittingPlacement = placements2[0];
    for (var i = 0; i < placements2.length; i++) {
      var placement = placements2[i];
      var _basePlacement = getBasePlacement(placement);
      var isStartVariation = getVariation(placement) === start2;
      var isVertical = [top, bottom].indexOf(_basePlacement) >= 0;
      var len = isVertical ? "width" : "height";
      var overflow = detectOverflow(state, {
        placement,
        boundary,
        rootBoundary,
        altBoundary,
        padding
      });
      var mainVariationSide = isVertical ? isStartVariation ? right : left : isStartVariation ? bottom : top;
      if (referenceRect[len] > popperRect[len]) {
        mainVariationSide = getOppositePlacement(mainVariationSide);
      }
      var altVariationSide = getOppositePlacement(mainVariationSide);
      var checks = [];
      if (checkMainAxis) {
        checks.push(overflow[_basePlacement] <= 0);
      }
      if (checkAltAxis) {
        checks.push(overflow[mainVariationSide] <= 0, overflow[altVariationSide] <= 0);
      }
      if (checks.every(function(check) {
        return check;
      })) {
        firstFittingPlacement = placement;
        makeFallbackChecks = false;
        break;
      }
      checksMap.set(placement, checks);
    }
    if (makeFallbackChecks) {
      var numberOfChecks = flipVariations ? 3 : 1;
      var _loop = function _loop2(_i2) {
        var fittingPlacement = placements2.find(function(placement2) {
          var checks2 = checksMap.get(placement2);
          if (checks2) {
            return checks2.slice(0, _i2).every(function(check) {
              return check;
            });
          }
        });
        if (fittingPlacement) {
          firstFittingPlacement = fittingPlacement;
          return "break";
        }
      };
      for (var _i = numberOfChecks; _i > 0; _i--) {
        var _ret = _loop(_i);
        if (_ret === "break") break;
      }
    }
    if (state.placement !== firstFittingPlacement) {
      state.modifiersData[name3]._skip = true;
      state.placement = firstFittingPlacement;
      state.reset = true;
    }
  }
  var flip_default = {
    name: "flip",
    enabled: true,
    phase: "main",
    fn: flip,
    requiresIfExists: ["offset"],
    data: {
      _skip: false
    }
  };

  // ../../node_modules/@popperjs/core/lib/modifiers/hide.js
  function getSideOffsets(overflow, rect, preventedOffsets) {
    if (preventedOffsets === void 0) {
      preventedOffsets = {
        x: 0,
        y: 0
      };
    }
    return {
      top: overflow.top - rect.height - preventedOffsets.y,
      right: overflow.right - rect.width + preventedOffsets.x,
      bottom: overflow.bottom - rect.height + preventedOffsets.y,
      left: overflow.left - rect.width - preventedOffsets.x
    };
  }
  function isAnySideFullyClipped(overflow) {
    return [top, right, bottom, left].some(function(side) {
      return overflow[side] >= 0;
    });
  }
  function hide(_ref) {
    var state = _ref.state, name3 = _ref.name;
    var referenceRect = state.rects.reference;
    var popperRect = state.rects.popper;
    var preventedOffsets = state.modifiersData.preventOverflow;
    var referenceOverflow = detectOverflow(state, {
      elementContext: "reference"
    });
    var popperAltOverflow = detectOverflow(state, {
      altBoundary: true
    });
    var referenceClippingOffsets = getSideOffsets(referenceOverflow, referenceRect);
    var popperEscapeOffsets = getSideOffsets(popperAltOverflow, popperRect, preventedOffsets);
    var isReferenceHidden = isAnySideFullyClipped(referenceClippingOffsets);
    var hasPopperEscaped = isAnySideFullyClipped(popperEscapeOffsets);
    state.modifiersData[name3] = {
      referenceClippingOffsets,
      popperEscapeOffsets,
      isReferenceHidden,
      hasPopperEscaped
    };
    state.attributes.popper = Object.assign({}, state.attributes.popper, {
      "data-popper-reference-hidden": isReferenceHidden,
      "data-popper-escaped": hasPopperEscaped
    });
  }
  var hide_default = {
    name: "hide",
    enabled: true,
    phase: "main",
    requiresIfExists: ["preventOverflow"],
    fn: hide
  };

  // ../../node_modules/@popperjs/core/lib/modifiers/offset.js
  function distanceAndSkiddingToXY(placement, rects, offset2) {
    var basePlacement = getBasePlacement(placement);
    var invertDistance = [left, top].indexOf(basePlacement) >= 0 ? -1 : 1;
    var _ref = typeof offset2 === "function" ? offset2(Object.assign({}, rects, {
      placement
    })) : offset2, skidding = _ref[0], distance = _ref[1];
    skidding = skidding || 0;
    distance = (distance || 0) * invertDistance;
    return [left, right].indexOf(basePlacement) >= 0 ? {
      x: distance,
      y: skidding
    } : {
      x: skidding,
      y: distance
    };
  }
  function offset(_ref2) {
    var state = _ref2.state, options = _ref2.options, name3 = _ref2.name;
    var _options$offset = options.offset, offset2 = _options$offset === void 0 ? [0, 0] : _options$offset;
    var data = placements.reduce(function(acc, placement) {
      acc[placement] = distanceAndSkiddingToXY(placement, state.rects, offset2);
      return acc;
    }, {});
    var _data$state$placement = data[state.placement], x2 = _data$state$placement.x, y = _data$state$placement.y;
    if (state.modifiersData.popperOffsets != null) {
      state.modifiersData.popperOffsets.x += x2;
      state.modifiersData.popperOffsets.y += y;
    }
    state.modifiersData[name3] = data;
  }
  var offset_default = {
    name: "offset",
    enabled: true,
    phase: "main",
    requires: ["popperOffsets"],
    fn: offset
  };

  // ../../node_modules/@popperjs/core/lib/modifiers/popperOffsets.js
  function popperOffsets(_ref) {
    var state = _ref.state, name3 = _ref.name;
    state.modifiersData[name3] = computeOffsets({
      reference: state.rects.reference,
      element: state.rects.popper,
      strategy: "absolute",
      placement: state.placement
    });
  }
  var popperOffsets_default = {
    name: "popperOffsets",
    enabled: true,
    phase: "read",
    fn: popperOffsets,
    data: {}
  };

  // ../../node_modules/@popperjs/core/lib/utils/getAltAxis.js
  function getAltAxis(axis) {
    return axis === "x" ? "y" : "x";
  }

  // ../../node_modules/@popperjs/core/lib/modifiers/preventOverflow.js
  function preventOverflow(_ref) {
    var state = _ref.state, options = _ref.options, name3 = _ref.name;
    var _options$mainAxis = options.mainAxis, checkMainAxis = _options$mainAxis === void 0 ? true : _options$mainAxis, _options$altAxis = options.altAxis, checkAltAxis = _options$altAxis === void 0 ? false : _options$altAxis, boundary = options.boundary, rootBoundary = options.rootBoundary, altBoundary = options.altBoundary, padding = options.padding, _options$tether = options.tether, tether = _options$tether === void 0 ? true : _options$tether, _options$tetherOffset = options.tetherOffset, tetherOffset = _options$tetherOffset === void 0 ? 0 : _options$tetherOffset;
    var overflow = detectOverflow(state, {
      boundary,
      rootBoundary,
      padding,
      altBoundary
    });
    var basePlacement = getBasePlacement(state.placement);
    var variation = getVariation(state.placement);
    var isBasePlacement = !variation;
    var mainAxis = getMainAxisFromPlacement(basePlacement);
    var altAxis = getAltAxis(mainAxis);
    var popperOffsets2 = state.modifiersData.popperOffsets;
    var referenceRect = state.rects.reference;
    var popperRect = state.rects.popper;
    var tetherOffsetValue = typeof tetherOffset === "function" ? tetherOffset(Object.assign({}, state.rects, {
      placement: state.placement
    })) : tetherOffset;
    var normalizedTetherOffsetValue = typeof tetherOffsetValue === "number" ? {
      mainAxis: tetherOffsetValue,
      altAxis: tetherOffsetValue
    } : Object.assign({
      mainAxis: 0,
      altAxis: 0
    }, tetherOffsetValue);
    var offsetModifierState = state.modifiersData.offset ? state.modifiersData.offset[state.placement] : null;
    var data = {
      x: 0,
      y: 0
    };
    if (!popperOffsets2) {
      return;
    }
    if (checkMainAxis) {
      var _offsetModifierState$;
      var mainSide = mainAxis === "y" ? top : left;
      var altSide = mainAxis === "y" ? bottom : right;
      var len = mainAxis === "y" ? "height" : "width";
      var offset2 = popperOffsets2[mainAxis];
      var min2 = offset2 + overflow[mainSide];
      var max2 = offset2 - overflow[altSide];
      var additive = tether ? -popperRect[len] / 2 : 0;
      var minLen = variation === start2 ? referenceRect[len] : popperRect[len];
      var maxLen = variation === start2 ? -popperRect[len] : -referenceRect[len];
      var arrowElement = state.elements.arrow;
      var arrowRect = tether && arrowElement ? getLayoutRect(arrowElement) : {
        width: 0,
        height: 0
      };
      var arrowPaddingObject = state.modifiersData["arrow#persistent"] ? state.modifiersData["arrow#persistent"].padding : getFreshSideObject();
      var arrowPaddingMin = arrowPaddingObject[mainSide];
      var arrowPaddingMax = arrowPaddingObject[altSide];
      var arrowLen = within(0, referenceRect[len], arrowRect[len]);
      var minOffset = isBasePlacement ? referenceRect[len] / 2 - additive - arrowLen - arrowPaddingMin - normalizedTetherOffsetValue.mainAxis : minLen - arrowLen - arrowPaddingMin - normalizedTetherOffsetValue.mainAxis;
      var maxOffset = isBasePlacement ? -referenceRect[len] / 2 + additive + arrowLen + arrowPaddingMax + normalizedTetherOffsetValue.mainAxis : maxLen + arrowLen + arrowPaddingMax + normalizedTetherOffsetValue.mainAxis;
      var arrowOffsetParent = state.elements.arrow && getOffsetParent(state.elements.arrow);
      var clientOffset = arrowOffsetParent ? mainAxis === "y" ? arrowOffsetParent.clientTop || 0 : arrowOffsetParent.clientLeft || 0 : 0;
      var offsetModifierValue = (_offsetModifierState$ = offsetModifierState == null ? void 0 : offsetModifierState[mainAxis]) != null ? _offsetModifierState$ : 0;
      var tetherMin = offset2 + minOffset - offsetModifierValue - clientOffset;
      var tetherMax = offset2 + maxOffset - offsetModifierValue;
      var preventedOffset = within(tether ? min(min2, tetherMin) : min2, offset2, tether ? max(max2, tetherMax) : max2);
      popperOffsets2[mainAxis] = preventedOffset;
      data[mainAxis] = preventedOffset - offset2;
    }
    if (checkAltAxis) {
      var _offsetModifierState$2;
      var _mainSide = mainAxis === "x" ? top : left;
      var _altSide = mainAxis === "x" ? bottom : right;
      var _offset = popperOffsets2[altAxis];
      var _len = altAxis === "y" ? "height" : "width";
      var _min = _offset + overflow[_mainSide];
      var _max = _offset - overflow[_altSide];
      var isOriginSide = [top, left].indexOf(basePlacement) !== -1;
      var _offsetModifierValue = (_offsetModifierState$2 = offsetModifierState == null ? void 0 : offsetModifierState[altAxis]) != null ? _offsetModifierState$2 : 0;
      var _tetherMin = isOriginSide ? _min : _offset - referenceRect[_len] - popperRect[_len] - _offsetModifierValue + normalizedTetherOffsetValue.altAxis;
      var _tetherMax = isOriginSide ? _offset + referenceRect[_len] + popperRect[_len] - _offsetModifierValue - normalizedTetherOffsetValue.altAxis : _max;
      var _preventedOffset = tether && isOriginSide ? withinMaxClamp(_tetherMin, _offset, _tetherMax) : within(tether ? _tetherMin : _min, _offset, tether ? _tetherMax : _max);
      popperOffsets2[altAxis] = _preventedOffset;
      data[altAxis] = _preventedOffset - _offset;
    }
    state.modifiersData[name3] = data;
  }
  var preventOverflow_default = {
    name: "preventOverflow",
    enabled: true,
    phase: "main",
    fn: preventOverflow,
    requiresIfExists: ["offset"]
  };

  // ../../node_modules/@popperjs/core/lib/dom-utils/getHTMLElementScroll.js
  function getHTMLElementScroll(element) {
    return {
      scrollLeft: element.scrollLeft,
      scrollTop: element.scrollTop
    };
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getNodeScroll.js
  function getNodeScroll(node) {
    if (node === getWindow(node) || !isHTMLElement(node)) {
      return getWindowScroll(node);
    } else {
      return getHTMLElementScroll(node);
    }
  }

  // ../../node_modules/@popperjs/core/lib/dom-utils/getCompositeRect.js
  function isElementScaled(element) {
    var rect = element.getBoundingClientRect();
    var scaleX = round(rect.width) / element.offsetWidth || 1;
    var scaleY = round(rect.height) / element.offsetHeight || 1;
    return scaleX !== 1 || scaleY !== 1;
  }
  function getCompositeRect(elementOrVirtualElement, offsetParent, isFixed) {
    if (isFixed === void 0) {
      isFixed = false;
    }
    var isOffsetParentAnElement = isHTMLElement(offsetParent);
    var offsetParentIsScaled = isHTMLElement(offsetParent) && isElementScaled(offsetParent);
    var documentElement = getDocumentElement(offsetParent);
    var rect = getBoundingClientRect(elementOrVirtualElement, offsetParentIsScaled, isFixed);
    var scroll = {
      scrollLeft: 0,
      scrollTop: 0
    };
    var offsets = {
      x: 0,
      y: 0
    };
    if (isOffsetParentAnElement || !isOffsetParentAnElement && !isFixed) {
      if (getNodeName(offsetParent) !== "body" || // https://github.com/popperjs/popper-core/issues/1078
      isScrollParent(documentElement)) {
        scroll = getNodeScroll(offsetParent);
      }
      if (isHTMLElement(offsetParent)) {
        offsets = getBoundingClientRect(offsetParent, true);
        offsets.x += offsetParent.clientLeft;
        offsets.y += offsetParent.clientTop;
      } else if (documentElement) {
        offsets.x = getWindowScrollBarX(documentElement);
      }
    }
    return {
      x: rect.left + scroll.scrollLeft - offsets.x,
      y: rect.top + scroll.scrollTop - offsets.y,
      width: rect.width,
      height: rect.height
    };
  }

  // ../../node_modules/@popperjs/core/lib/utils/orderModifiers.js
  function order(modifiers) {
    var map = /* @__PURE__ */ new Map();
    var visited = /* @__PURE__ */ new Set();
    var result = [];
    modifiers.forEach(function(modifier) {
      map.set(modifier.name, modifier);
    });
    function sort(modifier) {
      visited.add(modifier.name);
      var requires = [].concat(modifier.requires || [], modifier.requiresIfExists || []);
      requires.forEach(function(dep) {
        if (!visited.has(dep)) {
          var depModifier = map.get(dep);
          if (depModifier) {
            sort(depModifier);
          }
        }
      });
      result.push(modifier);
    }
    modifiers.forEach(function(modifier) {
      if (!visited.has(modifier.name)) {
        sort(modifier);
      }
    });
    return result;
  }
  function orderModifiers(modifiers) {
    var orderedModifiers = order(modifiers);
    return modifierPhases.reduce(function(acc, phase) {
      return acc.concat(orderedModifiers.filter(function(modifier) {
        return modifier.phase === phase;
      }));
    }, []);
  }

  // ../../node_modules/@popperjs/core/lib/utils/debounce.js
  function debounce4(fn2) {
    var pending;
    return function() {
      if (!pending) {
        pending = new Promise(function(resolve) {
          Promise.resolve().then(function() {
            pending = void 0;
            resolve(fn2());
          });
        });
      }
      return pending;
    };
  }

  // ../../node_modules/@popperjs/core/lib/utils/mergeByName.js
  function mergeByName(modifiers) {
    var merged = modifiers.reduce(function(merged2, current) {
      var existing = merged2[current.name];
      merged2[current.name] = existing ? Object.assign({}, existing, current, {
        options: Object.assign({}, existing.options, current.options),
        data: Object.assign({}, existing.data, current.data)
      }) : current;
      return merged2;
    }, {});
    return Object.keys(merged).map(function(key) {
      return merged[key];
    });
  }

  // ../../node_modules/@popperjs/core/lib/createPopper.js
  var DEFAULT_OPTIONS = {
    placement: "bottom",
    modifiers: [],
    strategy: "absolute"
  };
  function areValidElements() {
    for (var _len = arguments.length, args = new Array(_len), _key = 0; _key < _len; _key++) {
      args[_key] = arguments[_key];
    }
    return !args.some(function(element) {
      return !(element && typeof element.getBoundingClientRect === "function");
    });
  }
  function popperGenerator(generatorOptions) {
    if (generatorOptions === void 0) {
      generatorOptions = {};
    }
    var _generatorOptions = generatorOptions, _generatorOptions$def = _generatorOptions.defaultModifiers, defaultModifiers2 = _generatorOptions$def === void 0 ? [] : _generatorOptions$def, _generatorOptions$def2 = _generatorOptions.defaultOptions, defaultOptions2 = _generatorOptions$def2 === void 0 ? DEFAULT_OPTIONS : _generatorOptions$def2;
    return function createPopper2(reference2, popper2, options) {
      if (options === void 0) {
        options = defaultOptions2;
      }
      var state = {
        placement: "bottom",
        orderedModifiers: [],
        options: Object.assign({}, DEFAULT_OPTIONS, defaultOptions2),
        modifiersData: {},
        elements: {
          reference: reference2,
          popper: popper2
        },
        attributes: {},
        styles: {}
      };
      var effectCleanupFns = [];
      var isDestroyed = false;
      var instance = {
        state,
        setOptions: function setOptions(setOptionsAction) {
          var options2 = typeof setOptionsAction === "function" ? setOptionsAction(state.options) : setOptionsAction;
          cleanupModifierEffects();
          state.options = Object.assign({}, defaultOptions2, state.options, options2);
          state.scrollParents = {
            reference: isElement(reference2) ? listScrollParents(reference2) : reference2.contextElement ? listScrollParents(reference2.contextElement) : [],
            popper: listScrollParents(popper2)
          };
          var orderedModifiers = orderModifiers(mergeByName([].concat(defaultModifiers2, state.options.modifiers)));
          state.orderedModifiers = orderedModifiers.filter(function(m2) {
            return m2.enabled;
          });
          runModifierEffects();
          return instance.update();
        },
        // Sync update – it will always be executed, even if not necessary. This
        // is useful for low frequency updates where sync behavior simplifies the
        // logic.
        // For high frequency updates (e.g. `resize` and `scroll` events), always
        // prefer the async Popper#update method
        forceUpdate: function forceUpdate() {
          if (isDestroyed) {
            return;
          }
          var _state$elements = state.elements, reference3 = _state$elements.reference, popper3 = _state$elements.popper;
          if (!areValidElements(reference3, popper3)) {
            return;
          }
          state.rects = {
            reference: getCompositeRect(reference3, getOffsetParent(popper3), state.options.strategy === "fixed"),
            popper: getLayoutRect(popper3)
          };
          state.reset = false;
          state.placement = state.options.placement;
          state.orderedModifiers.forEach(function(modifier) {
            return state.modifiersData[modifier.name] = Object.assign({}, modifier.data);
          });
          for (var index = 0; index < state.orderedModifiers.length; index++) {
            if (state.reset === true) {
              state.reset = false;
              index = -1;
              continue;
            }
            var _state$orderedModifie = state.orderedModifiers[index], fn2 = _state$orderedModifie.fn, _state$orderedModifie2 = _state$orderedModifie.options, _options = _state$orderedModifie2 === void 0 ? {} : _state$orderedModifie2, name3 = _state$orderedModifie.name;
            if (typeof fn2 === "function") {
              state = fn2({
                state,
                options: _options,
                name: name3,
                instance
              }) || state;
            }
          }
        },
        // Async and optimistically optimized update – it will not be executed if
        // not necessary (debounced to run at most once-per-tick)
        update: debounce4(function() {
          return new Promise(function(resolve) {
            instance.forceUpdate();
            resolve(state);
          });
        }),
        destroy: function destroy() {
          cleanupModifierEffects();
          isDestroyed = true;
        }
      };
      if (!areValidElements(reference2, popper2)) {
        return instance;
      }
      instance.setOptions(options).then(function(state2) {
        if (!isDestroyed && options.onFirstUpdate) {
          options.onFirstUpdate(state2);
        }
      });
      function runModifierEffects() {
        state.orderedModifiers.forEach(function(_ref) {
          var name3 = _ref.name, _ref$options = _ref.options, options2 = _ref$options === void 0 ? {} : _ref$options, effect5 = _ref.effect;
          if (typeof effect5 === "function") {
            var cleanupFn = effect5({
              state,
              name: name3,
              instance,
              options: options2
            });
            var noopFn = function noopFn2() {
            };
            effectCleanupFns.push(cleanupFn || noopFn);
          }
        });
      }
      function cleanupModifierEffects() {
        effectCleanupFns.forEach(function(fn2) {
          return fn2();
        });
        effectCleanupFns = [];
      }
      return instance;
    };
  }

  // ../../node_modules/@popperjs/core/lib/popper.js
  var defaultModifiers = [eventListeners_default, popperOffsets_default, computeStyles_default, applyStyles_default, offset_default, flip_default, preventOverflow_default, arrow_default, hide_default];
  var createPopper = /* @__PURE__ */ popperGenerator({
    defaultModifiers
  });

  // ../../node_modules/tippy.js/dist/tippy.esm.js
  var BOX_CLASS = "tippy-box";
  var CONTENT_CLASS = "tippy-content";
  var BACKDROP_CLASS = "tippy-backdrop";
  var ARROW_CLASS = "tippy-arrow";
  var SVG_ARROW_CLASS = "tippy-svg-arrow";
  var TOUCH_OPTIONS = {
    passive: true,
    capture: true
  };
  var TIPPY_DEFAULT_APPEND_TO = function TIPPY_DEFAULT_APPEND_TO2() {
    return document.body;
  };
  function hasOwnProperty(obj, key) {
    return {}.hasOwnProperty.call(obj, key);
  }
  function getValueAtIndexOrReturn(value, index, defaultValue) {
    if (Array.isArray(value)) {
      var v2 = value[index];
      return v2 == null ? Array.isArray(defaultValue) ? defaultValue[index] : defaultValue : v2;
    }
    return value;
  }
  function isType(value, type) {
    var str = {}.toString.call(value);
    return str.indexOf("[object") === 0 && str.indexOf(type + "]") > -1;
  }
  function invokeWithArgsOrReturn(value, args) {
    return typeof value === "function" ? value.apply(void 0, args) : value;
  }
  function debounce5(fn2, ms) {
    if (ms === 0) {
      return fn2;
    }
    var timeout;
    return function(arg) {
      clearTimeout(timeout);
      timeout = setTimeout(function() {
        fn2(arg);
      }, ms);
    };
  }
  function removeProperties(obj, keys) {
    var clone = Object.assign({}, obj);
    keys.forEach(function(key) {
      delete clone[key];
    });
    return clone;
  }
  function splitBySpaces(value) {
    return value.split(/\s+/).filter(Boolean);
  }
  function normalizeToArray(value) {
    return [].concat(value);
  }
  function pushIfUnique(arr, value) {
    if (arr.indexOf(value) === -1) {
      arr.push(value);
    }
  }
  function unique(arr) {
    return arr.filter(function(item, index) {
      return arr.indexOf(item) === index;
    });
  }
  function getBasePlacement2(placement) {
    return placement.split("-")[0];
  }
  function arrayFrom(value) {
    return [].slice.call(value);
  }
  function removeUndefinedProps(obj) {
    return Object.keys(obj).reduce(function(acc, key) {
      if (obj[key] !== void 0) {
        acc[key] = obj[key];
      }
      return acc;
    }, {});
  }
  function div() {
    return document.createElement("div");
  }
  function isElement2(value) {
    return ["Element", "Fragment"].some(function(type) {
      return isType(value, type);
    });
  }
  function isNodeList(value) {
    return isType(value, "NodeList");
  }
  function isMouseEvent(value) {
    return isType(value, "MouseEvent");
  }
  function isReferenceElement(value) {
    return !!(value && value._tippy && value._tippy.reference === value);
  }
  function getArrayOfElements(value) {
    if (isElement2(value)) {
      return [value];
    }
    if (isNodeList(value)) {
      return arrayFrom(value);
    }
    if (Array.isArray(value)) {
      return value;
    }
    return arrayFrom(document.querySelectorAll(value));
  }
  function setTransitionDuration(els, value) {
    els.forEach(function(el) {
      if (el) {
        el.style.transitionDuration = value + "ms";
      }
    });
  }
  function setVisibilityState(els, state) {
    els.forEach(function(el) {
      if (el) {
        el.setAttribute("data-state", state);
      }
    });
  }
  function getOwnerDocument(elementOrElements) {
    var _element$ownerDocumen;
    var _normalizeToArray = normalizeToArray(elementOrElements), element = _normalizeToArray[0];
    return element != null && (_element$ownerDocumen = element.ownerDocument) != null && _element$ownerDocumen.body ? element.ownerDocument : document;
  }
  function isCursorOutsideInteractiveBorder(popperTreeData, event) {
    var clientX = event.clientX, clientY = event.clientY;
    return popperTreeData.every(function(_ref) {
      var popperRect = _ref.popperRect, popperState = _ref.popperState, props = _ref.props;
      var interactiveBorder = props.interactiveBorder;
      var basePlacement = getBasePlacement2(popperState.placement);
      var offsetData = popperState.modifiersData.offset;
      if (!offsetData) {
        return true;
      }
      var topDistance = basePlacement === "bottom" ? offsetData.top.y : 0;
      var bottomDistance = basePlacement === "top" ? offsetData.bottom.y : 0;
      var leftDistance = basePlacement === "right" ? offsetData.left.x : 0;
      var rightDistance = basePlacement === "left" ? offsetData.right.x : 0;
      var exceedsTop = popperRect.top - clientY + topDistance > interactiveBorder;
      var exceedsBottom = clientY - popperRect.bottom - bottomDistance > interactiveBorder;
      var exceedsLeft = popperRect.left - clientX + leftDistance > interactiveBorder;
      var exceedsRight = clientX - popperRect.right - rightDistance > interactiveBorder;
      return exceedsTop || exceedsBottom || exceedsLeft || exceedsRight;
    });
  }
  function updateTransitionEndListener(box, action, listener) {
    var method = action + "EventListener";
    ["transitionend", "webkitTransitionEnd"].forEach(function(event) {
      box[method](event, listener);
    });
  }
  function actualContains(parent, child) {
    var target = child;
    while (target) {
      var _target$getRootNode;
      if (parent.contains(target)) {
        return true;
      }
      target = target.getRootNode == null ? void 0 : (_target$getRootNode = target.getRootNode()) == null ? void 0 : _target$getRootNode.host;
    }
    return false;
  }
  var currentInput = {
    isTouch: false
  };
  var lastMouseMoveTime = 0;
  function onDocumentTouchStart() {
    if (currentInput.isTouch) {
      return;
    }
    currentInput.isTouch = true;
    if (window.performance) {
      document.addEventListener("mousemove", onDocumentMouseMove);
    }
  }
  function onDocumentMouseMove() {
    var now4 = performance.now();
    if (now4 - lastMouseMoveTime < 20) {
      currentInput.isTouch = false;
      document.removeEventListener("mousemove", onDocumentMouseMove);
    }
    lastMouseMoveTime = now4;
  }
  function onWindowBlur() {
    var activeElement2 = document.activeElement;
    if (isReferenceElement(activeElement2)) {
      var instance = activeElement2._tippy;
      if (activeElement2.blur && !instance.state.isVisible) {
        activeElement2.blur();
      }
    }
  }
  function bindGlobalEventListeners() {
    document.addEventListener("touchstart", onDocumentTouchStart, TOUCH_OPTIONS);
    window.addEventListener("blur", onWindowBlur);
  }
  var isBrowser = typeof window !== "undefined" && typeof document !== "undefined";
  var isIE11 = isBrowser ? (
    // @ts-ignore
    !!window.msCrypto
  ) : false;
  function createMemoryLeakWarning(method) {
    var txt = method === "destroy" ? "n already-" : " ";
    return [method + "() was called on a" + txt + "destroyed instance. This is a no-op but", "indicates a potential memory leak."].join(" ");
  }
  function clean(value) {
    var spacesAndTabs = /[ \t]{2,}/g;
    var lineStartWithSpaces = /^[ \t]*/gm;
    return value.replace(spacesAndTabs, " ").replace(lineStartWithSpaces, "").trim();
  }
  function getDevMessage(message) {
    return clean("\n  %ctippy.js\n\n  %c" + clean(message) + "\n\n  %c\u{1F477}\u200D This is a development-only message. It will be removed in production.\n  ");
  }
  function getFormattedMessage(message) {
    return [
      getDevMessage(message),
      // title
      "color: #00C584; font-size: 1.3em; font-weight: bold;",
      // message
      "line-height: 1.5",
      // footer
      "color: #a6a095;"
    ];
  }
  var visitedMessages;
  if (true) {
    resetVisitedMessages();
  }
  function resetVisitedMessages() {
    visitedMessages = /* @__PURE__ */ new Set();
  }
  function warnWhen(condition, message) {
    if (condition && !visitedMessages.has(message)) {
      var _console;
      visitedMessages.add(message);
      (_console = console).warn.apply(_console, getFormattedMessage(message));
    }
  }
  function errorWhen(condition, message) {
    if (condition && !visitedMessages.has(message)) {
      var _console2;
      visitedMessages.add(message);
      (_console2 = console).error.apply(_console2, getFormattedMessage(message));
    }
  }
  function validateTargets(targets) {
    var didPassFalsyValue = !targets;
    var didPassPlainObject = Object.prototype.toString.call(targets) === "[object Object]" && !targets.addEventListener;
    errorWhen(didPassFalsyValue, ["tippy() was passed", "`" + String(targets) + "`", "as its targets (first) argument. Valid types are: String, Element,", "Element[], or NodeList."].join(" "));
    errorWhen(didPassPlainObject, ["tippy() was passed a plain object which is not supported as an argument", "for virtual positioning. Use props.getReferenceClientRect instead."].join(" "));
  }
  var pluginProps = {
    animateFill: false,
    followCursor: false,
    inlinePositioning: false,
    sticky: false
  };
  var renderProps = {
    allowHTML: false,
    animation: "fade",
    arrow: true,
    content: "",
    inertia: false,
    maxWidth: 350,
    role: "tooltip",
    theme: "",
    zIndex: 9999
  };
  var defaultProps = Object.assign({
    appendTo: TIPPY_DEFAULT_APPEND_TO,
    aria: {
      content: "auto",
      expanded: "auto"
    },
    delay: 0,
    duration: [300, 250],
    getReferenceClientRect: null,
    hideOnClick: true,
    ignoreAttributes: false,
    interactive: false,
    interactiveBorder: 2,
    interactiveDebounce: 0,
    moveTransition: "",
    offset: [0, 10],
    onAfterUpdate: function onAfterUpdate() {
    },
    onBeforeUpdate: function onBeforeUpdate() {
    },
    onCreate: function onCreate() {
    },
    onDestroy: function onDestroy() {
    },
    onHidden: function onHidden() {
    },
    onHide: function onHide() {
    },
    onMount: function onMount() {
    },
    onShow: function onShow() {
    },
    onShown: function onShown() {
    },
    onTrigger: function onTrigger() {
    },
    onUntrigger: function onUntrigger() {
    },
    onClickOutside: function onClickOutside() {
    },
    placement: "top",
    plugins: [],
    popperOptions: {},
    render: null,
    showOnCreate: false,
    touch: true,
    trigger: "mouseenter focus",
    triggerTarget: null
  }, pluginProps, renderProps);
  var defaultKeys = Object.keys(defaultProps);
  var setDefaultProps = function setDefaultProps2(partialProps) {
    if (true) {
      validateProps(partialProps, []);
    }
    var keys = Object.keys(partialProps);
    keys.forEach(function(key) {
      defaultProps[key] = partialProps[key];
    });
  };
  function getExtendedPassedProps(passedProps) {
    var plugins = passedProps.plugins || [];
    var pluginProps2 = plugins.reduce(function(acc, plugin) {
      var name3 = plugin.name, defaultValue = plugin.defaultValue;
      if (name3) {
        var _name;
        acc[name3] = passedProps[name3] !== void 0 ? passedProps[name3] : (_name = defaultProps[name3]) != null ? _name : defaultValue;
      }
      return acc;
    }, {});
    return Object.assign({}, passedProps, pluginProps2);
  }
  function getDataAttributeProps(reference2, plugins) {
    var propKeys = plugins ? Object.keys(getExtendedPassedProps(Object.assign({}, defaultProps, {
      plugins
    }))) : defaultKeys;
    var props = propKeys.reduce(function(acc, key) {
      var valueAsString = (reference2.getAttribute("data-tippy-" + key) || "").trim();
      if (!valueAsString) {
        return acc;
      }
      if (key === "content") {
        acc[key] = valueAsString;
      } else {
        try {
          acc[key] = JSON.parse(valueAsString);
        } catch (e) {
          acc[key] = valueAsString;
        }
      }
      return acc;
    }, {});
    return props;
  }
  function evaluateProps(reference2, props) {
    var out = Object.assign({}, props, {
      content: invokeWithArgsOrReturn(props.content, [reference2])
    }, props.ignoreAttributes ? {} : getDataAttributeProps(reference2, props.plugins));
    out.aria = Object.assign({}, defaultProps.aria, out.aria);
    out.aria = {
      expanded: out.aria.expanded === "auto" ? props.interactive : out.aria.expanded,
      content: out.aria.content === "auto" ? props.interactive ? null : "describedby" : out.aria.content
    };
    return out;
  }
  function validateProps(partialProps, plugins) {
    if (partialProps === void 0) {
      partialProps = {};
    }
    if (plugins === void 0) {
      plugins = [];
    }
    var keys = Object.keys(partialProps);
    keys.forEach(function(prop) {
      var nonPluginProps = removeProperties(defaultProps, Object.keys(pluginProps));
      var didPassUnknownProp = !hasOwnProperty(nonPluginProps, prop);
      if (didPassUnknownProp) {
        didPassUnknownProp = plugins.filter(function(plugin) {
          return plugin.name === prop;
        }).length === 0;
      }
      warnWhen(didPassUnknownProp, ["`" + prop + "`", "is not a valid prop. You may have spelled it incorrectly, or if it's", "a plugin, forgot to pass it in an array as props.plugins.", "\n\n", "All props: https://atomiks.github.io/tippyjs/v6/all-props/\n", "Plugins: https://atomiks.github.io/tippyjs/v6/plugins/"].join(" "));
    });
  }
  var innerHTML = function innerHTML2() {
    return "innerHTML";
  };
  function dangerouslySetInnerHTML(element, html) {
    element[innerHTML()] = html;
  }
  function createArrowElement(value) {
    var arrow2 = div();
    if (value === true) {
      arrow2.className = ARROW_CLASS;
    } else {
      arrow2.className = SVG_ARROW_CLASS;
      if (isElement2(value)) {
        arrow2.appendChild(value);
      } else {
        dangerouslySetInnerHTML(arrow2, value);
      }
    }
    return arrow2;
  }
  function setContent(content, props) {
    if (isElement2(props.content)) {
      dangerouslySetInnerHTML(content, "");
      content.appendChild(props.content);
    } else if (typeof props.content !== "function") {
      if (props.allowHTML) {
        dangerouslySetInnerHTML(content, props.content);
      } else {
        content.textContent = props.content;
      }
    }
  }
  function getChildren(popper2) {
    var box = popper2.firstElementChild;
    var boxChildren = arrayFrom(box.children);
    return {
      box,
      content: boxChildren.find(function(node) {
        return node.classList.contains(CONTENT_CLASS);
      }),
      arrow: boxChildren.find(function(node) {
        return node.classList.contains(ARROW_CLASS) || node.classList.contains(SVG_ARROW_CLASS);
      }),
      backdrop: boxChildren.find(function(node) {
        return node.classList.contains(BACKDROP_CLASS);
      })
    };
  }
  function render(instance) {
    var popper2 = div();
    var box = div();
    box.className = BOX_CLASS;
    box.setAttribute("data-state", "hidden");
    box.setAttribute("tabindex", "-1");
    var content = div();
    content.className = CONTENT_CLASS;
    content.setAttribute("data-state", "hidden");
    setContent(content, instance.props);
    popper2.appendChild(box);
    box.appendChild(content);
    onUpdate(instance.props, instance.props);
    function onUpdate(prevProps, nextProps) {
      var _getChildren = getChildren(popper2), box2 = _getChildren.box, content2 = _getChildren.content, arrow2 = _getChildren.arrow;
      if (nextProps.theme) {
        box2.setAttribute("data-theme", nextProps.theme);
      } else {
        box2.removeAttribute("data-theme");
      }
      if (typeof nextProps.animation === "string") {
        box2.setAttribute("data-animation", nextProps.animation);
      } else {
        box2.removeAttribute("data-animation");
      }
      if (nextProps.inertia) {
        box2.setAttribute("data-inertia", "");
      } else {
        box2.removeAttribute("data-inertia");
      }
      box2.style.maxWidth = typeof nextProps.maxWidth === "number" ? nextProps.maxWidth + "px" : nextProps.maxWidth;
      if (nextProps.role) {
        box2.setAttribute("role", nextProps.role);
      } else {
        box2.removeAttribute("role");
      }
      if (prevProps.content !== nextProps.content || prevProps.allowHTML !== nextProps.allowHTML) {
        setContent(content2, instance.props);
      }
      if (nextProps.arrow) {
        if (!arrow2) {
          box2.appendChild(createArrowElement(nextProps.arrow));
        } else if (prevProps.arrow !== nextProps.arrow) {
          box2.removeChild(arrow2);
          box2.appendChild(createArrowElement(nextProps.arrow));
        }
      } else if (arrow2) {
        box2.removeChild(arrow2);
      }
    }
    return {
      popper: popper2,
      onUpdate
    };
  }
  render.$$tippy = true;
  var idCounter = 1;
  var mouseMoveListeners = [];
  var mountedInstances = [];
  function createTippy(reference2, passedProps) {
    var props = evaluateProps(reference2, Object.assign({}, defaultProps, getExtendedPassedProps(removeUndefinedProps(passedProps))));
    var showTimeout;
    var hideTimeout;
    var scheduleHideAnimationFrame;
    var isVisibleFromClick = false;
    var didHideDueToDocumentMouseDown = false;
    var didTouchMove = false;
    var ignoreOnFirstUpdate = false;
    var lastTriggerEvent;
    var currentTransitionEndListener;
    var onFirstUpdate;
    var listeners = [];
    var debouncedOnMouseMove = debounce5(onMouseMove, props.interactiveDebounce);
    var currentTarget;
    var id = idCounter++;
    var popperInstance = null;
    var plugins = unique(props.plugins);
    var state = {
      // Is the instance currently enabled?
      isEnabled: true,
      // Is the tippy currently showing and not transitioning out?
      isVisible: false,
      // Has the instance been destroyed?
      isDestroyed: false,
      // Is the tippy currently mounted to the DOM?
      isMounted: false,
      // Has the tippy finished transitioning in?
      isShown: false
    };
    var instance = {
      // properties
      id,
      reference: reference2,
      popper: div(),
      popperInstance,
      props,
      state,
      plugins,
      // methods
      clearDelayTimeouts,
      setProps,
      setContent: setContent2,
      show,
      hide: hide2,
      hideWithInteractivity,
      enable,
      disable,
      unmount,
      destroy
    };
    if (!props.render) {
      if (true) {
        errorWhen(true, "render() function has not been supplied.");
      }
      return instance;
    }
    var _props$render = props.render(instance), popper2 = _props$render.popper, onUpdate = _props$render.onUpdate;
    popper2.setAttribute("data-tippy-root", "");
    popper2.id = "tippy-" + instance.id;
    instance.popper = popper2;
    reference2._tippy = instance;
    popper2._tippy = instance;
    var pluginsHooks = plugins.map(function(plugin) {
      return plugin.fn(instance);
    });
    var hasAriaExpanded = reference2.hasAttribute("aria-expanded");
    addListeners();
    handleAriaExpandedAttribute();
    handleStyles();
    invokeHook("onCreate", [instance]);
    if (props.showOnCreate) {
      scheduleShow();
    }
    popper2.addEventListener("mouseenter", function() {
      if (instance.props.interactive && instance.state.isVisible) {
        instance.clearDelayTimeouts();
      }
    });
    popper2.addEventListener("mouseleave", function() {
      if (instance.props.interactive && instance.props.trigger.indexOf("mouseenter") >= 0) {
        getDocument().addEventListener("mousemove", debouncedOnMouseMove);
      }
    });
    return instance;
    function getNormalizedTouchSettings() {
      var touch = instance.props.touch;
      return Array.isArray(touch) ? touch : [touch, 0];
    }
    function getIsCustomTouchBehavior() {
      return getNormalizedTouchSettings()[0] === "hold";
    }
    function getIsDefaultRenderFn() {
      var _instance$props$rende;
      return !!((_instance$props$rende = instance.props.render) != null && _instance$props$rende.$$tippy);
    }
    function getCurrentTarget() {
      return currentTarget || reference2;
    }
    function getDocument() {
      var parent = getCurrentTarget().parentNode;
      return parent ? getOwnerDocument(parent) : document;
    }
    function getDefaultTemplateChildren() {
      return getChildren(popper2);
    }
    function getDelay(isShow) {
      if (instance.state.isMounted && !instance.state.isVisible || currentInput.isTouch || lastTriggerEvent && lastTriggerEvent.type === "focus") {
        return 0;
      }
      return getValueAtIndexOrReturn(instance.props.delay, isShow ? 0 : 1, defaultProps.delay);
    }
    function handleStyles(fromHide) {
      if (fromHide === void 0) {
        fromHide = false;
      }
      popper2.style.pointerEvents = instance.props.interactive && !fromHide ? "" : "none";
      popper2.style.zIndex = "" + instance.props.zIndex;
    }
    function invokeHook(hook, args, shouldInvokePropsHook) {
      if (shouldInvokePropsHook === void 0) {
        shouldInvokePropsHook = true;
      }
      pluginsHooks.forEach(function(pluginHooks) {
        if (pluginHooks[hook]) {
          pluginHooks[hook].apply(pluginHooks, args);
        }
      });
      if (shouldInvokePropsHook) {
        var _instance$props;
        (_instance$props = instance.props)[hook].apply(_instance$props, args);
      }
    }
    function handleAriaContentAttribute() {
      var aria = instance.props.aria;
      if (!aria.content) {
        return;
      }
      var attr = "aria-" + aria.content;
      var id2 = popper2.id;
      var nodes = normalizeToArray(instance.props.triggerTarget || reference2);
      nodes.forEach(function(node) {
        var currentValue = node.getAttribute(attr);
        if (instance.state.isVisible) {
          node.setAttribute(attr, currentValue ? currentValue + " " + id2 : id2);
        } else {
          var nextValue = currentValue && currentValue.replace(id2, "").trim();
          if (nextValue) {
            node.setAttribute(attr, nextValue);
          } else {
            node.removeAttribute(attr);
          }
        }
      });
    }
    function handleAriaExpandedAttribute() {
      if (hasAriaExpanded || !instance.props.aria.expanded) {
        return;
      }
      var nodes = normalizeToArray(instance.props.triggerTarget || reference2);
      nodes.forEach(function(node) {
        if (instance.props.interactive) {
          node.setAttribute("aria-expanded", instance.state.isVisible && node === getCurrentTarget() ? "true" : "false");
        } else {
          node.removeAttribute("aria-expanded");
        }
      });
    }
    function cleanupInteractiveMouseListeners() {
      getDocument().removeEventListener("mousemove", debouncedOnMouseMove);
      mouseMoveListeners = mouseMoveListeners.filter(function(listener) {
        return listener !== debouncedOnMouseMove;
      });
    }
    function onDocumentPress(event) {
      if (currentInput.isTouch) {
        if (didTouchMove || event.type === "mousedown") {
          return;
        }
      }
      var actualTarget = event.composedPath && event.composedPath()[0] || event.target;
      if (instance.props.interactive && actualContains(popper2, actualTarget)) {
        return;
      }
      if (normalizeToArray(instance.props.triggerTarget || reference2).some(function(el) {
        return actualContains(el, actualTarget);
      })) {
        if (currentInput.isTouch) {
          return;
        }
        if (instance.state.isVisible && instance.props.trigger.indexOf("click") >= 0) {
          return;
        }
      } else {
        invokeHook("onClickOutside", [instance, event]);
      }
      if (instance.props.hideOnClick === true) {
        instance.clearDelayTimeouts();
        instance.hide();
        didHideDueToDocumentMouseDown = true;
        setTimeout(function() {
          didHideDueToDocumentMouseDown = false;
        });
        if (!instance.state.isMounted) {
          removeDocumentPress();
        }
      }
    }
    function onTouchMove() {
      didTouchMove = true;
    }
    function onTouchStart() {
      didTouchMove = false;
    }
    function addDocumentPress() {
      var doc2 = getDocument();
      doc2.addEventListener("mousedown", onDocumentPress, true);
      doc2.addEventListener("touchend", onDocumentPress, TOUCH_OPTIONS);
      doc2.addEventListener("touchstart", onTouchStart, TOUCH_OPTIONS);
      doc2.addEventListener("touchmove", onTouchMove, TOUCH_OPTIONS);
    }
    function removeDocumentPress() {
      var doc2 = getDocument();
      doc2.removeEventListener("mousedown", onDocumentPress, true);
      doc2.removeEventListener("touchend", onDocumentPress, TOUCH_OPTIONS);
      doc2.removeEventListener("touchstart", onTouchStart, TOUCH_OPTIONS);
      doc2.removeEventListener("touchmove", onTouchMove, TOUCH_OPTIONS);
    }
    function onTransitionedOut(duration2, callback) {
      onTransitionEnd(duration2, function() {
        if (!instance.state.isVisible && popper2.parentNode && popper2.parentNode.contains(popper2)) {
          callback();
        }
      });
    }
    function onTransitionedIn(duration2, callback) {
      onTransitionEnd(duration2, callback);
    }
    function onTransitionEnd(duration2, callback) {
      var box = getDefaultTemplateChildren().box;
      function listener(event) {
        if (event.target === box) {
          updateTransitionEndListener(box, "remove", listener);
          callback();
        }
      }
      if (duration2 === 0) {
        return callback();
      }
      updateTransitionEndListener(box, "remove", currentTransitionEndListener);
      updateTransitionEndListener(box, "add", listener);
      currentTransitionEndListener = listener;
    }
    function on(eventType, handler, options) {
      if (options === void 0) {
        options = false;
      }
      var nodes = normalizeToArray(instance.props.triggerTarget || reference2);
      nodes.forEach(function(node) {
        node.addEventListener(eventType, handler, options);
        listeners.push({
          node,
          eventType,
          handler,
          options
        });
      });
    }
    function addListeners() {
      if (getIsCustomTouchBehavior()) {
        on("touchstart", onTrigger2, {
          passive: true
        });
        on("touchend", onMouseLeave, {
          passive: true
        });
      }
      splitBySpaces(instance.props.trigger).forEach(function(eventType) {
        if (eventType === "manual") {
          return;
        }
        on(eventType, onTrigger2);
        switch (eventType) {
          case "mouseenter":
            on("mouseleave", onMouseLeave);
            break;
          case "focus":
            on(isIE11 ? "focusout" : "blur", onBlurOrFocusOut);
            break;
          case "focusin":
            on("focusout", onBlurOrFocusOut);
            break;
        }
      });
    }
    function removeListeners() {
      listeners.forEach(function(_ref) {
        var node = _ref.node, eventType = _ref.eventType, handler = _ref.handler, options = _ref.options;
        node.removeEventListener(eventType, handler, options);
      });
      listeners = [];
    }
    function onTrigger2(event) {
      var _lastTriggerEvent;
      var shouldScheduleClickHide = false;
      if (!instance.state.isEnabled || isEventListenerStopped(event) || didHideDueToDocumentMouseDown) {
        return;
      }
      var wasFocused = ((_lastTriggerEvent = lastTriggerEvent) == null ? void 0 : _lastTriggerEvent.type) === "focus";
      lastTriggerEvent = event;
      currentTarget = event.currentTarget;
      handleAriaExpandedAttribute();
      if (!instance.state.isVisible && isMouseEvent(event)) {
        mouseMoveListeners.forEach(function(listener) {
          return listener(event);
        });
      }
      if (event.type === "click" && (instance.props.trigger.indexOf("mouseenter") < 0 || isVisibleFromClick) && instance.props.hideOnClick !== false && instance.state.isVisible) {
        shouldScheduleClickHide = true;
      } else {
        scheduleShow(event);
      }
      if (event.type === "click") {
        isVisibleFromClick = !shouldScheduleClickHide;
      }
      if (shouldScheduleClickHide && !wasFocused) {
        scheduleHide(event);
      }
    }
    function onMouseMove(event) {
      var target = event.target;
      var isCursorOverReferenceOrPopper = getCurrentTarget().contains(target) || popper2.contains(target);
      if (event.type === "mousemove" && isCursorOverReferenceOrPopper) {
        return;
      }
      var popperTreeData = getNestedPopperTree().concat(popper2).map(function(popper3) {
        var _instance$popperInsta;
        var instance2 = popper3._tippy;
        var state2 = (_instance$popperInsta = instance2.popperInstance) == null ? void 0 : _instance$popperInsta.state;
        if (state2) {
          return {
            popperRect: popper3.getBoundingClientRect(),
            popperState: state2,
            props
          };
        }
        return null;
      }).filter(Boolean);
      if (isCursorOutsideInteractiveBorder(popperTreeData, event)) {
        cleanupInteractiveMouseListeners();
        scheduleHide(event);
      }
    }
    function onMouseLeave(event) {
      var shouldBail = isEventListenerStopped(event) || instance.props.trigger.indexOf("click") >= 0 && isVisibleFromClick;
      if (shouldBail) {
        return;
      }
      if (instance.props.interactive) {
        instance.hideWithInteractivity(event);
        return;
      }
      scheduleHide(event);
    }
    function onBlurOrFocusOut(event) {
      if (instance.props.trigger.indexOf("focusin") < 0 && event.target !== getCurrentTarget()) {
        return;
      }
      if (instance.props.interactive && event.relatedTarget && popper2.contains(event.relatedTarget)) {
        return;
      }
      scheduleHide(event);
    }
    function isEventListenerStopped(event) {
      return currentInput.isTouch ? getIsCustomTouchBehavior() !== event.type.indexOf("touch") >= 0 : false;
    }
    function createPopperInstance() {
      destroyPopperInstance();
      var _instance$props2 = instance.props, popperOptions = _instance$props2.popperOptions, placement = _instance$props2.placement, offset2 = _instance$props2.offset, getReferenceClientRect = _instance$props2.getReferenceClientRect, moveTransition = _instance$props2.moveTransition;
      var arrow2 = getIsDefaultRenderFn() ? getChildren(popper2).arrow : null;
      var computedReference = getReferenceClientRect ? {
        getBoundingClientRect: getReferenceClientRect,
        contextElement: getReferenceClientRect.contextElement || getCurrentTarget()
      } : reference2;
      var tippyModifier = {
        name: "$$tippy",
        enabled: true,
        phase: "beforeWrite",
        requires: ["computeStyles"],
        fn: function fn2(_ref2) {
          var state2 = _ref2.state;
          if (getIsDefaultRenderFn()) {
            var _getDefaultTemplateCh = getDefaultTemplateChildren(), box = _getDefaultTemplateCh.box;
            ["placement", "reference-hidden", "escaped"].forEach(function(attr) {
              if (attr === "placement") {
                box.setAttribute("data-placement", state2.placement);
              } else {
                if (state2.attributes.popper["data-popper-" + attr]) {
                  box.setAttribute("data-" + attr, "");
                } else {
                  box.removeAttribute("data-" + attr);
                }
              }
            });
            state2.attributes.popper = {};
          }
        }
      };
      var modifiers = [{
        name: "offset",
        options: {
          offset: offset2
        }
      }, {
        name: "preventOverflow",
        options: {
          padding: {
            top: 2,
            bottom: 2,
            left: 5,
            right: 5
          }
        }
      }, {
        name: "flip",
        options: {
          padding: 5
        }
      }, {
        name: "computeStyles",
        options: {
          adaptive: !moveTransition
        }
      }, tippyModifier];
      if (getIsDefaultRenderFn() && arrow2) {
        modifiers.push({
          name: "arrow",
          options: {
            element: arrow2,
            padding: 3
          }
        });
      }
      modifiers.push.apply(modifiers, (popperOptions == null ? void 0 : popperOptions.modifiers) || []);
      instance.popperInstance = createPopper(computedReference, popper2, Object.assign({}, popperOptions, {
        placement,
        onFirstUpdate,
        modifiers
      }));
    }
    function destroyPopperInstance() {
      if (instance.popperInstance) {
        instance.popperInstance.destroy();
        instance.popperInstance = null;
      }
    }
    function mount() {
      var appendTo = instance.props.appendTo;
      var parentNode;
      var node = getCurrentTarget();
      if (instance.props.interactive && appendTo === TIPPY_DEFAULT_APPEND_TO || appendTo === "parent") {
        parentNode = node.parentNode;
      } else {
        parentNode = invokeWithArgsOrReturn(appendTo, [node]);
      }
      if (!parentNode.contains(popper2)) {
        parentNode.appendChild(popper2);
      }
      instance.state.isMounted = true;
      createPopperInstance();
      if (true) {
        warnWhen(instance.props.interactive && appendTo === defaultProps.appendTo && node.nextElementSibling !== popper2, ["Interactive tippy element may not be accessible via keyboard", "navigation because it is not directly after the reference element", "in the DOM source order.", "\n\n", "Using a wrapper <div> or <span> tag around the reference element", "solves this by creating a new parentNode context.", "\n\n", "Specifying `appendTo: document.body` silences this warning, but it", "assumes you are using a focus management solution to handle", "keyboard navigation.", "\n\n", "See: https://atomiks.github.io/tippyjs/v6/accessibility/#interactivity"].join(" "));
      }
    }
    function getNestedPopperTree() {
      return arrayFrom(popper2.querySelectorAll("[data-tippy-root]"));
    }
    function scheduleShow(event) {
      instance.clearDelayTimeouts();
      if (event) {
        invokeHook("onTrigger", [instance, event]);
      }
      addDocumentPress();
      var delay = getDelay(true);
      var _getNormalizedTouchSe = getNormalizedTouchSettings(), touchValue = _getNormalizedTouchSe[0], touchDelay = _getNormalizedTouchSe[1];
      if (currentInput.isTouch && touchValue === "hold" && touchDelay) {
        delay = touchDelay;
      }
      if (delay) {
        showTimeout = setTimeout(function() {
          instance.show();
        }, delay);
      } else {
        instance.show();
      }
    }
    function scheduleHide(event) {
      instance.clearDelayTimeouts();
      invokeHook("onUntrigger", [instance, event]);
      if (!instance.state.isVisible) {
        removeDocumentPress();
        return;
      }
      if (instance.props.trigger.indexOf("mouseenter") >= 0 && instance.props.trigger.indexOf("click") >= 0 && ["mouseleave", "mousemove"].indexOf(event.type) >= 0 && isVisibleFromClick) {
        return;
      }
      var delay = getDelay(false);
      if (delay) {
        hideTimeout = setTimeout(function() {
          if (instance.state.isVisible) {
            instance.hide();
          }
        }, delay);
      } else {
        scheduleHideAnimationFrame = requestAnimationFrame(function() {
          instance.hide();
        });
      }
    }
    function enable() {
      instance.state.isEnabled = true;
    }
    function disable() {
      instance.hide();
      instance.state.isEnabled = false;
    }
    function clearDelayTimeouts() {
      clearTimeout(showTimeout);
      clearTimeout(hideTimeout);
      cancelAnimationFrame(scheduleHideAnimationFrame);
    }
    function setProps(partialProps) {
      if (true) {
        warnWhen(instance.state.isDestroyed, createMemoryLeakWarning("setProps"));
      }
      if (instance.state.isDestroyed) {
        return;
      }
      invokeHook("onBeforeUpdate", [instance, partialProps]);
      removeListeners();
      var prevProps = instance.props;
      var nextProps = evaluateProps(reference2, Object.assign({}, prevProps, removeUndefinedProps(partialProps), {
        ignoreAttributes: true
      }));
      instance.props = nextProps;
      addListeners();
      if (prevProps.interactiveDebounce !== nextProps.interactiveDebounce) {
        cleanupInteractiveMouseListeners();
        debouncedOnMouseMove = debounce5(onMouseMove, nextProps.interactiveDebounce);
      }
      if (prevProps.triggerTarget && !nextProps.triggerTarget) {
        normalizeToArray(prevProps.triggerTarget).forEach(function(node) {
          node.removeAttribute("aria-expanded");
        });
      } else if (nextProps.triggerTarget) {
        reference2.removeAttribute("aria-expanded");
      }
      handleAriaExpandedAttribute();
      handleStyles();
      if (onUpdate) {
        onUpdate(prevProps, nextProps);
      }
      if (instance.popperInstance) {
        createPopperInstance();
        getNestedPopperTree().forEach(function(nestedPopper) {
          requestAnimationFrame(nestedPopper._tippy.popperInstance.forceUpdate);
        });
      }
      invokeHook("onAfterUpdate", [instance, partialProps]);
    }
    function setContent2(content) {
      instance.setProps({
        content
      });
    }
    function show() {
      if (true) {
        warnWhen(instance.state.isDestroyed, createMemoryLeakWarning("show"));
      }
      var isAlreadyVisible = instance.state.isVisible;
      var isDestroyed = instance.state.isDestroyed;
      var isDisabled = !instance.state.isEnabled;
      var isTouchAndTouchDisabled = currentInput.isTouch && !instance.props.touch;
      var duration2 = getValueAtIndexOrReturn(instance.props.duration, 0, defaultProps.duration);
      if (isAlreadyVisible || isDestroyed || isDisabled || isTouchAndTouchDisabled) {
        return;
      }
      if (getCurrentTarget().hasAttribute("disabled")) {
        return;
      }
      invokeHook("onShow", [instance], false);
      if (instance.props.onShow(instance) === false) {
        return;
      }
      instance.state.isVisible = true;
      if (getIsDefaultRenderFn()) {
        popper2.style.visibility = "visible";
      }
      handleStyles();
      addDocumentPress();
      if (!instance.state.isMounted) {
        popper2.style.transition = "none";
      }
      if (getIsDefaultRenderFn()) {
        var _getDefaultTemplateCh2 = getDefaultTemplateChildren(), box = _getDefaultTemplateCh2.box, content = _getDefaultTemplateCh2.content;
        setTransitionDuration([box, content], 0);
      }
      onFirstUpdate = function onFirstUpdate2() {
        var _instance$popperInsta2;
        if (!instance.state.isVisible || ignoreOnFirstUpdate) {
          return;
        }
        ignoreOnFirstUpdate = true;
        void popper2.offsetHeight;
        popper2.style.transition = instance.props.moveTransition;
        if (getIsDefaultRenderFn() && instance.props.animation) {
          var _getDefaultTemplateCh3 = getDefaultTemplateChildren(), _box = _getDefaultTemplateCh3.box, _content = _getDefaultTemplateCh3.content;
          setTransitionDuration([_box, _content], duration2);
          setVisibilityState([_box, _content], "visible");
        }
        handleAriaContentAttribute();
        handleAriaExpandedAttribute();
        pushIfUnique(mountedInstances, instance);
        (_instance$popperInsta2 = instance.popperInstance) == null ? void 0 : _instance$popperInsta2.forceUpdate();
        invokeHook("onMount", [instance]);
        if (instance.props.animation && getIsDefaultRenderFn()) {
          onTransitionedIn(duration2, function() {
            instance.state.isShown = true;
            invokeHook("onShown", [instance]);
          });
        }
      };
      mount();
    }
    function hide2() {
      if (true) {
        warnWhen(instance.state.isDestroyed, createMemoryLeakWarning("hide"));
      }
      var isAlreadyHidden = !instance.state.isVisible;
      var isDestroyed = instance.state.isDestroyed;
      var isDisabled = !instance.state.isEnabled;
      var duration2 = getValueAtIndexOrReturn(instance.props.duration, 1, defaultProps.duration);
      if (isAlreadyHidden || isDestroyed || isDisabled) {
        return;
      }
      invokeHook("onHide", [instance], false);
      if (instance.props.onHide(instance) === false) {
        return;
      }
      instance.state.isVisible = false;
      instance.state.isShown = false;
      ignoreOnFirstUpdate = false;
      isVisibleFromClick = false;
      if (getIsDefaultRenderFn()) {
        popper2.style.visibility = "hidden";
      }
      cleanupInteractiveMouseListeners();
      removeDocumentPress();
      handleStyles(true);
      if (getIsDefaultRenderFn()) {
        var _getDefaultTemplateCh4 = getDefaultTemplateChildren(), box = _getDefaultTemplateCh4.box, content = _getDefaultTemplateCh4.content;
        if (instance.props.animation) {
          setTransitionDuration([box, content], duration2);
          setVisibilityState([box, content], "hidden");
        }
      }
      handleAriaContentAttribute();
      handleAriaExpandedAttribute();
      if (instance.props.animation) {
        if (getIsDefaultRenderFn()) {
          onTransitionedOut(duration2, instance.unmount);
        }
      } else {
        instance.unmount();
      }
    }
    function hideWithInteractivity(event) {
      if (true) {
        warnWhen(instance.state.isDestroyed, createMemoryLeakWarning("hideWithInteractivity"));
      }
      getDocument().addEventListener("mousemove", debouncedOnMouseMove);
      pushIfUnique(mouseMoveListeners, debouncedOnMouseMove);
      debouncedOnMouseMove(event);
    }
    function unmount() {
      if (true) {
        warnWhen(instance.state.isDestroyed, createMemoryLeakWarning("unmount"));
      }
      if (instance.state.isVisible) {
        instance.hide();
      }
      if (!instance.state.isMounted) {
        return;
      }
      destroyPopperInstance();
      getNestedPopperTree().forEach(function(nestedPopper) {
        nestedPopper._tippy.unmount();
      });
      if (popper2.parentNode) {
        popper2.parentNode.removeChild(popper2);
      }
      mountedInstances = mountedInstances.filter(function(i) {
        return i !== instance;
      });
      instance.state.isMounted = false;
      invokeHook("onHidden", [instance]);
    }
    function destroy() {
      if (true) {
        warnWhen(instance.state.isDestroyed, createMemoryLeakWarning("destroy"));
      }
      if (instance.state.isDestroyed) {
        return;
      }
      instance.clearDelayTimeouts();
      instance.unmount();
      removeListeners();
      delete reference2._tippy;
      instance.state.isDestroyed = true;
      invokeHook("onDestroy", [instance]);
    }
  }
  function tippy(targets, optionalProps) {
    if (optionalProps === void 0) {
      optionalProps = {};
    }
    var plugins = defaultProps.plugins.concat(optionalProps.plugins || []);
    if (true) {
      validateTargets(targets);
      validateProps(optionalProps, plugins);
    }
    bindGlobalEventListeners();
    var passedProps = Object.assign({}, optionalProps, {
      plugins
    });
    var elements = getArrayOfElements(targets);
    if (true) {
      var isSingleContentElement = isElement2(passedProps.content);
      var isMoreThanOneReferenceElement = elements.length > 1;
      warnWhen(isSingleContentElement && isMoreThanOneReferenceElement, ["tippy() was passed an Element as the `content` prop, but more than", "one tippy instance was created by this invocation. This means the", "content element will only be appended to the last tippy instance.", "\n\n", "Instead, pass the .innerHTML of the element, or use a function that", "returns a cloned version of the element instead.", "\n\n", "1) content: element.innerHTML\n", "2) content: () => element.cloneNode(true)"].join(" "));
    }
    var instances = elements.reduce(function(acc, reference2) {
      var instance = reference2 && createTippy(reference2, passedProps);
      if (instance) {
        acc.push(instance);
      }
      return acc;
    }, []);
    return isElement2(targets) ? instances[0] : instances;
  }
  tippy.defaultProps = defaultProps;
  tippy.setDefaultProps = setDefaultProps;
  tippy.currentInput = currentInput;
  var applyStylesModifier = Object.assign({}, applyStyles_default, {
    effect: function effect4(_ref) {
      var state = _ref.state;
      var initialStyles = {
        popper: {
          position: state.options.strategy,
          left: "0",
          top: "0",
          margin: "0"
        },
        arrow: {
          position: "absolute"
        },
        reference: {}
      };
      Object.assign(state.elements.popper.style, initialStyles.popper);
      state.styles = initialStyles;
      if (state.elements.arrow) {
        Object.assign(state.elements.arrow.style, initialStyles.arrow);
      }
    }
  });
  tippy.setDefaultProps({
    render
  });
  var tippy_esm_default = tippy;

  // controllers/tippy_controller.js
  var tippy_controller_default = class extends Controller2 {
    initialize() {
      document.addEventListener(
        "cable-ready:after-morph",
        this.initializeTippys.bind(this),
        true
      );
    }
    connect() {
      this.initializeTippys();
    }
    disconnect() {
      this.destroyTippys();
    }
    initializeTippys() {
      this.destroyTippys();
      tippy_esm_default(document.querySelectorAll("[data-tippy-content]"));
    }
    destroyTippys() {
      let tips = document.querySelectorAll("[data-tippy-content]");
      tips.forEach((e) => {
        if (e._tippy) e._tippy.destroy();
      });
    }
  };

  // controllers/toggle_controller.js
  var toggle_controller_exports = {};
  __export(toggle_controller_exports, {
    default: () => toggle_controller_default
  });
  var toggle_controller_default = class extends Controller {
    static targets = ["toggleable"];
    connect() {
      this.toggleClass = this.data.get("class") || "hidden";
    }
    toggle() {
      this.toggleableTarget.classList.toggle("hidden");
    }
  };

  // controllers/tournament_controller.js
  var tournament_controller_exports = {};
  __export(tournament_controller_exports, {
    default: () => tournament_controller_default
  });
  var tournament_controller_default = class extends application_controller_default {
    /*
     * Regular Stimulus lifecycle methods
     * Learn more at: https://stimulusjs.org/reference/lifecycle-callbacks
     *
     * If you intend to use this controller as a regular stimulus controller as well,
     * make sure any Stimulus lifecycle methods overridden in ApplicationController call super.
     *
     * Important:
     * By default, StimulusReflex overrides the -connect- method so make sure you
     * call super if you intend to do anything else when this controller connects.
    */
    connect() {
      super.connect();
    }
    /* Reflex specific lifecycle methods.
     *
     * For every method defined in your Reflex class, a matching set of lifecycle methods become available
     * in this javascript controller. These are optional, so feel free to delete these stubs if you don't
     * need them.
     *
     * Important:
     * Make sure to add data-controller="example" to your markup alongside
     * data-reflex="Example#dance" for the lifecycle methods to fire properly.
     *
     * Example:
     *
     *   <a href="#" data-reflex="click->Example#dance" data-controller="example">Dance!</a>
     *
     * Arguments:
     *
     *   element - the element that triggered the reflex
     *             may be different than the Stimulus controller's this.element
     *
     *   reflex - the name of the reflex e.g. "Example#dance"
     *
     *   error/noop - the error message (for reflexError), otherwise null
     *
     *   reflexId - a UUID4 or developer-provided unique identifier for each Reflex
     */
    // Assuming you create a "Example#dance" action in your Reflex class
    // you'll be able to use the following lifecycle methods:
    // beforeDance(element, reflex, noop, reflexId) {
    //  element.innerText = 'Putting dance shoes on...'
    // }
    // danceSuccess(element, reflex, noop, reflexId) {
    //   element.innerText = 'Danced like no one was watching! Was someone watching?'
    // }
    // danceError(element, reflex, error, reflexId) {
    //   console.error('danceError', error);
    //   element.innerText = "Couldn't dance!"
    // }
  };

  // controllers/transition_controller.js
  var transition_controller_exports = {};
  __export(transition_controller_exports, {
    default: () => transition_controller_default
  });
  var transition_controller_default = class extends Controller {
    enter() {
      this.element.classList.remove(
        this.data.get("enterFrom"),
        this.data.get("leaveTo")
      );
      this.element.classList.add(
        this.data.get("enterTo"),
        this.data.get("enter")
      );
    }
    leave() {
      this.element.classList.remove(
        this.data.get("enterTo"),
        this.data.get("enter")
      );
      this.element.classList.add(
        this.data.get("leaveTo"),
        this.data.get("leave")
      );
    }
  };

  // rails:/Volumes/EXT2TB/gullrich/DEV/projects/carambus_api/app/javascript/controllers/**/*_controller.js
  var modules = [{ name: "application", module: application_controller_exports, filename: "application_controller.js" }, { name: "clipboard", module: clipboard_controller_exports, filename: "clipboard_controller.js" }, { name: "counter", module: counter_controller_exports, filename: "counter_controller.js" }, { name: "dark-mode", module: dark_mode_controller_exports, filename: "dark_mode_controller.js" }, { name: "dropdown", module: dropdown_controller_exports, filename: "dropdown_controller.js" }, { name: "example", module: example_controller_exports, filename: "example_controller.js" }, { name: "filter-popup", module: filter_popup_controller_exports, filename: "filter_popup_controller.js" }, { name: "hello", module: hello_controller_exports, filename: "hello_controller.js" }, { name: "markdown-editor", module: markdown_editor_controller_exports, filename: "markdown_editor_controller.js" }, { name: "pagy-url", module: pagy_url_controller_exports, filename: "pagy_url_controller.js" }, { name: "party", module: party_controller_exports, filename: "party_controller.js" }, { name: "scoreboard", module: module11, filename: "scoreboard_controller.js" }, { name: "search-parser", module: search_parser_controller_exports, filename: "search_parser_controller.js" }, { name: "sidebar", module: sidebar_controller_exports, filename: "sidebar_controller.js" }, { name: "table-monitor", module: table_monitor_controller_exports, filename: "table_monitor_controller.js" }, { name: "tabmon", module: tabmon_controller_exports, filename: "tabmon_controller.js" }, { name: "tippy", module: tippy_controller_exports, filename: "tippy_controller.js" }, { name: "toggle", module: toggle_controller_exports, filename: "toggle_controller.js" }, { name: "tournament", module: tournament_controller_exports, filename: "tournament_controller.js" }, { name: "transition", module: transition_controller_exports, filename: "transition_controller.js" }];
  var controller_default = modules;

  // ../../node_modules/tailwindcss-stimulus-components/dist/tailwindcss-stimulus-components.module.js
  var C = Object.defineProperty;
  var V = (t, e, a) => e in t ? C(t, e, { enumerable: true, configurable: true, writable: true, value: a }) : t[e] = a;
  var s = (t, e, a) => (V(t, typeof e != "symbol" ? e + "" : e, a), a);
  async function r(t, e, a = {}) {
    e ? T(t, a) : b(t, a);
  }
  async function T(t, e = {}) {
    let a = t.dataset.transitionEnter || e.enter || "enter", i = t.dataset.transitionEnterFrom || e.enterFrom || "enter-from", o = t.dataset.transitionEnterTo || e.enterTo || "enter-to", g = t.dataset.toggleClass || e.toggleClass || "hidden";
    t.classList.add(...a.split(" ")), t.classList.add(...i.split(" ")), t.classList.remove(...o.split(" ")), t.classList.remove(...g.split(" ")), await v(), t.classList.remove(...i.split(" ")), t.classList.add(...o.split(" "));
    try {
      await x(t);
    } finally {
      t.classList.remove(...a.split(" "));
    }
  }
  async function b(t, e = {}) {
    let a = t.dataset.transitionLeave || e.leave || "leave", i = t.dataset.transitionLeaveFrom || e.leaveFrom || "leave-from", o = t.dataset.transitionLeaveTo || e.leaveTo || "leave-to", g = t.dataset.toggleClass || e.toggle || "hidden";
    t.classList.add(...a.split(" ")), t.classList.add(...i.split(" ")), t.classList.remove(...o.split(" ")), await v(), t.classList.remove(...i.split(" ")), t.classList.add(...o.split(" "));
    try {
      await x(t);
    } finally {
      t.classList.remove(...a.split(" ")), t.classList.add(...g.split(" "));
    }
  }
  function v() {
    return new Promise((t) => {
      requestAnimationFrame(() => {
        requestAnimationFrame(t);
      });
    });
  }
  function x(t) {
    return Promise.all(t.getAnimations().map((e) => e.finished));
  }
  var p = class extends Controller {
    connect() {
      setTimeout(() => {
        T(this.element);
      }, this.showDelayValue), this.hasDismissAfterValue && setTimeout(() => {
        this.close();
      }, this.dismissAfterValue);
    }
    close() {
      b(this.element).then(() => {
        this.element.remove();
      });
    }
  };
  s(p, "values", { dismissAfter: Number, showDelay: { type: Number, default: 0 } });
  var h = class extends Controller {
    connect() {
      this.timeout = null;
    }
    save() {
      clearTimeout(this.timeout), this.timeout = setTimeout(() => {
        this.statusTarget.textContent = this.submittingTextValue, this.formTarget.requestSubmit();
      }, this.submitDurationValue);
    }
    success() {
      this.setStatus(this.successTextValue);
    }
    error() {
      this.setStatus(this.errorTextValue);
    }
    setStatus(t) {
      this.statusTarget.textContent = t, this.timeout = setTimeout(() => {
        this.statusTarget.textContent = "";
      }, this.statusDurationValue);
    }
  };
  s(h, "targets", ["form", "status"]), s(h, "values", { submitDuration: { type: Number, default: 1e3 }, statusDuration: { type: Number, default: 2e3 }, submittingText: { type: String, default: "Saving..." }, successText: { type: String, default: "Saved!" }, errorText: { type: String, default: "Unable to save." } });
  var u = class extends Controller {
    update() {
      this.preview = this.colorTarget.value;
    }
    set preview(t) {
      this.previewTarget.style[this.styleValue] = t;
      let e = this._getContrastYIQ(t);
      this.styleValue === "color" ? this.previewTarget.style.backgroundColor = e : this.previewTarget.style.color = e;
    }
    _getContrastYIQ(t) {
      t = t.replace("#", "");
      let e = 128, a = parseInt(t.substr(0, 2), 16), i = parseInt(t.substr(2, 2), 16), o = parseInt(t.substr(4, 2), 16);
      return (a * 299 + i * 587 + o * 114) / 1e3 >= e ? "#000" : "#fff";
    }
  };
  s(u, "targets", ["preview", "color"]), s(u, "values", { style: { type: String, default: "backgroundColor" } });
  var l = class extends Controller {
    connect() {
      document.addEventListener("turbo:before-cache", this.beforeCache.bind(this));
    }
    disconnect() {
      document.removeEventListener("turbo:before-cache", this.beforeCache.bind(this));
    }
    openValueChanged() {
      r(this.menuTarget, this.openValue, this.transitionOptions), this.openValue === true && this.hasMenuItemTarget && this.menuItemTargets[0].focus();
    }
    show() {
      this.openValue = true;
    }
    close() {
      this.openValue = false;
    }
    hide(t) {
      this.closeOnClickOutsideValue && t.target.nodeType && this.element.contains(t.target) === false && this.openValue && (this.openValue = false), this.closeOnEscapeValue && t.key === "Escape" && this.openValue && (this.openValue = false);
    }
    toggle() {
      this.openValue = !this.openValue;
    }
    nextItem(t) {
      t.preventDefault(), this.menuItemTargets[this.nextIndex].focus();
    }
    previousItem(t) {
      t.preventDefault(), this.menuItemTargets[this.previousIndex].focus();
    }
    get currentItemIndex() {
      return this.menuItemTargets.indexOf(document.activeElement);
    }
    get nextIndex() {
      return Math.min(this.currentItemIndex + 1, this.menuItemTargets.length - 1);
    }
    get previousIndex() {
      return Math.max(this.currentItemIndex - 1, 0);
    }
    get transitionOptions() {
      return { enter: this.hasEnterClass ? this.enterClass : "transition ease-out duration-100", enterFrom: this.hasEnterFromClass ? this.enterFromClass : "transform opacity-0 scale-95", enterTo: this.hasEnterToClass ? this.enterToClass : "transform opacity-100 scale-100", leave: this.hasLeaveClass ? this.leaveClass : "transition ease-in duration-75", leaveFrom: this.hasLeaveFromClass ? this.leaveFromClass : "transform opacity-100 scale-100", leaveTo: this.hasLeaveToClass ? this.leaveToClass : "transform opacity-0 scale-95", toggleClass: this.hasToggleClass ? this.toggleClass : "hidden" };
    }
    beforeCache() {
      this.openValue = false, this.menuTarget.classList.add("hidden");
    }
  };
  s(l, "targets", ["menu", "button", "menuItem"]), s(l, "values", { open: { type: Boolean, default: false }, closeOnEscape: { type: Boolean, default: true }, closeOnClickOutside: { type: Boolean, default: true } }), s(l, "classes", ["enter", "enterFrom", "enterTo", "leave", "leaveFrom", "leaveTo", "toggle"]);
  var c = class extends Controller {
    connect() {
      this.openValue && this.open(), document.addEventListener("turbo:before-cache", this.beforeCache.bind(this));
    }
    disconnect() {
      document.removeEventListener("turbo:before-cache", this.beforeCache.bind(this));
    }
    open() {
      this.dialogTarget.showModal();
    }
    close() {
      this.dialogTarget.setAttribute("closing", ""), Promise.all(this.dialogTarget.getAnimations().map((t) => t.finished)).then(() => {
        this.dialogTarget.removeAttribute("closing"), this.dialogTarget.close();
      });
    }
    backdropClose(t) {
      t.target.nodeName == "DIALOG" && this.close();
    }
    show() {
      this.dialogTarget.show();
    }
    hide() {
      this.close();
    }
    beforeCache() {
      this.close();
    }
  };
  s(c, "targets", ["dialog"]), s(c, "values", { open: Boolean });
  var d = class extends Controller {
    openValueChanged() {
      r(this.contentTarget, this.openValue), this.shouldAutoDismiss && this.scheduleDismissal();
    }
    show(t) {
      this.shouldAutoDismiss && this.scheduleDismissal(), this.openValue = true;
    }
    hide() {
      this.openValue = false;
    }
    toggle() {
      this.openValue = !this.openValue;
    }
    get shouldAutoDismiss() {
      return this.openValue && this.hasDismissAfterValue;
    }
    scheduleDismissal() {
      this.hasDismissAfterValue && (this.cancelDismissal(), this.timeoutId = setTimeout(() => {
        this.hide(), this.timeoutId = void 0;
      }, this.dismissAfterValue));
    }
    cancelDismissal() {
      typeof this.timeoutId == "number" && (clearTimeout(this.timeoutId), this.timeoutId = void 0);
    }
  };
  s(d, "targets", ["content"]), s(d, "values", { dismissAfter: Number, open: { type: Boolean, default: false } });
  var m = class extends Controller {
    connect() {
      this.openValue && this.open(), document.addEventListener("turbo:before-cache", this.beforeCache.bind(this));
    }
    disconnect() {
      document.removeEventListener("turbo:before-cache", this.beforeCache.bind(this));
    }
    open() {
      this.dialogTarget.showModal();
    }
    close() {
      this.dialogTarget.setAttribute("closing", ""), Promise.all(this.dialogTarget.getAnimations().map((t) => t.finished)).then(() => {
        this.dialogTarget.removeAttribute("closing"), this.dialogTarget.close();
      });
    }
    backdropClose(t) {
      t.target.nodeName == "DIALOG" && this.close();
    }
    show() {
      this.open();
    }
    hide() {
      this.close();
    }
    beforeCache() {
      this.close();
    }
  };
  s(m, "targets", ["dialog"]), s(m, "values", { open: Boolean });
  var n = class extends Controller {
    initialize() {
      this.anchor && (this.indexValue = this.tabTargets.findIndex((t) => t.id === this.anchor));
    }
    connect() {
      this.showTab();
    }
    change(t) {
      t.currentTarget.tagName === "SELECT" ? this.indexValue = t.currentTarget.selectedIndex : t.currentTarget.dataset.index ? this.indexValue = t.currentTarget.dataset.index : t.currentTarget.dataset.id ? this.indexValue = this.tabTargets.findIndex((e) => e.id == t.currentTarget.dataset.id) : this.indexValue = this.tabTargets.indexOf(t.currentTarget);
    }
    nextTab() {
      this.indexValue = Math.min(this.indexValue + 1, this.tabsCount - 1);
    }
    previousTab() {
      this.indexValue = Math.max(this.indexValue - 1, 0);
    }
    firstTab() {
      this.indexValue = 0;
    }
    lastTab() {
      this.indexValue = this.tabsCount - 1;
    }
    indexValueChanged() {
      if (this.showTab(), this.dispatch("tab-change", { target: this.tabTargets[this.indexValue], detail: { activeIndex: this.indexValue } }), this.updateAnchorValue) {
        let t = this.tabTargets[this.indexValue].id;
        if (this.scrollToAnchorValue) location.hash = t;
        else {
          let a = window.location.href.split("#")[0] + "#" + t;
          history.replaceState({}, document.title, a);
        }
      }
    }
    showTab() {
      this.panelTargets.forEach((t, e) => {
        let a = this.tabTargets[e];
        e === this.indexValue ? (t.classList.remove("hidden"), a.ariaSelected = "true", a.dataset.active = true, this.hasInactiveTabClass && a?.classList?.remove(...this.inactiveTabClasses), this.hasActiveTabClass && a?.classList?.add(...this.activeTabClasses)) : (t.classList.add("hidden"), a.ariaSelected = null, delete a.dataset.active, this.hasActiveTabClass && a?.classList?.remove(...this.activeTabClasses), this.hasInactiveTabClass && a?.classList?.add(...this.inactiveTabClasses));
      }), this.hasSelectTarget && (this.selectTarget.selectedIndex = this.indexValue), this.scrollActiveTabIntoViewValue && this.scrollToActiveTab();
    }
    scrollToActiveTab() {
      let t = this.element.querySelector("[aria-selected]");
      t && t.scrollIntoView({ inline: "center" });
    }
    get tabsCount() {
      return this.tabTargets.length;
    }
    get anchor() {
      return document.URL.split("#").length > 1 ? document.URL.split("#")[1] : null;
    }
  };
  s(n, "classes", ["activeTab", "inactiveTab"]), s(n, "targets", ["tab", "panel", "select"]), s(n, "values", { index: 0, updateAnchor: Boolean, scrollToAnchor: Boolean, scrollActiveTabIntoView: Boolean });
  var f = class extends Controller {
    toggle(t) {
      this.openValue = !this.openValue, this.animate();
    }
    toggleInput(t) {
      this.openValue = t.target.checked, this.animate();
    }
    hide() {
      this.openValue = false, this.animate();
    }
    show() {
      this.openValue = true, this.animate();
    }
    animate() {
      this.toggleableTargets.forEach((t) => {
        r(t, this.openValue);
      });
    }
  };
  s(f, "targets", ["toggleable"]), s(f, "values", { open: { type: Boolean, default: false } });

  // ../../node_modules/@stimulus/polyfills/index.js
  var import_find = __toESM(require_find());
  var import_find_index = __toESM(require_find_index());
  var import_from = __toESM(require_from());
  var import_map = __toESM(require_map());
  var import_assign = __toESM(require_assign());
  var import_promise = __toESM(require_promise());
  var import_set = __toESM(require_set());
  var import_starts_with = __toESM(require_starts_with());

  // ../../node_modules/element-closest/element-closest.js
  (function(ElementProto) {
    if (typeof ElementProto.matches !== "function") {
      ElementProto.matches = ElementProto.msMatchesSelector || ElementProto.mozMatchesSelector || ElementProto.webkitMatchesSelector || function matches(selector) {
        var element = this;
        var elements = (element.document || element.ownerDocument).querySelectorAll(selector);
        var index = 0;
        while (elements[index] && elements[index] !== element) {
          ++index;
        }
        return Boolean(elements[index]);
      };
    }
    if (typeof ElementProto.closest !== "function") {
      ElementProto.closest = function closest(selector) {
        var element = this;
        while (element && element.nodeType === 1) {
          if (element.matches(selector)) {
            return element;
          }
          element = element.parentNode;
        }
        return null;
      };
    }
  })(window.Element.prototype);

  // ../../node_modules/mutation-observer-inner-html-shim/mutation-observer-inner-html-shim.js
  if (window.MutationObserver) {
    element = document.createElement("div");
    element.innerHTML = "<div><div></div></div>";
    new MutationObserver(function(mutations, observer) {
      observer.disconnect();
      if (mutations[0] && mutations[0].type == "childList" && mutations[0].removedNodes[0].childNodes.length == 0) {
        var prototype = HTMLElement.prototype;
        var descriptor = Object.getOwnPropertyDescriptor(prototype, "innerHTML");
        if (descriptor && descriptor.set) {
          Object.defineProperty(prototype, "innerHTML", {
            set: function(value) {
              while (this.lastChild) this.removeChild(this.lastChild);
              descriptor.set.call(this, value);
            }
          });
        }
      }
    }).observe(element, { childList: true, subtree: true });
    element.innerHTML = "";
  }
  var element;

  // ../../node_modules/@stimulus/polyfills/index.js
  var import_eventlistener_polyfill = __toESM(require_src());
  if (typeof SVGElement.prototype.contains != "function") {
    SVGElement.prototype.contains = function(node) {
      return this === node || this.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_CONTAINED_BY;
    };
  }

  // ../../node_modules/@cable_ready/polyfills/index.js
  var import_flat = __toESM(require_flat());
  var import_for_each = __toESM(require_for_each());
  var import_from2 = __toESM(require_from());
  var import_includes = __toESM(require_includes());
  var import_entries = __toESM(require_entries());
  var import_promise2 = __toESM(require_promise());

  // ../../node_modules/@cable_ready/polyfills/polyfills/custom-event/custom-event.js
  (function() {
    if (typeof window.CustomEvent === "function") return false;
    function CustomEvent2(event, params2) {
      params2 = params2 || { bubbles: false, cancelable: false, detail: null };
      var evt = document.createEvent("CustomEvent");
      evt.initCustomEvent(event, params2.bubbles, params2.cancelable, params2.detail);
      return evt;
    }
    window.CustomEvent = CustomEvent2;
  })();

  // ../../node_modules/@webcomponents/template/template.js
  (function() {
    "use strict";
    var needsTemplate = typeof HTMLTemplateElement === "undefined";
    var brokenDocFragment = !(document.createDocumentFragment().cloneNode() instanceof DocumentFragment);
    var needsDocFrag = false;
    if (/Trident/.test(navigator.userAgent)) {
      (function() {
        needsDocFrag = true;
        var origCloneNode = Node.prototype.cloneNode;
        Node.prototype.cloneNode = function cloneNode2(deep) {
          var newDom = origCloneNode.call(this, deep);
          if (this instanceof DocumentFragment) {
            newDom.__proto__ = DocumentFragment.prototype;
          }
          return newDom;
        };
        DocumentFragment.prototype.querySelectorAll = HTMLElement.prototype.querySelectorAll;
        DocumentFragment.prototype.querySelector = HTMLElement.prototype.querySelector;
        Object.defineProperties(DocumentFragment.prototype, {
          "nodeType": {
            get: function() {
              return Node.DOCUMENT_FRAGMENT_NODE;
            },
            configurable: true
          },
          "localName": {
            get: function() {
              return void 0;
            },
            configurable: true
          },
          "nodeName": {
            get: function() {
              return "#document-fragment";
            },
            configurable: true
          }
        });
        var origInsertBefore = Node.prototype.insertBefore;
        function insertBefore(newNode, refNode) {
          if (newNode instanceof DocumentFragment) {
            var child;
            while (child = newNode.firstChild) {
              origInsertBefore.call(this, child, refNode);
            }
          } else {
            origInsertBefore.call(this, newNode, refNode);
          }
          return newNode;
        }
        Node.prototype.insertBefore = insertBefore;
        var origAppendChild = Node.prototype.appendChild;
        Node.prototype.appendChild = function appendChild(child) {
          if (child instanceof DocumentFragment) {
            insertBefore.call(this, child, null);
          } else {
            origAppendChild.call(this, child);
          }
          return child;
        };
        var origRemoveChild = Node.prototype.removeChild;
        var origReplaceChild = Node.prototype.replaceChild;
        Node.prototype.replaceChild = function replaceChild(newChild, oldChild) {
          if (newChild instanceof DocumentFragment) {
            insertBefore.call(this, newChild, oldChild);
            origRemoveChild.call(this, oldChild);
          } else {
            origReplaceChild.call(this, newChild, oldChild);
          }
          return oldChild;
        };
        Document.prototype.createDocumentFragment = function createDocumentFragment2() {
          var frag = this.createElement("df");
          frag.__proto__ = DocumentFragment.prototype;
          return frag;
        };
        var origImportNode = Document.prototype.importNode;
        Document.prototype.importNode = function importNode2(impNode, deep) {
          deep = deep || false;
          var newNode = origImportNode.call(this, impNode, deep);
          if (impNode instanceof DocumentFragment) {
            newNode.__proto__ = DocumentFragment.prototype;
          }
          return newNode;
        };
      })();
    }
    var capturedCloneNode = Node.prototype.cloneNode;
    var capturedCreateElement = Document.prototype.createElement;
    var capturedImportNode = Document.prototype.importNode;
    var capturedRemoveChild = Node.prototype.removeChild;
    var capturedAppendChild = Node.prototype.appendChild;
    var capturedReplaceChild = Node.prototype.replaceChild;
    var capturedParseFromString = DOMParser.prototype.parseFromString;
    var capturedHTMLElementInnerHTML = Object.getOwnPropertyDescriptor(
      window.HTMLElement.prototype,
      "innerHTML"
    ) || {
      /**
       * @this {!HTMLElement}
       * @return {string}
       */
      get: function() {
        return this.innerHTML;
      },
      /**
       * @this {!HTMLElement}
       * @param {string}
       */
      set: function(text) {
        this.innerHTML = text;
      }
    };
    var capturedChildNodes = Object.getOwnPropertyDescriptor(
      window.Node.prototype,
      "childNodes"
    ) || {
      /**
       * @this {!Node}
       * @return {!NodeList}
       */
      get: function() {
        return this.childNodes;
      }
    };
    var elementQuerySelectorAll = Element.prototype.querySelectorAll;
    var docQuerySelectorAll = Document.prototype.querySelectorAll;
    var fragQuerySelectorAll = DocumentFragment.prototype.querySelectorAll;
    var scriptSelector = 'script:not([type]),script[type="application/javascript"],script[type="text/javascript"]';
    function QSA(node, selector) {
      if (!node.childNodes.length) {
        return [];
      }
      switch (node.nodeType) {
        case Node.DOCUMENT_NODE:
          return docQuerySelectorAll.call(node, selector);
        case Node.DOCUMENT_FRAGMENT_NODE:
          return fragQuerySelectorAll.call(node, selector);
        default:
          return elementQuerySelectorAll.call(node, selector);
      }
    }
    var needsCloning = function() {
      if (!needsTemplate) {
        var t = document.createElement("template");
        var t2 = document.createElement("template");
        t2.content.appendChild(document.createElement("div"));
        t.content.appendChild(t2);
        var clone = t.cloneNode(true);
        return clone.content.childNodes.length === 0 || clone.content.firstChild.content.childNodes.length === 0 || brokenDocFragment;
      }
    }();
    var TEMPLATE_TAG = "template";
    var PolyfilledHTMLTemplateElement = function() {
    };
    if (needsTemplate) {
      var contentDoc = document.implementation.createHTMLDocument("template");
      var canDecorate = true;
      var templateStyle = document.createElement("style");
      templateStyle.textContent = TEMPLATE_TAG + "{display:none;}";
      var head = document.head;
      head.insertBefore(templateStyle, head.firstElementChild);
      PolyfilledHTMLTemplateElement.prototype = Object.create(
        HTMLElement.prototype
      );
      var canProtoPatch = !document.createElement("div").hasOwnProperty("innerHTML");
      PolyfilledHTMLTemplateElement.decorate = function(template2) {
        if (template2.content || template2.namespaceURI !== document.documentElement.namespaceURI) {
          return;
        }
        template2.content = contentDoc.createDocumentFragment();
        var child;
        while (child = template2.firstChild) {
          capturedAppendChild.call(template2.content, child);
        }
        if (canProtoPatch) {
          template2.__proto__ = PolyfilledHTMLTemplateElement.prototype;
        } else {
          template2.cloneNode = function(deep) {
            return PolyfilledHTMLTemplateElement._cloneNode(this, deep);
          };
          if (canDecorate) {
            try {
              defineInnerHTML(template2);
              defineOuterHTML(template2);
            } catch (err) {
              canDecorate = false;
            }
          }
        }
        PolyfilledHTMLTemplateElement.bootstrap(template2.content);
      };
      var topLevelWrappingMap = {
        "option": ["select"],
        "thead": ["table"],
        "col": ["colgroup", "table"],
        "tr": ["tbody", "table"],
        "th": ["tr", "tbody", "table"],
        "td": ["tr", "tbody", "table"]
      };
      var getTagName = function(text) {
        return (/<([a-z][^/\0>\x20\t\r\n\f]+)/i.exec(text) || [
          "",
          ""
        ])[1].toLowerCase();
      };
      var defineInnerHTML = function defineInnerHTML2(obj) {
        Object.defineProperty(obj, "innerHTML", {
          get: function() {
            return getInnerHTML(this);
          },
          set: function(text) {
            var wrap = topLevelWrappingMap[getTagName(text)];
            if (wrap) {
              for (var i = 0; i < wrap.length; i++) {
                text = "<" + wrap[i] + ">" + text + "</" + wrap[i] + ">";
              }
            }
            contentDoc.body.innerHTML = text;
            PolyfilledHTMLTemplateElement.bootstrap(contentDoc);
            while (this.content.firstChild) {
              capturedRemoveChild.call(this.content, this.content.firstChild);
            }
            var body = contentDoc.body;
            if (wrap) {
              for (var j = 0; j < wrap.length; j++) {
                body = body.lastChild;
              }
            }
            while (body.firstChild) {
              capturedAppendChild.call(this.content, body.firstChild);
            }
          },
          configurable: true
        });
      };
      var defineOuterHTML = function defineOuterHTML2(obj) {
        Object.defineProperty(obj, "outerHTML", {
          get: function() {
            return `<${TEMPLATE_TAG}>${this.innerHTML}</${TEMPLATE_TAG}>`;
          },
          set: function(innerHTML3) {
            if (this.parentNode) {
              contentDoc.body.innerHTML = innerHTML3;
              var docFrag = this.ownerDocument.createDocumentFragment();
              while (contentDoc.body.firstChild) {
                capturedAppendChild.call(docFrag, contentDoc.body.firstChild);
              }
              capturedReplaceChild.call(this.parentNode, docFrag, this);
            } else {
              throw new Error(
                "Failed to set the 'outerHTML' property on 'Element': This element has no parent node."
              );
            }
          },
          configurable: true
        });
      };
      defineInnerHTML(PolyfilledHTMLTemplateElement.prototype);
      defineOuterHTML(PolyfilledHTMLTemplateElement.prototype);
      PolyfilledHTMLTemplateElement.bootstrap = function bootstrap(doc2) {
        var templates = QSA(doc2, TEMPLATE_TAG);
        for (var i = 0, l2 = templates.length, t; i < l2 && (t = templates[i]); i++) {
          PolyfilledHTMLTemplateElement.decorate(t);
        }
      };
      document.addEventListener("DOMContentLoaded", function() {
        PolyfilledHTMLTemplateElement.bootstrap(document);
      });
      Document.prototype.createElement = function createElement() {
        var el = capturedCreateElement.apply(this, arguments);
        if (el.localName === "template") {
          PolyfilledHTMLTemplateElement.decorate(el);
        }
        return el;
      };
      DOMParser.prototype.parseFromString = function() {
        var el = capturedParseFromString.apply(this, arguments);
        PolyfilledHTMLTemplateElement.bootstrap(el);
        return el;
      };
      Object.defineProperty(HTMLElement.prototype, "innerHTML", {
        get: function() {
          return getInnerHTML(this);
        },
        set: function(text) {
          capturedHTMLElementInnerHTML.set.call(this, text);
          PolyfilledHTMLTemplateElement.bootstrap(this);
        },
        configurable: true,
        enumerable: true
      });
      var escapeAttrRegExp = /[&\u00A0"]/g;
      var escapeDataRegExp = /[&\u00A0<>]/g;
      var escapeReplace = function(c2) {
        switch (c2) {
          case "&":
            return "&amp;";
          case "<":
            return "&lt;";
          case ">":
            return "&gt;";
          case '"':
            return "&quot;";
          case "\xA0":
            return "&nbsp;";
        }
      };
      var escapeAttr = function(s2) {
        return s2.replace(escapeAttrRegExp, escapeReplace);
      };
      var escapeData = function(s2) {
        return s2.replace(escapeDataRegExp, escapeReplace);
      };
      var makeSet = function(arr) {
        var set = {};
        for (var i = 0; i < arr.length; i++) {
          set[arr[i]] = true;
        }
        return set;
      };
      var voidElements = makeSet([
        "area",
        "base",
        "br",
        "col",
        "command",
        "embed",
        "hr",
        "img",
        "input",
        "keygen",
        "link",
        "meta",
        "param",
        "source",
        "track",
        "wbr"
      ]);
      var plaintextParents = makeSet([
        "style",
        "script",
        "xmp",
        "iframe",
        "noembed",
        "noframes",
        "plaintext",
        "noscript"
      ]);
      var getOuterHTML = function(node, parentNode, callback) {
        switch (node.nodeType) {
          case Node.ELEMENT_NODE: {
            var tagName = node.localName;
            var s2 = "<" + tagName;
            var attrs = node.attributes;
            for (var i = 0, attr; attr = attrs[i]; i++) {
              s2 += " " + attr.name + '="' + escapeAttr(attr.value) + '"';
            }
            s2 += ">";
            if (voidElements[tagName]) {
              return s2;
            }
            return s2 + getInnerHTML(node, callback) + "</" + tagName + ">";
          }
          case Node.TEXT_NODE: {
            var data = (
              /** @type {Text} */
              node.data
            );
            if (parentNode && plaintextParents[parentNode.localName]) {
              return data;
            }
            return escapeData(data);
          }
          case Node.COMMENT_NODE: {
            return "<!--" + /** @type {Comment} */
            node.data + "-->";
          }
          default: {
            window.console.error(node);
            throw new Error("not implemented");
          }
        }
      };
      var getInnerHTML = function(node, callback) {
        if (node.localName === "template") {
          node = /** @type {HTMLTemplateElement} */
          node.content;
        }
        var s2 = "";
        var c$ = callback ? callback(node) : capturedChildNodes.get.call(node);
        for (var i = 0, l2 = c$.length, child; i < l2 && (child = c$[i]); i++) {
          s2 += getOuterHTML(child, node, callback);
        }
        return s2;
      };
    }
    if (needsTemplate || needsCloning) {
      PolyfilledHTMLTemplateElement._cloneNode = function _cloneNode(template2, deep) {
        var clone = capturedCloneNode.call(template2, false);
        if (this.decorate) {
          this.decorate(clone);
        }
        if (deep) {
          capturedAppendChild.call(
            clone.content,
            capturedCloneNode.call(template2.content, true)
          );
          fixClonedDom(clone.content, template2.content);
        }
        return clone;
      };
      var fixClonedDom = function fixClonedDom2(clone, source) {
        if (!source.querySelectorAll) {
          return;
        }
        var s$ = QSA(source, TEMPLATE_TAG);
        if (s$.length === 0) {
          return;
        }
        var t$ = QSA(clone, TEMPLATE_TAG);
        for (var i = 0, l2 = t$.length, t, s2; i < l2; i++) {
          s2 = s$[i];
          t = t$[i];
          if (PolyfilledHTMLTemplateElement && PolyfilledHTMLTemplateElement.decorate) {
            PolyfilledHTMLTemplateElement.decorate(s2);
          }
          capturedReplaceChild.call(t.parentNode, cloneNode.call(s2, true), t);
        }
      };
      var fixClonedScripts = function fixClonedScripts2(fragment) {
        var scripts3 = QSA(fragment, scriptSelector);
        for (var ns, s2, i = 0; i < scripts3.length; i++) {
          s2 = scripts3[i];
          ns = capturedCreateElement.call(document, "script");
          ns.textContent = s2.textContent;
          var attrs = s2.attributes;
          for (var ai = 0, a; ai < attrs.length; ai++) {
            a = attrs[ai];
            ns.setAttribute(a.name, a.value);
          }
          capturedReplaceChild.call(s2.parentNode, ns, s2);
        }
      };
      var cloneNode = Node.prototype.cloneNode = function cloneNode2(deep) {
        var dom;
        if (!needsDocFrag && brokenDocFragment && this instanceof DocumentFragment) {
          if (!deep) {
            return this.ownerDocument.createDocumentFragment();
          } else {
            dom = importNode.call(this.ownerDocument, this, true);
          }
        } else if (this.nodeType === Node.ELEMENT_NODE && this.localName === TEMPLATE_TAG && this.namespaceURI == document.documentElement.namespaceURI) {
          dom = PolyfilledHTMLTemplateElement._cloneNode(this, deep);
        } else {
          dom = capturedCloneNode.call(this, deep);
        }
        if (deep) {
          fixClonedDom(dom, this);
        }
        return dom;
      };
      var importNode = Document.prototype.importNode = function importNode2(element, deep) {
        deep = deep || false;
        if (element.localName === TEMPLATE_TAG) {
          return PolyfilledHTMLTemplateElement._cloneNode(element, deep);
        } else {
          var dom = capturedImportNode.call(this, element, deep);
          if (deep) {
            fixClonedDom(dom, element);
            fixClonedScripts(dom);
          }
          return dom;
        }
      };
    }
    if (needsTemplate) {
      window.HTMLTemplateElement = PolyfilledHTMLTemplateElement;
    }
  })();

  // ../../node_modules/@stimulus_reflex/polyfills/index.js
  var import_starts_with2 = __toESM(require_starts_with());
  var import_includes2 = __toESM(require_includes2());
  var import_delete_property = __toESM(require_delete_property());

  // ../../node_modules/@stimulus_reflex/polyfills/polyfills/node-list/for-each.js
  (function() {
    if (window.NodeList && !NodeList.prototype.forEach) {
      NodeList.prototype.forEach = Array.prototype.forEach;
    }
  })();

  // ../../node_modules/formdata-polyfill/formdata.min.js
  (function() {
    var h2;
    function l2(a) {
      var c2 = 0;
      return function() {
        return c2 < a.length ? { done: false, value: a[c2++] } : { done: true };
      };
    }
    var m2 = "function" == typeof Object.defineProperties ? Object.defineProperty : function(a, c2, b2) {
      if (a == Array.prototype || a == Object.prototype) return a;
      a[c2] = b2.value;
      return a;
    };
    function n2(a) {
      a = ["object" == typeof globalThis && globalThis, a, "object" == typeof window && window, "object" == typeof self && self, "object" == typeof global && global];
      for (var c2 = 0; c2 < a.length; ++c2) {
        var b2 = a[c2];
        if (b2 && b2.Math == Math) return b2;
      }
      throw Error("Cannot find global object");
    }
    var p2 = n2(this);
    function r2(a, c2) {
      if (c2) {
        for (var b2 = p2, d2 = a.split("."), e = 0; e < d2.length - 1; e++) {
          var f2 = d2[e];
          f2 in b2 || (b2[f2] = {});
          b2 = b2[f2];
        }
        d2 = d2[d2.length - 1];
        e = b2[d2];
        f2 = c2(e);
        f2 != e && null != f2 && m2(b2, d2, { configurable: true, writable: true, value: f2 });
      }
    }
    r2("Symbol", function(a) {
      function c2(e) {
        if (this instanceof c2) throw new TypeError("Symbol is not a constructor");
        return new b2("jscomp_symbol_" + (e || "") + "_" + d2++, e);
      }
      function b2(e, f2) {
        this.o = e;
        m2(this, "description", { configurable: true, writable: true, value: f2 });
      }
      if (a) return a;
      b2.prototype.toString = function() {
        return this.o;
      };
      var d2 = 0;
      return c2;
    });
    r2("Symbol.iterator", function(a) {
      if (a) return a;
      a = Symbol("Symbol.iterator");
      for (var c2 = "Array Int8Array Uint8Array Uint8ClampedArray Int16Array Uint16Array Int32Array Uint32Array Float32Array Float64Array".split(" "), b2 = 0; b2 < c2.length; b2++) {
        var d2 = p2[c2[b2]];
        "function" === typeof d2 && "function" != typeof d2.prototype[a] && m2(d2.prototype, a, { configurable: true, writable: true, value: function() {
          return u2(l2(this));
        } });
      }
      return a;
    });
    function u2(a) {
      a = { next: a };
      a[Symbol.iterator] = function() {
        return this;
      };
      return a;
    }
    function v2(a) {
      var c2 = "undefined" != typeof Symbol && Symbol.iterator && a[Symbol.iterator];
      return c2 ? c2.call(a) : { next: l2(a) };
    }
    var w;
    if ("function" == typeof Object.setPrototypeOf) w = Object.setPrototypeOf;
    else {
      var y;
      a: {
        var z = { u: true }, A = {};
        try {
          A.__proto__ = z;
          y = A.u;
          break a;
        } catch (a) {
        }
        y = false;
      }
      w = y ? function(a, c2) {
        a.__proto__ = c2;
        if (a.__proto__ !== c2) throw new TypeError(a + " is not extensible");
        return a;
      } : null;
    }
    var B = w;
    function C2() {
      this.h = false;
      this.f = null;
      this.m = void 0;
      this.b = 1;
      this.l = this.v = 0;
      this.g = null;
    }
    function D(a) {
      if (a.h) throw new TypeError("Generator is already running");
      a.h = true;
    }
    C2.prototype.i = function(a) {
      this.m = a;
    };
    C2.prototype.j = function(a) {
      this.g = { w: a, A: true };
      this.b = this.v || this.l;
    };
    C2.prototype["return"] = function(a) {
      this.g = { "return": a };
      this.b = this.l;
    };
    function E(a, c2) {
      a.b = 3;
      return { value: c2 };
    }
    function F(a) {
      this.a = new C2();
      this.B = a;
    }
    F.prototype.i = function(a) {
      D(this.a);
      if (this.a.f) return G(this, this.a.f.next, a, this.a.i);
      this.a.i(a);
      return H(this);
    };
    function I(a, c2) {
      D(a.a);
      var b2 = a.a.f;
      if (b2) return G(a, "return" in b2 ? b2["return"] : function(d2) {
        return { value: d2, done: true };
      }, c2, a.a["return"]);
      a.a["return"](c2);
      return H(a);
    }
    F.prototype.j = function(a) {
      D(this.a);
      if (this.a.f) return G(this, this.a.f["throw"], a, this.a.i);
      this.a.j(a);
      return H(this);
    };
    function G(a, c2, b2, d2) {
      try {
        var e = c2.call(a.a.f, b2);
        if (!(e instanceof Object)) throw new TypeError("Iterator result " + e + " is not an object");
        if (!e.done) return a.a.h = false, e;
        var f2 = e.value;
      } catch (g) {
        return a.a.f = null, a.a.j(g), H(a);
      }
      a.a.f = null;
      d2.call(a.a, f2);
      return H(a);
    }
    function H(a) {
      for (; a.a.b; ) try {
        var c2 = a.B(a.a);
        if (c2) return a.a.h = false, { value: c2.value, done: false };
      } catch (b2) {
        a.a.m = void 0, a.a.j(b2);
      }
      a.a.h = false;
      if (a.a.g) {
        c2 = a.a.g;
        a.a.g = null;
        if (c2.A) throw c2.w;
        return { value: c2["return"], done: true };
      }
      return { value: void 0, done: true };
    }
    function J(a) {
      this.next = function(c2) {
        return a.i(c2);
      };
      this["throw"] = function(c2) {
        return a.j(c2);
      };
      this["return"] = function(c2) {
        return I(a, c2);
      };
      this[Symbol.iterator] = function() {
        return this;
      };
    }
    function K(a, c2) {
      var b2 = new J(new F(c2));
      B && B(b2, a.prototype);
      return b2;
    }
    if ("undefined" !== typeof Blob && ("undefined" === typeof FormData || !FormData.prototype.keys)) {
      var L = function(a, c2) {
        for (var b2 = 0; b2 < a.length; b2++) c2(a[b2]);
      }, M = function(a, c2, b2) {
        return c2 instanceof Blob ? [String(a), c2, void 0 !== b2 ? b2 + "" : "string" === typeof c2.name ? c2.name : "blob"] : [String(a), String(c2)];
      }, N = function(a, c2) {
        if (a.length < c2) throw new TypeError(c2 + " argument required, but only " + a.length + " present.");
      }, O = function(a) {
        var c2 = v2(a);
        a = c2.next().value;
        var b2 = c2.next().value;
        c2 = c2.next().value;
        b2 instanceof Blob && (b2 = new File(
          [b2],
          c2,
          { type: b2.type, lastModified: b2.lastModified }
        ));
        return [a, b2];
      }, P = "object" === typeof globalThis ? globalThis : "object" === typeof window ? window : "object" === typeof self ? self : this, Q = P.FormData, R = P.XMLHttpRequest && P.XMLHttpRequest.prototype.send, S = P.Request && P.fetch, T2 = P.navigator && P.navigator.sendBeacon, U = P.Element && P.Element.prototype, V2 = P.Symbol && Symbol.toStringTag;
      V2 && (Blob.prototype[V2] || (Blob.prototype[V2] = "Blob"), "File" in P && !File.prototype[V2] && (File.prototype[V2] = "File"));
      try {
        new File([], "");
      } catch (a) {
        P.File = function(c2, b2, d2) {
          c2 = new Blob(c2, d2);
          d2 = d2 && void 0 !== d2.lastModified ? new Date(d2.lastModified) : /* @__PURE__ */ new Date();
          Object.defineProperties(c2, { name: { value: b2 }, lastModifiedDate: { value: d2 }, lastModified: { value: +d2 }, toString: { value: function() {
            return "[object File]";
          } } });
          V2 && Object.defineProperty(c2, V2, { value: "File" });
          return c2;
        };
      }
      var W = function(a) {
        this.c = [];
        var c2 = this;
        a && L(a.elements, function(b2) {
          if (b2.name && !b2.disabled && "submit" !== b2.type && "button" !== b2.type && !b2.matches("form fieldset[disabled] *")) if ("file" === b2.type) {
            var d2 = b2.files && b2.files.length ? b2.files : [new File([], "", { type: "application/octet-stream" })];
            L(d2, function(e) {
              c2.append(b2.name, e);
            });
          } else "select-multiple" === b2.type || "select-one" === b2.type ? L(b2.options, function(e) {
            !e.disabled && e.selected && c2.append(b2.name, e.value);
          }) : "checkbox" === b2.type || "radio" === b2.type ? b2.checked && c2.append(b2.name, b2.value) : (d2 = "textarea" === b2.type ? b2.value.replace(/\r\n/g, "\n").replace(/\n/g, "\r\n") : b2.value, c2.append(b2.name, d2));
        });
      };
      h2 = W.prototype;
      h2.append = function(a, c2, b2) {
        N(arguments, 2);
        this.c.push(M(a, c2, b2));
      };
      h2["delete"] = function(a) {
        N(
          arguments,
          1
        );
        var c2 = [];
        a = String(a);
        L(this.c, function(b2) {
          b2[0] !== a && c2.push(b2);
        });
        this.c = c2;
      };
      h2.entries = function c2() {
        var b2, d2 = this;
        return K(c2, function(e) {
          1 == e.b && (b2 = 0);
          if (3 != e.b) return b2 < d2.c.length ? e = E(e, O(d2.c[b2])) : (e.b = 0, e = void 0), e;
          b2++;
          e.b = 2;
        });
      };
      h2.forEach = function(c2, b2) {
        N(arguments, 1);
        for (var d2 = v2(this), e = d2.next(); !e.done; e = d2.next()) {
          var f2 = v2(e.value);
          e = f2.next().value;
          f2 = f2.next().value;
          c2.call(b2, f2, e, this);
        }
      };
      h2.get = function(c2) {
        N(arguments, 1);
        var b2 = this.c;
        c2 = String(c2);
        for (var d2 = 0; d2 < b2.length; d2++) if (b2[d2][0] === c2) return O(b2[d2])[1];
        return null;
      };
      h2.getAll = function(c2) {
        N(arguments, 1);
        var b2 = [];
        c2 = String(c2);
        L(this.c, function(d2) {
          d2[0] === c2 && b2.push(O(d2)[1]);
        });
        return b2;
      };
      h2.has = function(c2) {
        N(arguments, 1);
        c2 = String(c2);
        for (var b2 = 0; b2 < this.c.length; b2++) if (this.c[b2][0] === c2) return true;
        return false;
      };
      h2.keys = function b2() {
        var d2 = this, e, f2, g, k, q;
        return K(b2, function(t) {
          1 == t.b && (e = v2(d2), f2 = e.next());
          if (3 != t.b) {
            if (f2.done) {
              t.b = 0;
              return;
            }
            g = f2.value;
            k = v2(g);
            q = k.next().value;
            return E(t, q);
          }
          f2 = e.next();
          t.b = 2;
        });
      };
      h2.set = function(b2, d2, e) {
        N(arguments, 2);
        b2 = String(b2);
        var f2 = [], g = M(
          b2,
          d2,
          e
        ), k = true;
        L(this.c, function(q) {
          q[0] === b2 ? k && (k = !f2.push(g)) : f2.push(q);
        });
        k && f2.push(g);
        this.c = f2;
      };
      h2.values = function d2() {
        var e = this, f2, g, k, q, t;
        return K(d2, function(x2) {
          1 == x2.b && (f2 = v2(e), g = f2.next());
          if (3 != x2.b) {
            if (g.done) {
              x2.b = 0;
              return;
            }
            k = g.value;
            q = v2(k);
            q.next();
            t = q.next().value;
            return E(x2, t);
          }
          g = f2.next();
          x2.b = 2;
        });
      };
      W.prototype._asNative = function() {
        for (var d2 = new Q(), e = v2(this), f2 = e.next(); !f2.done; f2 = e.next()) {
          var g = v2(f2.value);
          f2 = g.next().value;
          g = g.next().value;
          d2.append(f2, g);
        }
        return d2;
      };
      W.prototype._blob = function() {
        for (var d2 = "----formdata-polyfill-" + Math.random(), e = [], f2 = v2(this), g = f2.next(); !g.done; g = f2.next()) {
          var k = v2(g.value);
          g = k.next().value;
          k = k.next().value;
          e.push("--" + d2 + "\r\n");
          k instanceof Blob ? e.push('Content-Disposition: form-data; name="' + g + '"; filename="' + k.name + '"\r\nContent-Type: ' + ((k.type || "application/octet-stream") + "\r\n\r\n"), k, "\r\n") : e.push('Content-Disposition: form-data; name="' + g + '"\r\n\r\n' + k + "\r\n");
        }
        e.push("--" + d2 + "--");
        return new Blob(e, { type: "multipart/form-data; boundary=" + d2 });
      };
      W.prototype[Symbol.iterator] = function() {
        return this.entries();
      };
      W.prototype.toString = function() {
        return "[object FormData]";
      };
      U && !U.matches && (U.matches = U.matchesSelector || U.mozMatchesSelector || U.msMatchesSelector || U.oMatchesSelector || U.webkitMatchesSelector || function(d2) {
        d2 = (this.document || this.ownerDocument).querySelectorAll(d2);
        for (var e = d2.length; 0 <= --e && d2.item(e) !== this; ) ;
        return -1 < e;
      });
      V2 && (W.prototype[V2] = "FormData");
      if (R) {
        var X = P.XMLHttpRequest.prototype.setRequestHeader;
        P.XMLHttpRequest.prototype.setRequestHeader = function(d2, e) {
          X.call(
            this,
            d2,
            e
          );
          "content-type" === d2.toLowerCase() && (this.s = true);
        };
        P.XMLHttpRequest.prototype.send = function(d2) {
          d2 instanceof W ? (d2 = d2._blob(), this.s || this.setRequestHeader("Content-Type", d2.type), R.call(this, d2)) : R.call(this, d2);
        };
      }
      S && (P.fetch = function(d2, e) {
        e && e.body && e.body instanceof W && (e.body = e.body._blob());
        return S.call(this, d2, e);
      });
      T2 && (P.navigator.sendBeacon = function(d2, e) {
        e instanceof W && (e = e._asNative());
        return T2.call(this, d2, e);
      });
      P.FormData = W;
    }
    ;
  })();

  // controllers/index.js
  controller_default.forEach((controller) => {
    application.register(controller.name, controller.module.default);
  });
  application.register("dropdown", l);
  application.register("filter-popup", filter_popup_controller_default);
  application.register("clipboard", clipboard_controller_default);
  application.register("pagy-url", pagy_url_controller_default);
  global3.initialize(application, {
    consumer: consumer_default,
    controller: application_controller_default,
    debug: true
  });

  // application.js
  var import_hotkeys = __toESM(require_hotkeys());

  // scoreboard_utils.js
  function tryResizeWindow() {
    try {
      window.resizeTo(window.screen.width, window.screen.height);
      window.moveTo(0, 0);
    } catch (e) {
      console.log("resizeTo/moveTo failed:", e);
    }
    try {
      if (document.documentElement.requestFullscreen) {
        document.documentElement.requestFullscreen();
      } else if (document.documentElement.webkitRequestFullscreen) {
        document.documentElement.webkitRequestFullscreen();
      } else if (document.documentElement.mozRequestFullScreen) {
        document.documentElement.mozRequestFullScreen();
      } else if (document.documentElement.msRequestFullscreen) {
        document.documentElement.msRequestFullscreen();
      }
    } catch (e) {
      console.log("Fullscreen API failed:", e);
    }
  }
  window.tryResizeWindow = tryResizeWindow;

  // application.js
  turbo_es2017_esm_exports.session.debug = true;
  require_activestorage().start();
  require_local_time_es2017_umd().start();
  window.hotkeys = import_hotkeys.default;
  console.log("ActionCable Consumer:", consumer_default);
  console.log("StimulusReflex Version:", StimulusReflex.version);
  if (!Element.prototype.hasAttribute) {
    Element.prototype.hasAttribute = function(name3) {
      return this.attributes.getNamedItem(name3) !== null;
    };
  }
})();
/*! Bundled license information:

clipboard/dist/clipboard.js:
  (*!
   * clipboard.js v2.0.11
   * https://clipboardjs.com/
   *
   * Licensed MIT © Zeno Rocha
   *)

@hotwired/turbo/dist/turbo.es2017-esm.js:
  (*!
  Turbo 8.0.4
  Copyright © 2024 37signals LLC
   *)

stimulus_reflex/dist/stimulus_reflex.js:
  (*!
   * Toastify js 1.12.0
   * https://github.com/apvarun/toastify-js
   * @license MIT licensed
   *
   * Copyright (C) 2018 Varun A P
   *)

@webcomponents/template/template.js:
  (**
   * @license
   * Copyright (c) 2016 The Polymer Project Authors. All rights reserved.
   * This code may only be used under the BSD style license found at http://polymer.github.io/LICENSE.txt
   * The complete set of authors may be found at http://polymer.github.io/AUTHORS.txt
   * The complete set of contributors may be found at http://polymer.github.io/CONTRIBUTORS.txt
   * Code distributed by Google as part of the polymer project is also
   * subject to an additional IP rights grant found at http://polymer.github.io/PATENTS.txt
   *)
*/
//# sourceMappingURL=/assets/application.js-172754a28b7e4a6fd61de184ad96ed3b4eabd240429897ccd46c74fe3f735306.map
//!
;
