import {FeedbackContext} from '../src/components/FeedbackContext.jsx';
import Disclosure from '../src/components/Disclosure.jsx';
import ActionButton from '../src/components/ActionButton.jsx';
import Choice from '../src/components/Choice.jsx';
import CheckControl from '../src/components/CheckControl.jsx';
import React,{useState} from 'react';
import {createRoot} from 'react-dom/client';
import {MenuPopover} from '../src/components/Menu.jsx';
import Slider from '../src/components/Slider.jsx';
import '../src/components/foundation.css';
import './components.css';
function recordFeedback(){window.feedbackCount=(window.feedbackCount||0)+1;}
function Lab(){const [menu,setMenu]=useState(null),[chosen,setChosen]=useState(''),[value,setValue]=useState(20),[commits,setCommits]=useState(0),[choice,setChoice]=useState('title'),[checked,setChecked]=useState(false);return <FeedbackContext.Provider value={recordFeedback}><main data-presentation="desktop"><ActionButton id="feedback" onClick={()=>setCommits(count=>count+1)}>交互反馈</ActionButton><ActionButton id="busy-feedback" busy onClick={()=>setCommits(count=>count+100)}>忙碌</ActionButton><Disclosure title="测试折叠面板"><input aria-label="折叠草稿" defaultValue="保留草稿"/></Disclosure><Disclosure title="禁用折叠面板" disabled>不可打开</Disclosure><h1>MiniVoice 自有组件交互回归</h1><p>合成测试页面，不连接音乐库或音频服务。</p><ActionButton id="launch" onClick={event=>setMenu({x:innerWidth-12,y:innerHeight-12,origin:event.currentTarget})}>打开边缘菜单</ActionButton><p id="chosen">{chosen}</p><div id="slider-fixture"><Slider label="测试进度" min={0} max={100} step={1} value={value} onCommit={next=>{setValue(next);setCommits(count=>count+1);}}/></div><p id="commits">{commits}</p><div id="choice-fixture"><Choice label="测试排序" value={choice} onChange={setChoice} options={[{value:'title',label:'歌曲名称'},{value:'artist',label:'歌手'},{value:'album',label:'专辑'}]}/><p id="choice-value">{choice}</p></div><CheckControl label="测试勾选" checked={checked} onCheckedChange={setChecked}/><ActionButton id="reset" onClick={()=>setValue(0)}>模拟轮询归零</ActionButton>{menu&&<MenuPopover label="测试操作" point={menu} origin={menu.origin} onClose={()=>setMenu(null)} className="lab-menu">{[['播放',false],['不可用',true],['加入歌单',false],['删除歌曲',false]].map(([label,disabled])=><ActionButton key={label} disabled={disabled} onClick={()=>{setChosen(label);setMenu(null);}}>{label}</ActionButton>)}</MenuPopover>}</main></FeedbackContext.Provider>;}
createRoot(document.getElementById('root')).render(<Lab/>);
