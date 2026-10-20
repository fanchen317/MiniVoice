import {test} from 'node:test';
import assert from 'node:assert/strict';
import {popoverPosition} from '../src/popoverPosition.js';
test('compact popovers stay inside the minimum window at every anchor edge',()=>{
  const viewport={width:304,height:600};
  for(const panel of [{width:240,height:76},{width:288,height:400},{width:208,height:190}])
    for(const x of [0,150,280])for(const y of [0,300,576])for(const above of [true,false]){
      const p=popoverPosition({left:x,right:x+24,top:y,bottom:y+24},panel,viewport,{above,align:'end'});
      assert.ok(p.left>=8&&p.left+panel.width<=296);
      assert.ok(p.top>=8&&p.top+panel.height<=592);
    }
});
test('short menus use their actual height and open next to the triggering control',()=>{
  const anchor={left:260,right:284,top:500,bottom:524};
  const p=popoverPosition(anchor,{width:208,height:190},{width:834,height:660},{above:true,align:'center'});
  assert.deepEqual(p,{left:168,top:304});
  const below=popoverPosition({left:100,right:124,top:30,bottom:54},{width:240,height:76},{width:304,height:600},{above:true});
  assert.deepEqual(below,{left:56,top:60});
});
