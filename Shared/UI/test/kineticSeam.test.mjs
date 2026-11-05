import test from 'node:test';
import assert from 'node:assert/strict';
import {kineticSeam} from '../src/components/kineticModel.js';
test('desktop seam stays below the timed row and inside the canvas',()=>{
 const chars=[{start:1},{start:3}],layout={fontSize:30,glyphs:[{x:50,y:30},{x:50,y:90}]};
 assert.equal(kineticSeam(layout,chars,0,200,150),null);
 const a=kineticSeam(layout,chars,2,200,150),b=kineticSeam(layout,chars,4,200,150);
 assert.ok(a.y>30&&a.y<90);assert.ok(b.y>a.y);assert.equal(a.x+a.width/2,100);
 assert.equal(kineticSeam(layout,chars,4,200,100),null);
});
