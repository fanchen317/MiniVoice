import React,{useEffect,useState} from 'react';

export default function MobileSettings({adapter,snapshot,style,theme,appearance,onAppearance,onExit}){
 const [settings,setSettings]=useState(null),[error,setError]=useState(''),[pending,setPending]=useState(false),[confirm,setConfirm]=useState(null),[notice,setNotice]=useState('');
 const refresh=()=>adapter.action('getSettings').then(setSettings);
 useEffect(()=>{let alive=true;adapter.action('getSettings').then(value=>{if(alive)setSettings(value);}).catch(failure=>{if(alive)setError(failure.message);});const focus=()=>refresh().catch(()=>{});globalThis.addEventListener('focus',focus);const timer=setInterval(()=>refresh().catch(()=>{}),2500);return()=>{alive=false;clearInterval(timer);globalThis.removeEventListener('focus',focus);};},[adapter]);
 const supports=name=>(settings?.actions||[]).includes(name);
 async function perform(name,payload={}){if(pending)return;setPending(true);setError('');try{await adapter.action(name,payload);await refresh();setConfirm(null);if(name==='rescan')setNotice('已开始扫描音乐库');if(name==='exportDiagnostics')setNotice('请选择诊断报告的保存位置');}catch(failure){setError(failure.message||String(failure));}finally{setPending(false);}}
 return <div className="mv-mobile-settings" aria-busy={pending}>
  {error&&<p role="alert" className="mv-inline-error">{error}</p>}{notice&&<p role="status" className="mv-settings-note">{notice}</p>}
  {confirm?<><h3>{confirm.name==='removeFolder'?'移除音乐文件夹？':'清空最近播放记录？'}</h3><p>{confirm.name==='removeFolder'?`移除“${confirm.label}”的授权和音乐库索引，音乐文件会保留。`:'只清空播放记录，歌曲、收藏和歌单会保留。'}</p><div className="mv-confirm-actions"><button disabled={pending} onClick={()=>setConfirm(null)}>取消</button><button className="mv-danger" disabled={pending} onClick={()=>perform(confirm.name,confirm.payload)}>确认</button></div></>:<>
   <h3>外观与样式</h3><div className="mv-style-picker">{[['simple','简易'],['library','音乐库'],['wall','音乐墙']].map(([value,label])=><button key={value} aria-pressed={style===value} onClick={()=>onAppearance({style:value})}>{label}</button>)}</div>
   { [['system','跟随系统'],['light','浅色模式'],['dark','深色模式']].map(([value,label])=><button key={value} className="mv-option" onClick={()=>onAppearance({theme:value})}>{label}<span>{(appearance.theme||'system')===value?'✓':''}</span></button>)}
   <h3>音乐文件夹</h3>{!settings?<p role="status">正在读取设置…</p>:settings.folders.length===0?<p className="mv-settings-note">尚未添加音乐文件夹</p>:settings.folders.map(folder=><div className="mv-folder-row" key={folder.id}><span><strong>{folder.name}</strong><small>{folder.path}</small></span>{supports('removeFolder')&&<button aria-label={`移除文件夹 ${folder.name}`} disabled={pending} onClick={()=>setConfirm({name:'removeFolder',label:folder.name,payload:{folder:folder.id}})}>移除</button>}</div>)}
   {supports('chooseFolder')&&<button className="mv-option" disabled={pending} onClick={()=>perform('chooseFolder')}>添加音乐文件夹 <span>＋</span></button>}
   <h3>音乐库</h3><p className="mv-settings-note">{snapshot.songs.length} 首歌曲{snapshot.scanning?' · 正在扫描':''}</p>
   {supports('recursive')&&<label className="mv-option">包含子文件夹<input type="checkbox" aria-label="包含子文件夹" checked={settings.recursive} disabled={pending} onChange={event=>perform('recursive',{value:event.target.checked})}/></label>}
   {supports('rescan')&&<button className="mv-option" disabled={pending||snapshot.scanning} onClick={()=>perform('rescan')}>{snapshot.scanning?snapshot.scanDetail||'正在扫描…':'重新扫描音乐库'}</button>}
   {supports('clearRecent')&&<button className="mv-option" disabled={pending} onClick={()=>setConfirm({name:'clearRecent',payload:{}})}>清空最近播放记录</button>}
   {supports('exportDiagnostics')&&<><h3>诊断与稳定性</h3><button className="mv-option" disabled={pending} onClick={()=>perform('exportDiagnostics')}>导出诊断报告<small>{settings.crashCount||0} 次本地崩溃记录</small></button></>}
   <button className="mv-option" onClick={()=>adapter.action('settings').catch(failure=>setError(failure.message))}>缓存、音乐库检查与其他设置 <span>›</span></button><button className="mv-option" onClick={onExit}>返回当前播放器</button>
  </>}
 </div>;
}
