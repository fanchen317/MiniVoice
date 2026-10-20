import {test} from 'node:test';
import assert from 'node:assert/strict';
import {backgroundTaskState} from '../src/backgroundTaskState.js';

test('idle state has no invented scan record',()=>{
  assert.deepEqual(backgroundTaskState({scanSummary:'尚未扫描'}),{active:0,hasScan:false,hasRecords:false,failed:false});
});
test('scan, queued AI jobs and model download all count as background work',()=>{
  const state={importing:true,jobs:[{finished:false},{finished:false},{finished:true}],tasks:{downloadingModel:true}};
  assert.equal(backgroundTaskState(state).active,4);
  assert.equal(backgroundTaskState(state,true).hasScan,true);
});
test('read completion records remain available until explicitly cleared',()=>{
  const state={importing:false,scanSummary:'歌单已载入',issues:['文件无法读取'],jobs:[{finished:true,failed:true}],tasks:{hasUnread:false}};
  assert.equal(backgroundTaskState(state).hasRecords,true);
  assert.equal(backgroundTaskState(state).failed,true);
  assert.equal(backgroundTaskState(state,true).hasScan,false);
  assert.equal(backgroundTaskState({...state,jobs:[]},true).hasRecords,false);
  assert.equal(backgroundTaskState({...state,jobs:[]},true).failed,false);
});
test('model failures and blocked AI status stay visible without running jobs',()=>{
  assert.equal(backgroundTaskState({tasks:{modelStatus:'下载失败',modelFailed:true}}).failed,true);
  const summary=backgroundTaskState({tasks:{notice:{title:'模型正在下载',message:'请稍后同步',kind:'warning'}}});
  assert.equal(summary.hasRecords,true);
  assert.equal(summary.active,0);
});
