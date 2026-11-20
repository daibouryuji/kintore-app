{{flutter_js}}
{{flutter_build_config}}

// iPhone（Safari 26.2以降）でも、より速い WebAssembly 版で動かす。
// 対応していないブラウザでは、自動的に従来の JavaScript 版で動く。
_flutter.loader.load({
  config: {
    wasmAllowList: {
      blink: true,
      webkit: true,
    },
  },
});
