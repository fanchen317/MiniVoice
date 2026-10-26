import test from 'node:test';
import assert from 'node:assert/strict';
import {wallDockPlacement} from '../src/motion.js';
test('expanded dock centers and only lifts settings inside its safety gap',()=>{
 assert.deepEqual(wallDockPlacement(1280,0,460),{left:410,toolsBottom:18});
 assert.deepEqual(wallDockPlacement(580,0,460),{left:60,toolsBottom:94});
 assert.deepEqual(wallDockPlacement(592,0,460),{left:66,toolsBottom:18});
 assert.deepEqual(wallDockPlacement(800,236,460),{left:288,toolsBottom:94});
 assert.deepEqual(wallDockPlacement(1200,284,460),{left:512,toolsBottom:18});
});
