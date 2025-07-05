const js = require('@eslint/js');

module.exports = [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: 'commonjs',
      globals: {
        console: 'readonly',
        process: 'readonly',
        Buffer: 'readonly',
        __dirname: 'readonly',
        __filename: 'readonly',
        module: 'readonly',
        require: 'readonly',
        exports: 'readonly',
        global: 'readonly',
        setTimeout: 'readonly',
        Promise: 'readonly',
      },
    },
    rules: {
      'quotes': ['error', 'single'],
      'indent': ['error', 2],
      'max-len': ['error', {'code': 120}],
      'no-undef': 'error',
      'no-unused-vars': 'warn',
    },
  },
];
