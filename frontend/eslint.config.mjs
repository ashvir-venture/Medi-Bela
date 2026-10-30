// ESLint for the management panel: Next's own rules (core web vitals) and its
// TypeScript rules, as `create-next-app` sets them up for Next 15. Run with
// `npm run lint`; `next build` runs the same checks.
import { dirname } from 'path';
import { fileURLToPath } from 'url';
import { FlatCompat } from '@eslint/eslintrc';

const compat = new FlatCompat({ baseDirectory: dirname(fileURLToPath(import.meta.url)) });

const eslintConfig = [
  ...compat.extends('next/core-web-vitals', 'next/typescript'),
  {
    ignores: ['node_modules/**', '.next/**', 'out/**', 'next-env.d.ts', 'src/lib/public-content.ts'],
  },
];

export default eslintConfig;
