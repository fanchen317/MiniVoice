import {test} from 'node:test';
import assert from 'node:assert/strict';
import {playerContentWidth,playerReflowFrames,responsivePlayerLayout,cancelPlayerReflow} from '../src/playerReflow.js';

test('native 680pt breakpoint uses content width after sidebar, padding and gap',()=>{
  assert.equal(playerContentWidth(704,false),680);
  assert.equal(playerContentWidth(703,false),679);
  assert.equal(playerContentWidth(1004,true),717);
  assert.equal(playerContentWidth(304,true),280);
});
test('reflow offsets are local to the moving panel, without double vertical movement',()=>{
  const oldPanel={x:300,y:600},newPanel={x:300,y:534};
  for(const [from,to] of [
    [{x:312,y:612,width:82,height:82},{x:312,y:553,width:44,height:44}],
    [{x:610,y:640,width:280,height:52},{x:490,y:630,width:280,height:52}]
  ]){
    const [first,last]=playerReflowFrames(from,to,oldPanel,newPanel);
    const [dx,dy]=first.translate.split(' ').map(parseFloat);
    assert.equal(oldPanel.x+to.x-newPanel.x+dx,from.x);
    assert.equal(oldPanel.y+to.y-newPanel.y+dy,from.y);
    assert.equal(first.width,`${from.width}px`);
    assert.equal(last.width,`${to.width}px`);
    assert.equal(last.translate,'0px 0px');
  }
});
test('continued resize retargets within 220ms and cancellation restores grid positioning',t=>{
  let time=100,rect={x:12,y:600,width:740,height:106};
  const layout={style:{height:''},getBoundingClientRect:()=>({height:148})};
  const animations=[],style={position:'',left:'',right:'',top:'',bottom:'',width:'',overflow:''};
  const panel={style,isConnected:true,getBoundingClientRect:()=>({...rect}),querySelectorAll:()=>[],querySelector:selector=>selector==='.player-layout'?layout:null,animate(frames,options){const animation={frames,options,finished:new Promise(()=>{}),cancel(){this.cancelled=true;}};animations.push(animation);return animation;}};
  const original=globalThis.document;
  globalThis.document={documentElement:{classList:{contains:()=>false}},querySelector:selector=>selector.includes('>.player')?panel:null};
  t.mock.method(performance,'now',()=>time);
  try{
    responsivePlayerLayout(()=>{rect={...rect,y:534,width:660,height:172};},{start:true});
    assert.equal(animations[0].options.duration,220);
    assert.equal(style.position,'absolute');
    assert.equal(layout.style.height,'148px');
    // A second window event must not restart a fresh 220ms transition.
    time=160;rect={...rect,y:580,height:126};
    responsivePlayerLayout(()=>{rect={...rect,y:534,width:640,height:172};});
    assert.equal(animations[0].cancelled,true);
    assert.equal(animations[1].options.duration,160);
    assert.equal(animations[1].frames[0].height,'126px');
    cancelPlayerReflow();
    assert.equal(style.position,'');assert.equal(style.left,'');
    assert.equal(layout.style.height,'');
    assert.equal(animations[1].cancelled,true);
  }finally{cancelPlayerReflow();globalThis.document=original;}
});
