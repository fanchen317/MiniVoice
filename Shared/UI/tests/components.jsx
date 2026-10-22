import React,{useState} from 'react';
import {createRoot} from 'react-dom/client';
import {MenuPopover} from '../src/components/Menu.jsx';
import Slider from '../src/components/Slider.jsx';
import '../src/components/foundation.css';
import './components.css';
function Lab(){const [menu,setMenu]=useState(null),[chosen,setChosen]=useState(''),[value,setValue]=useState(20),[commits,setCommits]=useState(0);return <main data-presentation="desktop"><h1>MiniVoice 自有组件交互回归</h1><p>合成测试页面，不连接音乐库或音频服务。</p><button id="launch" onClick={event=>setMenu({x:innerWidth-12,y:innerHeight-12,origin:event.currentTarget})}>打开边缘菜单</button><p id="chosen">{chosen}</p><div id="slider-fixture"><Slider label="测试进度" min={0} max={100} step={1} value={value} onCommit={next=>{setValue(next);setCommits(count=>count+1);}}/></div><p id="commits">{commits}</p><button id="reset" onClick={()=>setValue(0)}>模拟轮询归零</button>{menu&&<MenuPopover label="测试操作" point={menu} origin={menu.origin} onClose={()=>setMenu(null)} className="lab-menu">{[['播放',false],['不可用',true],['加入歌单',false],['删除歌曲',false]].map(([label,disabled])=><button key={label} disabled={disabled} onClick={()=>{setChosen(label);setMenu(null);}}>{label}</button>)}</MenuPopover>}</main>;}
createRoot(document.getElementById('root')).render(<Lab/>);
