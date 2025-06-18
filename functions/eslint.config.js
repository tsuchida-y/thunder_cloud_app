const js = require("@eslint/js");
const googleConfig = require("eslint-config-google");

module.exports = [
  js.configs.recommended,
  googleConfig,
  {
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "module",
      globals: {
        console: "readonly",
        process: "readonly",
        Buffer: "readonly",
        __dirname: "readonly",
        __filename: "readonly",
        module: "readonly",
        require: "readonly",
        exports: "readonly",
        global: "readonly",
      },
    },
    rules: {
      "quotes": ["error", "double"],
      "indent": ["error", 2],
      "max-len": ["error", {"code": 120}],
      "no-undef": "error",
    },
  },
];