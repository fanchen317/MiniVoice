function createPanelWindows({BrowserWindow,screen,index,preload,parent,events,isQuitting}){
 const windows=new Map();
 function open(surface){
  const key=surface.type==='settings'?'settings':`editor:${surface.id}`;
  if(windows.has(key)){const current=windows.get(key);if(current.isMinimized())current.restore();current.show();current.focus();return current;}
  const area=screen.getDisplayMatching(parent()?.getBounds()||screen.getPrimaryDisplay().workArea).workArea;
  const target=new BrowserWindow({width:Math.min(1040,area.width),height:Math.min(780,area.height),minWidth:Math.min(760,area.width),minHeight:Math.min(580,area.height),show:false,title:surface.type==='settings'?'设置':'歌曲编辑',backgroundColor:'#17231d',parent:parent(),modal:false,autoHideMenuBar:true,webPreferences:{preload,contextIsolation:true,sandbox:true,nodeIntegration:false,spellcheck:false}});
  windows.set(key,target);target.webContents.setWindowOpenHandler(()=>({action:'deny'}));target.webContents.on('will-navigate',event=>event.preventDefault());
  target.webContents.on('did-finish-load',()=>{for(const [event,data]of events())if(event!=='uiSurface')target.webContents.send('engine:event',{event,data});});
  target.once('ready-to-show',()=>target.show());
  target.on('close',event=>{if(!isQuitting()){event.preventDefault();target.webContents.send('engine:event',{event:'panelClose',data:null});}});
  target.on('closed',()=>windows.delete(key));
  target.loadFile(index,{query:{surface:'panel',panel:surface.type,...(surface.id?{id:surface.id}:{})}});return target;
 }
 return {open,all:()=>[...windows.values()].filter(w=>!w.isDestroyed()),owns:sender=>[...windows.values()].some(w=>!w.isDestroyed()&&w.webContents===sender),close:sender=>{const target=[...windows.values()].find(w=>w.webContents===sender);target?.destroy();},broadcast:(event,data)=>{for(const w of windows.values())if(!w.isDestroyed())w.webContents.send('engine:event',{event,data});}};
}
module.exports={createPanelWindows};
