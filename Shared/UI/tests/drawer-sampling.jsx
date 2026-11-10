import React,{useRef,useState} from 'react';
import {createRoot} from 'react-dom/client';
import DrawerMaterial from '../src/DrawerMaterial.jsx';
import WallDrawerBackdrop from '../src/WallDrawerBackdrop.jsx';
import DrawerLayer from '../src/components/DrawerLayer.jsx';
import '../src/player.css';
import '../src/wall.css';
import '../src/components/materials.css';
import '../src/mobileSurfaces.css';
import '../src/mobilePlayer.css';
const source=name=>`drawer-cover://image/${name}`;
const cells=name=>[{id:'one',artwork:source(name),x:0,y:0,width:260,height:900},{id:'two',artwork:source(name),x:260,y:0,width:600,height:900}];
function Lab(){
 const [state,set]=useState({open:false,mode:'wall',artwork:source('a'),cells:cells('a'),sourceKey:'a',mounted:true}),latest=useRef(state);latest.current=state;
 const wall=useRef({backdrop:()=>latest.current.cells});window.drawerSamplingFixture={set:value=>set(previous=>({...previous,...value})),cells,source};
 return <main className="mv-workspace style-wall theme-dark" data-presentation="mobile" data-input="touch" data-host="Android" style={{position:'fixed',inset:0}}>
  {state.mounted&&<><WallDrawerBackdrop open={state.open} wall={wall} sourceKey={state.sourceKey}/><div className={`mv-scene ${state.open?'is-drawer-behind':''}`} inert={state.open} style={{position:'absolute',inset:0,background:'#24382c'}}/>
  <DrawerLayer open={state.open} className="mv-drawer-shade"><section className="mv-drawer"><DrawerMaterial open={state.open} sampleKey={state.mode} wall={state.cells} artwork={state.artwork} sample={()=>state.cells}/><header><strong>合成侧栏</strong></header></section></DrawerLayer></>}
 </main>;
}
createRoot(document.getElementById('root')).render(<Lab/>);
