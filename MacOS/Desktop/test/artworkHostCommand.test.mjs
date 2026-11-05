import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
test('native subject analysis is reachable through the production IPC allowlist',()=>{
 const main=readFileSync(new URL('../electron/main.cjs',import.meta.url),'utf8');
 const declaration=main.match(/const actions = new Set\(\[([^\]]+)\]\)/)?.[1];
 assert.ok(declaration);assert.ok([...declaration.matchAll(/'([^']+)'/g)].some(m=>m[1]==='artworkSubjects'));
 const engine=readFileSync(new URL('../../Sources/MiniVoice/DesktopEngine.swift',import.meta.url),'utf8');
 assert.ok(engine.includes('case "artworkSubjects":'));
});
