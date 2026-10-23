import {test} from 'node:test';
import assert from 'node:assert/strict';
import {contentViolations,componentViolations} from './ui-standards-rules.mjs';
test('boundary rejects direct native-looking content controls and browser confirmations',()=>{
 for(const snippet of ['<button onClick={save}>保存</button>','<select/>','<input type="range"/>',"<input type={'checkbox'}/>",'window.confirm("删除？")'])assert(contentViolations(snippet,'Shared/UI/src/Page.jsx').length>0,snippet);
});
test('boundary permits owned controls, IME text fields and the sole button primitive',()=>{
 assert.deepEqual(contentViolations('<ActionButton/><Choice/><input type="text"/><textarea/>','Shared/UI/src/Page.jsx'),[]);
 assert.deepEqual(contentViolations('<button {...props}/>','Shared/UI/src/components/ActionButton.jsx'),[]);
});

test('portable components reject host, storage, network and platform/page dependencies',()=>{
 const file='Shared/UI/src/components/Example.jsx';
 for(const source of ["import api from '../platform.js'", "import Page from '../../../../MacOS/Page.jsx'", "import x from './nested/../../platform.js'", "import('native-service')", 'MiniVoiceHost.play()', 'window.localStorage.getItem("x")', 'fetch(url)', 'new WebSocket(url)'])assert(componentViolations(source,file).length>0,source);
});
test('portable components permit DOM, React, sibling behavior and reviewed pure models',()=>{
 const source="import React from 'react'; import {createPortal} from 'react-dom'; import Slider from './Slider.jsx'; import {layoutFor} from '../presentation.js'; document.addEventListener('pointerdown', handler);";
 assert.deepEqual(componentViolations(source,'Shared/UI/src/components/Example.jsx'),[]);
 assert.deepEqual(componentViolations('MiniVoiceHost.play()','Shared/UI/src/platform.js'),[]);
});
