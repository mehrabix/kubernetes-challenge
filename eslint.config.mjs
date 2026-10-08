import js from '@eslint/js';

export default [
  js.configs.recommended,
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: 'commonjs',
      globals: {
        process: 'readonly',
        console: 'readonly',
        require: 'readonly',
        module: 'writable',
        __dirname: 'readonly',
        describe: 'readonly',
        it: 'readonly',
        afterEach: 'readonly',
        beforeEach: 'readonly'
      }
    },
    rules: {
      'no-unused-vars': 'warn'
    }
  },
  {
    ignores: ['node_modules/**', 'coverage/**']
  }
];
