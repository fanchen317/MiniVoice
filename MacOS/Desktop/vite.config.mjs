import { defineConfig } from 'vite';
import {fileURLToPath} from 'node:url';
const dependency=name=>fileURLToPath(new URL(`./node_modules/${name}`,import.meta.url));
export default defineConfig({ base: './', cacheDir:'../../.build/cache/vite/desktop', resolve:{alias:{react:dependency('react'),'react-dom':dependency('react-dom')}}, build: { target: 'chrome130' } });
