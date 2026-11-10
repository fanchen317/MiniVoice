import React,{useState} from 'react';
import {createRoot} from 'react-dom/client';
import ActionButton from '../src/components/ActionButton.jsx';
import DrawerLayer from '../src/components/DrawerLayer.jsx';
import '../src/player.css';
import '../src/wall.css';
import '../src/mobileSurfaces.css';
import '../src/mobilePlayer.css';
window.drawerAnimationCalls=[];
const nativeAnimate=Element.prototype.animate;
Element.prototype.animate=function(...args){if(this.classList.contains('mv-drawer'))window.drawerAnimationCalls.push({frames:args[0],timing:args[1]});return nativeAnimate.apply(this,args);};
function Lab(){const [open,setOpen]=useState(false);return <main className="mv-workspace style-wall theme-dark" data-presentation="mobile" data-input="touch" data-host="Android"><div className={`mv-scene ${open?'is-drawer-behind':''}`} inert={open}><ActionButton aria-label="打开侧边栏" onClick={()=>setOpen(true)}>打开</ActionButton></div><DrawerLayer open={open} className="mv-drawer-shade"><section className="mv-drawer"><ActionButton aria-label="关闭侧边栏" onClick={()=>setOpen(false)}>关闭</ActionButton><p>合成组件夹具，不连接音乐库。</p></section></DrawerLayer></main>;}
createRoot(document.getElementById('root')).render(<Lab/>);
