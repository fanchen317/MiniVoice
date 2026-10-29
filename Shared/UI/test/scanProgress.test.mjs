import test from 'node:test';
import assert from 'node:assert/strict';
import {scanProgress} from '../src/components/scanProgress.js';
test('scan discovery has no fabricated percentage; processing and pause remain visible',()=>{
 assert.equal(scanProgress({}).visible,false);
 const discovery=scanProgress({scanning:true,scanCompleted:30});
 assert.equal(discovery.percent,null);assert.match(discovery.title,/已发现 30/);
 const processing=scanProgress({scanning:true,scanCompleted:25,scanTotal:100,scanDetail:'读取封面'});
 assert.equal(processing.percent,25);assert.equal(processing.detail,'读取封面');
 assert.equal(scanProgress({scanning:true,scanCompleted:200,scanTotal:100}).percent,100);
 assert.equal(scanProgress({scanPaused:true}).paused,true);
 assert.equal(scanProgress({scanning:false,scanCompleted:100,scanTotal:100}).visible,false);
});
