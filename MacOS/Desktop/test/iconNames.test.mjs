import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {desktopIconName} from '../src/iconNames.js';import {paths} from '../../../Shared/UI/src/components/iconPaths.js';
test('all existing desktop icon names resolve to app-drawn vectors',()=>{for(const file of fs.readdirSync(new URL('../public/symbols',import.meta.url))){if(file.endsWith('.png')){const name=file.slice(0,-4);assert.ok(paths[desktopIconName(name)],'Missing app icon '+name);}}});
